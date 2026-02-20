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
      predicates.orderByAsc('chapter_order');
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
      const orderIndex = resultSet.getColumnIndex('chapter_order');
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

  async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    if (chapters.length === 0) {
      return;
    }

    const BATCH_SIZE = 200;
    let insertedCount = 0;
    let failedCount = 0;

    Logger.info(ChapterRepository.TAG, `开始批量插入 ${chapters.length} 个章节，每批 ${BATCH_SIZE} 个`);

    try {
      await this.deleteChaptersByBookId(chapters[0].bookId);
      Logger.info(ChapterRepository.TAG, `已删除书籍 ${chapters[0].bookId} 的旧章节数据`);

      for (let i = 0; i < chapters.length; i += BATCH_SIZE) {
        const batch = chapters.slice(i, i + BATCH_SIZE);
        const valueBuckets: relationalStore.ValuesBucket[] = [];

        for (const chapter of batch) {
          valueBuckets.push({
            'id': chapter.id,
            'book_id': chapter.bookId,
            'title': chapter.title,
            'url': chapter.url,
            'chapter_order': chapter.order,
            'is_vip': chapter.isVip ? VIP_FLAG_TRUE : VIP_FLAG_FALSE
          });
        }

        try {
          const insertCount = await this.rdbStore.batchInsert(TABLE_CHAPTER, valueBuckets);
          insertedCount += insertCount;
          Logger.debug(ChapterRepository.TAG, `批次 ${Math.floor(i / BATCH_SIZE) + 1} 插入成功: ${insertCount} 条`);
        } catch (batchError) {
          failedCount += batch.length;
          Logger.error(ChapterRepository.TAG, `批次 ${Math.floor(i / BATCH_SIZE) + 1} 插入失败: ${batchError instanceof Error ? batchError.message : String(batchError)}`);
          
          for (const chapter of batch) {
            try {
              const valueBucket: relationalStore.ValuesBucket = {
                'id': chapter.id,
                'book_id': chapter.bookId,
                'title': chapter.title,
                'url': chapter.url,
                'chapter_order': chapter.order,
                'is_vip': chapter.isVip ? VIP_FLAG_TRUE : VIP_FLAG_FALSE
              };
              await this.rdbStore.insert(TABLE_CHAPTER, valueBucket);
              insertedCount++;
            } catch (singleError) {
              Logger.warn(ChapterRepository.TAG, `单条插入失败 - 章节ID: ${chapter.id}, 标题: ${chapter.title}`);
            }
          }
        }
      }

      Logger.info(ChapterRepository.TAG, `批量插入完成 - 成功: ${insertedCount}, 失败: ${failedCount}`);
      
      if (insertedCount === 0) {
        throw new Error('所有章节插入失败');
      }
    }
    catch (error) {
      Logger.error(ChapterRepository.TAG, `批量插入章节失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async deleteChaptersByBookId(bookId: string): Promise<number> {
    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_CHAPTER);
      predicates.equalTo('book_id', bookId);
      const deletedRows = await this.rdbStore.delete(predicates);
      Logger.debug(ChapterRepository.TAG, `删除书籍 ${bookId} 的 ${deletedRows} 个章节`);
      return deletedRows;
    } catch (error) {
      Logger.error(ChapterRepository.TAG, `删除章节失败: ${error instanceof Error ? error.message : String(error)}`);
      return 0;
    }
  }
}