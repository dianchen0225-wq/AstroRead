/**
 * EnhancedBookSourceSearchEngine - 增强版书源搜索引擎
 * 包含缓存、验证、查询解析、动态超时等优化功能
 */

import { BookSource } from '../models/BookSource';
import { Book } from '../models/Book';
import { 
  PagedSearchResult, 
  SourceSearchStats, 
  SearchPaginationConfig, 
  DEFAULT_PAGINATION_CONFIG,
  SearchResultBuilder,
  SearchProgress,
  SearchStopCondition,
  DEFAULT_STOP_CONDITION
} from '../models/SearchResult';
import NetworkAdapter, { NetworkError } from './NetworkAdapter';
import { HTMLParser } from './HTMLParser';
import { CssSelectorParser } from './CssSelectorParser';
import { AsyncCssSelectorParser } from './AsyncCssSelectorParser';
import { parseCache } from './ParseCache';
import { EnhancedJSEngine } from './EnhancedJSEngine';
import { Logger } from './Logger';
import { sourceHealthManager } from './SourceHealthManager';
import { searchCache } from './SearchCache';
import { searchResultValidator } from './SearchResultValidator';
import { searchQueryParser, ParsedQuery, QueryEncodingConfig } from './SearchQueryParser';

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
  enableCache?: boolean;
  enableValidation?: boolean;
  enableQueryParsing?: boolean;
  onPartialResult?: (books: Book[]) => void; // 渐进式结果回调
}

export type SearchProgressCallback = (progress: SearchProgress) => void;
export type BookFoundCallback = (books: Book[], progress: SearchProgress) => void;

interface UrlConfig {
  method: 'GET' | 'POST';
  body?: string;
  headers: Record<string, string>;
}

interface SearchUrlResult {
  url: string;
  config: UrlConfig;
}

interface MutexInterface {
  lock: () => Promise<void>;
  unlock: () => void;
}

export class EnhancedBookSourceSearchEngine {
  private static instance: EnhancedBookSourceSearchEngine | null = null;
  private htmlParser: HTMLParser;
  private jsEngine: EnhancedJSEngine;
  private asyncCssSelectorParser: AsyncCssSelectorParser;
  private requestTimestamps: Map<string, number[]> = new Map();
  private pendingTimers: Set<number> = new Set();
  private isCancelled: boolean = false;
  private readonly TAG = 'EnhancedBookSourceSearchEngine';

  private config: SearchConfig = {
    maxConcurrent: 5,
    requestInterval: 500,
    timeout: 10000,
    maxResultsPerSource: 20,
    enableCache: true,
    enableValidation: true,
    enableQueryParsing: true,
    dynamicTimeout: true,
    minSimilarity: 0.3,
    maxIntroLength: 200
  };

