import relationalStore from '@ohos.data.relationalStore';
import { Chapter } from '../../models/Book';
import { Logger } from '../Logger';

const DEFAULT_ORDER: number = 0;
const VIP_FLAG_TRUE: number = 1;
const VIP_FLAG_FALSE: number = 0;

const TABLE_CHAPTER: string = 'chapter';

export class ChapterRepository {
  private static readonly TAG = 'ChapterRepository';
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 根据书籍ID获取章节列表
   */
  async getChaptersByBookId(bookId: string): Promise<Chapter[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAPTER);
    try {
      predicates.equalTo('book_id', bookId);
      predicates.orderByAsc('order');
    } catch (error) {
      Logger.error(ChapterRepository.TAG, `设置查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const chapters: Chapter[] = [];

      while (resultSet.goToNextRow()) {
        const chapter = this.parseChapter(resultSet);
        chapters.push(chapter);
      }

      return chapters;
    }
    catch (error) {
      Logger.error(ChapterRepository.TAG, `查询章节列表失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
    finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(ChapterRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

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
        order: resultSet.getLong(orderIndex) || DEFAULT_ORDER,
        isVip: resultSet.getLong(isVipIndex) === VIP_FLAG_TRUE
      };
    }
    catch (error) {
      Logger.error(ChapterRepository.TAG, `解析章节数据失败: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        bookId: '',
        title: '',
        url: '',
        order: DEFAULT_ORDER,
        isVip: false
      };
    }
  }

  /**
   * 批量插入或更新章节
   */
  async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    if (chapters.length === DEFAULT_ORDER) {
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
          'is_vip': chapter.isVip ? VIP_FLAG_TRUE : VIP_FLAG_FALSE
        };

        // 先尝试更新
        const predicates = new relationalStore.RdbPredicates(TABLE_CHAPTER);
        predicates.equalTo('id', chapter.id);
        const updatedRows = await this.rdbStore.update(valueBucket, predicates);

        // 如果更新失败则插入
        if (updatedRows === DEFAULT_ORDER) {
          await this.rdbStore.insert(TABLE_CHAPTER, valueBucket);
        }
      }

      this.rdbStore.commit();
    }
    catch (error) {
      try {
        await this.rdbStore.rollback(relationalStore.TransactionType.IMMEDIATE);
      } catch (rollbackError) {
        Logger.error(ChapterRepository.TAG, `回滚失败: ${rollbackError instanceof Error ? rollbackError.message : String(rollbackError)}`);
      }
      Logger.error(ChapterRepository.TAG, `批量插入或更新章节失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}