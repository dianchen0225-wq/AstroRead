import { relationalStore } from '@kit.ArkData';
import { Bookmark } from '../../models/Bookmark';
import { Logger } from '../Logger';

export class BookmarkRepository {
  private static readonly TAG = 'BookmarkRepository';
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 根据书籍ID获取书签列表
   */
  async getBookmarksByBookId(bookId: string): Promise<Bookmark[]> {
    const predicates = new relationalStore.RdbPredicates('bookmark');
    try {
      predicates.equalTo('book_id', bookId);
      predicates.orderByDesc('create_time');
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `设置查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookmarks: Bookmark[] = [];

      while (resultSet.goToNextRow()) {
        const bookmark = this.parseBookmark(resultSet);
        bookmarks.push(bookmark);
      }

      return bookmarks;
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `查询书签列表失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookmarkRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

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
      Logger.error(BookmarkRepository.TAG, `解析书签数据失败: ${error instanceof Error ? error.message : String(error)}`);
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
      Logger.error(BookmarkRepository.TAG, `添加书签失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async deleteBookmark(bookmarkId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('bookmark');
      predicates.equalTo('id', bookmarkId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `删除书签失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async getAllBookmarks(): Promise<Bookmark[]> {
    const predicates = new relationalStore.RdbPredicates('bookmark');
    try {
      predicates.orderByDesc('create_time');
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `设置查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookmarks: Bookmark[] = [];

      while (resultSet.goToNextRow()) {
        const bookmark = this.parseBookmark(resultSet);
        bookmarks.push(bookmark);
      }

      return bookmarks;
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `查询所有书签失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookmarkRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

  async getBookmarkById(id: string): Promise<Bookmark | null> {
    const predicates = new relationalStore.RdbPredicates('bookmark');
    try {
      predicates.equalTo('id', id);
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `设置查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      if (resultSet.goToNextRow()) {
        return this.parseBookmark(resultSet);
      }
      return null;
    } catch (error) {
      Logger.error(BookmarkRepository.TAG, `查询书签失败: ${error instanceof Error ? error.message : String(error)}`);
      return null;
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookmarkRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }
}
