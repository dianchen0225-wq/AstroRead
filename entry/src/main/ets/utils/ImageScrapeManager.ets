import { Logger } from './Logger';
import { ImageScraperService, ImageDownloadResult, ImageScrapeConfig, ImageScrapeStats, ImageFormat } from './ImageScraperService';
import { ImageDetector, ImageCandidate, ImageDetectionConfig } from './ImageDetector';
import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { NetworkManager } from './NetworkManager';
import { common } from '@kit.AbilityKit';

export interface BookImageResult {
  bookId: string;
  bookName: string;
  coverUrl: string;
  localCoverPath: string | null;
  interiorImages: InteriorImageResult[];
  success: boolean;
  errorMessage?: string;
  metadata: ImageMetadata;
}

export interface InteriorImageResult {
  url: string;
  localPath: string | null;
  chapterTitle?: string;
  success: boolean;
}

export interface ImageMetadata {
  format: ImageFormat;
  width: number;
  height: number;
  size: number;
  source: string;
  downloadTime: number;
}

export interface ScrapeProgress {
  phase: 'detecting' | 'downloading' | 'processing' | 'completed' | 'error';
  current: number;
  total: number;
  currentItem: string;
  message: string;
  stats: ImageScrapeStats;
}

export interface AntiScrapingStrategy {
  type: 'delay' | 'rotate_user_agent' | 'rotate_referer' | 'use_proxy' | 'skip' | 'manual';
  params: Record<string, string | number | boolean>;
  description: string;
}

export interface ImageScrapeTask {
  id: string;
  bookId: string;
  bookName: string;
  bookUrl: string;
  bookSourceId: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  coverUrl: string | null;
  result: BookImageResult | null;
  error: string | null;
  retryCount: number;
  createdAt: number;
  startedAt: number | null;
  completedAt: number | null;
}

export type ProgressCallback = (progress: ScrapeProgress) => void;
export type TaskCompleteCallback = (task: ImageScrapeTask) => void;

interface UserAgentRotation {
  agents: string[];
  currentIndex: number;
}

const USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
];

export class ImageScrapeManager {
  private static instance: ImageScrapeManager | null = null;
  private scraperService: ImageScraperService;
  private imageDetector: ImageDetector;
  private networkManager: NetworkManager;
  private context: common.UIAbilityContext | null = null;

  private taskQueue: Map<string, ImageScrapeTask> = new Map();
  private runningTasks: Set<string> = new Set();
  private maxConcurrentTasks: number = 3;

  private userAgentRotation: UserAgentRotation = {
    agents: USER_AGENTS,
    currentIndex: 0
  };

  private progressCallbacks: Set<ProgressCallback> = new Set();
  private taskCompleteCallbacks: Set<TaskCompleteCallback> = new Set();

  private readonly TAG = 'ImageScrapeManager';

  private constructor() {
    this.scraperService = ImageScraperService.getInstance();
    this.imageDetector = new ImageDetector();
    this.networkManager = NetworkManager.getInstance();
  }

  static getInstance(): ImageScrapeManager {
    if (!ImageScrapeManager.instance) {
      ImageScrapeManager.instance = new ImageScrapeManager();
    }
    return ImageScrapeManager.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.scraperService.setContext(context);
  }

  configure(scraperConfig?: Partial<ImageScrapeConfig>, detectorConfig?: Partial<ImageDetectionConfig>): void {
    if (scraperConfig) {
      this.scraperService.updateConfig(scraperConfig);
    }
    if (detectorConfig) {
      this.imageDetector.updateConfig(detectorConfig);
    }
  }

