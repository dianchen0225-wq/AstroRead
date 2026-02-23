import { Logger } from './Logger';
import { ResourceMonitor, ResourceLevel } from './ResourceMonitor';
import { ReadingBehaviorMonitor, ReadingState, ReadingBehaviorStats, BehaviorPrediction } from './ReadingBehaviorMonitor';
import { ParseTaskQueue, ParseTaskPriority, ParseTaskStatus, ParseTaskType } from './ParseTaskQueue';

const TAG = 'SmartStopEngine';

export enum StopDecision {
  CONTINUE = 'continue',
  PAUSE = 'pause',
  STOP = 'stop',
  TERMINATE = 'terminate'
}

export enum StopReason {
  NONE = 'none',
  USER_LEFT = 'user_left',
  USER_IDLE = 'user_idle',
  LOW_ENGAGEMENT = 'low_engagement',
  CHAPTER_CHANGE = 'chapter_change',
  RESOURCE_CRITICAL = 'resource_critical',
  MEMORY_PRESSURE = 'memory_pressure',
  THERMAL_WARNING = 'thermal_warning',
  BATTERY_LOW = 'battery_low',
  NETWORK_ISSUE = 'network_issue',
  TASK_TIMEOUT = 'task_timeout',
  MANUAL_STOP = 'manual_stop',
  COMPLETED = 'completed'
}

export interface StopContext {
  bookId: string;
  chapterId?: string;
  taskId?: string;
  taskType: ParseTaskType;
  progress: number;
  elapsed: number;
  remainingItems: number;
}

export interface StopDecisionResult {
  decision: StopDecision;
  reason: StopReason;
  confidence: number;
  shouldCancelRunning: boolean;
  shouldPauseQueue: boolean;
  affectedTaskIds: string[];
  message: string;
  suggestedAction?: string;
}

export interface DecisionFactors {
  resource: ResourceFactor;
  behavior: BehaviorFactor;
  task: TaskFactor;
  weights: DecisionWeights;
}

export interface ResourceFactor {
  level: ResourceLevel;
  score: number;
  cpuUsage: number;
  memoryUsage: number;
  thermalStatus: string;
  batteryLevel: number;
  isCharging: boolean;
  networkConnected: boolean;
}

export interface BehaviorFactor {
  state: ReadingState;
  engagementScore: number;
  sessionDuration: number;
  scrollActivity: number;
  pauseCount: number;
  likelyToContinue: boolean;
}

export interface TaskFactor {
  progress: number;
  elapsed: number;
  priority: ParseTaskPriority;
  retryCount: number;
  hasPartialResults: boolean;
  estimatedRemaining: number;
}

export interface DecisionWeights {
  resource: number;
  behavior: number;
  task: number;
  progress: number;
}

export interface EngineConfig {
  enableAutoStop: boolean;
  enableAdaptivePriority: boolean;
  enableResourceAware: boolean;
  enableBehaviorAware: boolean;
  idleTimeout: number;
  lowEngagementThreshold: number;
  criticalResourceThreshold: number;
  minProgressToKeep: number;
  maxIdleTimeBeforeStop: number;
  decisionInterval: number;
}

interface TaskTrackingInfo {
  taskId: string;
  bookId: string;
  chapterId?: string;
  type: ParseTaskType;
  startTime: number;
  lastProgressUpdate: number;
  progress: number;
  partialResults: object[];
  stopRequested: boolean;
}

export class SmartStopEngine {
  private static instance: SmartStopEngine | null = null;
  private resourceMonitor: ResourceMonitor;
  private behaviorMonitor: ReadingBehaviorMonitor;
  private taskQueue: ParseTaskQueue;
  private trackedTasks: Map<string, TaskTrackingInfo> = new Map();
  private decisionTimer: number = 0;
  private lastDecision: StopDecisionResult | null = null;
  private decisionHistory: StopDecisionResult[] = [];
  private config: EngineConfig = {
    enableAutoStop: true,
    enableAdaptivePriority: true,
    enableResourceAware: true,
    enableBehaviorAware: true,
    idleTimeout: 60000,
    lowEngagementThreshold: 0.4,
    criticalResourceThreshold: 30,
    minProgressToKeep: 0.1,
    maxIdleTimeBeforeStop: 120000,
    decisionInterval: 5000
  };
  private onDecision?: (result: StopDecisionResult) => void;
  private onStopRequested?: (taskId: string, reason: StopReason) => void;

