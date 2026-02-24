/**
 * QueryOptimizer - 数据库查询优化器
 * 提供批量查询、JOIN查询、查询缓存等优化功能
 */

import { relationalStore } from '@kit.ArkData';
import { Logger } from '../Logger';

/**
 * 查询条件
 */
interface QueryCondition {
  column: string;
  operator: '=' | '!=' | '<' | '>' | '<=' | '>=' | 'LIKE' | 'IN';
  value: string | number | boolean | null | (string | number | boolean | null)[];
}

/**
 * 排序配置
 */
interface OrderConfig {
  column: string;
  direction: 'ASC' | 'DESC';
}

/**
 * 分页配置
 */
interface PaginationConfig {
  page: number;
  pageSize: number;
}

/**
 * JOIN配置
 */
interface JoinConfig {
  type: 'INNER' | 'LEFT' | 'RIGHT';
  table: string;
  onCondition: string;
  columns: string[];
}

/**
 * 查询构建器
 */
export class QueryBuilder {
  private table: string = '';
  private columns: string[] = ['*'];
  private conditions: QueryCondition[] = [];
  private orders: OrderConfig[] = [];
  private pagination?: PaginationConfig;
  private joins: JoinConfig[] = [];
  private groupBy?: string;
  private having?: string;

  /**
   * 设置表名
   */
  from(table: string): QueryBuilder {
    this.table = table;
    return this;
  }

  /**
   * 设置查询列
   */
  select(columns: string[]): QueryBuilder {
    this.columns = columns;
    return this;
  }

  /**
   * 添加WHERE条件
   */
  where(column: string, operator: QueryCondition['operator'], value: string | number | boolean | null): QueryBuilder {
    this.conditions.push({ column, operator, value });
    return this;
  }

  /**
   * 添加IN条件
   */
  whereIn(column: string, values: (string | number | boolean | null)[]): QueryBuilder {
    this.conditions.push({ column, operator: 'IN', value: values });
    return this;
  }

  /**
   * 添加排序
   */
  orderBy(column: string, direction: 'ASC' | 'DESC' = 'ASC'): QueryBuilder {
    this.orders.push({ column, direction });
    return this;
  }

  /**
   * 设置分页
   */
  paginate(page: number, pageSize: number): QueryBuilder {
    this.pagination = { page, pageSize };
    return this;
  }

  /**
   * 添加JOIN
   */
  join(type: JoinConfig['type'], table: string, onCondition: string, columns: string[]): QueryBuilder {
    this.joins.push({ type, table, onCondition, columns });
    return this;
  }

  /**
   * 设置GROUP BY
   */
  groupByColumn(column: string): QueryBuilder {
    this.groupBy = column;
    return this;
  }

  /**
   * 设置HAVING
   */
  havingCondition(condition: string): QueryBuilder {
    this.having = condition;
    return this;
  }

  /**
   * 构建SQL查询
   */
  build(): { sql: string; params: (string | number | boolean | null)[] } {
    const params: (string | number | boolean | null)[] = [];
    let sql = `SELECT ${this.columns.join(', ')} FROM ${this.table}`;

    // 添加JOIN
    for (const join of this.joins) {
      sql += ` ${join.type} JOIN ${join.table} ON ${join.onCondition}`;
    }

    // 添加WHERE条件
    if (this.conditions.length > 0) {
      const whereClauses: string[] = [];
      for (const condition of this.conditions) {
        if (condition.operator === 'IN' && Array.isArray(condition.value)) {
          const placeholders = condition.value.map(() => '?').join(', ');
          whereClauses.push(`${condition.column} IN (${placeholders})`);
          params.push(...condition.value);
        } else {
          whereClauses.push(`${condition.column} ${condition.operator} ?`);
          params.push(condition.value);
        }
      }
      sql += ` WHERE ${whereClauses.join(' AND ')}`;
    }

    // 添加GROUP BY
    if (this.groupBy) {
      sql += ` GROUP BY ${this.groupBy}`;
    }

    // 添加HAVING
    if (this.having) {
      sql += ` HAVING ${this.having}`;
    }

    // 添加ORDER BY
    if (this.orders.length > 0) {
      const orderClauses = this.orders.map(o => `${o.column} ${o.direction}`);
      sql += ` ORDER BY ${orderClauses.join(', ')}`;
    }

    // 添加分页
    if (this.pagination) {
      const offset = (this.pagination.page - 1) * this.pagination.pageSize;
      sql += ` LIMIT ${this.pagination.pageSize} OFFSET ${offset}`;
    }

    return { sql, params };
  }

