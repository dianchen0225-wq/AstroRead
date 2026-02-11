import relationalStore from '@ohos.data.relationalStore';
import { Bookmark } from '../../models/Bookmark';

/**
 * 书签数据库操作
 */
export class BookmarkRepository {
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 根据书籍ID获取书签列表
   */
  async getBookmarksByBookId(bookId: string): Promise<Bookmark[]> {
    const predicates = new relationalStore.RdbPredicates('bookmark');
    predicates.equalTo('book_id', bookId);
    predicates.orderByDesc('create_time');

    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookmarks: Bookmark[] = [];

      while (resultSet.goToNextRow()) {
        const bookmark = this.parseBookmark(resultSet);
        bookmarks.push(bookmark);
      }

      resultSet.close();
      return bookmarks;
    } catch (error) {
      console.error(`Failed to query bookmarks by book id: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 解析书签数据
   */
  private parseBookmark(resultSet: relationalStore.ResultSet): Bookmark {
    try {
      const idIndex = resultSet.getColumnIndex('id');
      const bookIdIndex = resultSet.getColumnIndex('book_id');
      const chapterIdIndex = resultSet.getColumnIndex('chapter_id');
      const chapterTitleIndex = resultSet.getColumnIndex('chapter_title');
      const contentIndex = resultSet.getColumnIndex('content');
      const createTimeIndex = resultSet.getColumnIndex('create_time');

      return {
        id: resultSet.getString(idIndex) || '',
        bookId: resultSet.getString(bookIdIndex) || '',
        chapterId: resultSet.getString(chapterIdIndex) || '',
        chapterTitle: resultSet.getString(chapterTitleIndex) || '',
        content: resultSet.getString(contentIndex) || '',
        createTime: resultSet.getLong(createTimeIndex) || 0
      };
    } catch (error) {
      console.error(`Failed to parse bookmark: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        bookId: '',
        chapterId: '',
        chapterTitle: '',
        content: '',
        createTime: 0
      };
    }
  }

  /**
   * 添加书签
   */
  async addBookmark(bookmark: Bookmark): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'id': bookmark.id,
      'book_id': bookmark.bookId,
      'chapter_id': bookmark.chapterId,
      'chapter_title': bookmark.chapterTitle,
      'content': bookmark.content,
      'create_time': Date.now()
    };

    try {
      await this.rdbStore.insert('bookmark', valueBucket);
    } catch (error) {
      console.error(`Failed to add bookmark: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 删除书签
   */
  async deleteBookmark(bookmarkId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('bookmark');
      predicates.equalTo('id', bookmarkId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error(`Failed to delete bookmark: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
