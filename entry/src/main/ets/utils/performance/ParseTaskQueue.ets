import { Logger } from '../performance/Logger';

const TAG = 'ParseTaskQueue';

export enum ParseTaskPriority {
  CRITICAL = 0,
  HIGH = 1,
  NORMAL = 2,
  LOW = 3,
  BACKGROUND = 4
}

export enum ParseTaskStatus {
  PENDING = 'pending',
  RUNNING = 'running',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  FAILED = 'failed'
}

export enum ParseTaskType {
  SEARCH = 'search',
  CHAPTER_LIST = 'chapter_list',
  CHAPTER_CONTENT = 'chapter_content',
  BOOK_DETAIL = 'book_detail',
  BATCH_CACHE = 'batch_cache'
}

export interface ParseTaskData {
  bookId?: string;
  chapterId?: string;
  chapterUrl?: string;
  bookSourceId?: string;
  searchKey?: string;
  pageIndex?: number;
  batchUrls?: string[];
  progress?: number;
}

export interface ParseTaskResult {
  taskId: string;
  success: boolean;
  data?: ESObject;
  error?: string;
  partialResults?: ESObject[];
  completedItems?: number;
  totalItems?: number;
}

export interface ParseTask {
  id: string;
  type: ParseTaskType;
  priority: ParseTaskPriority;
  status: ParseTaskStatus;
  data: ParseTaskData;
  createdAt: number;
  startedAt?: number;
  completedAt?: number;
  progress: number;
  retryCount: number;
  maxRetries: number;
  isCancelled: boolean;
  onProgress?: (progress: number) => void;
  onComplete?: (result: ParseTaskResult) => void;
  onError?: (error: Error) => void;
}

export interface TaskQueueConfig {
  maxConcurrent: number;
  maxQueueSize: number;
  taskTimeout: number;
  retryDelay: number;
  enablePriorityAging: boolean;
  priorityAgingInterval: number;
}

interface PriorityQueueItem {
  task: ParseTask;
  effectivePriority: number;
  insertionOrder: number;
}

export class ParseTaskQueue {
  private static instance: ParseTaskQueue | null = null;
  private queue: PriorityQueueItem[] = [];
  private runningTasks: Map<string, ParseTask> = new Map();
  private completedTasks: Map<string, ParseTaskResult> = new Map();
  private insertionCounter: number = 0;
  private isProcessing: boolean = false;
  private isPaused: boolean = false;
  private config: TaskQueueConfig = {
    maxConcurrent: 3,
    maxQueueSize: 100,
    taskTimeout: 30000,
    retryDelay: 1000,
    enablePriorityAging: true,
    priorityAgingInterval: 5000
  };
  private priorityAgingTimer: number = 0;
  private taskExecutors: Map<ParseTaskType, (task: ParseTask) => Promise<ParseTaskResult>> = new Map();

  private constructor() {
    this.startPriorityAging();
  }

  static getInstance(): ParseTaskQueue {
    if (!ParseTaskQueue.instance) {
      ParseTaskQueue.instance = new ParseTaskQueue();
    }
    return ParseTaskQueue.instance;
  }

  registerExecutor(type: ParseTaskType, executor: (task: ParseTask) => Promise<ParseTaskResult>): void {
    this.taskExecutors.set(type, executor);
    Logger.info(TAG, `注册任务执行器: ${type}`);
  }

  unregisterExecutor(type: ParseTaskType): void {
    this.taskExecutors.delete(type);
    Logger.info(TAG, `注销任务执行器: ${type}`);
  }

