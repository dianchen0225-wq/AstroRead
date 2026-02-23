import { Logger } from '../performance/Logger';
import { ParseTaskQueue, ParseTaskPriority, ParseTaskType, ParseTaskResult, ParseTask, ParseTaskData } from '../performance/ParseTaskQueue';
import { ResourceMonitor, ResourceLevel } from '../performance/ResourceMonitor';
import { ReadingBehaviorMonitor, ReadingState, BehaviorPrediction } from '../performance/ReadingBehaviorMonitor';
import { SmartStopEngine, StopReason } from '../performance/SmartStopEngine';
import { NetworkManager } from '../network/NetworkManager';
import { BookSource } from '../../models/BookSource';
import { Chapter } from '../../models/Book';

const TAG = 'ProgressiveContentLoader';

export enum LoadState {
  IDLE = 'idle',
  LOADING = 'loading',
  PARTIAL = 'partial',
  COMPLETE = 'complete',
  ERROR = 'error',
  CANCELLED = 'cancelled'
}

export interface ProgressiveLoadResult {
  chapterId: string;
  content: string;
  state: LoadState;
  progress: number;
  isPartial: boolean;
  error?: string;
  loadedAt: number;
}

export interface PreloadConfig {
  maxPreloadCount: number;
  preloadDistance: number;
  enableSmartPreload: boolean;
  minEngagementForPreload: number;
  resourceThresholdForPreload: ResourceLevel;
}

export interface ContentSegment {
  index: number;
  content: string;
  isComplete: boolean;
  loadedAt: number;
}

export interface ChapterLoadProgress {
  chapterId: string;
  chapterIndex: number;
  state: LoadState;
  progress: number;
  segments: ContentSegment[];
  totalSegments: number;
  loadedSegments: number;
  startTime: number;
  lastUpdateTime: number;
}

export interface LoaderStats {
  totalLoaded: number;
  totalPreloaded: number;
  cacheHits: number;
  cacheMisses: number;
  averageLoadTime: number;
  partialLoads: number;
  cancelledLoads: number;
  currentLoadCount: number;
  preloadQueueSize: number;
}

type ContentCallback = (result: ProgressiveLoadResult) => void;
type ProgressCallback = (chapterId: string, progress: number) => void;

export class ProgressiveContentLoader {
  private static instance: ProgressiveContentLoader | null = null;
  private taskQueue: ParseTaskQueue;
  private resourceMonitor: ResourceMonitor;
  private behaviorMonitor: ReadingBehaviorMonitor;
  private smartStopEngine: SmartStopEngine;
  private networkManager: NetworkManager;

  private contentCache: Map<string, ProgressiveLoadResult> = new Map();
  private loadProgress: Map<string, ChapterLoadProgress> = new Map();
  private preloadQueue: string[] = [];
  private activeLoads: Map<string, boolean> = new Map();
  private currentBookId: string | null = null;
  private currentChapterId: string | null = null;
  private chapters: Chapter[] = [];

  private preloadConfig: PreloadConfig = {
    maxPreloadCount: 5,
    preloadDistance: 3,
    enableSmartPreload: true,
    minEngagementForPreload: 0.5,
    resourceThresholdForPreload: ResourceLevel.NORMAL
  };

  private callbacks: Map<string, ContentCallback> = new Map();
  private progressCallbacks: Map<string, ProgressCallback> = new Map();

  private stats: LoaderStats = {
    totalLoaded: 0,
    totalPreloaded: 0,
    cacheHits: 0,
    cacheMisses: 0,
    averageLoadTime: 0,
    partialLoads: 0,
    cancelledLoads: 0,
    currentLoadCount: 0,
    preloadQueueSize: 0
  };

  private loadTimes: number[] = [];
  private bookSource: BookSource | null = null;

  private constructor() {
    this.taskQueue = ParseTaskQueue.getInstance();
    this.resourceMonitor = ResourceMonitor.getInstance();
    this.behaviorMonitor = ReadingBehaviorMonitor.getInstance();
    this.smartStopEngine = SmartStopEngine.getInstance();
    this.networkManager = NetworkManager.getInstance();

    this.setupTaskExecutor();
    this.setupCallbacks();
  }

