import { Bookmark } from '../models/Bookmark';
import { databaseManager } from '../utils/DatabaseManager';
import { IdGenerator } from '../utils/IdGenerator';
import { Logger } from '../utils/Logger';

export class BookmarkViewModel {
  private static readonly TAG = 'BookmarkViewModel';
  private readonly databaseManager = databaseManager;

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
      return bookmark;
    } catch (error) {
      Logger.error(BookmarkViewModel.TAG, `添加书签失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async deleteBookmark(bookmarkId: string): Promise<void> {
    try {
      await this.databaseManager.deleteBookmark(bookmarkId);
    } catch (error) {
      Logger.error(BookmarkViewModel.TAG, `删除书签失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}