  /**
   * 构建计数查询
   */
  buildCount(): { sql: string; params: (string | number | boolean | null)[] } {
    const params: (string | number | boolean | null)[] = [];
    let sql = `SELECT COUNT(*) as count FROM ${this.table}`;

    // 添加JOIN
    for (const join of this.joins) {
      sql += ` ${join.type} JOIN ${join.table} ON ${join.onCondition}`;
    }

    // 添加WHERE条件
    if (this.conditions.length > 0) {
      const whereClauses: string[] = [];
      for (const condition of this.conditions) {
        if (condition.operator === 'IN' && Array.isArray(condition.value)) {
          const placeholders = condition.value.map(() => '?').join(', ');
          whereClauses.push(`${condition.column} IN (${placeholders})`);
          params.push(...condition.value);
        } else {
          whereClauses.push(`${condition.column} ${condition.operator} ?`);
          params.push(condition.value);
        }
      }
      sql += ` WHERE ${whereClauses.join(' AND ')}`;
    }

    return { sql, params };
  }
}

/**
 * 批量查询执行器
 */
export class BatchQueryExecutor {
  private readonly TAG = 'BatchQueryExecutor';
  private rdbStore: relationalStore.RdbStore;
  private batchSize: number;

  constructor(rdbStore: relationalStore.RdbStore, batchSize: number = 100) {
    this.rdbStore = rdbStore;
    this.batchSize = batchSize;
  }

  /**
   * 批量查询（使用IN语句替代多次查询）
   */
  async batchQuery<T>(
    table: string,
    column: string,
    values: (string | number | boolean | null)[],
    mapper: (rs: relationalStore.ResultSet) => T
  ): Promise<Map<string, T>> {
    const result = new Map<string, T>();

    if (values.length === 0) {
      return result;
    }

    // 分批处理
    for (let i = 0; i < values.length; i += this.batchSize) {
      const batch = values.slice(i, i + this.batchSize);

      try {
        const builder = new QueryBuilder()
          .from(table)
          .whereIn(column, batch);

        const { sql, params } = builder.build();
        const resultSet = await this.rdbStore.querySql(sql, params);

        while (resultSet.goToNextRow()) {
          const item = mapper(resultSet);
          const key = resultSet.getString(resultSet.getColumnIndex(column));
          result.set(key, item);
        }

        resultSet.close();
      } catch (error) {
        Logger.error(this.TAG, `批量查询失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    return result;
  }

  /**
   * 批量插入（使用事务）
   */
  async batchInsert(
    table: string,
    valueBuckets: relationalStore.ValuesBucket[]
  ): Promise<number> {
    if (valueBuckets.length === 0) {
      return 0;
    }

    let insertedCount = 0;

    try {
      this.rdbStore.beginTransaction();

      for (const bucket of valueBuckets) {
        await this.rdbStore.insert(table, bucket);
        insertedCount++;
      }

      this.rdbStore.commit();
      return insertedCount;
    } catch (error) {
      try {
        await this.rdbStore.rollback(relationalStore.TransactionType.IMMEDIATE);
      } catch (rollbackError) {
        Logger.error(this.TAG, `回滚失败: ${rollbackError instanceof Error ? rollbackError.message : String(rollbackError)}`);
      }
      Logger.error(this.TAG, `批量插入失败: ${error instanceof Error ? error.message : String(error)}`);
      throw error;
    }
  }

  /**
   * 批量更新（使用CASE语句优化）
   */
  async batchUpdate(
    table: string,
    column: string,
    updates: Map<string, relationalStore.ValuesBucket>
  ): Promise<number> {
    if (updates.size === 0) {
      return 0;
    }

    let updatedCount = 0;

    try {
      this.rdbStore.beginTransaction();

      for (const entry of updates) {
        const id: string = entry[0];
        const bucket: valuesBucket.ValuesBucket = entry[1];
        const predicates = new relationalStore.RdbPredicates(table);
        predicates.equalTo(column, id);
        const rows = await this.rdbStore.update(bucket, predicates);
        updatedCount += rows;
      }

      this.rdbStore.commit();
      return updatedCount;
    } catch (error) {
      try {
        await this.rdbStore.rollback(relationalStore.TransactionType.IMMEDIATE);
      } catch (rollbackError) {
        Logger.error(this.TAG, `回滚失败: ${rollbackError instanceof Error ? rollbackError.message : String(rollbackError)}`);
      }
      Logger.error(this.TAG, `批量更新失败: ${error instanceof Error ? error.message : String(error)}`);
      throw error;
    }
  }

  /**
   * 批量删除
   */
  async batchDelete(
    table: string,
    column: string,
    values: (string | number | boolean | null)[]
  ): Promise<number> {
    if (values.length === 0) {
      return 0;
    }

    let deletedCount = 0;

    // 分批处理
    for (let i = 0; i < values.length; i += this.batchSize) {
      const batch = values.slice(i, i + this.batchSize);

      try {
        const builder = new QueryBuilder()
          .from(table)
          .whereIn(column, batch);

        const { sql, params } = builder.build();
        // 构建DELETE语句
        const deleteSql = sql.replace('SELECT *', 'DELETE');
        await this.rdbStore.executeSql(deleteSql, params);
        deletedCount += batch.length;
      } catch (error) {
        Logger.error(this.TAG, `批量删除失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    return deletedCount;
  }
}

/**
 * 查询缓存
 */
export class QueryCache {
  private cache: Map<string, { data: Object; timestamp: number; ttl: number }> = new Map();
  private readonly defaultTTL: number;

  constructor(defaultTTL: number = 60000) {
    this.defaultTTL = defaultTTL;
  }

  /**
   * 生成缓存键
   */
  private generateKey(sql: string, params: (string | number | boolean | null)[]): string {
    return `${sql}:${JSON.stringify(params)}`;
  }

  /**
   * 获取缓存
   */
  get<T>(sql: string, params: (string | number | boolean | null)[]): T | undefined {
    const key = this.generateKey(sql, params);
    const cached = this.cache.get(key);

    if (!cached) {
      return undefined;
    }

    // 检查是否过期
    if (Date.now() - cached.timestamp > cached.ttl) {
      this.cache.delete(key);
      return undefined;
    }

    return cached.data as T;
  }

  /**
   * 设置缓存
   */
  set(sql: string, params: (string | number | boolean | null)[], data: Object, ttl?: number): void {
    const key = this.generateKey(sql, params);
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl: ttl ?? this.defaultTTL,
    });
  }

  /**
   * 清除缓存
   */
  clear(): void {
    this.cache.clear();
  }

  /**
   * 清除特定表的缓存
   */
  clearByTable(table: string): void {
    for (const entry of this.cache) {
      const key: string = entry[0];
      if (key.includes(table)) {
        this.cache.delete(key);
      }
    }
  }

  /**
   * 获取缓存大小
   */
  size(): number {
    return this.cache.size;
  }
}

/**
 * 优化的Repository基类
 */
export abstract class OptimizedRepository<T> {
  protected readonly TAG: string;
  protected rdbStore: relationalStore.RdbStore;
  protected batchExecutor: BatchQueryExecutor;
  protected queryCache: QueryCache;