  async scrapeBookCover(
    book: Book,
    bookSource: BookSource,
    html?: string
  ): Promise<BookImageResult> {
    const startTime = Date.now();
    const result: BookImageResult = {
      bookId: book.id,
      bookName: book.name,
      coverUrl: book.cover || '',
      localCoverPath: null,
      interiorImages: [],
      success: false,
      metadata: {
        format: 'unknown',
        width: 0,
        height: 0,
        size: 0,
        source: 'unknown',
        downloadTime: 0
      }
    };

    try {
      let coverUrl = book.cover;

      if (!coverUrl && html) {
        const candidates = this.imageDetector.detectBookCoverImages(html, bookSource.url);
        const bestCandidate = this.imageDetector.selectBestImage(candidates);

        if (bestCandidate) {
          coverUrl = bestCandidate.url;
          result.coverUrl = coverUrl;
          Logger.info(this.TAG, `Detected cover image for "${book.name}": ${coverUrl}`);
        }
      }

      if (!coverUrl) {
        result.errorMessage = 'No cover image found';
        return result;
      }

      const downloadResult = await this.downloadWithRetry(coverUrl, book.id, 'cover');

      if (downloadResult.success) {
        result.localCoverPath = downloadResult.localPath;
        result.success = true;
        result.metadata = {
          format: downloadResult.format || 'unknown',
          width: downloadResult.width || 0,
          height: downloadResult.height || 0,
          size: downloadResult.size || 0,
          source: 'downloaded',
          downloadTime: Date.now() - startTime
        };
      } else {
        result.errorMessage = downloadResult.errorMessage || 'Download failed';
      }
    } catch (error) {
      result.errorMessage = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `Failed to scrape cover for "${book.name}": ${result.errorMessage}`);
    }

