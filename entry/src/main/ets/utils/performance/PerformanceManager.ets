import { Logger } from './Logger';
import { ParseTaskQueue, ParseTaskPriority, ParseTaskType, TaskQueueConfig } from './ParseTaskQueue';
import { ResourceMonitor, ResourceLevel, ResourceThresholds, MonitorConfig } from './ResourceMonitor';
import { ReadingBehaviorMonitor, ReadingState, MonitorConfig as BehaviorMonitorConfig } from './ReadingBehaviorMonitor';
import { SmartStopEngine, EngineConfig, StopDecision, StopReason } from './SmartStopEngine';
import { ProgressiveContentLoader, PreloadConfig, LoadState, ProgressiveLoadResult, LoadChapterOptions } from './ProgressiveContentLoader';
import { Chapter } from '../../models/Book';
import { BookSource } from '../../models/BookSource';

const TAG = 'PerformanceManager';

export interface PerformanceConfig {
  taskQueue: TaskQueueConfig;
  resourceMonitor: MonitorConfig;
  resourceThresholds: ResourceThresholds;
  behaviorMonitor: BehaviorMonitorConfig;
  smartStopEngine: EngineConfig;
  preload: PreloadConfig;
  enableAllOptimizations: boolean;
  logLevel: string;
}

export interface PerformanceStatus {
  isInitialized: boolean;
  isActive: boolean;
  resourceLevel: ResourceLevel;
  readingState: ReadingState;
  activeTaskCount: number;
  queuedTaskCount: number;
  cachedChapterCount: number;
  preloadQueueSize: number;
  lastDecision: StopDecision;
  lastDecisionReason: StopReason;
}

export interface PerformanceReport {
  timestamp: number;
  uptime: number;
  resource: ResourceStats;
  behavior: BehaviorStats;
  tasks: TaskStats;
  cache: CacheStats;
  recommendations: string[];
}

interface ResourceStats {
  level: ResourceLevel;
  score: number;
  cpuUsage: number;
  memoryUsage: number;
}

interface BehaviorStats {
  state: ReadingState;
  engagementScore: number;
  sessionDuration: number;
}

interface TaskStats {
  completed: number;
  cancelled: number;
  averageTime: number;
}

interface CacheStats {
  hits: number;
  misses: number;
  hitRate: number;
}

export class PerformanceManager {
  private static instance: PerformanceManager | null = null;
  private taskQueue: ParseTaskQueue;
  private resourceMonitor: ResourceMonitor;
  private behaviorMonitor: ReadingBehaviorMonitor;
  private smartStopEngine: SmartStopEngine;
  private progressiveLoader: ProgressiveContentLoader;

  private isInitialized: boolean = false;
  private isActive: boolean = false;
  private startTime: number = 0;
  private config: PerformanceConfig = {
    taskQueue: {
      maxConcurrent: 3,
      maxQueueSize: 100,
      taskTimeout: 30000,
      retryDelay: 1000,
      enablePriorityAging: true,
      priorityAgingInterval: 5000
    },
    resourceMonitor: {
      sampleInterval: 5000,
      historySize: 60,
      enableThermalMonitoring: true,
      enableBatteryMonitoring: true,
      enableNetworkMonitoring: true
    },
    resourceThresholds: {
      cpuHigh: 70,
      cpuCritical: 90,
      memoryHigh: 75,
      memoryCritical: 90,
      batteryLow: 20,
      thermalWarning: 2,
      thermalCritical: 3
    },
    behaviorMonitor: {
      scrollEventThreshold: 50,
      pauseDetectionDelay: 3000,
      sessionTimeout: 300000,
      engagementThreshold: 0.6,
      maxScrollEventsHistory: 100,
      behaviorAnalysisInterval: 10000
    },
    smartStopEngine: {
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
    },
    preload: {
      maxPreloadCount: 5,
      preloadDistance: 3,
      enableSmartPreload: true,
      minEngagementForPreload: 0.5,
      resourceThresholdForPreload: ResourceLevel.NORMAL
    },
    enableAllOptimizations: true,
    logLevel: 'info'
  };

  private onStatusChange?: (status: PerformanceStatus) => void;
  private onResourceWarning?: (level: ResourceLevel, message: string) => void;
  private onDecisionMade?: (decision: StopDecision, reason: StopReason) => void;

  private constructor() {
    this.taskQueue = ParseTaskQueue.getInstance();
    this.resourceMonitor = ResourceMonitor.getInstance();
    this.behaviorMonitor = ReadingBehaviorMonitor.getInstance();
    this.smartStopEngine = SmartStopEngine.getInstance();
    this.progressiveLoader = ProgressiveContentLoader.getInstance();
  }

  static getInstance(): PerformanceManager {
    if (!PerformanceManager.instance) {
      PerformanceManager.instance = new PerformanceManager();
    }
    return PerformanceManager.instance;
  }

