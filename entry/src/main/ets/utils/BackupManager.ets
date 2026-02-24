import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { DatabaseManager } from './DatabaseManager';
import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { BookCategory } from '../models/BookCategory';
import { Chapter } from '../models/Book';
import { Bookmark } from '../models/Bookmark';
import { Logger } from './Logger';
import { common } from '@kit.AbilityKit';

export interface BackupData {
  version: string;
  timestamp: number;
  books: Book[];
  bookSources: BookSource[];
  categories: BookCategory[];
  chapters: Chapter[];
  bookmarks: Bookmark[];
  readConfig: ReadConfig | null;
}

export class BackupManager {
  private static readonly TAG = 'BackupManager';
  private static instance: BackupManager | null = null;
  private databaseManager: DatabaseManager | null = null;

  private constructor() {
  }

  static getInstance(): BackupManager {
    if (BackupManager.instance === null) {
      BackupManager.instance = new BackupManager();
    }
    return BackupManager.instance;
  }

  /**
   * 设置数据库管理器实例
   */
  setDatabaseManager(databaseManager: DatabaseManager): void {
    this.databaseManager = databaseManager;
  }

  /**
   * 获取数据库管理器实例
   */
  private getDatabaseManager(): DatabaseManager {
    if (this.databaseManager === null) {
      throw new Error('DatabaseManager not set. Please call setDatabaseManager() first.');
    }
    return this.databaseManager;
  }

  /**
   * 执行全量备份
   */
  async backupAll(context: common.UIAbilityContext): Promise<string> {
    try {
      const databaseManager = this.getDatabaseManager();
      
      const backupData: BackupData = {
        version: '1.0.0',
        timestamp: Date.now(),
        books: await databaseManager.getAllBooks(),
        bookSources: await databaseManager.getAllBookSources(),
        categories: await databaseManager.getAllBookCategories(),
        chapters: [],
        bookmarks: [],
        readConfig: await databaseManager.getOrCreateReadConfig()
      };

      for (const book of backupData.books) {
        const chapters = await databaseManager.getChaptersByBookId(book.id);
        if (chapters && chapters.length > 0) {
          backupData.chapters = backupData.chapters.concat(chapters);
        }
        
        const bookmarks = await databaseManager.getBookmarksByBookId(book.id);
        if (bookmarks && bookmarks.length > 0) {
          backupData.bookmarks = backupData.bookmarks.concat(bookmarks);
        }
      }

      const backupDir = context.filesDir + '/backup';
      await this.ensureDirectory(backupDir);
      
      const fileName = `backup_${backupData.timestamp}.json`;
      const filePath = backupDir + '/' + fileName;
      
      const file = await fileIo.open(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const content = JSON.stringify(backupData, null, 2);
      await fileIo.write(file.fd, content);
      await fileIo.close(file.fd);

      return filePath;
    } catch (error) {
      Logger.error(BackupManager.TAG, `备份失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 恢复备份
   */
  async restoreFromFile(filePath: string): Promise<void> {
    try {
      const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(filePath);
      const buffer = new ArrayBuffer(stat.size);
      await fileIo.read(file.fd, buffer);
      await fileIo.close(file.fd);

      const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
      const content = decoder.decodeToString(new Uint8Array(buffer), { stream: false });
      const backupData: BackupData = JSON.parse(content);

      // 恢复数据
      await this.restoreData(backupData);
    } catch (error) {
      Logger.error(BackupManager.TAG, `恢复失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 恢复数据
   */
  private async restoreData(backupData: BackupData): Promise<void> {
    const databaseManager = this.getDatabaseManager();
    
    for (const book of backupData.books) {
      await databaseManager.upsertBook(book);
    }

    if (backupData.chapters && backupData.chapters.length > 0) {
      await databaseManager.batchUpsertChapters(backupData.chapters);
    }

    if (backupData.bookmarks && backupData.bookmarks.length > 0) {
      for (const bookmark of backupData.bookmarks) {
        await databaseManager.addBookmark(bookmark);
      }
    }

    if (backupData.readConfig) {
      await databaseManager.updateReadConfig(backupData.readConfig);
    }

    if (backupData.bookSources && backupData.bookSources.length > 0) {
      await databaseManager.batchUpsertBookSources(backupData.bookSources);
    }

    if (backupData.categories && backupData.categories.length > 0) {
      for (const category of backupData.categories) {
        await databaseManager.addBookCategory(category);
      }
    }
  }

  /**
   * 确保目录存在
   */
  private async ensureDirectory(path: string): Promise<void> {
    try {
      const stat = await fileIo.stat(path);
      if (!stat.isDirectory()) {
        await fileIo.mkdir(path, true);
      }
    } catch (error) {
      await fileIo.mkdir(path, true);
    }
  }

  /**
   * 导出备份文件（用于分享）
   */
  async exportBackup(context: common.UIAbilityContext): Promise<string> {
    return await this.backupAll(context);
  }
}