import { BookSource } from '../../models/BookSource';
import { Logger } from './Logger';
import { LRUCache } from './LRUCache';
import { NetworkManager } from '../network/NetworkManager';
import { IdGenerator } from '../content/IdGenerator';

/**
 * 内容块
 */
interface ContentChunk {
  index: number;
  content: string;
  isComplete: boolean;
}

/**
 * 渐进式加载回调
 */
interface ProgressiveLoadCallbacks {
  onProgress?: (progress: number) => void;
  onPartial?: (chunk: ContentChunk) => void;
  onComplete?: (content: string) => void;
  onError?: (error: Error) => void;
}
/**
 * 加载任务
 */
interface LoadTask {
  chapterId: string;
  chapterUrl: string;
  bookSource: BookSource;
  isCancelled: boolean;
  callbacks: ProgressiveLoadCallbacks;
}

/**
 * 章节加载优化器
 * 使用TaskPool异步加载章节内容，支持渐进式加载和LRU缓存
 */
export class ChapterLoadOptimizer {
  private static instance: ChapterLoadOptimizer;
  private loadingQueue: Map<string, LoadTask> = new Map();
  private contentCache: LRUCache<string, string>;
  private networkManager: NetworkManager;

  private constructor() {
    this.contentCache = new LRUCache<string, string>(5, 30 * 60 * 1000); // 缓存5章，TTL 30分钟
    this.networkManager = NetworkManager.getInstance();
  }

  public static getInstance(): ChapterLoadOptimizer {
    if (!ChapterLoadOptimizer.instance) {
      ChapterLoadOptimizer.instance = new ChapterLoadOptimizer();
    }
    return ChapterLoadOptimizer.instance;
  }

  /**
   * 加载章节内容
   * @param chapterId 章节ID
   * @param chapterUrl 章节URL
   * @param bookSource 书源
   * @returns 章节内容
   */
  async loadChapter(
    chapterId: string,
    chapterUrl: string,
    bookSource: BookSource
  ): Promise<string> {
    Logger.info('ChapterLoadOptimizer', `开始加载章节: ${chapterId}`);

    // 检查缓存
    const cached = this.contentCache.get(chapterId);
    if (cached) {
      Logger.info('ChapterLoadOptimizer', `从缓存加载章节: ${chapterId}`);
      return cached;
    }

    // 检查是否正在加载
    if (this.loadingQueue.has(chapterId)) {
      Logger.info('ChapterLoadOptimizer', `章节正在加载中: ${chapterId}`);
      throw new Error('Chapter is loading');
    }
    // 创建加载任务
    const task: LoadTask = {
      chapterId,
      chapterUrl,
      bookSource,
      isCancelled: false,
      callbacks: {}
    };

    this.loadingQueue.set(chapterId, task);

    try {
      const content = await this.networkManager.getChapterContent(bookSource, chapterUrl);
      this.contentCache.set(chapterId, content);
      Logger.info('ChapterLoadOptimizer', `章节加载完成: ${chapterId}`);
      return content;
    } catch (error) {
      Logger.error('ChapterLoadOptimizer', `章节加载失败: ${chapterId}, ${error.message}`);
      throw new Error(error.message);
    } finally {
      this.loadingQueue.delete(chapterId);
    }
  }

  /**
   * 渐进式加载章节内容
   * @param chapterId 章节ID
   * @param chapterUrl 章节URL
   * @param bookSource 书源
   * @param callbacks 回调函数
   */
  async loadChapterProgressive(
    chapterId: string,
    chapterUrl: string,
    bookSource: BookSource,
    callbacks: ProgressiveLoadCallbacks
  ): Promise<void> {
    Logger.info('ChapterLoadOptimizer', `开始渐进式加载章节: ${chapterId}`);

    // 检查缓存
    const cached = this.contentCache.get(chapterId);
    if (cached) {
      Logger.info('ChapterLoadOptimizer', `从缓存加载章节: ${chapterId}`);
      callbacks.onComplete?.(cached);
      return;
    }

    // 检查是否正在加载
    if (this.loadingQueue.has(chapterId)) {
      Logger.info('ChapterLoadOptimizer', `章节正在加载中: ${chapterId}`);
      throw new Error('Chapter is loading');
    }
    // 创建加载任务
    const task: LoadTask = {
      chapterId,
      chapterUrl,
      bookSource,
      isCancelled: false,
      callbacks
    };

    this.loadingQueue.set(chapterId, task);

    try {
      const content = await this.networkManager.getChapterContent(bookSource, chapterUrl);

      // 分块处理内容
      const chunkSize = 100 * 1024; // 100KB
      const totalChunks = Math.ceil(content.length / chunkSize);

      for (let i = 0; i < totalChunks; i++) {
        const start = i * chunkSize;
        const end = Math.min(start + chunkSize, content.length);
        const chunkContent = content.substring(start, end);

        const chunk: ContentChunk = {
          index: i,
          content: chunkContent,
          isComplete: i === totalChunks - 1
        };

        callbacks.onPartial?.(chunk);
        callbacks.onProgress?.(((i + 1) / totalChunks) * 100);
      }

      this.contentCache.set(chapterId, content);
      callbacks.onComplete?.(content);
      Logger.info('ChapterLoadOptimizer', `章节渐进式加载完成: ${chapterId}`);
    } catch (error) {
      Logger.error('ChapterLoadOptimizer', `章节渐进式加载失败: ${chapterId}, ${error.message}`);
      callbacks.onError?.(new Error(error.message));
      throw new Error(error.message);
    } finally {
      this.loadingQueue.delete(chapterId);
    }
  }
  /**
   * 取消加载
   * @param chapterId 章节ID
   */
  cancelLoad(chapterId: string): boolean {
    const task = this.loadingQueue.get(chapterId);
    if (task) {
      task.isCancelled = true;
      this.loadingQueue.delete(chapterId);
      Logger.info('ChapterLoadOptimizer', `取消加载章节: ${chapterId}`);
      return true;
    }
    return false;
  }

  /**
   * 清空缓存
   */
  clearCache(): void {
    this.contentCache.clear();
    Logger.info('ChapterLoadOptimizer', '缓存已清空');
  }
  /**
   * 获取缓存统计信息
   */
  getCacheStats(): object {
    return this.contentCache.getStats();
  }
}