  initialize(config?: PerformanceConfig): void {
    if (this.isInitialized) {
      Logger.warn(TAG, '性能管理器已初始化');
      return;
    }

    if (config) {
      this.config = this.mergeConfig(this.config, config);
    }

    this.applyConfig();
    this.setupInternalCallbacks();

    this.isInitialized = true;
    this.startTime = Date.now();

    Logger.info(TAG, '性能管理器初始化完成');
  }

  private mergeConfig(base: PerformanceConfig, override: PerformanceConfig): PerformanceConfig {
    return {
      taskQueue: override.taskQueue ?? base.taskQueue,
      resourceMonitor: override.resourceMonitor ?? base.resourceMonitor,
      resourceThresholds: override.resourceThresholds ?? base.resourceThresholds,
      behaviorMonitor: override.behaviorMonitor ?? base.behaviorMonitor,
      smartStopEngine: override.smartStopEngine ?? base.smartStopEngine,
      preload: override.preload ?? base.preload,
      enableAllOptimizations: override.enableAllOptimizations ?? base.enableAllOptimizations,
      logLevel: override.logLevel ?? base.logLevel
    };
  }

  private applyConfig(): void {
    this.taskQueue.setConfig(this.config.taskQueue);
    this.resourceMonitor.setConfig(this.config.resourceMonitor);
    this.resourceMonitor.setThresholds(this.config.resourceThresholds);
    this.behaviorMonitor.setConfig(this.config.behaviorMonitor);
    this.smartStopEngine.setConfig(this.config.smartStopEngine);
    this.progressiveLoader.setPreloadConfig(this.config.preload);
  }

  private setupInternalCallbacks(): void {
    this.resourceMonitor.setOnResourceWarning((level: ResourceLevel, message: string) => {
      Logger.warn(TAG, `资源警告 [${level}]: ${message}`);
      this.onResourceWarning?.(level, message);
      this.notifyStatusChange();
    });

    this.smartStopEngine.setOnDecision((result) => {
      Logger.info(TAG, `决策: ${result.decision}, 原因: ${result.reason}`);
      this.onDecisionMade?.(result.decision, result.reason);
      this.notifyStatusChange();
    });

    this.behaviorMonitor.setOnStateChange(() => {
      this.notifyStatusChange();
    });
  }

  start(): void {
    if (!this.isInitialized) {
      this.initialize();
    }

    if (this.isActive) {
      Logger.warn(TAG, '性能管理器已在运行');
      return;
    }

    this.resourceMonitor.startMonitoring();
    this.isActive = true;

    Logger.info(TAG, '性能管理器已启动');
    this.notifyStatusChange();
  }

  stop(): void {
    if (!this.isActive) return;

    this.resourceMonitor.stopMonitoring();
    this.progressiveLoader.cancelAllLoads();
    this.taskQueue.pauseQueue();

    this.isActive = false;

    Logger.info(TAG, '性能管理器已停止');
    this.notifyStatusChange();
  }

  pause(): void {
    this.taskQueue.pauseQueue();
    Logger.info(TAG, '性能管理器已暂停');
  }

  resume(): void {
    this.taskQueue.resumeQueue();
    Logger.info(TAG, '性能管理器已恢复');
  }

  setBookContext(bookId: string, chapters: Chapter[], bookSource: BookSource): void {
    this.progressiveLoader.setBookContext(bookId, chapters, bookSource);
    const firstChapterId = chapters[0]?.id ?? '';
    this.behaviorMonitor.startReadingSession(bookId, firstChapterId);
  }

  setCurrentChapter(chapterId: string, chapterIndex: number): void {
    this.progressiveLoader.setCurrentChapter(chapterId, chapterIndex);
    this.behaviorMonitor.recordChapterChange(chapterId);
  }

  recordScroll(direction: string, distance: number, speed: number): void {
    this.behaviorMonitor.recordScroll(direction as 'up' | 'down', distance, speed);
  }

  recordPause(): void {
    this.behaviorMonitor.recordPause('user');
  }

  recordResume(): void {
    this.behaviorMonitor.recordResume();
  }

  recordAppBackground(): void {
    this.behaviorMonitor.recordAppBackground();
  }

  recordAppForeground(): void {
    this.behaviorMonitor.recordAppForeground();
  }

  async loadChapter(
    chapterId: string,
    chapterUrl: string,
    options?: LoadChapterOptions
  ): Promise<string> {
    return this.progressiveLoader.loadChapter(chapterId, chapterUrl, options);
  }

  cancelLoad(chapterId: string): boolean {
    return this.progressiveLoader.cancelLoad(chapterId);
  }

  cancelAllLoads(): void {
    this.progressiveLoader.cancelAllLoads();
  }

