import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { Logger } from './Logger';
import { DatabaseSchema } from './database/DatabaseSchema';
import { BookRepository } from './database/BookRepository';
import { BookSourceRepository } from './database/BookSourceRepository';
import { CategoryRepository } from './database/CategoryRepository';
import { ReadConfigRepository } from './database/ReadConfigRepository';
import { ChapterRepository } from './database/ChapterRepository';
import { BookmarkRepository } from './database/BookmarkRepository';
import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { BookCategory } from '../models/BookCategory';
import { Bookmark } from '../models/Bookmark';
import { Chapter } from '../models/Book';

export class DatabaseManager {
  private rdbStore: relationalStore.RdbStore | null = null;

  private bookRepository: BookRepository | null = null;
  private bookSourceRepository: BookSourceRepository | null = null;
  private categoryRepository: CategoryRepository | null = null;
  private readConfigRepository: ReadConfigRepository | null = null;
  private chapterRepository: ChapterRepository | null = null;
  private bookmarkRepository: BookmarkRepository | null = null;

  private constructor() {
  }

  static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  private static instance: DatabaseManager | null = null;

  async initDatabase(context: common.UIAbilityContext): Promise<void> {
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, DatabaseSchema.DB_CONFIG);
      await DatabaseSchema.createTables(this.rdbStore);
      this.initRepositories();
      await this.initDefaultData();
    } catch (error) {
      Logger.error('DatabaseManager', `初始化数据库失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  private initRepositories(): void {
    if (this.rdbStore === null) {
      return;
    }
    this.bookRepository = new BookRepository(this.rdbStore);
    this.bookSourceRepository = new BookSourceRepository(this.rdbStore);
    this.categoryRepository = new CategoryRepository(this.rdbStore);
    this.readConfigRepository = new ReadConfigRepository(this.rdbStore);
    this.chapterRepository = new ChapterRepository(this.rdbStore);
    this.bookmarkRepository = new BookmarkRepository(this.rdbStore);
  }

  private async initDefaultData(): Promise<void> {
    if (this.readConfigRepository) {
      await this.readConfigRepository.getOrCreateReadConfig();
    }
  }

  /**
   * 获取书籍 Repository
   */
  getBookRepo(): BookRepository {
    if (!this.bookRepository) {
      throw new Error('Database not initialized');
    }
    return this.bookRepository;
  }

  /**
   * 获取书源 Repository
   */
  getBookSourceRepo(): BookSourceRepository {
    if (!this.bookSourceRepository) {
      throw new Error('Database not initialized');
    }
    return this.bookSourceRepository;
  }

  /**
   * 获取分类 Repository
   */
  getCategoryRepo(): CategoryRepository {
    if (!this.categoryRepository) {
      throw new Error('Database not initialized');
    }
    return this.categoryRepository;
  }

  /**
   * 获取阅读配置 Repository
   */
  getReadConfigRepo(): ReadConfigRepository {
    if (!this.readConfigRepository) {
      throw new Error('Database not initialized');
    }
    return this.readConfigRepository;
  }

  /**
   * 获取章节 Repository
   */
  getChapterRepo(): ChapterRepository {
    if (!this.chapterRepository) {
      throw new Error('Database not initialized');
    }
    return this.chapterRepository;
  }

  /**
   * 获取书签 Repository
   */
  getBookmarkRepo(): BookmarkRepository {
    if (!this.bookmarkRepository) {
      throw new Error('Database not initialized');
    }
    return this.bookmarkRepository;
  }

  // ========== 便捷方法 - 保持向后兼容 ==========

  // 阅读配置
  async getOrCreateReadConfig(): Promise<ReadConfig> {
    return this.getReadConfigRepo().getOrCreateReadConfig();
  }

  async updateReadConfig(config: ReadConfig): Promise<void> {
    return this.getReadConfigRepo().updateReadConfig(config);
  }

  // 书籍
  async getAllBooks(): Promise<Book[]> {
    return this.getBookRepo().getAllBooks();
  }

  async getBooksByCategory(categoryId: string): Promise<Book[]> {
    return this.getBookRepo().getBooksByCategory(categoryId);
  }

  async upsertBook(book: Book): Promise<void> {
    return this.getBookRepo().upsertBook(book);
  }

  async deleteBook(bookId: string): Promise<void> {
    return this.getBookRepo().deleteBook(bookId);
  }

  // 章节
  async getChaptersByBookId(bookId: string): Promise<Chapter[]> {
    return this.getChapterRepo().getChaptersByBookId(bookId);
  }

  async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    return this.getChapterRepo().batchUpsertChapters(chapters);
  }

  // 书签
  async getBookmarksByBookId(bookId: string): Promise<Bookmark[]> {
    return this.getBookmarkRepo().getBookmarksByBookId(bookId);
  }

  async addBookmark(bookmark: Bookmark): Promise<void> {
    return this.getBookmarkRepo().addBookmark(bookmark);
  }

  async deleteBookmark(bookmarkId: string): Promise<void> {
    return this.getBookmarkRepo().deleteBookmark(bookmarkId);
  }

  // 书源
  async getAllEnabledBookSources(): Promise<BookSource[]> {
    return this.getBookSourceRepo().getAllEnabledBookSources();
  }

  async getAllBookSources(): Promise<BookSource[]> {
    return this.getBookSourceRepo().getAllBookSources();
  }

  async upsertBookSource(bookSource: BookSource): Promise<void> {
    return this.getBookSourceRepo().upsertBookSource(bookSource);
  }

  async batchUpsertBookSources(sources: BookSource[]): Promise<void> {
    return this.getBookSourceRepo().batchUpsertBookSources(sources);
  }

  async deleteBookSource(sourceId: string): Promise<void> {
    return this.getBookSourceRepo().deleteBookSource(sourceId);
  }

  // 分类
  async getAllBookCategories(): Promise<BookCategory[]> {
    return this.getCategoryRepo().getAllBookCategories();
  }

  async addBookCategory(category: BookCategory): Promise<void> {
    return this.getCategoryRepo().addBookCategory(category);
  }

  async deleteCategory(categoryId: string): Promise<void> {
    return this.getCategoryRepo().deleteCategory(categoryId);
  }

  async addBookToCategory(bookId: string, categoryId: string): Promise<void> {
    return this.getCategoryRepo().addBookToCategory(bookId, categoryId);
  }

  async removeBookFromCategory(bookId: string, categoryId: string): Promise<void> {
    return this.getCategoryRepo().removeBookFromCategory(bookId, categoryId);
  }
}

// 导出默认实例
export const databaseManager = DatabaseManager.getInstance();

// 导出所有 Repository 类型以便按需使用
export { BookRepository, BookSourceRepository, CategoryRepository, ReadConfigRepository, ChapterRepository, BookmarkRepository };
