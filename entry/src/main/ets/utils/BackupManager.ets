import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import { databaseManager } from './DatabaseManager';
import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig } from '../models/ReadConfig';
import { BookCategory } from '../models/BookCategory';
import { Chapter } from '../models/Book';
import { Bookmark } from '../models/Bookmark';
import common from '@ohos.app.ability.common';

/**
 * 备份数据模型
 */
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

/**
 * 备份管理器
 */
export class BackupManager {
  private static instance: BackupManager | null = null;
  private readonly backupDir: string = 'backup';

  private constructor() {
  }

  static getInstance(): BackupManager {
    if (BackupManager.instance === null) {
      BackupManager.instance = new BackupManager();
    }
    return BackupManager.instance;
  }

  /**
   * 执行全量备份
   */
  async backupAll(context: common.UIAbilityContext): Promise<string> {
    try {
      const backupData: BackupData = {
        version: '1.0.0',
        timestamp: Date.now(),
        books: await databaseManager.getAllBooks(),
        bookSources: await databaseManager.getAllEnabledBookSources(),
        categories: await databaseManager.getAllCategories(),
        chapters: [],
        bookmarks: [],
        readConfig: await databaseManager.getOrCreateReadConfig()
      };

      // 获取所有书籍的章节和书签
      for (const book of backupData.books) {
        const chapters = await databaseManager.getChaptersByBookId(book.id);
        backupData.chapters.push(...chapters);
        
        const bookmarks = await databaseManager.getBookmarksByBookId(book.id);
        backupData.bookmarks.push(...bookmarks);
      }

      // 保存到文件
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
      console.error('Backup failed:', error);
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

      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const content = decoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
      const backupData: BackupData = JSON.parse(content);

      // 恢复数据
      await this.restoreData(backupData);
    } catch (error) {
      console.error('Restore failed:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 恢复数据
   */
  private async restoreData(backupData: BackupData): Promise<void> {
    // 恢复书源
    for (const source of backupData.bookSources) {
      await databaseManager.upsertBookSource(source);
    }

    // 恢复分类
    for (const category of backupData.categories) {
      await databaseManager.addCategory(category);
    }

    // 恢复书籍
    for (const book of backupData.books) {
      await databaseManager.upsertBook(book);
    }

    // 恢复章节
    await databaseManager.batchUpsertChapters(backupData.chapters);

    // 恢复书签
    for (const bookmark of backupData.bookmarks) {
      await databaseManager.addBookmark(bookmark);
    }

    // 恢复阅读配置
    if (backupData.readConfig) {
      await databaseManager.updateReadConfig(backupData.readConfig);
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
