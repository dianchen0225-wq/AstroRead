/**
 * ISearchEngine - 搜索引擎接口
 * 定义搜索引擎的通用接口，用于解耦具体实现
 */

import { Book } from '../../models/Book';
import { BookSource } from '../../models/BookSource';
import { SearchProgress, SearchStopCondition } from '../../models/SearchResult';

export interface SearchResult {
  books: Book[];
  sourceName: string;
  sourceUrl: string;
  success: boolean;
  error?: string;
  responseTime: number;
}

export interface SearchOptions {
  key: string;
  page?: number;
  timeout?: number;
  concurrent?: number;
  interval?: number;
  pageSize?: number;
  maxResultsPerSource?: number;
  stopCondition?: SearchStopCondition;
}

export type SearchProgressCallback = (progress: SearchProgress) => void;
export type BookFoundCallback = (books: Book[], progress: SearchProgress) => void;

/**
 * 搜索引擎接口
 * 所有搜索引擎实现都应该遵循此接口
 */
export interface ISearchEngine {
  /**
   * 在单个书源中搜索
   * @param source 书源
   * @param keyword 搜索关键词
   * @param options 搜索选项
   * @returns 搜索结果
   */
  searchInSource(
    source: BookSource, 
    keyword: string, 
    options?: SearchOptions
  ): Promise<SearchResult>;

  /**
   * 在多个书源中并发搜索
   * @param sources 书源列表
   * @param keyword 搜索关键词
   * @param options 搜索选项
   * @param onProgress 进度回调
   * @param onBookFound 发现书籍回调
   * @returns 聚合后的搜索结果
   */
  searchInMultipleSources(
    sources: BookSource[],
    keyword: string,
    options?: SearchOptions,
    onProgress?: SearchProgressCallback,
    onBookFound?: BookFoundCallback
  ): Promise<SearchResult[]>;

  /**
   * 搜索多个书源
   * @param sources 书源列表
   * @param options 搜索选项
   * @returns 搜索结果数组
   */
  search(
    sources: BookSource[],
    options: SearchOptions
  ): Promise<SearchResult[]>;

  /**
   * 在单个书源中搜索（简化版）
   * @param source 书源
   * @param keyword 搜索关键词
   * @param page 页码
   * @returns 搜索结果
   */
  searchSingleSource(
    source: BookSource,
    keyword: string,
    page?: number
  ): Promise<SearchResult>;

  /**
   * 聚合搜索结果（去重）
   * @param results 搜索结果数组
   * @returns 去重后的书籍列表
   */
  aggregateResults(results: SearchResult[]): Book[];

  /**
   * 取消当前搜索
   */
  cancelSearch(): void;

  /**
   * 检查是否正在搜索
   */
  isSearching(): boolean;

  /**
   * 设置搜索引擎配置
   * @param config 配置对象
   */
  setConfig(config: Partial<SearchEngineConfig>): void;

  /**
   * 获取当前配置
   */
  getConfig(): SearchEngineConfig;

  /**
   * 清除缓存
   */
  clearCache(): void;
}

/**
 * 搜索引擎配置
 */
export interface SearchEngineConfig {
  /** 最大并发数 */
  maxConcurrent: number;
  /** 请求间隔（毫秒） */
  requestInterval: number;
  /** 超时时间（毫秒） */
  timeout: number;
  /** 每个书源最大结果数 */
  maxResultsPerSource: number;
  /** 是否启用缓存 */
  enableCache: boolean;
  /** 缓存过期时间（毫秒） */
  cacheExpiry: number;
}

/**
 * 默认搜索引擎配置
 */
export const DEFAULT_SEARCH_ENGINE_CONFIG: SearchEngineConfig = {
  maxConcurrent: 5,
  requestInterval: 500,
  timeout: 10000,
  maxResultsPerSource: 20,
  enableCache: true,
  cacheExpiry: 5 * 60 * 1000 // 5分钟
};

/**
 * 搜索引擎工厂接口
 * 用于创建搜索引擎实例
 */
export interface ISearchEngineFactory {
  /**
   * 创建搜索引擎实例
   */
  createSearchEngine(): ISearchEngine;

  /**
   * 获取默认搜索引擎实例（单例）
   */
  getDefaultEngine(): ISearchEngine;
}
