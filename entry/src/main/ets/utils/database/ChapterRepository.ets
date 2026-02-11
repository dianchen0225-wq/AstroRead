import relationalStore from '@ohos.data.relationalStore';
import { Chapter } from '../../models/Book';

/**
 * 章节数据库操作
 */
export class ChapterRepository {
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 根据书籍ID获取章节列表
   */
  async getChaptersByBookId(bookId: string): Promise<Chapter[]> {
    const predicates = new relationalStore.RdbPredicates('chapter');
    predicates.equalTo('book_id', bookId);
    predicates.orderByAsc('order');

    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const chapters: Chapter[] = [];

      while (resultSet.goToNextRow()) {
        const chapter = this.parseChapter(resultSet);
        chapters.push(chapter);
      }

      resultSet.close();
      return chapters;
    } catch (error) {
      console.error(`Failed to query chapters by book id: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 解析章节数据
   */
  private parseChapter(resultSet: relationalStore.ResultSet): Chapter {
    try {
      const idIndex = resultSet.getColumnIndex('id');
      const bookIdIndex = resultSet.getColumnIndex('book_id');
      const titleIndex = resultSet.getColumnIndex('title');
      const urlIndex = resultSet.getColumnIndex('url');
      const orderIndex = resultSet.getColumnIndex('order');
      const isVipIndex = resultSet.getColumnIndex('is_vip');

      return {
        id: resultSet.getString(idIndex) || '',
        bookId: resultSet.getString(bookIdIndex) || '',
        title: resultSet.getString(titleIndex) || '',
        url: resultSet.getString(urlIndex) || '',
        order: resultSet.getLong(orderIndex) || 0,
        isVip: resultSet.getLong(isVipIndex) === 1
      };
    } catch (error) {
      console.error(`Failed to parse chapter: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        bookId: '',
        title: '',
        url: '',
        order: 0,
        isVip: false
      };
    }
  }

  /**
   * 批量插入或更新章节
   */
  async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    if (chapters.length === 0) {
      return;
    }

    try {
      // 使用事务确保批量操作的原子性
      this.rdbStore.beginTransaction();

      for (const chapter of chapters) {
        const valueBucket: relationalStore.ValuesBucket = {
          'id': chapter.id,
          'book_id': chapter.bookId,
          'title': chapter.title,
          'url': chapter.url,
          'order': chapter.order,
          'is_vip': chapter.isVip ? 1 : 0
        };

        // 先尝试更新
        const predicates = new relationalStore.RdbPredicates('chapter');
        predicates.equalTo('id', chapter.id);
        const updatedRows = await this.rdbStore.update(valueBucket, predicates);
        
        // 如果更新失败则插入
        if (updatedRows === 0) {
          await this.rdbStore.insert('chapter', valueBucket);
        }
      }

      this.rdbStore.commit();
    } catch (error) {
      this.rdbStore.rollback();
      console.error(`Failed to batch upsert chapters: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}