  private constructor() {
    this.resourceMonitor = ResourceMonitor.getInstance();
    this.behaviorMonitor = ReadingBehaviorMonitor.getInstance();
    this.taskQueue = ParseTaskQueue.getInstance();

    this.setupCallbacks();
    this.startDecisionLoop();
  }

  static getInstance(): SmartStopEngine {
    if (!SmartStopEngine.instance) {
      SmartStopEngine.instance = new SmartStopEngine();
    }
    return SmartStopEngine.instance;
  }

  private setupCallbacks(): void {
    this.resourceMonitor.setOnResourceWarning((level: ResourceLevel, message: string) => {
      if (level === ResourceLevel.CRITICAL) {
        this.handleCriticalResource(message);
      }
    });

    this.behaviorMonitor.setOnStateChange((state: ReadingState) => {
      this.handleBehaviorStateChange(state);
    });

    this.behaviorMonitor.setOnPredictionUpdate((prediction: BehaviorPrediction) => {
      this.handleBehaviorPrediction(prediction);
    });
  }

  private startDecisionLoop(): void {
    this.decisionTimer = setInterval(() => {
      if (this.config.enableAutoStop) {
        this.evaluateAndDecide();
      }
    }, this.config.decisionInterval);
  }

  trackTask(taskId: string, bookId: string, type: ParseTaskType, chapterId?: string): void {
    const now = Date.now();
    this.trackedTasks.set(taskId, {
      taskId,
      bookId,
      chapterId,
      type,
      startTime: now,
      lastProgressUpdate: now,
      progress: 0,
      partialResults: [],
      stopRequested: false
    });

    Logger.debug(TAG, `开始跟踪任务: ${taskId}, 类型: ${type}`);
  }

  updateTaskProgress(taskId: string, progress: number, partialResults?: object[]): void {
    const task = this.trackedTasks.get(taskId);
    if (task) {
      task.progress = progress;
      task.lastProgressUpdate = Date.now();
      if (partialResults) {
        task.partialResults = partialResults;
      }
    }
  }

  untrackTask(taskId: string): void {
    this.trackedTasks.delete(taskId);
    Logger.debug(TAG, `停止跟踪任务: ${taskId}`);
  }

  private handleCriticalResource(message: string): void {
    Logger.warn(TAG, `资源严重警告: ${message}`);

    const decision = this.makeEmergencyDecision(message);
    this.executeDecision(decision);
  }

  private handleBehaviorStateChange(state: ReadingState): void {
    if (!this.config.enableBehaviorAware) return;

    Logger.debug(TAG, `行为状态变更: ${state}`);

    switch (state) {
      case ReadingState.IDLE:
        this.checkIdleStop();
        break;
      case ReadingState.APP_BACKGROUND:
        this.handleAppBackground();
        break;
      case ReadingState.CHAPTER_CHANGE:
        this.handleChapterChange();
        break;
      default:
        break;
    }
  }

  private handleBehaviorPrediction(prediction: BehaviorPrediction): void {
    if (!this.config.enableBehaviorAware) return;

    if (!prediction.likelyToContinue && prediction.confidence > 0.7) {
      Logger.info(TAG, '预测用户不太可能继续阅读，考虑停止后台任务');

      const stats = this.behaviorMonitor.getBehaviorStats();
      if (stats.sessionDuration > 30000) {
        this.considerStoppingLowPriorityTasks(stats.currentBookId);
      }
    }
  }

  private evaluateAndDecide(): void {
    if (this.trackedTasks.size === 0) return;

    const factors = this.collectDecisionFactors();
    const decision = this.makeDecision(factors);

    if (decision.decision !== StopDecision.CONTINUE) {
      this.executeDecision(decision);
    }

    this.lastDecision = decision;
    this.decisionHistory.push(decision);
    if (this.decisionHistory.length > 100) {
      this.decisionHistory.shift();
    }

    this.onDecision?.(decision);
  }

