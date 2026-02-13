import { databaseManager } from './DatabaseManager';
import { NetworkManager } from './NetworkManager';
import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';

/**
 * 后台任务类型
 */
export enum BackgroundTaskType {
  CACHE_CHAPTERS = 'cache_chapters',
  UPDATE_BOOK_SOURCES = 'update_book_sources',
  BACKUP_DATA = 'backup_data'
}

/**
 * 后台任务管理器
 */
export class BackgroundTaskManager {
  private static instance: BackgroundTaskManager | null = null;
  private readonly taskQueue: Map<string, Promise<void>> = new Map();

  private constructor() {
  }

  static getInstance(): BackgroundTaskManager {
    if (BackgroundTaskManager.instance === null) {
      BackgroundTaskManager.instance = new BackgroundTaskManager();
    }
    return BackgroundTaskManager.instance;
  }

  /**
   * 批量缓存章节
   */
  async cacheChapters(book: Book, bookSource: BookSource, chapterUrls: string[]): Promise<void> {
    const taskId = `cache_${book.id}`;
    
    if (this.taskQueue.has(taskId)) {
      return; // 任务已存在
    }

    const task = this.executeCacheTask(book, bookSource, chapterUrls);
    this.taskQueue.set(taskId, task);
    
    try {
      await task;
    } finally {
      this.taskQueue.delete(taskId);
    }
  }

  /**
   * 执行缓存任务
   */
  private async executeCacheTask(
    book: Book,
    bookSource: BookSource,
    chapterUrls: string[]
  ): Promise<void> {
    const networkManager = NetworkManager.getInstance();

    // 分批处理，避免一次性缓存太多
    const batchSize = 10;
    for (let i = 0; i < chapterUrls.length; i += batchSize) {
      const batch = chapterUrls.slice(i, i + batchSize);

      await Promise.all(batch.map(async (url: string) => {
        try {
          // 获取章节内容
          await networkManager.getChapterContent(bookSource, url);

          // TODO: 保存到本地缓存文件
          // 这里可以实现本地文件缓存逻辑

        } catch (error) {
          console.error(`Failed to cache chapter ${url}:`, error);
        }
      }));

      // 给UI线程一些时间
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => resolve(), 100);
      });
    }
  }

  /**
   * 更新书源
   */
  async updateBookSources(): Promise<void> {
    try {
      await databaseManager.getAllEnabledBookSources();

      // 这里可以实现书源自动更新逻辑
      // 例如：从远程服务器获取最新书源列表

    } catch (error) {
      console.error('Failed to update book sources:', error);
    }
  }

  /**
   * 取消任务
   */
  cancelTask(taskId: string): void {
    this.taskQueue.delete(taskId);
  }

  /**
   * 检查任务是否运行中
   */
  isTaskRunning(taskId: string): boolean {
    return this.taskQueue.has(taskId);
  }
}