  private paginationConfig: SearchPaginationConfig = DEFAULT_PAGINATION_CONFIG;

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.jsEngine = EnhancedJSEngine.getInstance();
    this.asyncCssSelectorParser = AsyncCssSelectorParser.getInstance();
  }

  static getInstance(): EnhancedBookSourceSearchEngine {
    if (!EnhancedBookSourceSearchEngine.instance) {
      EnhancedBookSourceSearchEngine.instance = new EnhancedBookSourceSearchEngine();
    }
    return EnhancedBookSourceSearchEngine.instance;
  }

  /**
   * 复制 SearchProgress 对象
   */
  private cloneSearchProgress(progress: SearchProgress): SearchProgress {
    const clone: SearchProgress = {
      totalSources: progress.totalSources,
      completedSources: progress.completedSources,
      currentSource: progress.currentSource,
      foundBooks: progress.foundBooks,
      isComplete: progress.isComplete
    };
    if (progress.newBooks !== undefined) {
      clone.newBooks = progress.newBooks;
    }
    return clone;
  }

  cancelSearch(): void {
    this.isCancelled = true;
    this.clearAllTimers();
  }

  private clearAllTimers(): void {
    this.pendingTimers.forEach((timerId: number) => {
      clearTimeout(timerId);
    });
    this.pendingTimers.clear();
    Logger.debug(this.TAG, '已清理所有挂起的定时器');
  }

  /**
   * 分页搜索 - 支持渐进式加载和智能停止
   */
  async searchWithPaging(
    sources: BookSource[],
    options: SearchOptions,
    progressCallback?: SearchProgressCallback,
    bookFoundCallback?: BookFoundCallback
  ): Promise<PagedSearchResult> {
    const searchKey = options.key;
    const displayPage = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;
    const pageSize = options.pageSize || this.paginationConfig.pageSize;
    const maxPerSource = options.maxResultsPerSource || this.paginationConfig.maxResultsPerSource;
    const stopCondition = options.stopCondition || DEFAULT_STOP_CONDITION;
    const enableCache = options.enableCache ?? this.config.enableCache;
    const enableValidation = options.enableValidation ?? this.config.enableValidation;
    const enableQueryParsing = options.enableQueryParsing ?? this.config.enableQueryParsing;
    const onPartialResult = options.onPartialResult;

    const config: SearchPaginationConfig = {
      pageSize: pageSize,
      maxResultsPerSource: maxPerSource,
      maxTotalResults: this.paginationConfig.maxTotalResults,
      enableDeduplication: this.paginationConfig.enableDeduplication,
      sortByRelevance: this.paginationConfig.sortByRelevance
    };

    const resultBuilder = new SearchResultBuilder(config);
    const enabledSources = sources.filter((s: BookSource) => {
      if (!s.enabled) {
        return false;
      }
      if (!sourceHealthManager.isSourceEnabled(s.id)) {
        Logger.debug(this.TAG, `跳过已禁用的书源: ${s.name}`);
        return false;
      }
      return true;
    });

    // 按书源质量排序
    const sortedSources = enabledSources.sort((a: BookSource, b: BookSource) => {
      const scoreA = sourceHealthManager.getSourceScore(a.id);
      const scoreB = sourceHealthManager.getSourceScore(b.id);
      return scoreB - scoreA; // 高质量书源优先
    });

    Logger.info(this.TAG, 
      `开始渐进式搜索: "${searchKey}", ` +
      `书源数: ${sortedSources.length}, ` +
      `每页: ${pageSize}, ` +
      `缓存: ${enableCache}, ` +
      `验证: ${enableValidation}`
    );

    // 检查缓存
    if (enableCache) {
      const sourceIds = sortedSources.map(s => s.id);
      const cachedBooks = searchCache.get(searchKey, sourceIds);
      if (cachedBooks && cachedBooks.length > 0) {
        Logger.info(this.TAG, `缓存命中: "${searchKey}", 书籍数量: ${cachedBooks.length}`);
        
        // 验证缓存结果
        let validBooks = cachedBooks;
        if (enableValidation) {
          validBooks = searchResultValidator.validateBooks(cachedBooks, searchKey);
        }
        
        // 构建分页结果
        const pagedResult = this.buildPagedResult(validBooks, displayPage, config, []);
        const sourceStatsList: SourceSearchStats[] = sortedSources.map((source: BookSource): SourceSearchStats => {
          const stats: SourceSearchStats = {
            sourceId: source.id,
            sourceName: source.name,
            resultCount: 0,
            success: true,
            responseTime: 0
          };
          return stats;
        });
        pagedResult.sourceStats = sourceStatsList;
        
        return pagedResult;
      }
    }

    const progress: SearchProgress = {
      totalSources: sortedSources.length,
      completedSources: 0,
      currentSource: '',
      foundBooks: 0,
      isComplete: false,
      newBooks: []
    };

    const startTime = Date.now();
    let shouldStop = false;
    let lastProgressUpdate = 0;
    const THROTTLE_MS = 200;

    const throttledProgressCallback = progressCallback ? (p: SearchProgress) => {
      const now = Date.now();
      if (now - lastProgressUpdate >= THROTTLE_MS || p.isComplete) {
        lastProgressUpdate = now;
        progressCallback(p);
      }
    } : undefined;

    const checkStopCondition = (): boolean => {
      const elapsed = Date.now() - startTime;
      const totalBooks = resultBuilder.getTotalCount();
      const completedSources = progress.completedSources;
      const sourceStats = resultBuilder.getSourceStats();
      const successSources = sourceStats.filter((s: SourceSearchStats) => s.success).length;

      if (totalBooks >= stopCondition.maxBooks) {
        Logger.info(this.TAG, `智能停止: 已找到${totalBooks}本书，达到最大数量${stopCondition.maxBooks}`);
        return true;
      }

      if (elapsed >= stopCondition.maxTime) {
        Logger.info(this.TAG, `智能停止: 搜索时间${elapsed}ms超过阈值${stopCondition.maxTime}ms`);
        return true;
      }

      if (successSources >= stopCondition.minSources && totalBooks > 0) {
        Logger.info(this.TAG, `智能停止: 已成功搜索${successSources}个书源，找到${totalBooks}本书`);
        return true;
      }

      return false;
    };

    const executing: Promise<void>[] = [];
    const pendingSources: BookSource[] = sortedSources.slice();

    while (pendingSources.length > 0 && !shouldStop) {
      while (executing.length < concurrent && pendingSources.length > 0 && !shouldStop) {
        const source = pendingSources.shift()!;
        
        await this.checkRateLimit(source.url);

        const promise = this.searchSingleSource(source, searchKey, 1, enableQueryParsing)
          .then((result: SearchResult) => {
            if (shouldStop) return;

            // 验证结果
            let validBooks = result.books;
            if (enableValidation && result.success) {
              validBooks = searchResultValidator.validateBooks(result.books, searchKey);
            }

            const newBooks = resultBuilder.addSourceResult(
              source.id,
              source.name,
              validBooks,
              result.success,
              result.error,
              result.responseTime
            );
            
            if (result.success) {
              sourceHealthManager.recordSuccess(source.id, source.name, source.url, result.responseTime);
            } else {
              const networkError = this.parseNetworkError(result.error || '');
              sourceHealthManager.recordFailure(source.id, source.name, source.url, networkError.type, networkError.message);
            }

            progress.completedSources++;
            progress.currentSource = source.name;
            progress.foundBooks = resultBuilder.getTotalCount();
            progress.newBooks = newBooks;

            if (bookFoundCallback && newBooks.length > 0) {
              bookFoundCallback(newBooks, this.cloneSearchProgress(progress));
            }

            // 渐进式结果回调
            if (onPartialResult && newBooks.length > 0) {
              const allBooksSoFar = this.getAllBooksFromBuilder(resultBuilder);
              onPartialResult(allBooksSoFar);
            }

            if (throttledProgressCallback) {
              throttledProgressCallback(this.cloneSearchProgress(progress));
            }

            if (checkStopCondition()) {
              shouldStop = true;
              progress.isComplete = true;
              if (throttledProgressCallback) {
                throttledProgressCallback(this.cloneSearchProgress(progress));
              }
            }
          })
          .catch((error: Error) => {
            if (shouldStop) return;
            
            Logger.error(this.TAG, `搜索失败: ${source.name}, ${error}`);
            
            const networkError = this.parseNetworkError(error.message);
            sourceHealthManager.recordFailure(source.id, source.name, source.url, networkError.type, networkError.message);
            
            resultBuilder.addSourceResult(
              source.id,
              source.name,
              [],
              false,
              String(error),
              0
            );

            progress.completedSources++;
            progress.currentSource = source.name;
            progress.foundBooks = resultBuilder.getTotalCount();

            if (throttledProgressCallback) {
              throttledProgressCallback(this.cloneSearchProgress(progress));
            }
          })
          .finally(() => {
            const index = executing.indexOf(promise);
            if (index > -1) {
              executing.splice(index, 1);
            }
          });

        executing.push(promise);
      }

      if (executing.length > 0 && !shouldStop) {
        await Promise.race(executing);
      }
    }

    if (executing.length > 0) {
      await Promise.all(executing);
    }

    progress.isComplete = true;
    progress.foundBooks = resultBuilder.getTotalCount();
    if (throttledProgressCallback) {
      throttledProgressCallback(this.cloneSearchProgress(progress));
    }

    // 获取所有书籍并缓存
    const allBooks = this.getAllBooksFromBuilder(resultBuilder);
    if (enableCache && allBooks.length > 0) {
      const sourceIds = sortedSources.map(s => s.id);
      searchCache.set(searchKey, sourceIds, allBooks);
      Logger.info(this.TAG, `缓存设置: "${searchKey}", 书籍数量: ${allBooks.length}`);
    }

    const pagedResult = resultBuilder.build(displayPage);

    Logger.info(this.TAG, 
      `渐进式搜索完成: 共${pagedResult.totalCount}本书, ` +
      `第${pagedResult.currentPage}/${pagedResult.totalPages}页, ` +
      `成功书源: ${pagedResult.sourceStats.filter((s: SourceSearchStats) => s.success).length}/${enabledSources.length}` +
      `${shouldStop ? ' (智能停止)' : ''}`
    );

    return pagedResult;
  }

  /**
   * 从结果构建器获取所有书籍
   */
  private getAllBooksFromBuilder(builder: SearchResultBuilder): Book[] {
    // 由于 SearchResultBuilder 没有公开获取所有书籍的方法，
    // 我们需要通过反射或其他方式获取
    // 这里使用一个简单的方法：通过构建第1页获取所有书籍
    const tempResult = builder.build(1);
    const totalCount = tempResult.totalCount;
    
    // 获取所有书籍（假设每页大小足够大）
    const allPagesResult = builder.build(1);
    // 注意：这里需要修改 SearchResultBuilder 以支持获取所有书籍
    // 暂时返回第一页的结果
    return allPagesResult.books;
  }

  /**
   * 构建分页结果
   */
  private buildPagedResult(
    books: Book[], 
    page: number, 
    config: SearchPaginationConfig,
    sourceStats: SourceSearchStats[]
  ): PagedSearchResult {
    const totalCount = books.length;
    const totalPages = Math.ceil(totalCount / config.pageSize);
    const validPage = Math.max(1, Math.min(page, totalPages || 1));
    const startIndex = (validPage - 1) * config.pageSize;
    const endIndex = startIndex + config.pageSize;
    const pageBooks = books.slice(startIndex, endIndex);

    return {
      books: pageBooks,
      totalCount,
      currentPage: validPage,
      pageSize: config.pageSize,
      totalPages,
      hasMore: validPage < totalPages,
      sourceStats
    };
  }

  private createMutex(): MutexInterface {
    let locked = false;
    const queue: Array<() => void> = [];
    const mutexObj: MutexInterface = {
      lock: async (): Promise<void> => {
        if (locked) {
          await new Promise<void>((resolve: () => void) => queue.push(resolve));
        }
        locked = true;
      },
      unlock: (): void => {
        locked = false;
        const next = queue.shift();
        if (next) next();
      }
    };
    return mutexObj;
  }

  /**
   * 在单个书源中搜索（支持动态超时）
   */
  async searchSingleSource(
    source: BookSource,
    key: string,
    page: number = 1,
    enableQueryParsing: boolean = true
  ): Promise<SearchResult> {
    const startTime = Date.now();

    try {
      Logger.debug(this.TAG, `开始搜索: ${source.name}, 关键词: ${key}`);

      // 解析查询（如果启用）
      let searchKey = key;
      if (enableQueryParsing) {
        const parsedQuery = searchQueryParser.parse(key);
        type ValidEncoding = 'urlencode' | 'base64' | 'double-urlencode' | 'none';
        const validEncodings: ValidEncoding[] = ['urlencode', 'base64', 'double-urlencode', 'none'];
        const rawEncoding = source.keywordEncoding || 'urlencode';
        const encoding: ValidEncoding = validEncodings.includes(rawEncoding as ValidEncoding)
          ? (rawEncoding as ValidEncoding)
          : 'urlencode';
        const queryConfig: QueryEncodingConfig = {
          encoding: encoding,
          separator: source.keywordSeparator || '+',
          supportAdvanced: source.advancedQuerySupport || false
        };
        searchKey = searchQueryParser.encodeQuery(key, queryConfig);
      }

      const urlConfig = await this.buildSearchUrlWithConfig(source, searchKey, page);
      if (!urlConfig.url) {
        throw new Error('无法构建搜索 URL');
      }

      // 使用动态超时
      const timeout = this.getAdaptiveTimeout(source);
      const html = await this.executeSearchRequestWithTimeout(source, urlConfig, timeout);

      const books = await this.parseSearchResults(source, html, key);

      const responseTime = Date.now() - startTime;

      return {
        books: books.slice(0, this.config.maxResultsPerSource),
        sourceName: source.name,
        sourceUrl: source.url,
        success: true,
        responseTime
      };

    } catch (error) {
      const responseTime = Date.now() - startTime;
      const errorMsg = error instanceof Error ? error.message : String(error);
      const errorStack = error instanceof Error ? error.stack : '';
      Logger.error(this.TAG, `搜索失败: ${source.name}, 错误: ${errorMsg}`);
      if (errorStack) {
        Logger.error(this.TAG, `错误堆栈: ${errorStack}`);
      }

      return {
        books: [],
        sourceName: source.name,
        sourceUrl: source.url,
        success: false,
        error: errorMsg || '搜索失败',
        responseTime
      };
    }
  }

  /**
   * 获取自适应超时时间
   */
  private getAdaptiveTimeout(source: BookSource): number {
    if (!this.config.dynamicTimeout) {
      return this.config.timeout;
    }

    const stats = sourceHealthManager.getSourceStats(source.id);
    if (!stats || stats.requestCount < 5) {
      return this.config.timeout;
    }

    // 基于历史响应时间动态调整
    const adaptiveTimeout = Math.min(
      stats.avgResponseTime * 2 + 2000, // 平均响应时间的2倍 + 2秒缓冲
      this.config.timeout * 2 // 不超过默认超时的2倍
    );

    Logger.debug(this.TAG, 
      `动态超时: ${source.name}, ` +
      `平均响应: ${stats.avgResponseTime}ms, ` +
      `超时: ${adaptiveTimeout}ms`
    );

    return adaptiveTimeout;
  }

  /**
   * 执行带超时的搜索请求
   */
  private async executeSearchRequestWithTimeout(
    source: BookSource,
    urlConfig: SearchUrlResult,
    timeout: number
  ): Promise<string> {
    let timeoutId: number | undefined = undefined;

    const timeoutPromise: Promise<string> = new Promise<string>((_resolve, reject): void => {
      timeoutId = setTimeout((): void => {
        reject(new Error(`请求超时: ${timeout}ms`));
      }, timeout);
    });

    try {
      const result = await Promise.race([
        this.executeSearchRequestWithConfig(source, urlConfig),
        timeoutPromise
      ]);

      if (timeoutId !== undefined) {
        clearTimeout(timeoutId);
      }
      return result;
    } catch (error) {
      if (timeoutId !== undefined) {
        clearTimeout(timeoutId);
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(String(error));
    }
  }

  /**
   * 构建搜索 URL
   */
  private async buildSearchUrlWithConfig(source: BookSource, key: string, page: number): Promise<SearchUrlResult> {
    if (!source.searchUrl) {
      throw new Error('书源未配置搜索 URL');
    }

    let searchUrl = source.searchUrl;
    const config: UrlConfig = {
      method: 'GET',
      headers: {}
    };

    if (source.header) {
      try {
        const customHeaders: Record<string, string> = JSON.parse(source.header);
        config.headers = this.copyHeaders(customHeaders);
      } catch {
        Logger.warn(this.TAG, '解析 header 失败');
      }
    }

    if (searchUrl.includes('@js:') || searchUrl.includes('<js>')) {
      const jsCode = searchUrl.replace(/^@js:/, '').replace(/<js>|<\/js>/g, '');
      const result = await this.jsEngine.executeSearchUrl(jsCode, {
        key,
        page,
        baseUrl: source.url
      });
      return { url: result, config };
    }

    const commaIndex = searchUrl.indexOf(',{');
    if (commaIndex > 0 && searchUrl.endsWith('}')) {
      try {
        const urlPart = searchUrl.substring(0, commaIndex);
        const configPart = searchUrl.substring(commaIndex + 1);
        const parsedConfig = this.parseUrlConfig(configPart, config.headers);
        searchUrl = urlPart;
        config.method = parsedConfig.method;
        config.body = parsedConfig.body;
        config.headers = parsedConfig.headers;
        Logger.debug(this.TAG, `从URL中提取配置，方法: ${config.method}`);
      } catch {
        Logger.warn(this.TAG, 'URL配置解析失败');
      }
    }

    searchUrl = searchUrl
      .replace(/\{\{key\}\}/g, encodeURIComponent(key))
      .replace(/\{\{page\}\}/g, String(page))
      .replace(/\{key\}/g, encodeURIComponent(key))
      .replace(/\{page\}/g, String(page))
      .replace(/<key>/g, encodeURIComponent(key))
      .replace(/<page>/g, String(page))
      .replace(/\$key\$/g, encodeURIComponent(key))
      .replace(/\$page\$/g, String(page));

    if (config.body) {
      config.body = config.body
        .replace(/\{\{key\}\}/g, encodeURIComponent(key))
        .replace(/\{\{page\}\}/g, String(page))
        .replace(/\{key\}/g, encodeURIComponent(key))
        .replace(/\{page\}/g, String(page))
        .replace(/<key>/g, encodeURIComponent(key))
        .replace(/<page>/g, String(page))
        .replace(/\$key\$/g, encodeURIComponent(key))
        .replace(/\$page\$/g, String(page));
      Logger.debug(this.TAG, `POST请求体: ${config.body}`);
    }

    if (!searchUrl.startsWith('http')) {
      searchUrl = this.resolveUrl(source.url, searchUrl);
    }

    return { url: searchUrl, config };
  }

  private parseUrlConfig(configStr: string, baseHeaders: Record<string, string>): UrlConfig {
    const config: UrlConfig = {
      method: 'GET',
      headers: this.copyHeaders(baseHeaders)
    };

    try {
      const parsed = JSON.parse(configStr) as Record<string, string | number | boolean | object | null | undefined>;
      
      if (parsed.method && typeof parsed.method === 'string') {
        const method = parsed.method.toUpperCase();
        if (method === 'POST') {
          config.method = 'POST';
        }
      }

      if (parsed.body && typeof parsed.body === 'string') {
        config.body = parsed.body;
      }

      if (parsed.headers && typeof parsed.headers === 'object') {
        const headerObj = parsed.headers as Record<string, string>;
        const keys = Object.keys(headerObj);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          config.headers[key] = headerObj[key];
        }
      }

      const otherKeys = Object.keys(parsed);
      for (let i = 0; i < otherKeys.length; i++) {
        const key = otherKeys[i];
        if (key !== 'method' && key !== 'body' && key !== 'headers') {
          const value = parsed[key];
          if (typeof value === 'string') {
            config.headers[key] = value;
          }
        }
      }
    } catch (e) {
      Logger.warn(this.TAG, `解析URL配置失败: ${e}`);
    }

    return config;
  }

  private copyHeaders(source: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(source);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      result[key] = source[key];
    }
    return result;
  }

  private async executeSearchRequestWithConfig(
    source: BookSource,
    urlConfig: SearchUrlResult
  ): Promise<string> {
    const url = urlConfig.url;
    const config = urlConfig.config;

    Logger.info(this.TAG, `执行请求: ${source.name}, URL: ${url}, 方法: ${config.method}`);

    try {
      let result: string;
      if (config.method === 'POST') {
        result = await NetworkAdapter.post(url, config.body || '', config.headers);
      } else {
        result = await NetworkAdapter.get(url, config.headers);
      }
      Logger.info(this.TAG, `请求成功: ${source.name}, 响应长度: ${result.length}`);
      Logger.debug(this.TAG, `响应内容片段[${source.name}]: ${result.substring(0, 1000)}`);
      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `请求失败: ${source.name}, URL: ${url}, 错误: ${errorMsg}`);
      throw new Error(errorMsg);
    }
  }

  /**
   * 解析搜索结果
   */
  private async parseSearchResults(
    source: BookSource,
    html: string,
    key: string
  ): Promise<Book[]> {
    const books: Book[] = [];
    const searchRule = source.searchRule;

    if (!searchRule) {
      Logger.error(this.TAG, `书源未配置搜索规则: ${source.name}`);
      throw new Error('书源未配置搜索规则');
    }

    Logger.debug(this.TAG, `开始解析: ${source.name}, 列表规则: ${searchRule.bookList}`);

    // 1. 获取书籍列表（使用异步解析避免主线程阻塞）
    const bookListHtml = await this.htmlParser.parseAsync(html, searchRule.bookList);

    if (!bookListHtml || bookListHtml.length === 0) {
      Logger.warn(this.TAG, `解析结果为空: ${source.name}, 列表规则: ${searchRule.bookList}`);
      Logger.debug(this.TAG, `HTML前500字符: ${html.substring(0, 500)}`);
      return books;
    }

    Logger.info(this.TAG, `解析到 ${bookListHtml.length} 个书籍块: ${source.name}`);

    // 2. 限制每批次解析的书籍数量，避免一次性处理过多
    const MAX_BOOKS_PER_BATCH = 5;
    const totalBooks = Math.min(bookListHtml.length, this.config.maxResultsPerSource);

    for (let i = 0; i < totalBooks; i += MAX_BOOKS_PER_BATCH) {
      const batch = bookListHtml.slice(i, i + MAX_BOOKS_PER_BATCH);
      const batchPromises: Promise<Book | null>[] = [];

      for (const bookHtml of batch) {
        batchPromises.push(this.parseSingleBook(source, bookHtml, key));
      }

      const batchResults = await Promise.all(batchPromises);

      for (const book of batchResults) {
        if (book && book.name) {
          books.push(book);
          Logger.debug(this.TAG, `解析书籍成功: ${book.name} - ${book.author || '未知作者'}`);
        }
      }

      // 每批次处理后让出主线程，避免阻塞
      if (i + MAX_BOOKS_PER_BATCH < totalBooks) {
        await new Promise<void>(resolve => setTimeout(resolve, 0));
      }
    }

    Logger.info(this.TAG, `解析完成: ${source.name}, 成功 ${books.length}/${totalBooks} 本`);
    return books;
  }

  /**
   * 解析单本书籍
   */
  private async parseSingleBook(
    source: BookSource,
    html: string,
    searchKey: string
  ): Promise<Book | null> {
    const searchRule = source.searchRule;

    // 提取书名
    const name = await this.extractField(html, searchRule.name, source);
    if (!name) {
      Logger.debug(this.TAG, `书名提取失败: 书源=${source.name}, 规则=${searchRule.name}, HTML片段=${html.substring(0, 200)}`);
      return null;
    }

    // 提取作者
    const author = await this.extractField(html, searchRule.author, source);
    Logger.debug(this.TAG, `字段提取: 书源=${source.name}, 书名=${name}, 作者=${author || '空'}, 作者规则=${searchRule.author}`);

    // 提取封面
    let cover = await this.extractField(html, searchRule.cover || '', source);
    if (cover && !cover.startsWith('http')) {
      cover = this.resolveUrl(source.url, cover);
    }

    // 提取简介
    const intro = await this.extractField(html, searchRule.intro || '', source);

    // 提取书籍 URL
    let bookUrl = await this.extractField(html, searchRule.bookUrl, source);
    if (bookUrl && !bookUrl.startsWith('http')) {
      bookUrl = this.resolveUrl(source.url, bookUrl);
    }
    Logger.debug(this.TAG, `字段提取: 书源=${source.name}, 书籍URL=${bookUrl || '空'}, URL规则=${searchRule.bookUrl}`);

    const book: Book = {
      id: '',
      name: this.cleanText(name),
      author: searchResultValidator.normalizeAuthor(this.cleanText(author) || '未知作者'),
      cover: cover || undefined,
      intro: intro || undefined,
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookSourceId: source.id,
      bookSourceName: source.name,
      bookUrl: bookUrl || '',
      lastUpdateTime: 0,
      addTime: 0,
      readProgress: 0,
      lastReadChapter: undefined,
      lastReadChapterIndex: undefined,
      lastReadTime: 0,
      totalChapters: 0,
      currentChapterIndex: 0,
      currentChapterTitle: '',
      isInShelf: false
    };

    return book;
  }

  /**
   * 提取字段
   */
  private async extractField(html: string, rule: string, source: BookSource): Promise<string> {
    if (!rule) return '';

    // 处理 JS 规则
    if (rule.startsWith('@js:') || rule.includes('<js>')) {
      const result = await this.jsEngine.executeRule(html, rule, source.url);
      return result;
    }

    // 先检查缓存
    const cached = parseCache.get(html, rule);
    if (cached && cached.length > 0) {
      // 从缓存的元素中提取文本
      return this.extractTextFromElement(cached[0]);
    }

    // 使用异步 CSS 选择器解析器提取文本内容（避免主线程阻塞）
    const text = await this.asyncCssSelectorParser.extractValue(html, rule);

    // 缓存解析结果
    if (text) {
      const elements = await this.asyncCssSelectorParser.selectElements(html, rule);
      if (elements.length > 0) {
        parseCache.set(html, rule, elements);
      }
    }

    return text || '';
  }

  /**
   * 从元素中提取文本
   */
  private extractTextFromElement(element: string): string {
    if (!element) return '';

    // 提取文本内容
    const textMatch = element.match(/>([^<]*)</);
    if (textMatch) {
      return this.decodeHtmlEntities(textMatch[1].trim());
    }

    return '';
  }

  /**
   * 解码 HTML 实体
   */
  private decodeHtmlEntities(text: string): string {
    const entities: Map<string, string> = new Map([
      ['&amp;', '&'],
      ['&lt;', '<'],
      ['&gt;', '>'],
      ['&quot;', '"'],
      ['&#39;', "'"],
      ['&nbsp;', ' '],
      ['&hellip;', '…'],
      ['&mdash;', '—'],
      ['&ndash;', '–'],
      ['&ldquo;', '"'],
      ['&rdquo;', '"'],
      ['&lsquo;', '\u2018'],
      ['&rsquo;', '\u2019'],
    ]);

    let result = text;
    entities.forEach((value: string, key: string) => {
      result = result.split(key).join(value);
    });

    // 处理数字实体
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });

    return result;
  }

  /**
   * 清理文本
   */
  private cleanText(text: string): string {
    if (!text) return '';
    return text
      .replace(/[\n\r\t]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 解析 URL
   */
  private resolveUrl(base: string, relative: string): string {
    if (!relative) return '';
    if (relative.startsWith('http')) return relative;

    try {
      // 简单的 URL 解析
      const protocolEnd = base.indexOf('://');
      if (protocolEnd === -1) return relative;

      const protocol = base.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = base.indexOf('/', hostStart);
      const host = pathStart === -1 ? base.substring(hostStart) : base.substring(hostStart, pathStart);

      if (relative.startsWith('/')) {
        return `${protocol}${host}${relative}`;
      }

      const path = pathStart === -1 ? '/' : base.substring(pathStart);
      const lastSlash = path.lastIndexOf('/');
      const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);

      return `${protocol}${host}${basePath}${relative}`;
    } catch {
      return relative;
    }
  }

  /**
   * 检查请求频率限制
   */
  private async checkRateLimit(sourceUrl: string): Promise<void> {
    const now = Date.now();
    const timestamps = this.requestTimestamps.get(sourceUrl) || [];

    // 清理过期的时间戳（保留最近1秒的）
    const validTimestamps = timestamps.filter((t: number) => now - t < 1000);

    // 检查是否需要等待
    if (validTimestamps.length > 0) {
      const lastRequest = validTimestamps[validTimestamps.length - 1];
      const waitTime = this.config.requestInterval - (now - lastRequest);

      if (waitTime > 0) {
        Logger.debug(this.TAG, `频率限制: 等待 ${waitTime}ms`);
        await this.sleep(waitTime);
      }
    }

    // 更新时间戳
    validTimestamps.push(Date.now());
    this.requestTimestamps.set(sourceUrl, validTimestamps);
  }

  /**
   * 延迟 - 支持取消和清理
   */
  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
      if (this.isCancelled) {
        reject(new Error('搜索已取消'));
        return;
      }
      
      const timerId: number = Number(setTimeout(() => {
        this.pendingTimers.delete(timerId);
        if (this.isCancelled) {
          reject(new Error('搜索已取消'));
        } else {
          resolve();
        }
      }, ms));
      
      this.pendingTimers.add(timerId);
    });
  }

  /**
   * 解析网络错误
   */
  private parseNetworkError(errorMsg: string): NetworkError {
    if (errorMsg.startsWith('NETWORK_ERROR:')) {
      try {
        const jsonStr = errorMsg.substring('NETWORK_ERROR:'.length);
        return JSON.parse(jsonStr) as NetworkError;
      } catch {
        // ignore
      }
    }
    
    const lowerMsg = errorMsg.toLowerCase();
    if (lowerMsg.includes('timeout')) {
      return { type: 'timeout', message: errorMsg };
    }
    if (lowerMsg.includes('ssl') || lowerMsg.includes('certificate')) {
      return { type: 'ssl', message: errorMsg };
    }
    if (lowerMsg.includes('resolve') || lowerMsg.includes('dns') || lowerMsg.includes('host')) {
      return { type: 'dns', message: errorMsg };
    }
    if (lowerMsg.includes('403')) {
      return { type: 'http', message: errorMsg, statusCode: 403 };
    }
    if (lowerMsg.includes('404')) {
      return { type: 'http', message: errorMsg, statusCode: 404 };
    }
    
    return { type: 'unknown', message: errorMsg };
  }

  /**
   * 设置配置
   */
  setConfig(config: Partial<SearchConfig>): void {
    this.config.maxConcurrent = config.maxConcurrent ?? this.config.maxConcurrent;
    this.config.requestInterval = config.requestInterval ?? this.config.requestInterval;
    this.config.timeout = config.timeout ?? this.config.timeout;
    this.config.maxResultsPerSource = config.maxResultsPerSource ?? this.config.maxResultsPerSource;
    this.config.enableCache = config.enableCache ?? this.config.enableCache;
    this.config.enableValidation = config.enableValidation ?? this.config.enableValidation;
    this.config.enableQueryParsing = config.enableQueryParsing ?? this.config.enableQueryParsing;
    this.config.dynamicTimeout = config.dynamicTimeout ?? this.config.dynamicTimeout;
    this.config.minSimilarity = config.minSimilarity ?? this.config.minSimilarity;
    this.config.maxIntroLength = config.maxIntroLength ?? this.config.maxIntroLength;

    // 更新验证器配置
    if (config.minSimilarity !== undefined || config.maxIntroLength !== undefined) {
      searchResultValidator.setConfig({
        minSimilarity: this.config.minSimilarity,
        maxIntroLength: this.config.maxIntroLength
      });
    }

    Logger.info(this.TAG, 
      `搜索配置已更新: ` +
      `并发=${this.config.maxConcurrent}, ` +
      `间隔=${this.config.requestInterval}ms, ` +
      `超时=${this.config.timeout}ms, ` +
      `缓存=${this.config.enableCache}, ` +
      `验证=${this.config.enableValidation}, ` +
      `动态超时=${this.config.dynamicTimeout}`
    );
  }

  /**
   * 设置分页配置
   */
  setPaginationConfig(config: Partial<SearchPaginationConfig>): void {
    if (config.pageSize !== undefined) {
      this.paginationConfig.pageSize = Math.max(5, Math.min(50, config.pageSize));
    }
    if (config.maxResultsPerSource !== undefined) {
      this.paginationConfig.maxResultsPerSource = Math.max(5, Math.min(100, config.maxResultsPerSource));
    }
    if (config.maxTotalResults !== undefined) {
      this.paginationConfig.maxTotalResults = Math.max(50, Math.min(500, config.maxTotalResults));
    }
    if (config.enableDeduplication !== undefined) {
      this.paginationConfig.enableDeduplication = config.enableDeduplication;
    }
    if (config.sortByRelevance !== undefined) {
      this.paginationConfig.sortByRelevance = config.sortByRelevance;
    }
    Logger.info(this.TAG, `分页配置已更新: pageSize=${this.paginationConfig.pageSize}, maxPerSource=${this.paginationConfig.maxResultsPerSource}`);
  }

  /**
   * 获取分页配置
   */
  getPaginationConfig(): SearchPaginationConfig {
    const config: SearchPaginationConfig = {
      pageSize: this.paginationConfig.pageSize,
      maxResultsPerSource: this.paginationConfig.maxResultsPerSource,
      maxTotalResults: this.paginationConfig.maxTotalResults,
      enableDeduplication: this.paginationConfig.enableDeduplication,
      sortByRelevance: this.paginationConfig.sortByRelevance
    };
    return config;
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.requestTimestamps.clear();
    searchCache.clearAll();
    Logger.info(this.TAG, '所有缓存已清除');
  }

  /**
   * 获取搜索统计信息
   */
  getSearchStats(): SearchStats {
    const cacheStats = searchCache.getStats();
    
    return {
      cacheEntries: cacheStats.totalEntries,
      cacheHitRate: 0, // 需要记录命中率
      avgResponseTime: 0, // 需要记录平均响应时间
      totalSearches: 0, // 需要记录总搜索次数
      enabledSources: sourceHealthManager.getEnabledSources().length,
      totalSources: sourceHealthManager.getAllHealthRecords().length
    };
  }
}

export interface SearchConfig {
  maxConcurrent: number;
  requestInterval: number;
  timeout: number;
  maxResultsPerSource: number;
  enableCache: boolean;
  enableValidation: boolean;
  enableQueryParsing: boolean;
  dynamicTimeout: boolean;
  minSimilarity: number;
  maxIntroLength: number;
}

export interface SearchStats {
  cacheEntries: number;
  cacheHitRate: number;
  avgResponseTime: number;
  totalSearches: number;
  enabledSources: number;
  totalSources: number;
}

export default EnhancedBookSourceSearchEngine.getInstance();