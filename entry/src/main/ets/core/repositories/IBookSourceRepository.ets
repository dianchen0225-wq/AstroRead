/**
 * IBookSourceRepository - 书源仓库接口
 * 定义书源数据访问的契约
 */

import { BookSource } from '../../models/BookSource';

/**
 * 分页结果
 */
export interface PagedResult<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/**
 * 查询选项
 */
export interface QueryOptions {
  page?: number;
  pageSize?: number;
  orderBy?: string;
  orderDirection?: 'ASC' | 'DESC';
  filters?: Record<string, string | number | boolean | null>;
}

/**
 * 批量操作结果
 */
export interface BatchOperationResult {
  success: boolean;
  affectedCount: number;
  errors: Error[];
}

/**
 * 书源仓库接口
 * 遵循Repository模式，抽象数据访问逻辑
 */
export interface IBookSourceRepository {
  /**
   * 根据ID获取书源
   */
  getById(id: string): Promise<BookSource | null>;

  /**
   * 获取所有书源
   */
  getAll(): Promise<BookSource[]>;

  /**
   * 获取所有启用的书源
   */
  getAllEnabled(): Promise<BookSource[]>;

  /**
   * 分页获取书源
   */
  getPaged(options: QueryOptions): Promise<PagedResult<BookSource>>;

  /**
   * 根据条件查询书源
   */
  findByCondition(conditions: Partial<BookSource>): Promise<BookSource[]>;

  /**
   * 保存书源（插入或更新）
   */
  save(bookSource: BookSource): Promise<void>;

  /**
   * 批量保存书源
   */
  saveBatch(bookSources: BookSource[]): Promise<BatchOperationResult>;

  /**
   * 删除书源
   */
  delete(id: string): Promise<void>;

  /**
   * 批量删除书源
   */
  deleteBatch(ids: string[]): Promise<BatchOperationResult>;

  /**
   * 检查书源是否存在
   */
  exists(id: string): Promise<boolean>;

  /**
   * 获取书源总数
   */
  getCount(): Promise<number>;

  /**
   * 获取启用的书源数量
   */
  getEnabledCount(): Promise<number>;

  /**
   * 更新书源启用状态
   */
  updateEnabled(id: string, enabled: boolean): Promise<void>;

  /**
   * 更新书源排序
   */
  updateSort(id: string, sort: number): Promise<void>;

  /**
   * 搜索书源
   */
  search(keyword: string): Promise<BookSource[]>;
}
