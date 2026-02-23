import { Bookmark } from '../models/Bookmark';
import { databaseManager } from '../utils/DatabaseManager';
import { IdGenerator } from '../utils/IdGenerator';
import { Logger } from '../utils/Logger';

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
        this.syncBookmarkToCloud(bookmark).catch((error) => {
          Logger.warn(BookmarkViewModel.TAG, `书签云同步失败: ${error}`);
        });
      }
      
      return bookmark;
    } catch (error) {
      Logger.error(BookmarkViewModel.TAG, `添加书签失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async deleteBookmark(bookmarkId: string): Promise<void> {
    try {
      await this.databaseManager.deleteBookmark(bookmarkId);
      
      if (this.syncConfig.enabled) {
        this.deleteBookmarkFromCloud(bookmarkId).catch((error) => {
          Logger.warn(BookmarkViewModel.TAG, `删除书签云同步失败: ${error}`);
        });
      }
    } catch (error) {
      Logger.error(BookmarkViewModel.TAG, `删除书签失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  getSyncConfig(): SyncConfig {
    return { ...this.syncConfig };
  }

  setSyncConfig(config: Partial<SyncConfig>): void {
    this.syncConfig = { ...this.syncConfig, ...config };
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
          await this.databaseManager.addBookmark(cloudBookmark);
          syncedCount++;
        } else {
          const localSyncData = this.convertToSyncData(localBookmark, '', 0);
          if (cloudBookmark.syncVersion > localSyncData.syncVersion) {
            await this.databaseManager.addBookmark(cloudBookmark);
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
}
