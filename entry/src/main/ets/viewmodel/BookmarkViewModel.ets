import { Bookmark } from '../models/Bookmark';
import { databaseManager } from '../utils/DatabaseManager';
import { IdGenerator } from '../utils/IdGenerator';

/**
 * 书签视图模型
 */
export class BookmarkViewModel {
  private readonly databaseManager = databaseManager;

  /**
   * 获取书籍的所有书签
   */
  async getBookmarksByBookId(bookId: string): Promise<Bookmark[]> {
    try {
      return await this.databaseManager.getBookmarksByBookId(bookId);
    } catch (error) {
      console.error('Failed to get bookmarks:', error);
      return [];
    }
  }

  /**
   * 添加书签
   */
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
      console.error('Failed to add bookmark:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 删除书签
   */
  async deleteBookmark(bookmarkId: string): Promise<void> {
    try {
      await this.databaseManager.deleteBookmark(bookmarkId);
    } catch (error) {
      console.error('Failed to delete bookmark:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}