  enqueue(
    type: ParseTaskType,
    priority: ParseTaskPriority,
    data: ParseTaskData,
    maxRetries: number,
    onProgress?: (progress: number) => void,
    onComplete?: (result: ParseTaskResult) => void,
    onError?: (error: Error) => void
  ): string {
    const taskId = this.generateTaskId();
    const task: ParseTask = {
      id: taskId,
      type: type,
      priority: priority,
      status: ParseTaskStatus.PENDING,
      data: data,
      createdAt: Date.now(),
      progress: 0,
      retryCount: 0,
      maxRetries: maxRetries,
      isCancelled: false,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError
    };

    if (this.queue.length >= this.config.maxQueueSize) {
      this.evictLowestPriorityTask();
    }

    const priorityItem: PriorityQueueItem = {
      task: task,
      effectivePriority: task.priority,
      insertionOrder: this.insertionCounter++
    };

    this.queue.push(priorityItem);
    this.sortQueue();

    Logger.info(TAG, `任务入队: ${taskId}, 类型: ${task.type}, 优先级: ${task.priority}, 队列长度: ${this.queue.length}`);

    this.processQueue();

    return taskId;
  }

  private generateTaskId(): string {
    return `task_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  private sortQueue(): void {
    this.queue.sort((a: PriorityQueueItem, b: PriorityQueueItem) => {
      if (a.effectivePriority !== b.effectivePriority) {
        return a.effectivePriority - b.effectivePriority;
      }
      return a.insertionOrder - b.insertionOrder;
    });
  }

  private evictLowestPriorityTask(): void {
    if (this.queue.length === 0) return;

    let lowestIndex = 0;
    let lowestPriority = this.queue[0].effectivePriority;

    for (let i = 1; i < this.queue.length; i++) {
      if (this.queue[i].effectivePriority > lowestPriority) {
        lowestPriority = this.queue[i].effectivePriority;
        lowestIndex = i;
      }
    }

    const evicted = this.queue.splice(lowestIndex, 1)[0];
    Logger.warn(TAG, `队列已满，移除最低优先级任务: ${evicted.task.id}`);
  }

  private async processQueue(): Promise<void> {
    if (this.isProcessing || this.isPaused) return;
    this.isProcessing = true;

    while (this.queue.length > 0 && this.runningTasks.size < this.config.maxConcurrent) {
      const item = this.queue.shift();
      if (!item) break;

      const task = item.task;
      if (task.status === ParseTaskStatus.CANCELLED) continue;

      this.executeTask(task);
    }

    this.isProcessing = false;
  }

  private async executeTask(task: ParseTask): Promise<void> {
    const executor = this.taskExecutors.get(task.type);
    if (!executor) {
      Logger.error(TAG, `未找到任务执行器: ${task.type}`);
      task.status = ParseTaskStatus.FAILED;
      task.onError?.(new Error(`未找到任务执行器: ${task.type}`));
      return;
    }

    task.status = ParseTaskStatus.RUNNING;
    task.startedAt = Date.now();
    task.isCancelled = false;
    this.runningTasks.set(task.id, task);

    Logger.info(TAG, `开始执行任务: ${task.id}, 类型: ${task.type}`);

    const timeoutId = setTimeout(() => {
      if (task.status === ParseTaskStatus.RUNNING) {
        Logger.warn(TAG, `任务超时: ${task.id}`);
        task.isCancelled = true;
      }
    }, this.config.taskTimeout);

    try {
      const result = await executor(task);

      if (task.isCancelled) {
        Logger.info(TAG, `任务已取消: ${task.id}`);
        return;
      }

      task.status = ParseTaskStatus.COMPLETED;
      task.completedAt = Date.now();
      task.progress = 100;

      this.completedTasks.set(task.id, result);
      task.onComplete?.(result);

      Logger.info(TAG, `任务完成: ${task.id}, 耗时: ${task.completedAt - (task.startedAt ?? 0)}ms`);
    } catch (error) {
      const err = error as Error;

      if (task.isCancelled) {
        Logger.info(TAG, `任务已取消: ${task.id}`);
        return;
      }

      Logger.error(TAG, `任务执行失败: ${task.id}, 错误: ${err.message}`);

      task.retryCount++;

      if (task.retryCount < task.maxRetries) {
        Logger.info(TAG, `任务将重试: ${task.id}, 重试次数: ${task.retryCount}/${task.maxRetries}`);
        task.status = ParseTaskStatus.PENDING;

        setTimeout(() => {
          const priorityItem: PriorityQueueItem = {
            task: task,
            effectivePriority: task.priority,
            insertionOrder: this.insertionCounter++
          };
          this.queue.push(priorityItem);
          this.sortQueue();
          this.processQueue();
        }, this.config.retryDelay * task.retryCount);
      } else {
        task.status = ParseTaskStatus.FAILED;
        task.completedAt = Date.now();
        task.onError?.(err);

        const errorResult: ParseTaskResult = {
          taskId: task.id,
          success: false,
          error: err.message
        };
        this.completedTasks.set(task.id, errorResult);
      }
    } finally {
      clearTimeout(timeoutId);
      this.runningTasks.delete(task.id);
      this.processQueue();
    }
  }

  cancelTask(taskId: string): boolean {
    const runningTask = this.runningTasks.get(taskId);
    if (runningTask) {
      runningTask.status = ParseTaskStatus.CANCELLED;
      runningTask.isCancelled = true;
      Logger.info(TAG, `取消运行中任务: ${taskId}`);
      return true;
    }

    const queueIndex = this.queue.findIndex((item: PriorityQueueItem) => item.task.id === taskId);
    if (queueIndex !== -1) {
      this.queue[queueIndex].task.status = ParseTaskStatus.CANCELLED;
      this.queue.splice(queueIndex, 1);
      Logger.info(TAG, `取消排队中任务: ${taskId}`);
      return true;
    }

    return false;
  }

  cancelTasksByBookId(bookId: string): number {
    let cancelledCount = 0;

    this.runningTasks.forEach((task: ParseTask, taskId: string) => {
      if (task.data.bookId === bookId) {
        this.cancelTask(taskId);
        cancelledCount++;
      }
    });

    const toRemove: number[] = [];
    this.queue.forEach((item: PriorityQueueItem, index: number) => {
      if (item.task.data.bookId === bookId) {
        item.task.status = ParseTaskStatus.CANCELLED;
        toRemove.push(index);
        cancelledCount++;
      }
    });

    for (let i = toRemove.length - 1; i >= 0; i--) {
      this.queue.splice(toRemove[i], 1);
    }

    Logger.info(TAG, `取消书籍相关任务: ${bookId}, 数量: ${cancelledCount}`);
    return cancelledCount;
  }

  pauseTask(taskId: string): boolean {
    const task = this.runningTasks.get(taskId);
    if (task && task.status === ParseTaskStatus.RUNNING) {
      task.status = ParseTaskStatus.PAUSED;
      task.isCancelled = true;
      Logger.info(TAG, `暂停任务: ${taskId}`);
      return true;
    }
    return false;
  }

  resumeTask(taskId: string): boolean {
    const task = this.runningTasks.get(taskId);
    if (task && task.status === ParseTaskStatus.PAUSED) {
      task.status = ParseTaskStatus.PENDING;
      task.retryCount = 0;
      task.isCancelled = false;

      const priorityItem: PriorityQueueItem = {
        task: task,
        effectivePriority: task.priority,
        insertionOrder: this.insertionCounter++
      };
      this.queue.push(priorityItem);
      this.sortQueue();

      this.runningTasks.delete(taskId);
      this.processQueue();

      Logger.info(TAG, `恢复任务: ${taskId}`);
      return true;
    }
    return false;
  }

  pauseQueue(): void {
    this.isPaused = true;
    Logger.info(TAG, '暂停任务队列处理');
  }

  resumeQueue(): void {
    this.isPaused = false;
    Logger.info(TAG, '恢复任务队列处理');
    this.processQueue();
  }

  updateTaskPriority(taskId: string, newPriority: ParseTaskPriority): boolean {
    const queueIndex = this.queue.findIndex((item: PriorityQueueItem) => item.task.id === taskId);
    if (queueIndex !== -1) {
      this.queue[queueIndex].task.priority = newPriority;
      this.queue[queueIndex].effectivePriority = newPriority;
      this.sortQueue();
      Logger.info(TAG, `更新任务优先级: ${taskId}, 新优先级: ${newPriority}`);
      return true;
    }
    return false;
  }

  updateTaskProgress(taskId: string, progress: number): void {
    const task = this.runningTasks.get(taskId);
    if (task) {
      task.progress = Math.min(100, Math.max(0, progress));
      task.onProgress?.(task.progress);
    }
  }

  getTaskStatus(taskId: string): ParseTaskStatus | undefined {
    const runningTask = this.runningTasks.get(taskId);
    if (runningTask) return runningTask.status;

    const queueItem = this.queue.find((item: PriorityQueueItem) => item.task.id === taskId);
    if (queueItem) return queueItem.task.status;

    const completedTask = this.completedTasks.get(taskId);
    if (completedTask) {
      return completedTask.success ? ParseTaskStatus.COMPLETED : ParseTaskStatus.FAILED;
    }

    return undefined;
  }

  getTaskResult(taskId: string): ParseTaskResult | undefined {
    return this.completedTasks.get(taskId);
  }

  getQueueStats(): QueueStatsResult {
    return {
      queueLength: this.queue.length,
      runningCount: this.runningTasks.size,
      completedCount: this.completedTasks.size,
      isPaused: this.isPaused
    };
  }

  getTasksByBookId(bookId: string): ParseTask[] {
    const tasks: ParseTask[] = [];

    this.runningTasks.forEach((task: ParseTask) => {
      if (task.data.bookId === bookId) {
        tasks.push(task);
      }
    });

    this.queue.forEach((item: PriorityQueueItem) => {
      if (item.task.data.bookId === bookId) {
        tasks.push(item.task);
      }
    });

    return tasks;
  }

  private startPriorityAging(): void {
    if (!this.config.enablePriorityAging) return;

    this.priorityAgingTimer = setInterval(() => {
      const now = Date.now();
      this.queue.forEach((item: PriorityQueueItem) => {
        const waitTime = now - item.task.createdAt;
        const agingBonus = Math.floor(waitTime / this.config.priorityAgingInterval);
        item.effectivePriority = Math.max(0, item.task.priority - agingBonus);
      });
      this.sortQueue();
    }, this.config.priorityAgingInterval);
  }

  setConfig(config: Partial<TaskQueueConfig>): void {
    const newConfig: TaskQueueConfig = {
      maxConcurrent: config.maxConcurrent ?? this.config.maxConcurrent,
      maxQueueSize: config.maxQueueSize ?? this.config.maxQueueSize,
      taskTimeout: config.taskTimeout ?? this.config.taskTimeout,
      retryDelay: config.retryDelay ?? this.config.retryDelay,
      enablePriorityAging: config.enablePriorityAging ?? this.config.enablePriorityAging,
      priorityAgingInterval: config.priorityAgingInterval ?? this.config.priorityAgingInterval
    };
    this.config = newConfig;
    Logger.info(TAG, `更新队列配置`);
  }

  clearCompletedTasks(): void {
    this.completedTasks.clear();
    Logger.info(TAG, '清理已完成任务缓存');
  }

  destroy(): void {
    if (this.priorityAgingTimer) {
      clearInterval(this.priorityAgingTimer);
    }

    this.queue.forEach((item: PriorityQueueItem) => {
      item.task.isCancelled = true;
    });

    this.runningTasks.forEach((task: ParseTask) => {
      task.isCancelled = true;
    });

    this.queue = [];
    this.runningTasks.clear();
    this.completedTasks.clear();

    Logger.info(TAG, '任务队列已销毁');
  }
}

interface QueueStatsResult {
  queueLength: number;
  runningCount: number;
  completedCount: number;
  isPaused: boolean;
}

export default ParseTaskQueue.getInstance();