    return result;
  }

  async scrapeBookImages(
    book: Book,
    bookSource: BookSource,
    options?: {
      includeCover?: boolean;
      includeInterior?: boolean;
      html?: string;
    }
  ): Promise<BookImageResult> {
    const opts = {
      includeCover: true,
      includeInterior: false,
      ...options
    };

    const result: BookImageResult = {
      bookId: book.id,
      bookName: book.name,
      coverUrl: book.cover || '',
      localCoverPath: null,
      interiorImages: [],
      success: false,
      metadata: {
        format: 'unknown',
        width: 0,
        height: 0,
        size: 0,
        source: 'unknown',
        downloadTime: 0
      }
    };

    try {
      if (opts.includeCover) {
        const coverResult = await this.scrapeBookCover(book, bookSource, opts.html);
        result.localCoverPath = coverResult.localCoverPath;
        result.coverUrl = coverResult.coverUrl;
        result.metadata = coverResult.metadata;

        if (!coverResult.success) {
          result.errorMessage = coverResult.errorMessage;
          return result;
        }
      }

      result.success = true;
    } catch (error) {
      result.errorMessage = error instanceof Error ? error.message : String(error);
    }

    return result;
  }

  createTask(book: Book, bookSource: BookSource): ImageScrapeTask {
    const task: ImageScrapeTask = {
      id: `${book.id}_${Date.now()}`,
      bookId: book.id,
      bookName: book.name,
      bookUrl: book.bookUrl,
      bookSourceId: book.bookSourceId,
      status: 'pending',
      coverUrl: book.cover || null,
      result: null,
      error: null,
      retryCount: 0,
      createdAt: Date.now(),
      startedAt: null,
      completedAt: null
    };

    this.taskQueue.set(task.id, task);
    return task;
  }

  async executeTask(
    task: ImageScrapeTask,
    bookSource: BookSource,
    html?: string
  ): Promise<ImageScrapeTask> {
    if (this.runningTasks.size >= this.maxConcurrentTasks) {
      Logger.warn(this.TAG, `Max concurrent tasks reached, task ${task.id} will wait`);
    }

    task.status = 'running';
    task.startedAt = Date.now();
    this.runningTasks.add(task.id);

    this.notifyProgress({
      phase: 'detecting',
      current: 0,
      total: 1,
      currentItem: task.bookName,
      message: `Detecting images for "${task.bookName}"`,
      stats: this.scraperService.getStats()
    });

    try {
      const book: Book = {
        id: task.bookId,
        name: task.bookName,
        bookUrl: task.bookUrl,
        bookSourceId: task.bookSourceId,
        bookSourceName: bookSource.name,
        cover: task.coverUrl || undefined,
        author: '',
        intro: undefined,
        kind: undefined,
        wordCount: undefined,
        latestChapter: undefined,
        lastUpdateTime: Date.now(),
        addTime: Date.now(),
        readProgress: 0
      };

      this.notifyProgress({
        phase: 'downloading',
        current: 0,
        total: 1,
        currentItem: task.bookName,
        message: `Downloading cover for "${task.bookName}"`,
        stats: this.scraperService.getStats()
      });

      const result = await this.scrapeBookCover(book, bookSource, html);

      task.result = result;
      task.status = result.success ? 'completed' : 'failed';
      task.error = result.errorMessage || null;
      task.completedAt = Date.now();

      this.notifyProgress({
        phase: result.success ? 'completed' : 'error',
        current: 1,
        total: 1,
        currentItem: task.bookName,
        message: result.success ?
          `Successfully scraped images for "${task.bookName}"` :
          `Failed to scrape images for "${task.bookName}": ${result.errorMessage}`,
        stats: this.scraperService.getStats()
      });
    } catch (error) {
      task.status = 'failed';
      task.error = error instanceof Error ? error.message : String(error);
      task.completedAt = Date.now();

      this.notifyProgress({
        phase: 'error',
        current: 1,
        total: 1,
        currentItem: task.bookName,
        message: `Error scraping "${task.bookName}": ${task.error}`,
        stats: this.scraperService.getStats()
      });
    } finally {
      this.runningTasks.delete(task.id);
      this.notifyTaskComplete(task);
    }

    return task;
  }

  async executeBatch(
    items: Array<{ book: Book; bookSource: BookSource; html?: string }>,
    onProgress?: ProgressCallback
  ): Promise<BookImageResult[]> {
    const results: BookImageResult[] = [];
    let completed = 0;

    if (onProgress) {
      this.progressCallbacks.add(onProgress);
    }

    for (const item of items) {
      const task = this.createTask(item.book, item.bookSource);
      const completedTask = await this.executeTask(task, item.bookSource, item.html);

      if (completedTask.result) {
        results.push(completedTask.result);
      }

      completed++;

      this.notifyProgress({
        phase: 'processing',
        current: completed,
        total: items.length,
        currentItem: item.book.name,
        message: `Processed ${completed}/${items.length} books`,
        stats: this.scraperService.getStats()
      });

      if (completed < items.length) {
        await this.delay(this.getRandomDelay(500, 1500));
      }
    }

    if (onProgress) {
      this.progressCallbacks.delete(onProgress);
    }

    return results;
  }

  cancelTask(taskId: string): boolean {
    const task = this.taskQueue.get(taskId);
    if (!task) return false;

    if (task.status === 'pending') {
      task.status = 'cancelled';
      task.completedAt = Date.now();
      this.taskQueue.delete(taskId);
      return true;
    }

    return false;
  }

  getTask(taskId: string): ImageScrapeTask | null {
    return this.taskQueue.get(taskId) || null;
  }

  getPendingTasks(): ImageScrapeTask[] {
    return Array.from(this.taskQueue.values()).filter(t => t.status === 'pending');
  }

  getRunningTasks(): ImageScrapeTask[] {
    return Array.from(this.taskQueue.values()).filter(t => t.status === 'running');
  }

  clearCompletedTasks(): number {
    let cleared = 0;
    for (const [id, task] of this.taskQueue) {
      if (task.status === 'completed' || task.status === 'failed' || task.status === 'cancelled') {
        this.taskQueue.delete(id);
        cleared++;
      }
    }
    return cleared;
  }

  private async downloadWithRetry(
    url: string,
    bookId: string,
    type: 'cover' | 'interior' | 'thumbnail'
  ): Promise<ImageDownloadResult> {
    const config = this.scraperService.getConfig();
    let lastResult: ImageDownloadResult | null = null;

    for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
      if (attempt > 0) {
        const strategy = this.getAntiScrapingStrategy(lastResult?.errorMessage || '');
        await this.applyStrategy(strategy);
        Logger.info(this.TAG, `Retry attempt ${attempt} with strategy: ${strategy.type}`);
      }

      const result = await this.scraperService.downloadImage(url, bookId, type);
      lastResult = result;

      if (result.success) {
        return result;
      }

      const detection = this.detectAntiScraping(result.errorMessage || '');
      if (detection.needsManualIntervention) {
        Logger.warn(this.TAG, `Manual intervention required: ${detection.reason}`);
        break;
      }
    }

    return lastResult || {
      success: false,
      url,
      bookId,
      errorMessage: 'Max retries exceeded'
    };
  }

  private getAntiScrapingStrategy(errorMessage: string): AntiScrapingStrategy {
    const lowerMessage = errorMessage.toLowerCase();

    if (lowerMessage.includes('captcha') || lowerMessage.includes('验证')) {
      return {
        type: 'manual',
        params: {},
        description: 'CAPTCHA detected, requires manual intervention'
      };
    }

    if (lowerMessage.includes('429') || lowerMessage.includes('rate limit')) {
      return {
        type: 'delay',
        params: { delayMs: 5000 },
        description: 'Rate limited, waiting before retry'
      };
    }

    if (lowerMessage.includes('403') || lowerMessage.includes('forbidden')) {
      return {
        type: 'rotate_user_agent',
        params: {},
        description: 'Access forbidden, rotating user agent'
      };
    }

    if (lowerMessage.includes('cloudflare')) {
      return {
        type: 'rotate_referer',
        params: {},
        description: 'Cloudflare protection detected, trying different approach'
      };
    }

    return {
      type: 'delay',
      params: { delayMs: 1000 },
      description: 'Standard retry with delay'
    };
  }

  private async applyStrategy(strategy: AntiScrapingStrategy): Promise<void> {
    switch (strategy.type) {
      case 'delay':
        const delayMs = (strategy.params.delayMs as number) || 1000;
        await this.delay(delayMs);
        break;

      case 'rotate_user_agent':
        this.rotateUserAgent();
        break;

      case 'rotate_referer':
        // Referer rotation is handled per request
        break;

      case 'skip':
        Logger.info(this.TAG, 'Skipping due to strategy');
        break;

      case 'manual':
        Logger.warn(this.TAG, 'Manual intervention required');
        break;
    }
  }

  private detectAntiScraping(errorMessage: string): {
    needsManualIntervention: boolean;
    reason: string;
  } {
    const lowerMessage = errorMessage.toLowerCase();

    if (lowerMessage.includes('captcha') || lowerMessage.includes('验证码')) {
      return {
        needsManualIntervention: true,
        reason: 'CAPTCHA verification required'
      };
    }

    if (lowerMessage.includes('cloudflare') && lowerMessage.includes('challenge')) {
      return {
        needsManualIntervention: true,
        reason: 'Cloudflare challenge page detected'
      };
    }

    return {
      needsManualIntervention: false,
      reason: ''
    };
  }

  private rotateUserAgent(): string {
    this.userAgentRotation.currentIndex =
      (this.userAgentRotation.currentIndex + 1) % this.userAgentRotation.agents.length;

    const newUserAgent = this.userAgentRotation.agents[this.userAgentRotation.currentIndex];
    this.scraperService.updateConfig({ userAgent: newUserAgent });

    Logger.debug(this.TAG, `Rotated user agent to index ${this.userAgentRotation.currentIndex}`);
    return newUserAgent;
  }

  getCurrentUserAgent(): string {
    return this.userAgentRotation.agents[this.userAgentRotation.currentIndex];
  }

  private getRandomDelay(min: number, max: number): number {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private notifyProgress(progress: ScrapeProgress): void {
    for (const callback of this.progressCallbacks) {
      try {
        callback(progress);
      } catch (error) {
        Logger.error(this.TAG, `Progress callback error: ${error}`);
      }
    }
  }

  private notifyTaskComplete(task: ImageScrapeTask): void {
    for (const callback of this.taskCompleteCallbacks) {
      try {
        callback(task);
      } catch (error) {
        Logger.error(this.TAG, `Task complete callback error: ${error}`);
      }
    }
  }

  onProgress(callback: ProgressCallback): () => void {
    this.progressCallbacks.add(callback);
    return () => this.progressCallbacks.delete(callback);
  }

  onTaskComplete(callback: TaskCompleteCallback): () => void {
    this.taskCompleteCallbacks.add(callback);
    return () => this.taskCompleteCallbacks.delete(callback);
  }

  getStats(): ImageScrapeStats {
    return this.scraperService.getStats();
  }

  resetStats(): void {
    this.scraperService.resetStats();
  }

  async cleanupOldImages(maxAgeDays: number = 30): Promise<number> {
    const maxAge = maxAgeDays * 24 * 60 * 60 * 1000;
    return this.scraperService.cleanupOldImages(maxAge);
  }

  async getStorageUsage(): Promise<{ totalSize: number; imageCount: number; bookCount: number }> {
    return this.scraperService.getStorageUsage();
  }

  clearCache(): void {
    this.scraperService.clearCache();
  }
}
