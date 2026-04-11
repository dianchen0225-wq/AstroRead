
import { Logger } from './Logger';
import { LRUCache } from './LRUCache';
import relationalStore from '@ohos.data.relationalStore';
/**
 * 查询结果
 */
export interface QueryResult<T> {
  data: T[];
  count: number;
}
/**
 * 查询配置
 */
export interface QueryConfig<T> {
  tableName: string;
  predicates: relationalStore.RdbPredicates | undefined;
  columns?: string[];
  cache?: boolean;
}

/**
 * 数据库查询优化器
 * 优化数据库查询性能，支持查询缓存、批量查询和索引创建
 */
export class DatabaseQueryOptimizer {
  private static instance: DatabaseQueryOptimizer;
  private queryCache: LRUCache<string, QueryResult<object>>;
  private indexCreated: Set<string> = new Set();
  private constructor() {
    this.queryCache = new LRUCache<string, QueryResult<object>>(100, 5 * 60 * 1000); // 缓存100条，TTL 5分钟
  }

  public static getInstance(): DatabaseQueryOptimizer {
    if (!DatabaseQueryOptimizer.instance) {
      DatabaseQueryOptimizer.instance = new DatabaseQueryOptimizer();
    }
    return DatabaseQueryOptimizer.instance;
  }

  /**
   * 优化查询（带缓存）
   * @param config 查询配置
   * @param queryExecutor 查询执行器
   * @returns 查询结果
   */
  async optimizedQuery<T extends object>(
    config: QueryConfig<T>,
    queryExecutor: (config: QueryConfig<T>) => Promise<QueryResult<T>>
  ): Promise<QueryResult<T>> {
    const cacheKey = this.generateCacheKey(config);

    // 检查缓存
    if (config.cache !== false) {
      const cached = this.queryCache.get(cacheKey);
      if (cached) {
        Logger.debug('DatabaseQueryOptimizer', `从缓存获取查询结果: ${config.tableName}`);
        return cached as QueryResult<T>;
      }
    }

    // 执行查询
    const result = await queryExecutor(config);

    // 存入缓存
    if (config.cache !== false) {
      this.queryCache.set(cacheKey, result);
    }

    return result;
  }

  /**
   * 批量查询
   * @param configs 查询配置数组
   * @param queryExecutor 查询执行器
   * @returns 查询结果数组
   */
  async batchQuery<T extends object>(
    configs: QueryConfig<T>[],
    queryExecutor: (config: QueryConfig<T>) => Promise<QueryResult<T>>
  ): Promise<QueryResult<T>[]> {
    Logger.debug('DatabaseQueryOptimizer', `批量查询: ${configs.length}个`);

    const promises = configs.map(config =>
      this.optimizedQuery(config, queryExecutor).catch((error: Error) => {
        Logger.error('DatabaseQueryOptimizer', `批量查询失败: ${config.tableName}, ${error.message}`);
        return { data: [], count: 0 } as QueryResult<T>;
      })
    );

    const results = await Promise.all(promises);
    return results;
  }
  /**
   * 创建索引
   * @param dbName 数据库名称
   * @param tableName 表名
   * @param indexName 索引名
   * @param columns 列名数组
   */
  async createIndex(
    db: relationalStore.RdbStore,
    tableName: string,
    indexName: string,
    columns: string[]
  ): Promise<void> {
    const indexKey = `${tableName}_${indexName}`;

    if (this.indexCreated.has(indexKey)) {
      Logger.debug('DatabaseQueryOptimizer', `索引已存在: ${indexKey}`);
      return;
    }

    try {
      // 使用SQL语句创建索引
      const sql = `CREATE INDEX IF NOT EXISTS ${indexName} ON ${tableName} (${columns.join(', ')})`;
      await db.executeSql(sql);
      this.indexCreated.add(indexKey);
      Logger.info('DatabaseQueryOptimizer', `索引创建成功: ${indexKey}`);
    } catch (error) {
      Logger.error('DatabaseQueryOptimizer', `索引创建失败: ${indexKey}, ${error.message}`);
    }
  }

  /**
   * 清空查询缓存
   */
  clearCache(): void {
    this.queryCache.clear();
    Logger.info('DatabaseQueryOptimizer', '查询缓存已清空');
  }

  /**
   * 清理过期缓存
   */
  cleanExpiredCache(): void {
    this.queryCache.cleanExpired();
  }
  /**
   * 获取缓存统计信息
   */
  getCacheStats(): object {
    return this.queryCache.getStats();
  }

  /**
   * 生成缓存键
   * @param config 查询配置
   * @returns 缓存键
   */
  private generateCacheKey<T extends object>(config: QueryConfig<T>): string {
    const predicatesStr = config.predicates ?
      config.predicates.toString() : '';
    const columnsStr = config.columns?.join(',') || '';

    return `${config.tableName}_${predicatesStr}_${columnsStr}`;
  }
}