  getStatus(): PerformanceStatus {
    const resourceMetrics = this.resourceMonitor.getCurrentMetrics();
    const behaviorStats = this.behaviorMonitor.getBehaviorStats();
    const queueStats = this.taskQueue.getQueueStats();
    const loaderStats = this.progressiveLoader.getStats();
    const lastDecision = this.smartStopEngine.getLastDecision();

    return {
      isInitialized: this.isInitialized,
      isActive: this.isActive,
      resourceLevel: resourceMetrics?.overall.level ?? ResourceLevel.NORMAL,
      readingState: behaviorStats.readingState,
      activeTaskCount: queueStats.runningCount,
      queuedTaskCount: queueStats.queueLength,
      cachedChapterCount: loaderStats.totalLoaded,
      preloadQueueSize: loaderStats.preloadQueueSize,
      lastDecision: lastDecision?.decision ?? StopDecision.CONTINUE,
      lastDecisionReason: lastDecision?.reason ?? StopReason.NONE
    };
  }

  getReport(): PerformanceReport {
    const resourceMetrics = this.resourceMonitor.getCurrentMetrics();
    const behaviorStats = this.behaviorMonitor.getBehaviorStats();
    const loaderStats = this.progressiveLoader.getStats();

    const recommendations: string[] = [];

    if (resourceMetrics && resourceMetrics.overall.level !== ResourceLevel.ABUNDANT) {
      recommendations.push(...resourceMetrics.overall.recommendations);
    }

    if (behaviorStats.engagementScore < 0.5) {
      recommendations.push('用户参与度较低，建议减少后台活动');
    }

    if (loaderStats.cacheMisses > loaderStats.cacheHits) {
      recommendations.push('缓存命中率较低，建议增加预加载数量');
    }

    const totalCacheRequests = loaderStats.cacheHits + loaderStats.cacheMisses;
    const hitRate = totalCacheRequests > 0 ? loaderStats.cacheHits / totalCacheRequests : 0;

    const resourceStats: ResourceStats = {
      level: resourceMetrics?.overall.level ?? ResourceLevel.NORMAL,
      score: resourceMetrics?.overall.score ?? 100,
      cpuUsage: resourceMetrics?.cpu.usage ?? 0,
      memoryUsage: resourceMetrics?.memory.usagePercent ?? 0
    };

    const behaviorStatsResult: BehaviorStats = {
      state: behaviorStats.readingState,
      engagementScore: behaviorStats.engagementScore,
      sessionDuration: behaviorStats.sessionDuration
    };

    const taskStats: TaskStats = {
      completed: loaderStats.totalLoaded,
      cancelled: loaderStats.cancelledLoads,
      averageTime: loaderStats.averageLoadTime
    };

    const cacheStats: CacheStats = {
      hits: loaderStats.cacheHits,
      misses: loaderStats.cacheMisses,
      hitRate: hitRate
    };

    return {
      timestamp: Date.now(),
      uptime: Date.now() - this.startTime,
      resource: resourceStats,
      behavior: behaviorStatsResult,
      tasks: taskStats,
      cache: cacheStats,
      recommendations: recommendations
    };
  }

  canHandleNewTask(): boolean {
    return this.resourceMonitor.canHandleNewTask();
  }

  getSuggestedConcurrency(): number {
    return this.resourceMonitor.getSuggestedConcurrency();
  }

  getResourceLevel(): ResourceLevel {
    return this.resourceMonitor.getResourceLevel();
  }

  getReadingState(): ReadingState {
    return this.behaviorMonitor.getCurrentState();
  }

  hasCachedContent(chapterId: string): boolean {
    return this.progressiveLoader.hasCachedContent(chapterId);
  }

  getCachedContent(chapterId: string): ProgressiveLoadResult | undefined {
    return this.progressiveLoader.getCachedContent(chapterId);
  }

  setConfig(config: PerformanceConfig): void {
    this.config = this.mergeConfig(this.config, config);
    this.applyConfig();
  }

  setOnStatusChange(callback: (status: PerformanceStatus) => void): void {
    this.onStatusChange = callback;
  }

  setOnResourceWarning(callback: (level: ResourceLevel, message: string) => void): void {
    this.onResourceWarning = callback;
  }

  setOnDecisionMade(callback: (decision: StopDecision, reason: StopReason) => void): void {
    this.onDecisionMade = callback;
  }

  private notifyStatusChange(): void {
    this.onStatusChange?.(this.getStatus());
  }

  clearCache(): void {
    this.progressiveLoader.clearCache();
  }

  reset(): void {
    this.stop();
    this.progressiveLoader.destroy();
    this.taskQueue.clearCompletedTasks();
    this.start();
  }

  destroy(): void {
    this.stop();

    this.taskQueue.destroy();
    this.resourceMonitor.destroy();
    this.behaviorMonitor.destroy();
    this.smartStopEngine.destroy();
    this.progressiveLoader.destroy();

    this.isInitialized = false;

    Logger.info(TAG, '性能管理器已销毁');
  }
}



export default PerformanceManager.getInstance();
