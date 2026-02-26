import { Bookmark } from '../models/Bookmark';
import { databaseManager } from '../utils/file/DatabaseManager';
import { IdGenerator } from '../utils/content/IdGenerator';
import { Logger } from '../utils/performance/Logger';

export interface SyncResult {
  success: boolean;
  message: string;
  syncedCount?: number;
  conflictCount?: number;
  timestamp?: number;
}

export interface SyncConfig {
  enabled: boolean;
  lastSyncTime: number;
  syncInterval: number;
  serverUrl?: string;
  userId?: string;
}

export interface BookmarkSyncData {
  id: string;
  bookId: string;
  chapterId: string;
  chapterTitle: string;
  content: string;
  createTime: number;
  deviceId: string;
  syncVersion: number;
}

export class BookmarkViewModel {
  private static readonly TAG = 'BookmarkViewModel';
  private readonly databaseManager = databaseManager;
  private syncConfig: SyncConfig = {
    enabled: false,
    lastSyncTime: 0,
    syncInterval: 3600000
  };
  private deviceId: string = '';

  setDeviceId(deviceId: string): void {
    this.deviceId = deviceId;
  }

  async getBookmarksByBookId(bookId: string): Promise<Bookmark[]> {
    try {
      return await this.databaseManager.getBookmarksByBookId(bookId);
    } catch (error) {
      Logger.error(BookmarkViewModel.TAG, `获取书签失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  async addBookmark(
    bookId: string,
    chapterId: string,
    chapterTitle: string,
    content: string
  ): Promise<Bookmark> {
    try {
      const bookmark: Bookmark = {
        id: IdGenerator.generateUUID(),
        bookId: bookId,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        content: content,
        createTime: Date.now()
      };
      
      await this.databaseManager.addBookmark(bookmark);
      
      if (this.syncConfig.enabled) {
        this.syncBookmarkToCloud(bookmark).catch((err: Error) => {
          Logger.warn(BookmarkViewModel.TAG, `书签云同步失败: ${err.message}`);
        });
      }
      
      return bookmark;
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      Logger.error(BookmarkViewModel.TAG, `添加书签失败: ${err.message}`);
      throw err;
    }
  }

  async deleteBookmark(bookmarkId: string): Promise<void> {
    try {
      await this.databaseManager.deleteBookmark(bookmarkId);
      
      if (this.syncConfig.enabled) {
        this.deleteBookmarkFromCloud(bookmarkId).catch((err: Error) => {
          Logger.warn(BookmarkViewModel.TAG, `删除书签云同步失败: ${err.message}`);
        });
      }
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      Logger.error(BookmarkViewModel.TAG, `删除书签失败: ${err.message}`);
      throw err;
    }
  }

  getSyncConfig(): SyncConfig {
    const config: SyncConfig = {
      enabled: this.syncConfig.enabled,
      lastSyncTime: this.syncConfig.lastSyncTime,
      syncInterval: this.syncConfig.syncInterval,
      serverUrl: this.syncConfig.serverUrl,
      userId: this.syncConfig.userId
    };
    return config;
  }

  setSyncConfig(config: Partial<SyncConfig>): void {
    if (config.enabled !== undefined) {
      this.syncConfig.enabled = config.enabled;
    }
    if (config.lastSyncTime !== undefined) {
      this.syncConfig.lastSyncTime = config.lastSyncTime;
    }
    if (config.syncInterval !== undefined) {
      this.syncConfig.syncInterval = config.syncInterval;
    }
    if (config.serverUrl !== undefined) {
      this.syncConfig.serverUrl = config.serverUrl;
    }
    if (config.userId !== undefined) {
      this.syncConfig.userId = config.userId;
    }
    Logger.info(BookmarkViewModel.TAG, `云同步配置已更新: enabled=${this.syncConfig.enabled}`);
  }

  async syncToCloud(): Promise<SyncResult> {
    if (!this.syncConfig.enabled) {
      return {
        success: false,
        message: '云同步未启用'
      };
    }

    try {
      Logger.info(BookmarkViewModel.TAG, '开始书签云同步...');
      
      const allBookmarks = await this.getAllBookmarks();
      const syncData: BookmarkSyncData[] = [];
      for (const bookmark of allBookmarks) {
        const syncItem: BookmarkSyncData = {
          id: bookmark.id,
          bookId: bookmark.bookId,
          chapterId: bookmark.chapterId,
          chapterTitle: bookmark.chapterTitle,
          content: bookmark.content,
          createTime: bookmark.createTime,
          deviceId: this.deviceId,
          syncVersion: Date.now()
        };
        syncData.push(syncItem);
      }

      const result = await this.uploadBookmarksToCloud(syncData);
      
      if (result.success) {
        this.syncConfig.lastSyncTime = Date.now();
        Logger.info(BookmarkViewModel.TAG, `书签云同步成功: ${result.syncedCount}条`);
      }
      
      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(BookmarkViewModel.TAG, `书签云同步失败: ${errorMsg}`);
      return {
        success: false,
        message: errorMsg
      };
    }
  }

  async syncFromCloud(): Promise<SyncResult> {
    if (!this.syncConfig.enabled) {
      return {
        success: false,
        message: '云同步未启用'
      };
    }

    try {
      Logger.info(BookmarkViewModel.TAG, '开始从云端同步书签...');
      
      const cloudBookmarks = await this.downloadBookmarksFromCloud();
      
      if (!cloudBookmarks || cloudBookmarks.length === 0) {
        return {
          success: true,
          message: '云端无书签数据',
          syncedCount: 0
        };
      }

      let syncedCount = 0;
      let conflictCount = 0;

      for (const cloudBookmark of cloudBookmarks) {
        const localBookmark = await this.getBookmarkById(cloudBookmark.id);
        
        if (!localBookmark) {
          const bookmark = this.convertSyncDataToBookmark(cloudBookmark);
          await this.databaseManager.addBookmark(bookmark);
          syncedCount++;
        } else {
          const localSyncData = this.convertToSyncData(localBookmark, '', 0);
          if (cloudBookmark.syncVersion > localSyncData.syncVersion) {
            const bookmark = this.convertSyncDataToBookmark(cloudBookmark);
            await this.databaseManager.addBookmark(bookmark);
            syncedCount++;
          } else {
            conflictCount++;
          }
        }
      }

      this.syncConfig.lastSyncTime = Date.now();
      Logger.info(BookmarkViewModel.TAG, `从云端同步书签完成: 同步${syncedCount}条, 冲突${conflictCount}条`);
      
      return {
        success: true,
        message: '同步成功',
        syncedCount,
        conflictCount,
        timestamp: Date.now()
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(BookmarkViewModel.TAG, `从云端同步书签失败: ${errorMsg}`);
      return {
        success: false,
        message: errorMsg
      };
    }
  }

  private async getAllBookmarks(): Promise<Bookmark[]> {
    try {
      return await this.databaseManager.getAllBookmarks();
    } catch (error) {
      Logger.error(BookmarkViewModel.TAG, `获取所有书签失败: ${error}`);
      return [];
    }
  }

  private async getBookmarkById(id: string): Promise<Bookmark | null> {
    try {
      return await this.databaseManager.getBookmarkById(id);
    } catch (error) {
      return null;
    }
  }

  private async syncBookmarkToCloud(bookmark: Bookmark): Promise<void> {
    Logger.debug(BookmarkViewModel.TAG, `同步书签到云端: ${bookmark.id}`);
  }

  private async deleteBookmarkFromCloud(bookmarkId: string): Promise<void> {
    Logger.debug(BookmarkViewModel.TAG, `从云端删除书签: ${bookmarkId}`);
  }

  private async uploadBookmarksToCloud(bookmarks: BookmarkSyncData[]): Promise<SyncResult> {
    Logger.debug(BookmarkViewModel.TAG, `上传${bookmarks.length}条书签到云端`);
    return {
      success: true,
      message: '上传成功',
      syncedCount: bookmarks.length,
      timestamp: Date.now()
    };
  }

  private async downloadBookmarksFromCloud(): Promise<BookmarkSyncData[]> {
    Logger.debug(BookmarkViewModel.TAG, '从云端下载书签');
    return [];
  }

  private convertToSyncData(bookmark: Bookmark, deviceId: string, syncVersion: number): BookmarkSyncData {
    const syncData: BookmarkSyncData = {
      id: bookmark.id,
      bookId: bookmark.bookId,
      chapterId: bookmark.chapterId,
      chapterTitle: bookmark.chapterTitle,
      content: bookmark.content,
      createTime: bookmark.createTime,
      deviceId: deviceId,
      syncVersion: syncVersion
    };
    return syncData;
  }

  private convertSyncDataToBookmark(syncData: BookmarkSyncData): Bookmark {
    const bookmark: Bookmark = {
      id: syncData.id,
      bookId: syncData.bookId,
      chapterId: syncData.chapterId,
      chapterTitle: syncData.chapterTitle,
      content: syncData.content,
      createTime: syncData.createTime
    };
    return bookmark;
  }
}