  constructor(tag: string, rdbStore: relationalStore.RdbStore) {
    this.TAG = tag;
    this.rdbStore = rdbStore;
    this.batchExecutor = new BatchQueryExecutor(rdbStore);
    this.queryCache = new QueryCache();
  }

  /**
   * 执行查询（带缓存）
   */
  protected async executeQuery<R>(
    sql: string,
    params: (string | number | boolean | null)[],
    mapper: (rs: relationalStore.ResultSet) => R,
    useCache: boolean = false,
    cacheTTL?: number
  ): Promise<R[]> {
    // 检查缓存
    if (useCache) {
      const cached = this.queryCache.get<R[]>(sql, params);
      if (cached) {
        return cached;
      }
    }

    const result: R[] = [];
    let resultSet: relationalStore.ResultSet | null = null;

    try {
      resultSet = await this.rdbStore.querySql(sql, params);

      while (resultSet.goToNextRow()) {
        result.push(mapper(resultSet));
      }

      // 设置缓存
      if (useCache) {
        this.queryCache.set(sql, params, result, cacheTTL);
      }

      return result;
    } catch (error) {
      Logger.error(this.TAG, `查询失败: ${error instanceof Error ? error.message : String(error)}`);
      throw error;
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
   * 执行单条查询
   */
  protected async executeSingleQuery<R>(
    sql: string,
    params: (string | number | boolean | null)[],
    mapper: (rs: relationalStore.ResultSet) => R
  ): Promise<R | null> {
    const results = await this.executeQuery(sql, params, mapper);
    return results.length > 0 ? results[0] : null;
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.queryCache.clear();
  }

  /**
   * 获取缓存统计
   */
  getCacheStats(): { size: number } {
    return { size: this.queryCache.size() };
  }

  /**
   * 抽象方法：解析结果集
   */
  protected abstract parseResultSet(resultSet: relationalStore.ResultSet): T;
}

// 导出工具函数
export function createQueryBuilder(): QueryBuilder {
  return new QueryBuilder();
}