  static getInstance(): ProgressiveContentLoader {
    if (!ProgressiveContentLoader.instance) {
      ProgressiveContentLoader.instance = new ProgressiveContentLoader();
    }
    return ProgressiveContentLoader.instance;
  }

  private setupTaskExecutor(): void {
    this.taskQueue.registerExecutor(ParseTaskType.CHAPTER_CONTENT, async (task: ParseTask) => {
      return this.executeChapterLoad(task);
    });

    this.taskQueue.registerExecutor(ParseTaskType.BATCH_CACHE, async (task: ParseTask) => {
      return this.executeBatchCache(task);
    });
  }

  private setupCallbacks(): void {
    this.smartStopEngine.setOnStopRequested((taskId: string, reason: StopReason) => {
      Logger.info(TAG, `任务被停止: ${taskId}, 原因: ${reason}`);
      this.handleTaskStopped(taskId, reason);
    });

    this.behaviorMonitor.setOnPredictionUpdate((prediction: BehaviorPrediction) => {
      this.handleBehaviorPrediction(prediction);
    });
  }

  setBookContext(bookId: string, chapters: Chapter[], bookSource: BookSource): void {
    this.currentBookId = bookId;
    this.chapters = chapters;
    this.bookSource = bookSource;

    Logger.info(TAG, `设置书籍上下文: ${bookId}, 章节数: ${chapters.length}`);
  }

  setCurrentChapter(chapterId: string, chapterIndex: number): void {
    this.currentChapterId = chapterId;

    this.behaviorMonitor.startReadingSession(this.currentBookId ?? '', chapterId);

    this.schedulePreload(chapterIndex);
  }

  async loadChapter(
    chapterId: string,
    chapterUrl: string,
    options?: LoadChapterOptions
  ): Promise<string> {
    const cached = this.contentCache.get(chapterId);
    if (cached && cached.state === LoadState.COMPLETE) {
      this.stats.cacheHits++;
      const callback = options?.callback;
      if (callback) {
        callback(cached);
      }
      return cached.content;
    }

    this.stats.cacheMisses++;

    if (this.activeLoads.has(chapterId)) {
      const callback = options?.callback;
      if (callback) {
        this.callbacks.set(chapterId, callback);
      }
      const progressCallback = options?.progressCallback;
      if (progressCallback) {
        this.progressCallbacks.set(chapterId, progressCallback);
      }

      const progress = this.loadProgress.get(chapterId);
      if (progress && progress.state === LoadState.PARTIAL) {
        return this.getPartialContent(chapterId);
      }

      return '';
    }

    return this.startChapterLoad(chapterId, chapterUrl, options);
  }

  private async startChapterLoad(
    chapterId: string,
    chapterUrl: string,
    options?: LoadChapterOptions
  ): Promise<string> {
    const priority = options?.priority ?? ParseTaskPriority.HIGH;

    const callback = options?.callback;
    if (callback) {
      this.callbacks.set(chapterId, callback);
    }
    const progressCallback = options?.progressCallback;
    if (progressCallback) {
      this.progressCallbacks.set(chapterId, progressCallback);
    }

    this.activeLoads.set(chapterId, true);
    this.stats.currentLoadCount++;

    const progress: ChapterLoadProgress = {
      chapterId: chapterId,
      chapterIndex: this.getChapterIndex(chapterId),
      state: LoadState.LOADING,
      progress: 0,
      segments: [],
      totalSegments: 1,
      loadedSegments: 0,
      startTime: Date.now(),
      lastUpdateTime: Date.now()
    };
    this.loadProgress.set(chapterId, progress);

    const taskData: ParseTaskData = {
      bookId: this.currentBookId ?? undefined,
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      bookSourceId: this.bookSource?.id
    };

    const onProgress = (p: number) => this.updateLoadProgress(chapterId, p);
    const onComplete = (result: ParseTaskResult) => this.handleLoadComplete(chapterId, result);
    const onError = (error: Error) => this.handleLoadError(chapterId, error);

    const taskId = this.taskQueue.enqueue(
      ParseTaskType.CHAPTER_CONTENT,
      priority,
      taskData,
      2,
      onProgress,
      onComplete,
      onError
    );

    this.smartStopEngine.trackTask(taskId, this.currentBookId ?? '', ParseTaskType.CHAPTER_CONTENT, chapterId);

    return '';
  }

