import relationalStore from '@ohos.data.relationalStore';
import { BookSource, SearchRule, FindRule, ChapterRule, ContentRule } from '../../models/BookSource';
import { Logger } from '../Logger';

const DB_ENABLED_TRUE: number = 1;
const DB_ENABLED_FALSE: number = 0;
const DB_DEFAULT_SORT: number = 0;
const DB_DEFAULT_TIME: number = 0;
const DB_UPDATED_ROWS_ZERO: number = 0;

const DB_COLUMN_ID: string = 'id';
export interface PagedBookSourcesResult {
  sources: BookSource[];
  total: number;
}

export class BookSourceRepository {
  private static readonly TAG = 'BookSourceRepository';
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 获取所有启用的书源
   */
  async getAllEnabledBookSources(): Promise<BookSource[]> {
    const predicates = new relationalStore.RdbPredicates('book_source');
    try {
      predicates.equalTo('enabled', DB_ENABLED_TRUE);
      predicates.orderByAsc('sort');
    } catch (error) {
      Logger.error(BookSourceRepository.TAG, `设置查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookSources: BookSource[] = [];

      while (resultSet.goToNextRow()) {
        const bookSource = this.parseBookSource(resultSet);
        bookSources.push(bookSource);
      }

      return bookSources;
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `查询启用的书源失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
    finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookSourceRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

  async getAllBookSources(): Promise<BookSource[]> {
    const predicates = new relationalStore.RdbPredicates('book_source');
    try {
      predicates.orderByAsc('sort');
    } catch (error) {
      Logger.error(BookSourceRepository.TAG, `设置排序失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookSources: BookSource[] = [];

      while (resultSet.goToNextRow()) {
        const bookSource = this.parseBookSource(resultSet);
        bookSources.push(bookSource);
      }

      return bookSources;
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `查询所有书源失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
    finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookSourceRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

    async getBookSourceById(id: string): Promise<BookSource | null> {
      const predicates = new relationalStore.RdbPredicates('book_source');
      try {
        predicates.equalTo('id', id);
      } catch (error) {
        Logger.error(BookSourceRepository.TAG, `设置查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
      }

      let resultSet: relationalStore.ResultSet | null = null;
      try {
        resultSet = await this.rdbStore.query(predicates, ['*']);
        let bookSource: BookSource | null = null;

        if (resultSet.goToNextRow()) {
          bookSource = this.parseBookSource(resultSet);
        }

        return bookSource;
      }
      catch (error) {
        Logger.error(BookSourceRepository.TAG, `查询书源失败: ${error instanceof Error ? error.message : String(error)}`);
        return null;
      }
      finally {
        if (resultSet) {
          try {
            resultSet.close();
          } catch (e) {
            Logger.warn(BookSourceRepository.TAG, `关闭resultSet失败: ${e}`);
          }
        }
      }
    }

  async getBookSourcesPaged(page: number, pageSize: number): Promise<PagedBookSourcesResult> {
    const offset = (page - 1) * pageSize;
    const predicates = new relationalStore.RdbPredicates('book_source');
    try {
      predicates.orderByAsc('sort');
      predicates.limitAs(pageSize);
      predicates.offsetAs(offset);
    } catch (error) {
      Logger.error(BookSourceRepository.TAG, `设置分页查询条件失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    let totalResultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookSources: BookSource[] = [];

      while (resultSet.goToNextRow()) {
        const bookSource = this.parseBookSource(resultSet);
        bookSources.push(bookSource);
      }

      try {
        resultSet.close();
      } catch (closeError) {
        Logger.warn(BookSourceRepository.TAG, `关闭resultSet失败: ${closeError}`);
      }
      resultSet = null;

      const totalPredicates = new relationalStore.RdbPredicates('book_source');
      totalResultSet = await this.rdbStore.query(totalPredicates, ['COUNT(*) as count']);
      let total = 0;
      if (totalResultSet.goToNextRow()) {
        total = totalResultSet.getLong(totalResultSet.getColumnIndex('count'));
      }

      const result: PagedBookSourcesResult = { sources: bookSources, total: total };
      return result;
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `分页查询书源失败: ${error instanceof Error ? error.message : String(error)}`);
      const emptyResult: PagedBookSourcesResult = { sources: [], total: 0 };
      return emptyResult;
    }
    finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookSourceRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
      if (totalResultSet) {
        try {
          totalResultSet.close();
        } catch (e) {
          Logger.warn(BookSourceRepository.TAG, `关闭totalResultSet失败: ${e}`);
        }
      }
    }
  }

  async getBookSourcesCount(): Promise<number> {
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      const predicates = new relationalStore.RdbPredicates('book_source');
      resultSet = await this.rdbStore.query(predicates, ['COUNT(*) as count']);
      let count = 0;
      if (resultSet.goToNextRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('count'));
      }
      return count;
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `查询书源数量失败: ${error instanceof Error ? error.message : String(error)}`);
      return 0;
    }
    finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(BookSourceRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

  async upsertBookSource(bookSource: BookSource): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'id': bookSource.id,
      'name': bookSource.name,
      'url': bookSource.url,
      'enabled': bookSource.enabled ? DB_ENABLED_TRUE : DB_ENABLED_FALSE,
      'header': bookSource.header || null,
      'search_url': bookSource.searchUrl,
      'search_rule': JSON.stringify(bookSource.searchRule),
      'find_rule': bookSource.findRule ? JSON.stringify(bookSource.findRule) : null,
      'chapter_rule': JSON.stringify(bookSource.chapterRule),
      'content_rule': JSON.stringify(bookSource.contentRule),
      'rule_type': bookSource.ruleType,
      'sort': bookSource.sort || DB_DEFAULT_SORT,
      'last_update_time': Date.now(),
      'add_time': bookSource.addTime || Date.now()
    };

    try {
      // 先尝试更新
      const predicates = new relationalStore.RdbPredicates('book_source');
      predicates.equalTo(DB_COLUMN_ID, bookSource.id);
      const updatedRows = await this.rdbStore.update(valueBucket, predicates);

      // 如果更新失败则插入
      if (updatedRows === DB_UPDATED_ROWS_ZERO) {
        await this.rdbStore.insert('book_source', valueBucket);
      }

      Logger.debug(BookSourceRepository.TAG, `书源保存成功: ${bookSource.name}`);
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `插入或更新书源失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async batchUpsertBookSources(sources: BookSource[]): Promise<void> {
    if (sources.length === 0) {
      return;
    }

    try {
      // 使用事务确保批量操作的原子性
      this.rdbStore.beginTransaction();

      for (const source of sources) {
        await this.upsertBookSource(source);
      }

      this.rdbStore.commit();
    }
    catch (error) {
      try {
        await this.rdbStore.rollback(relationalStore.TransactionType.IMMEDIATE);
      } catch (rollbackError) {
        Logger.error(BookSourceRepository.TAG, `回滚失败: ${rollbackError instanceof Error ? rollbackError.message : String(rollbackError)}`);
      }
      Logger.error(BookSourceRepository.TAG, `批量插入或更新书源失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async deleteBookSource(sourceId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book_source');
      predicates.equalTo(DB_COLUMN_ID, sourceId);
      await this.rdbStore.delete(predicates);
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `删除书源失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private parseBookSource(resultSet: relationalStore.ResultSet): BookSource {
    try {
      const idIndex = resultSet.getColumnIndex('id');
      const nameIndex = resultSet.getColumnIndex('name');
      const urlIndex = resultSet.getColumnIndex('url');
      const enabledIndex = resultSet.getColumnIndex('enabled');
      const headerIndex = resultSet.getColumnIndex('header');
      const searchUrlIndex = resultSet.getColumnIndex('search_url');
      const searchRuleIndex = resultSet.getColumnIndex('search_rule');
      const findRuleIndex = resultSet.getColumnIndex('find_rule');
      const chapterRuleIndex = resultSet.getColumnIndex('chapter_rule');
      const contentRuleIndex = resultSet.getColumnIndex('content_rule');
      const ruleTypeIndex = resultSet.getColumnIndex('rule_type');
      const sortIndex = resultSet.getColumnIndex('sort');
      const lastUpdateTimeIndex = resultSet.getColumnIndex('last_update_time');
      const addTimeIndex = resultSet.getColumnIndex('add_time');

      const searchRuleJson = this.parseJson(resultSet.getString(searchRuleIndex));
      const searchRule: SearchRule = {
        bookList: searchRuleJson.bookList as string || '',
        name: searchRuleJson.name as string || '',
        author: searchRuleJson.author as string || '',
        cover: searchRuleJson.cover as string | undefined,
        intro: searchRuleJson.intro as string | undefined,
        bookUrl: searchRuleJson.bookUrl as string || '',
        nextUrl: searchRuleJson.nextUrl as string | undefined
      };

      const chapterRuleJson = this.parseJson(resultSet.getString(chapterRuleIndex));
      const chapterRule: ChapterRule = {
        chapterList: chapterRuleJson.chapterList as string || '',
        chapterName: chapterRuleJson.chapterName as string || '',
        chapterUrl: chapterRuleJson.chapterUrl as string || '',
        nextUrl: chapterRuleJson.nextUrl as string | undefined
      };

      const contentRuleJson = this.parseJson(resultSet.getString(contentRuleIndex));
      const contentRule: ContentRule = {
        content: contentRuleJson.content as string || '',
        nextUrl: contentRuleJson.nextUrl as string | undefined,
        prevUrl: contentRuleJson.prevUrl as string | undefined,
        replaceRule: contentRuleJson.replaceRule as string | undefined
      };

      let findRule: FindRule | undefined = undefined;
      if (!resultSet.isColumnNull(findRuleIndex)) {
        const findRuleJson = this.parseJson(resultSet.getString(findRuleIndex));
        findRule = {
          url: findRuleJson.url as string || '',
          bookList: findRuleJson.bookList as string || '',
          name: findRuleJson.name as string || '',
          author: findRuleJson.author as string || '',
          cover: findRuleJson.cover as string | undefined,
          intro: findRuleJson.intro as string | undefined,
          bookUrl: findRuleJson.bookUrl as string || ''
        };
      }

      return {
        id: resultSet.getString(idIndex) || '',
        name: resultSet.getString(nameIndex) || '',
        url: resultSet.getString(urlIndex) || '',
        enabled: resultSet.getLong(enabledIndex) === DB_ENABLED_TRUE,
        header: resultSet.isColumnNull(headerIndex)
          ? undefined
          : resultSet.getString(headerIndex) || '',
        searchUrl: resultSet.getString(searchUrlIndex) || '',
        searchRule: searchRule,
        findRule: findRule,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: (resultSet.getString(ruleTypeIndex) || 'xpath') as 'xpath' | 'jsonpath' | 'regex',
        sort: resultSet.getLong(sortIndex) || DB_DEFAULT_SORT,
        lastUpdateTime: resultSet.getLong(lastUpdateTimeIndex) || DB_DEFAULT_TIME,
        addTime: resultSet.getLong(addTimeIndex) || DB_DEFAULT_TIME
      };
    }
    catch (error) {
      Logger.error(BookSourceRepository.TAG, `解析书源数据失败: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        name: '',
        url: '',
        enabled: true,
        header: undefined,
        searchUrl: '',
        searchRule: { bookList: '', name: '', author: '', bookUrl: '', cover: undefined, intro: undefined, nextUrl: undefined },
        findRule: undefined,
        chapterRule: { chapterList: '', chapterName: '', chapterUrl: '', nextUrl: undefined },
        contentRule: { content: '', nextUrl: undefined, prevUrl: undefined, replaceRule: undefined },
        ruleType: 'xpath' as 'xpath' | 'jsonpath' | 'regex',
        sort: 0,
        lastUpdateTime: 0,
        addTime: 0
      };
    }
  }

  /**
   * 安全解析JSON字符串
   */
  private parseJson(jsonString: string | undefined): Record<string, Object> {
    if (!jsonString) {
      return {} as Record<string, Object>;
    }
    try {
      return JSON.parse(jsonString) as Record<string, Object>;
    }
    catch (error) {
      Logger.warn(BookSourceRepository.TAG, `解析JSON失败: ${error instanceof Error ? error.message : String(error)}`);
      return {} as Record<string, Object>;
    }
  }
}