  private collectDecisionFactors(): DecisionFactors {
    const resourceMetrics = this.resourceMonitor.getCurrentMetrics();
    const behaviorStats = this.behaviorMonitor.getBehaviorStats();

    const resourceFactor: ResourceFactor = {
      level: resourceMetrics?.overall.level ?? ResourceLevel.NORMAL,
      score: resourceMetrics?.overall.score ?? 100,
      cpuUsage: resourceMetrics?.cpu.usage ?? 0,
      memoryUsage: resourceMetrics?.memory.usagePercent ?? 0,
      thermalStatus: resourceMetrics?.thermal.status ?? 'normal',
      batteryLevel: resourceMetrics?.battery.level ?? 100,
      isCharging: resourceMetrics?.battery.isCharging ?? true,
      networkConnected: resourceMetrics?.network.isConnected ?? true
    };

    const behaviorFactor: BehaviorFactor = {
      state: behaviorStats.readingState,
      engagementScore: behaviorStats.engagementScore,
      sessionDuration: behaviorStats.sessionDuration,
      scrollActivity: behaviorStats.scrollCount,
      pauseCount: behaviorStats.pauseCount,
      likelyToContinue: true
    };

    const prediction = this.behaviorMonitor.predictBehavior(behaviorStats);
    behaviorFactor.likelyToContinue = prediction.likelyToContinue;

    const taskFactor: TaskFactor = this.calculateAggregateTaskFactor();

    const weights: DecisionWeights = this.calculateWeights(resourceFactor, behaviorFactor);

    return {
      resource: resourceFactor,
      behavior: behaviorFactor,
      task: taskFactor,
      weights
    };
  }

  private calculateAggregateTaskFactor(): TaskFactor {
    const tasks = Array.from(this.trackedTasks.values());

    if (tasks.length === 0) {
      return {
        progress: 0,
        elapsed: 0,
        priority: ParseTaskPriority.NORMAL,
        retryCount: 0,
        hasPartialResults: false,
        estimatedRemaining: 0
      };
    }

    const avgProgress = tasks.reduce((sum, t) => sum + t.progress, 0) / tasks.length;
    const now = Date.now();
    const avgElapsed = tasks.reduce((sum, t) => sum + (now - t.startTime), 0) / tasks.length;
    const hasPartialResults = tasks.some(t => t.partialResults.length > 0);

    return {
      progress: avgProgress,
      elapsed: avgElapsed,
      priority: ParseTaskPriority.NORMAL,
      retryCount: 0,
      hasPartialResults,
      estimatedRemaining: avgElapsed * (1 - avgProgress / 100)
    };
  }

  private calculateWeights(resource: ResourceFactor, behavior: BehaviorFactor): DecisionWeights {
    let resourceWeight = 0.3;
    let behaviorWeight = 0.3;
    let taskWeight = 0.2;
    let progressWeight = 0.2;

    if (resource.level === ResourceLevel.CRITICAL) {
      resourceWeight = 0.6;
      behaviorWeight = 0.15;
      taskWeight = 0.15;
      progressWeight = 0.1;
    } else if (resource.level === ResourceLevel.LOW) {
      resourceWeight = 0.4;
      behaviorWeight = 0.25;
      taskWeight = 0.2;
      progressWeight = 0.15;
    }

    if (behavior.state === ReadingState.IDLE || behavior.state === ReadingState.APP_BACKGROUND) {
      behaviorWeight = Math.min(0.5, behaviorWeight + 0.2);
    }

    return {
      resource: resourceWeight,
      behavior: behaviorWeight,
      task: taskWeight,
      progress: progressWeight
    };
  }

  private makeDecision(factors: DecisionFactors): StopDecisionResult {
    const resource = factors.resource;
    const behavior = factors.behavior;
    const task = factors.task;
    const weights = factors.weights;

    if (resource.level === ResourceLevel.CRITICAL) {
      return this.createStopResult(
        StopDecision.TERMINATE,
        StopReason.RESOURCE_CRITICAL,
        0.95,
        true,
        true,
        '资源严重不足，立即终止所有后台任务'
      );
    }

    if (behavior.state === ReadingState.IDLE && behavior.sessionDuration > this.config.maxIdleTimeBeforeStop) {
      return this.createStopResult(
        StopDecision.STOP,
        StopReason.USER_IDLE,
        0.85,
        true,
        false,
        '用户长时间无活动，停止后台任务'
      );
    }

    if (behavior.engagementScore < this.config.lowEngagementThreshold && behavior.sessionDuration > 60000) {
      return this.createStopResult(
        StopDecision.PAUSE,
        StopReason.LOW_ENGAGEMENT,
        0.75,
        false,
        true,
        '用户参与度低，暂停后台任务'
      );
    }

    if (resource.thermalStatus === 'critical') {
      return this.createStopResult(
        StopDecision.STOP,
        StopReason.THERMAL_WARNING,
        0.9,
        true,
        true,
        '设备过热，停止后台任务'
      );
    }

    if (!resource.isCharging && resource.batteryLevel < 15) {
      return this.createStopResult(
        StopDecision.PAUSE,
        StopReason.BATTERY_LOW,
        0.8,
        false,
        true,
        '电量低，暂停后台任务'
      );
    }

    if (!resource.networkConnected) {
      return this.createStopResult(
        StopDecision.PAUSE,
        StopReason.NETWORK_ISSUE,
        0.85,
        false,
        true,
        '网络断开，暂停后台任务'
      );
    }

    if (task.progress > 80 && task.hasPartialResults) {
      return this.createStopResult(
        StopDecision.CONTINUE,
        StopReason.NONE,
        0.9,
        false,
        false,
        '任务接近完成，继续执行'
      );
    }

    return this.createStopResult(
      StopDecision.CONTINUE,
      StopReason.NONE,
      0.7,
      false,
      false,
      '继续执行任务'
    );
  }