  private async executeChapterLoad(task: ParseTask): Promise<ParseTaskResult> {
    const data = task.data;
    const chapterId = data.chapterId;
    const chapterUrl = data.chapterUrl;

    if (!chapterId || !chapterUrl || !this.bookSource) {
      return {
        taskId: task.id,
        success: false,
        error: '缺少必要参数'
      };
    }

    const startTime = Date.now();

    try {
      const html = await this.networkManager.getChapterContent(this.bookSource, chapterUrl);

      this.updateLoadProgress(chapterId, 50);

      const content = html;

      const elapsed = Date.now() - startTime;
      this.loadTimes.push(elapsed);
      if (this.loadTimes.length > 50) {
        this.loadTimes.shift();
      }
      const totalTime = this.loadTimes.reduce((a, b) => a + b, 0);
      this.stats.averageLoadTime = totalTime / this.loadTimes.length;

      this.updateLoadProgress(chapterId, 100);

      return {
        taskId: task.id,
        success: true,
        data: { content: content, chapterId: chapterId }
      };
    } catch (error) {
      return {
        taskId: task.id,
        success: false,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  private async executeBatchCache(task: ParseTask): Promise<ParseTaskResult> {
    const data = task.data;
    const batchUrls = data.batchUrls;

    if (!batchUrls || !this.bookSource) {
      return {
        taskId: task.id,
        success: false,
        error: '缺少必要参数'
      };
    }

    let completedItems = 0;
    const totalItems = batchUrls.length;
    const results: ESObject[] = [];

    for (let i = 0; i < batchUrls.length; i++) {
      const url = batchUrls[i];
      if (!this.resourceMonitor.canHandleNewTask()) {
        Logger.warn(TAG, '资源不足，停止批量缓存');
        break;
      }

      try {
        const content = await this.networkManager.getChapterContent(this.bookSource, url);
        results.push({ url: url, content: content, success: true });

        const chapterId = this.getChapterIdByUrl(url);
        if (chapterId) {
          this.contentCache.set(chapterId, {
            chapterId: chapterId,
            content: content,
            state: LoadState.COMPLETE,
            progress: 100,
            isPartial: false,
            loadedAt: Date.now()
          });
        }
      } catch (error) {
        results.push({ url: url, success: false, error: error instanceof Error ? error.message : String(error) });
      }

      completedItems++;
      data.progress = (completedItems / totalItems) * 100;
    }

    return {
      taskId: task.id,
      success: true,
      data: { results: results },
      completedItems: completedItems,
      totalItems: totalItems
    };
  }

  private updateLoadProgress(chapterId: string, progress: number): void {
    const loadProgress = this.loadProgress.get(chapterId);
    if (loadProgress) {
      loadProgress.progress = progress;
      loadProgress.lastUpdateTime = Date.now();

      if (progress > 0 && progress < 100) {
        loadProgress.state = LoadState.PARTIAL;
      }

      const callback = this.progressCallbacks.get(chapterId);
      if (callback) {
        callback(chapterId, progress);
      }
    }
  }

  private handleLoadComplete(chapterId: string, result: ParseTaskResult): void {
    const loadProgress = this.loadProgress.get(chapterId);
    if (!loadProgress) return;

    if (result.success && result.data) {
      const data: Record<string, string> = result.data as Record<string, string>;
      const content: string = data['content'] as string;

      const loadResult: ProgressiveLoadResult = {
        chapterId: chapterId,
        content: content,
        state: LoadState.COMPLETE,
        progress: 100,
        isPartial: false,
        loadedAt: Date.now()
      };

      this.contentCache.set(chapterId, loadResult);

      loadProgress.state = LoadState.COMPLETE;
      loadProgress.progress = 100;

      this.stats.totalLoaded++;
      const currentChapterIndex = this.getChapterIndex(this.currentChapterId ?? '');
      if (loadProgress.chapterIndex !== currentChapterIndex) {
        this.stats.totalPreloaded++;
      }

      const callback = this.callbacks.get(chapterId);
      if (callback) {
        callback(loadResult);
      }
    } else {
      this.handleLoadError(chapterId, new Error(result.error ?? '加载失败'));
    }

    this.cleanupLoad(chapterId);
  }

  private handleLoadError(chapterId: string, error: Error): void {
    const loadProgress = this.loadProgress.get(chapterId);
    if (!loadProgress) return;

    loadProgress.state = LoadState.ERROR;

    const loadResult: ProgressiveLoadResult = {
      chapterId: chapterId,
      content: '',
      state: LoadState.ERROR,
      progress: loadProgress.progress,
      isPartial: loadProgress.progress > 0,
      error: error.message,
      loadedAt: Date.now()
    };

    if (loadProgress.progress > 0) {
      this.stats.partialLoads++;
    }

    const callback = this.callbacks.get(chapterId);
    if (callback) {
      callback(loadResult);
    }

    this.cleanupLoad(chapterId);
    Logger.error(TAG, `章节加载失败: ${chapterId}, 错误: ${error.message}`);
  }

  private handleTaskStopped(taskId: string, reason: StopReason): void {
    this.loadProgress.forEach((progress, chapterId) => {
      progress.state = LoadState.CANCELLED;
      this.stats.cancelledLoads++;

      const loadResult: ProgressiveLoadResult = {
        chapterId: chapterId,
        content: '',
        state: LoadState.CANCELLED,
        progress: progress.progress,
        isPartial: progress.progress > 0,
        error: `任务已停止: ${reason}`,
        loadedAt: Date.now()
      };

      const callback = this.callbacks.get(chapterId);
      if (callback) {
        callback(loadResult);
      }
      this.cleanupLoad(chapterId);
    });
  }

  private cleanupLoad(chapterId: string): void {
    this.activeLoads.delete(chapterId);
    this.callbacks.delete(chapterId);
    this.progressCallbacks.delete(chapterId);
    this.stats.currentLoadCount--;
  }

  private schedulePreload(currentIndex: number): void {
    if (!this.preloadConfig.enableSmartPreload) return;

    const prediction = this.behaviorMonitor.predictBehavior(this.behaviorMonitor.getBehaviorStats());

    if (!prediction.likelyToContinue || prediction.confidence < 0.5) {
      Logger.debug(TAG, '用户不太可能继续阅读，跳过预加载');
      return;
    }

    const resourceLevel = this.resourceMonitor.getResourceLevel();
    if (resourceLevel === ResourceLevel.CRITICAL || resourceLevel === ResourceLevel.LOW) {
      Logger.debug(TAG, '资源不足，跳过预加载');
      return;
    }

    const preloadCount = Math.min(
      prediction.recommendedPreloadCount,
      this.preloadConfig.maxPreloadCount
    );

    const toPreload: string[] = [];

    for (let i = 1; i <= preloadCount; i++) {
      const nextIndex = currentIndex + i;
      if (nextIndex < this.chapters.length) {
        const chapter = this.chapters[nextIndex];
        if (!this.contentCache.has(chapter.id) && !this.activeLoads.has(chapter.id)) {
          toPreload.push(chapter.id);
        }
      }
    }

    if (toPreload.length > 0) {
      this.executePreload(toPreload);
    }
  }

  private executePreload(chapterIds: string[]): void {
    Logger.info(TAG, `开始预加载 ${chapterIds.length} 个章节`);

    const batchUrls: string[] = [];

    for (let i = 0; i < chapterIds.length; i++) {
      const chapterId = chapterIds[i];
      const chapter = this.chapters.find(c => c.id === chapterId);
      if (chapter && chapter.url) {
        batchUrls.push(chapter.url);

        this.activeLoads.set(chapterId, true);
        this.stats.currentLoadCount++;

        const progress: ChapterLoadProgress = {
          chapterId: chapterId,
          chapterIndex: this.getChapterIndex(chapterId),
          state: LoadState.LOADING,
          progress: 0,
          segments: [],
          totalSegments: 1,
          loadedSegments: 0,
          startTime: Date.now(),
          lastUpdateTime: Date.now()
        };
        this.loadProgress.set(chapterId, progress);
      }
    }

    if (batchUrls.length > 0) {
      const taskData: ParseTaskData = {
        bookId: this.currentBookId ?? undefined,
        batchUrls: batchUrls,
        bookSourceId: this.bookSource?.id
      };

      const taskId = this.taskQueue.enqueue(
        ParseTaskType.BATCH_CACHE,
        ParseTaskPriority.LOW,
        taskData,
        1
      );

      this.smartStopEngine.trackTask(taskId, this.currentBookId ?? '', ParseTaskType.BATCH_CACHE);
    }
  }

  private handleBehaviorPrediction(prediction: BehaviorPrediction): void {
    if (prediction.likelyToContinue && this.currentChapterId) {
      const currentIndex = this.getChapterIndex(this.currentChapterId);
      if (currentIndex >= 0) {
        this.schedulePreload(currentIndex);
      }
    }
  }

  private getChapterIndex(chapterId: string): number {
    return this.chapters.findIndex(c => c.id === chapterId);
  }

  private getChapterIdByUrl(url: string): string | null {
    const chapter = this.chapters.find(c => c.url === url);
    return chapter?.id ?? null;
  }

  private getPartialContent(chapterId: string): string {
    const progress = this.loadProgress.get(chapterId);
    if (!progress || progress.segments.length === 0) return '';

    const sortedSegments = progress.segments.slice().sort((a, b) => a.index - b.index);
    const contents: string[] = [];
    for (let i = 0; i < sortedSegments.length; i++) {
      contents.push(sortedSegments[i].content);
    }
    return contents.join('\n');
  }

  getCachedContent(chapterId: string): ProgressiveLoadResult | undefined {
    return this.contentCache.get(chapterId);
  }

  hasCachedContent(chapterId: string): boolean {
    const cached = this.contentCache.get(chapterId);
    return cached !== undefined && cached.state === LoadState.COMPLETE;
  }

  getLoadProgress(chapterId: string): ChapterLoadProgress | undefined {
    return this.loadProgress.get(chapterId);
  }

  isLoading(chapterId: string): boolean {
    return this.activeLoads.has(chapterId);
  }

  cancelLoad(chapterId: string): boolean {
    if (!this.activeLoads.has(chapterId)) return false;

    this.smartStopEngine.manualStop(chapterId, StopReason.MANUAL_STOP);

    const progress = this.loadProgress.get(chapterId);
    if (progress) {
      progress.state = LoadState.CANCELLED;
    }

    this.cleanupLoad(chapterId);
    this.stats.cancelledLoads++;

    return true;
  }

  cancelAllLoads(): void {
    this.activeLoads.forEach((_, chapterId) => {
      this.cancelLoad(chapterId);
    });
  }

  clearCache(chapterId?: string): void {
    if (chapterId) {
      this.contentCache.delete(chapterId);
    } else {
      this.contentCache.clear();
    }
  }

  getStats(): LoaderStats {
    this.stats.preloadQueueSize = this.preloadQueue.length;
    return {
      totalLoaded: this.stats.totalLoaded,
      totalPreloaded: this.stats.totalPreloaded,
      cacheHits: this.stats.cacheHits,
      cacheMisses: this.stats.cacheMisses,
      averageLoadTime: this.stats.averageLoadTime,
      partialLoads: this.stats.partialLoads,
      cancelledLoads: this.stats.cancelledLoads,
      currentLoadCount: this.stats.currentLoadCount,
      preloadQueueSize: this.stats.preloadQueueSize
    };
  }

  setPreloadConfig(config: PreloadConfig): void {
    this.preloadConfig = config;
  }

  destroy(): void {
    this.cancelAllLoads();
    this.contentCache.clear();
    this.loadProgress.clear();
    this.callbacks.clear();
    this.progressCallbacks.clear();
    this.activeLoads.clear();
    this.preloadQueue = [];
    this.chapters = [];
    this.bookSource = null;
    this.currentBookId = null;
    this.currentChapterId = null;

    Logger.info(TAG, '渐进式内容加载器已销毁');
  }
}

export interface LoadChapterOptions {
  priority?: ParseTaskPriority;
  callback?: ContentCallback;
  progressCallback?: ProgressCallback;
}

export default ProgressiveContentLoader.getInstance();
