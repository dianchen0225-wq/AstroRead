/**
 * BookSourceRepositoryImpl - 书源仓库实现
 * 实现IBookSourceRepository接口，处理具体的数据访问逻辑
 */

import { relationalStore } from '@kit.ArkData';
import { BookSource } from '../../models/BookSource';
import {
  IBookSourceRepository,
  PagedResult,
  QueryOptions,
  BatchOperationResult,
} from '../../core/repositories/IBookSourceRepository';
import { Logger } from '../../utils/Logger';
import { QueryBuilder, BatchQueryExecutor } from '../../utils/database/QueryOptimizer';

const DB_ENABLED_TRUE: number = 1;
const DB_ENABLED_FALSE: number = 0;
const DB_DEFAULT_SORT: number = 0;
const DB_DEFAULT_TIME: number = 0;
const DB_UPDATED_ROWS_ZERO: number = 0;

interface BuildResult {
  sql: string;
  params: (string | number | boolean | null)[];
}

/**
 * 书源仓库实现类
 */
export class BookSourceRepositoryImpl implements IBookSourceRepository {
  private readonly TAG = 'BookSourceRepositoryImpl';
  private rdbStore: relationalStore.RdbStore;
  private batchExecutor: BatchQueryExecutor;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
    this.batchExecutor = new BatchQueryExecutor(rdbStore);
  }

  /**
   * 根据ID获取书源
   */
  async getById(id: string): Promise<BookSource | null> {
    const builder = new QueryBuilder()
      .from('book_source')
      .where('id', '=', id);

    const buildResult: BuildResult = builder.build();
    let resultSet: relationalStore.ResultSet | null = null;

    try {
      resultSet = await this.rdbStore.querySql(buildResult.sql, buildResult.params);
      if (resultSet !== null && resultSet.goToNextRow()) {
        return this.parseBookSource(resultSet);
      }
      return null;
    } catch (error) {
      Logger.error(this.TAG, `根据ID获取书源失败: ${error instanceof Error ? error.message : String(error)}`);
      return null;
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(this.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

  /**
   * 获取所有书源
   */
  async getAll(): Promise<BookSource[]> {
    const builder = new QueryBuilder()
      .from('book_source')
      .orderBy('sort', 'ASC');

    const buildResult: BuildResult = builder.build();
    return this.executeQuery(buildResult.sql, buildResult.params);
  }

  /**
   * 获取所有启用的书源
   */
  async getAllEnabled(): Promise<BookSource[]> {
    const builder = new QueryBuilder()
      .from('book_source')
      .where('enabled', '=', DB_ENABLED_TRUE)
      .orderBy('sort', 'ASC');

    const buildResult: BuildResult = builder.build();
    return this.executeQuery(buildResult.sql, buildResult.params);
  }

  /**
   * 分页获取书源
   */
  async getPaged(options: QueryOptions): Promise<PagedResult<BookSource>> {
    const page = options.page ?? 1;
    const pageSize = options.pageSize ?? 20;

    const dataBuilder = new QueryBuilder()
      .from('book_source')
      .orderBy(options.orderBy ?? 'sort', options.orderDirection ?? 'ASC')
      .paginate(page, pageSize);

    if (options.filters) {
      const keys = Object.keys(options.filters);
      for (let i: number = 0; i < keys.length; i++) {
        const key = keys[i];
        const value = options.filters[key];
        if (value !== null && value !== undefined) {
          dataBuilder.where(key, '=', value);
        }
      }
    }

    const dataBuildResult: BuildResult = dataBuilder.build();
    const data = await this.executeQuery(dataBuildResult.sql, dataBuildResult.params);

    const countBuilder = new QueryBuilder().from('book_source');
    if (options.filters) {
      const keys = Object.keys(options.filters);
      for (let i: number = 0; i < keys.length; i++) {
        const key = keys[i];
        const value = options.filters[key];
        if (value !== null && value !== undefined) {
          countBuilder.where(key, '=', value);
        }
      }
    }

    const countBuildResult: BuildResult = countBuilder.buildCount();
    const total = await this.executeCount(countBuildResult.sql, countBuildResult.params);

    return {
      data,
      total,
      page,
      pageSize,
      hasMore: page * pageSize < total,
    };
  }

  /**
   * 根据条件查询书源
   */
  async findByCondition(conditions: Partial<BookSource>): Promise<BookSource[]> {
    const builder = new QueryBuilder().from('book_source');

    if (conditions.enabled !== undefined) {
      builder.where('enabled', '=', conditions.enabled ? DB_ENABLED_TRUE : DB_ENABLED_FALSE);
    }
    if (conditions.name) {
      builder.where('name', 'LIKE', `%${conditions.name}%`);
    }
    if (conditions.url) {
      builder.where('url', 'LIKE', `%${conditions.url}%`);
    }

    builder.orderBy('sort', 'ASC');

    const buildResult: BuildResult = builder.build();
    return this.executeQuery(buildResult.sql, buildResult.params);
  }

  /**
   * 保存书源
   */
  async save(bookSource: BookSource): Promise<void> {
    const valueBucket = this.toValueBucket(bookSource);

    try {
      const sql = `
        INSERT OR REPLACE INTO book_source (
          id, name, url, enabled, header, search_url, search_rule,
          find_rule, chapter_rule, content_rule, rule_type, sort,
          last_update_time, add_time
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      const params: (string | number | boolean | null)[] = [
        valueBucket['id'] as string,
        valueBucket['name'] as string,
        valueBucket['url'] as string,
        valueBucket['enabled'] as number,
        valueBucket['header'] as string | null,
        valueBucket['search_url'] as string,
        valueBucket['search_rule'] as string,
        valueBucket['find_rule'] as string | null,
        valueBucket['chapter_rule'] as string,
        valueBucket['content_rule'] as string,
        valueBucket['rule_type'] as string,
        valueBucket['sort'] as number,
        valueBucket['last_update_time'] as number,
        valueBucket['add_time'] as number,
      ];

      await this.rdbStore.executeSql(sql, params);
      Logger.debug(this.TAG, `书源保存成功: ${bookSource.name}`);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `保存书源失败: ${errorMsg}`);
      throw new Error(`保存书源失败: ${errorMsg}`);
    }
  }

  /**
   * 批量保存书源
   */
  async saveBatch(bookSources: BookSource[]): Promise<BatchOperationResult> {
    const errors: Error[] = [];
    let affectedCount = 0;

    try {
      this.rdbStore.beginTransaction();

      for (const source of bookSources) {
        try {
          await this.save(source);
          affectedCount++;
        } catch (error) {
          errors.push(error instanceof Error ? error : new Error(String(error)));
        }
      }

      this.rdbStore.commit();
    } catch (error) {
      try {
        await this.rdbStore.rollback(relationalStore.TransactionType.IMMEDIATE);
      } catch (rollbackError) {
        Logger.error(this.TAG, `回滚失败: ${rollbackError instanceof Error ? rollbackError.message : String(rollbackError)}`);
      }
      errors.push(error instanceof Error ? error : new Error(String(error)));
    }

    return {
      success: errors.length === 0,
      affectedCount,
      errors,
    };
  }

  /**
   * 删除书源
   */
  async delete(id: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book_source');
      predicates.equalTo('id', id);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `删除书源失败: ${errorMsg}`);
      throw new Error(`删除书源失败: ${errorMsg}`);
    }
  }

  /**
   * 批量删除书源
   */
  async deleteBatch(ids: string[]): Promise<BatchOperationResult> {
    const errors: Error[] = [];
    let affectedCount = 0;

    try {
      this.rdbStore.beginTransaction();

      for (const id of ids) {
        try {
          await this.delete(id);
          affectedCount++;
        } catch (error) {
          errors.push(error instanceof Error ? error : new Error(String(error)));
        }
      }

      this.rdbStore.commit();
    } catch (error) {
      try {
        await this.rdbStore.rollback(relationalStore.TransactionType.IMMEDIATE);
      } catch (rollbackError) {
        Logger.error(this.TAG, `回滚失败: ${rollbackError instanceof Error ? rollbackError.message : String(rollbackError)}`);
      }
      errors.push(error instanceof Error ? error : new Error(String(error)));
    }

    return {
      success: errors.length === 0,
      affectedCount,
      errors,
    };
  }

  /**
   * 检查书源是否存在
   */
  async exists(id: string): Promise<boolean> {
    const builder = new QueryBuilder()
      .from('book_source')
      .select(['COUNT(*) as count'])
      .where('id', '=', id);

    const buildResult: BuildResult = builder.build();
    const count = await this.executeCount(buildResult.sql, buildResult.params);
    return count > 0;
  }

  /**
   * 获取书源总数
   */
  async getCount(): Promise<number> {
    const builder = new QueryBuilder()
      .from('book_source')
      .select(['COUNT(*) as count']);

    const buildResult: BuildResult = builder.build();
    return this.executeCount(buildResult.sql, buildResult.params);
  }

  /**
   * 获取启用的书源数量
   */
  async getEnabledCount(): Promise<number> {
    const builder = new QueryBuilder()
      .from('book_source')
      .select(['COUNT(*) as count'])
      .where('enabled', '=', DB_ENABLED_TRUE);

    const buildResult: BuildResult = builder.build();
    return this.executeCount(buildResult.sql, buildResult.params);
  }

  /**
   * 更新书源启用状态
   */
  async updateEnabled(id: string, enabled: boolean): Promise<void> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        enabled: enabled ? DB_ENABLED_TRUE : DB_ENABLED_FALSE,
        last_update_time: Date.now(),
      };

      const predicates = new relationalStore.RdbPredicates('book_source');
      predicates.equalTo('id', id);
      await this.rdbStore.update(valueBucket, predicates);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `更新书源启用状态失败: ${errorMsg}`);
      throw new Error(`更新书源启用状态失败: ${errorMsg}`);
    }
  }

  /**
   * 更新书源排序
   */
  async updateSort(id: string, sort: number): Promise<void> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        sort,
        last_update_time: Date.now(),
      };

      const predicates = new relationalStore.RdbPredicates('book_source');
      predicates.equalTo('id', id);
      await this.rdbStore.update(valueBucket, predicates);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `更新书源排序失败: ${errorMsg}`);
      throw new Error(`更新书源排序失败: ${errorMsg}`);
    }
  }

  /**
   * 搜索书源
   */
  async search(keyword: string): Promise<BookSource[]> {
    const builder = new QueryBuilder()
      .from('book_source')
      .where('name', 'LIKE', `%${keyword}%`)
      .orderBy('sort', 'ASC');

    const buildResult: BuildResult = builder.build();
    return this.executeQuery(buildResult.sql, buildResult.params);
  }

  /**
   * 执行查询
   */
  private async executeQuery(sql: string, params: (string | number | boolean | null)[]): Promise<BookSource[]> {
    const bookSources: BookSource[] = [];
    let resultSet: relationalStore.ResultSet | null = null;

    try {
      resultSet = await this.rdbStore.querySql(sql, params);

      if (resultSet !== null) {
        while (resultSet.goToNextRow()) {
          bookSources.push(this.parseBookSource(resultSet));
        }
      }

      return bookSources;
    } catch (error) {
      Logger.error(this.TAG, `查询失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(this.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

  /**
   * 执行计数查询
   */
  private async executeCount(sql: string, params: (string | number | boolean | null)[]): Promise<number> {
    let resultSet: relationalStore.ResultSet | null = null;

    try {
      resultSet = await this.rdbStore.querySql(sql, params);

      if (resultSet !== null && resultSet.goToNextRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('count'));
      }
      return 0;
    } catch (error) {
      Logger.error(this.TAG, `计数查询失败: ${error instanceof Error ? error.message : String(error)}`);
      return 0;
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(this.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

  /**
   * 转换为ValueBucket
   */
  private toValueBucket(bookSource: BookSource): relationalStore.ValuesBucket {
    return {
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
      'add_time': bookSource.addTime || Date.now(),
    };
  }

  /**
   * 解析书源
   */
  private parseBookSource(resultSet: relationalStore.ResultSet): BookSource {
    const getString = (column: string): string => {
      const index = resultSet.getColumnIndex(column);
      return resultSet.getString(index) || '';
    };

    const getLong = (column: string): number => {
      const index = resultSet.getColumnIndex(column);
      return resultSet.getLong(index);
    };

    const getNullableString = (column: string): string | undefined => {
      const index = resultSet.getColumnIndex(column);
      return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index) || '';
    };

    const parseJson = (jsonString: string | undefined): Record<string, Object> => {
      if (!jsonString) return {};
      try {
        return JSON.parse(jsonString) as Record<string, Object>;
      } catch {
        return {};
      }
    };

    const searchRuleJson = parseJson(getString('search_rule'));
    const chapterRuleJson = parseJson(getString('chapter_rule'));
    const contentRuleJson = parseJson(getString('content_rule'));
    const findRuleJson = parseJson(getNullableString('find_rule'));

    return {
      id: getString('id'),
      name: getString('name'),
      url: getString('url'),
      enabled: getLong('enabled') === DB_ENABLED_TRUE,
      header: getNullableString('header'),
      searchUrl: getString('search_url'),
      searchRule: {
        bookList: searchRuleJson.bookList as string || '',
        name: searchRuleJson.name as string || '',
        author: searchRuleJson.author as string || '',
        cover: searchRuleJson.cover as string | undefined,
        intro: searchRuleJson.intro as string | undefined,
        bookUrl: searchRuleJson.bookUrl as string || '',
        nextUrl: searchRuleJson.nextUrl as string | undefined,
      },
      findRule: findRuleJson.url ? {
        url: findRuleJson.url as string || '',
        bookList: findRuleJson.bookList as string || '',
        name: findRuleJson.name as string || '',
        author: findRuleJson.author as string || '',
        cover: findRuleJson.cover as string | undefined,
        intro: findRuleJson.intro as string | undefined,
        bookUrl: findRuleJson.bookUrl as string || '',
      } : undefined,
      chapterRule: {
        chapterList: chapterRuleJson.chapterList as string || '',
        chapterName: chapterRuleJson.chapterName as string || '',
        chapterUrl: chapterRuleJson.chapterUrl as string || '',
        nextUrl: chapterRuleJson.nextUrl as string | undefined,
      },
      contentRule: {
        content: contentRuleJson.content as string || '',
        nextUrl: contentRuleJson.nextUrl as string | undefined,
        prevUrl: contentRuleJson.prevUrl as string | undefined,
        replaceRule: contentRuleJson.replaceRule as string | undefined,
      },
      ruleType: (getString('rule_type') || 'xpath') as 'xpath' | 'jsonpath' | 'regex',
      sort: getLong('sort') || DB_DEFAULT_SORT,
      lastUpdateTime: getLong('last_update_time') || DB_DEFAULT_TIME,
      addTime: getLong('add_time') || DB_DEFAULT_TIME,
    };
  }
}