  private createStopResult(
    decision: StopDecision,
    reason: StopReason,
    confidence: number,
    shouldCancelRunning: boolean,
    shouldPauseQueue: boolean,
    message: string
  ): StopDecisionResult {
    const affectedTaskIds = this.getAffectedTaskIds(decision);

    return {
      decision,
      reason,
      confidence,
      shouldCancelRunning,
      shouldPauseQueue,
      affectedTaskIds,
      message,
      suggestedAction: this.getSuggestedAction(decision, reason)
    };
  }

  private getAffectedTaskIds(decision: StopDecision): string[] {
    const taskIds: string[] = [];

    this.trackedTasks.forEach((task, taskId) => {
      if (decision === StopDecision.TERMINATE) {
        taskIds.push(taskId);
      } else if (decision === StopDecision.STOP) {
        if (task.progress < this.config.minProgressToKeep * 100) {
          taskIds.push(taskId);
        }
      } else if (decision === StopDecision.PAUSE) {
        if (task.type !== ParseTaskType.CHAPTER_CONTENT) {
          taskIds.push(taskId);
        }
      }
    });

    return taskIds;
  }

  private getSuggestedAction(decision: StopDecision, reason: StopReason): string {
    switch (reason) {
      case StopReason.RESOURCE_CRITICAL:
        return '释放内存或等待资源恢复';
      case StopReason.THERMAL_WARNING:
        return '让设备冷却后继续';
      case StopReason.BATTERY_LOW:
        return '连接充电器';
      case StopReason.NETWORK_ISSUE:
        return '检查网络连接';
      case StopReason.USER_IDLE:
        return '用户返回时自动恢复';
      case StopReason.LOW_ENGAGEMENT:
        return '用户重新活跃时恢复';
      default:
        return '';
    }
  }

  private executeDecision(decision: StopDecisionResult): void {
    Logger.info(TAG, `执行决策: ${decision.decision}, 原因: ${decision.reason}, 消息: ${decision.message}`);

    switch (decision.decision) {
      case StopDecision.TERMINATE:
        this.executeTerminate(decision);
        break;
      case StopDecision.STOP:
        this.executeStop(decision);
        break;
      case StopDecision.PAUSE:
        this.executePause(decision);
        break;
      case StopDecision.CONTINUE:
        break;
    }
  }

  private executeTerminate(decision: StopDecisionResult): void {
    if (decision.shouldPauseQueue) {
      this.taskQueue.pauseQueue();
    }

    for (const taskId of decision.affectedTaskIds) {
      this.taskQueue.cancelTask(taskId);
      this.onStopRequested?.(taskId, decision.reason);
    }

    this.trackedTasks.clear();
  }

  private executeStop(decision: StopDecisionResult): void {
    for (const taskId of decision.affectedTaskIds) {
      this.taskQueue.cancelTask(taskId);
      this.onStopRequested?.(taskId, decision.reason);
      this.trackedTasks.delete(taskId);
    }
  }

  private executePause(decision: StopDecisionResult): void {
    if (decision.shouldPauseQueue) {
      this.taskQueue.pauseQueue();
    }

    for (const taskId of decision.affectedTaskIds) {
      this.taskQueue.pauseTask(taskId);
    }
  }

  private makeEmergencyDecision(message: string): StopDecisionResult {
    return this.createStopResult(
      StopDecision.TERMINATE,
      StopReason.RESOURCE_CRITICAL,
      1.0,
      true,
      true,
      `紧急停止: ${message}`
    );
  }

  private checkIdleStop(): void {
    const stats = this.behaviorMonitor.getBehaviorStats();

    if (stats.sessionDuration > this.config.idleTimeout) {
      const decision = this.createStopResult(
        StopDecision.PAUSE,
        StopReason.USER_IDLE,
        0.8,
        false,
        true,
        '用户空闲超时，暂停后台任务'
      );
      this.executeDecision(decision);
    }
  }

  private handleAppBackground(): void {
    const stats = this.behaviorMonitor.getBehaviorStats();

    if (stats.engagementScore < 0.5) {
      const decision = this.createStopResult(
        StopDecision.PAUSE,
        StopReason.USER_LEFT,
        0.75,
        false,
        true,
        '应用进入后台，暂停后台任务'
      );
      this.executeDecision(decision);
    }
  }

  private handleChapterChange(): void {
    const stats = this.behaviorMonitor.getBehaviorStats();

    this.trackedTasks.forEach((task, taskId) => {
      if (task.chapterId && task.chapterId !== stats.currentChapterId) {
        if (task.progress < 50) {
          this.taskQueue.cancelTask(taskId);
          this.trackedTasks.delete(taskId);
          Logger.info(TAG, `章节切换，取消旧章节任务: ${taskId}`);
        }
      }
    });
  }

  private considerStoppingLowPriorityTasks(currentBookId: string | null): void {
    const tasksToStop: string[] = [];

    this.trackedTasks.forEach((task, taskId) => {
      if (task.bookId !== currentBookId) {
        tasksToStop.push(taskId);
      }
    });

    if (tasksToStop.length > 0) {
      const decision = this.createStopResult(
        StopDecision.STOP,
        StopReason.LOW_ENGAGEMENT,
        0.7,
        false,
        false,
        '停止非当前书籍的后台任务'
      );
      decision.affectedTaskIds = tasksToStop;
      this.executeDecision(decision);
    }
  }

  manualStop(taskId: string, reason: StopReason = StopReason.MANUAL_STOP): boolean {
    const task = this.trackedTasks.get(taskId);
    if (!task) return false;

    task.stopRequested = true;
    this.taskQueue.cancelTask(taskId);
    this.trackedTasks.delete(taskId);

    Logger.info(TAG, `手动停止任务: ${taskId}, 原因: ${reason}`);
    this.onStopRequested?.(taskId, reason);

    return true;
  }

  manualStopAll(bookId?: string): number {
    let stoppedCount = 0;

    this.trackedTasks.forEach((task, taskId) => {
      if (!bookId || task.bookId === bookId) {
        if (this.manualStop(taskId, StopReason.MANUAL_STOP)) {
          stoppedCount++;
        }
      }
    });

    return stoppedCount;
  }

  resumeAfterPause(): void {
    this.taskQueue.resumeQueue();
    Logger.info(TAG, '恢复任务队列');
  }

  getLastDecision(): StopDecisionResult | null {
    return this.lastDecision;
  }

  getDecisionHistory(): StopDecisionResult[] {
    return [...this.decisionHistory];
  }

  getTrackedTasks(): TaskTrackingInfo[] {
    return Array.from(this.trackedTasks.values());
  }

  setOnDecision(callback: (result: StopDecisionResult) => void): void {
    this.onDecision = callback;
  }

  setOnStopRequested(callback: (taskId: string, reason: StopReason) => void): void {
    this.onStopRequested = callback;
  }

  setConfig(config: Partial<EngineConfig>): void {
    if (config.enableAutoStop !== undefined) {
      this.config.enableAutoStop = config.enableAutoStop;
    }
    if (config.enableAdaptivePriority !== undefined) {
      this.config.enableAdaptivePriority = config.enableAdaptivePriority;
    }
    if (config.enableResourceAware !== undefined) {
      this.config.enableResourceAware = config.enableResourceAware;
    }
    if (config.enableBehaviorAware !== undefined) {
      this.config.enableBehaviorAware = config.enableBehaviorAware;
    }
    if (config.idleTimeout !== undefined) {
      this.config.idleTimeout = config.idleTimeout;
    }
    if (config.lowEngagementThreshold !== undefined) {
      this.config.lowEngagementThreshold = config.lowEngagementThreshold;
    }
    if (config.criticalResourceThreshold !== undefined) {
      this.config.criticalResourceThreshold = config.criticalResourceThreshold;
    }
    if (config.minProgressToKeep !== undefined) {
      this.config.minProgressToKeep = config.minProgressToKeep;
    }
    if (config.maxIdleTimeBeforeStop !== undefined) {
      this.config.maxIdleTimeBeforeStop = config.maxIdleTimeBeforeStop;
    }
    if (config.decisionInterval !== undefined) {
      this.config.decisionInterval = config.decisionInterval;
    }
  }

  destroy(): void {
    if (this.decisionTimer) {
      clearInterval(this.decisionTimer);
    }
    this.trackedTasks.clear();
    this.decisionHistory = [];
    Logger.info(TAG, '智能停止引擎已销毁');
  }
}

export default SmartStopEngine.getInstance();
