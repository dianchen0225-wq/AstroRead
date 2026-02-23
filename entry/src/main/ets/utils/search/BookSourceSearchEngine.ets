/**
 * BookSourceSearchEngine - 书源搜索引擎
 * 支持多书源并发搜索、请求频率控制、结果聚合、分页控制
 * 实现 ISearchEngine 接口
 */

import { BookSource } from '../../models/BookSource';
import { Book } from '../../models/Book';
import { 
  PagedSearchResult, 
  SourceSearchStats, 
  SearchPaginationConfig, 
  DEFAULT_PAGINATION_CONFIG,
  SearchResultBuilder,
  SearchProgress,
  SearchStopCondition,
  DEFAULT_STOP_CONDITION
} from '../../models/SearchResult';
import { 
  ISearchEngine, 
  SearchResult as ISearchResult, 
  SearchOptions as ISearchOptions,
  SearchEngineConfig,
  DEFAULT_SEARCH_ENGINE_CONFIG,
  SearchProgressCallback,
  BookFoundCallback
} from '../../core/interfaces/ISearchEngine';
import NetworkAdapter, { NetworkError } from '../network/NetworkAdapter';
import { HTMLParser } from '../parser/HTMLParser';
import { CssSelectorParser } from '../parser/CssSelectorParser';
import { AsyncCssSelectorParser } from '../parser/AsyncCssSelectorParser';
import { parseCache } from '../cache/ParseCache';
import { EnhancedJSEngine } from '../scripting/EnhancedJSEngine';
import { Logger } from '../performance/Logger';
import { sourceHealthManager } from '../validation/SourceHealthManager';
import { parseDebugLogger, ParseErrorInfo, ParseResultInfo, FieldExtractionParams, BookListExtractionParams, SearchDebugParams } from '../performance/ParseDebugLogger';
import { searchCache } from './SearchCache';
import { SearchResultValidator } from './SearchResultValidator';
import { SearchQueryParser } from './SearchQueryParser';
import { UniversalParser } from '../parser/UniversalParser';

// 为了保持向后兼容，重新导出接口
export { ISearchResult as SearchResult, ISearchOptions as SearchOptions, SearchProgressCallback, BookFoundCallback };

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

interface FieldExtractionResult {
  value: string;
  ruleType: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js';
}

interface RuleParseResult {
  selector: string;
  attribute?: string;
}

export class BookSourceSearchEngine implements ISearchEngine {
  private static instance: BookSourceSearchEngine | null = null;
  private htmlParser: HTMLParser;
  private jsEngine: EnhancedJSEngine;
  private asyncCssSelectorParser: AsyncCssSelectorParser;
  private universalParser: UniversalParser;
  private requestTimestamps: Map<string, number[]> = new Map();
  private pendingTimers: Set<number> = new Set();
  private isCancelled: boolean = false;
  private isSearchingFlag: boolean = false;
  private readonly TAG = 'BookSourceSearchEngine';

  private config: SearchEngineConfig = DEFAULT_SEARCH_ENGINE_CONFIG;

  private paginationConfig: SearchPaginationConfig = DEFAULT_PAGINATION_CONFIG;

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.jsEngine = EnhancedJSEngine.getInstance();
    this.asyncCssSelectorParser = AsyncCssSelectorParser.getInstance();
    this.universalParser = UniversalParser.getInstance();
  }

  static getInstance(): BookSourceSearchEngine {
    if (!BookSourceSearchEngine.instance) {
      BookSourceSearchEngine.instance = new BookSourceSearchEngine();
    }
    return BookSourceSearchEngine.instance;
  }

  /**
   * 设置配置
   */
  setConfig(config: Partial<SearchEngineConfig>): void {
    // ArkTS 不支持对象展开运算符，手动合并配置
    if (config.maxConcurrent !== undefined) {
      this.config.maxConcurrent = config.maxConcurrent;
    }
    if (config.requestInterval !== undefined) {
      this.config.requestInterval = config.requestInterval;
    }
    if (config.timeout !== undefined) {
      this.config.timeout = config.timeout;
    }
    if (config.maxResultsPerSource !== undefined) {
      this.config.maxResultsPerSource = config.maxResultsPerSource;
    }
    if (config.enableCache !== undefined) {
      this.config.enableCache = config.enableCache;
    }
    if (config.cacheExpiry !== undefined) {
      this.config.cacheExpiry = config.cacheExpiry;
    }
  }

  /**
   * 获取配置
   */
  getConfig(): SearchEngineConfig {
    // ArkTS 不支持对象展开运算符，手动复制配置
    return {
      maxConcurrent: this.config.maxConcurrent,
      requestInterval: this.config.requestInterval,
      timeout: this.config.timeout,
      maxResultsPerSource: this.config.maxResultsPerSource,
      enableCache: this.config.enableCache,
      cacheExpiry: this.config.cacheExpiry
    };
  }

  /**
   * 是否正在搜索
   */
  isSearching(): boolean {
    return this.isSearchingFlag;
  }

  /**
   * 复制 SearchProgress 对象（ArkTS 不支持 spread 操作符）
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

  /**
   * 在单个书源中搜索（实现 ISearchEngine 接口）
   */
  async searchInSource(
    source: BookSource,
    keyword: string,
    options?: ISearchOptions
  ): Promise<ISearchResult> {
    const page = options?.page || 1;
    return this.searchSingleSource(source, keyword, page);
  }

  /**
   * 在多个书源中并发搜索（实现 ISearchEngine 接口）
   */
  async searchInMultipleSources(
    sources: BookSource[],
    keyword: string,
    options?: ISearchOptions,
    onProgress?: SearchProgressCallback,
    onBookFound?: BookFoundCallback
  ): Promise<ISearchResult[]> {
    const searchOptions: ISearchOptions = {
      key: keyword,
      page: options?.page || 1,
      concurrent: options?.concurrent || this.config.maxConcurrent,
      timeout: options?.timeout || this.config.timeout
    };
    return this.search(sources, searchOptions);
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
    options: ISearchOptions,
    progressCallback?: SearchProgressCallback,
    bookFoundCallback?: BookFoundCallback
  ): Promise<PagedSearchResult> {
    const searchKey = options.key;
    const displayPage = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;
    const pageSize = options.pageSize || this.paginationConfig.pageSize;
    const maxPerSource = options.maxResultsPerSource || this.paginationConfig.maxResultsPerSource;
    const stopCondition = DEFAULT_STOP_CONDITION;

    const config: SearchPaginationConfig = {
      pageSize: pageSize,
      maxResultsPerSource: maxPerSource,
      maxTotalResults: this.paginationConfig.maxTotalResults,
      enableDeduplication: this.paginationConfig.enableDeduplication,
      sortByRelevance: this.paginationConfig.sortByRelevance
    };

    const resultBuilder = new SearchResultBuilder(config);
    const enabledSources = sources.filter((s: BookSource) => {
      if (!s.metadata.enabled) {
        return false;
      }
      if (!sourceHealthManager.isSourceEnabled(s.id)) {
        Logger.debug(this.TAG, `跳过已禁用的书源: ${s.name}`);
        return false;
      }
      return true;
    });

    const sortedSources = enabledSources.sort((a: BookSource, b: BookSource) => {
      const scoreA = sourceHealthManager.getSourceScore(a.id);
      const scoreB = sourceHealthManager.getSourceScore(b.id);
      return scoreB - scoreA;
    });

    Logger.info(this.TAG, `开始渐进式搜索: "${searchKey}", 书源数: ${sortedSources.length}, 每页: ${pageSize}`);

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
    const THROTTLE_MS = 300;

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

        const promise = this.searchSingleSource(source, searchKey, 1)
          .then((result: ISearchResult) => {
            if (shouldStop) return;

            const newBooks = resultBuilder.addSourceResult(
              source.id,
              source.name,
              result.books,
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

    const pagedResult = resultBuilder.build(displayPage);

    Logger.info(this.TAG, 
      `渐进式搜索完成: 共${pagedResult.totalCount}本书, ` +
      `第${pagedResult.currentPage}/${pagedResult.totalPages}页, ` +
      `成功书源: ${pagedResult.sourceStats.filter((s: SourceSearchStats) => s.success).length}/${enabledSources.length}` +
      `${shouldStop ? ' (智能停止)' : ''}`
    );

    return pagedResult;
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
   * 在多个书源中搜索（兼容旧接口）
   */
  async search(
    sources: BookSource[],
    options: ISearchOptions
  ): Promise<ISearchResult[]> {
    const searchKey = options.key;
    const page = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;

    Logger.info(this.TAG, `开始搜索: "${searchKey}", 书源数: ${sources.length}`);

    const enabledSources = sources.filter((s: BookSource) => s.metadata.enabled);

    const results: ISearchResult[] = [];
    const executing: Promise<void>[] = [];

    for (let i = 0; i < enabledSources.length; i++) {
      const source = enabledSources[i];

      if (executing.length >= concurrent) {
        await Promise.race(executing);
      }

      await this.checkRateLimit(source.url);

      const promise = this.searchSingleSource(source, searchKey, page)
        .then((result: ISearchResult) => {
          results.push(result);
        })
        .catch((error: Error) => {
          Logger.error(this.TAG, `搜索失败: ${source.name}, ${error}`);
          const failedResult: ISearchResult = {
            books: [],
            sourceName: source.name,
            sourceUrl: source.url,
            success: false,
            error: String(error),
            responseTime: 0
          };
          results.push(failedResult);
        })
        .finally(() => {
          const index = executing.indexOf(promise);
          if (index > -1) {
            executing.splice(index, 1);
          }
        });

      executing.push(promise);
    }

    await Promise.all(executing);

    Logger.info(this.TAG, `搜索完成: ${results.filter((r: ISearchResult) => r.success).length}/${sources.length} 成功`);
    return results;
  }

  /**
   * 在单个书源中搜索
   */
  async searchSingleSource(
    source: BookSource,
    key: string,
    page: number = 1
  ): Promise<ISearchResult> {
    const startTime = Date.now();

    try {
      Logger.debug(this.TAG, `开始搜索: ${source.name}, 关键词: ${key}`);

      const urlConfig = await this.buildSearchUrlWithConfig(source, key, page);
      if (!urlConfig.url) {
        throw new Error('无法构建搜索 URL');
      }

      const html = await this.executeSearchRequestWithConfig(source, urlConfig);

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
   * 构建搜索 URL
   */
  private async buildSearchUrlWithConfig(source: BookSource, key: string, page: number): Promise<SearchUrlResult> {
    if (!source.legacy.searchUrl) {
      throw new Error('书源未配置搜索 URL');
    }

    let searchUrl = source.legacy.searchUrl;
    const config: UrlConfig = {
      method: 'GET',
      headers: {}
    };

    if (source.networkConfig?.header) {
      try {
        const customHeaders: Record<string, string> = JSON.parse(source.networkConfig.header);
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
    const searchRule = source.rules.searchRule;
    const parseStartTime = Date.now();

    if (!searchRule) {
      Logger.error(this.TAG, `书源未配置搜索规则: ${source.name}`);
      const logParams: BookListExtractionParams = {
        sourceName: source.name,
        sourceId: source.id,
        listRule: '',
        inputHtmlLength: html.length,
        matchedCount: 0,
        extractionStatus: 'failed',
        htmlPreview: html.substring(0, 500),
        errorMessage: '书源未配置搜索规则',
        suggestions: ['在书源配置中添加搜索规则']
      };
      parseDebugLogger.logBookListExtraction(logParams);
      throw new Error('书源未配置搜索规则');
    }

    Logger.debug(this.TAG, `开始解析: ${source.name}, 列表规则: ${searchRule.bookList}`);

    // 1. 获取书籍列表（使用异步解析避免主线程阻塞）
    let bookListHtml = await this.htmlParser.parseAsync(html, searchRule.bookList);

    // 2. 如果规则解析失败，尝试使用 UniversalParser 的智能解析
    if (!bookListHtml || bookListHtml.length === 0) {
      Logger.warn(this.TAG, `规则解析失败，尝试智能解析: ${source.name}`);
      bookListHtml = await this.universalParser.parseBookList(html, searchRule.bookList, {
        tryMultipleStrategies: true
      });
    }

    if (!bookListHtml || bookListHtml.length === 0) {
      Logger.warn(this.TAG, `解析结果为空: ${source.name}, 列表规则: ${searchRule.bookList}`);
      Logger.debug(this.TAG, `HTML前500字符: ${html.substring(0, 500)}`);
      
      const logParams: BookListExtractionParams = {
        sourceName: source.name,
        sourceId: source.id,
        listRule: searchRule.bookList,
        inputHtmlLength: html.length,
        matchedCount: 0,
        extractionStatus: 'failed',
        htmlPreview: html.substring(0, 500),
        suggestions: this.generateBookListSuggestions(searchRule.bookList, html)
      };
      parseDebugLogger.logBookListExtraction(logParams);
      
      return books;
    }

    Logger.info(this.TAG, `解析到 ${bookListHtml.length} 个书籍块: ${source.name}`);

    const successLogParams: BookListExtractionParams = {
      sourceName: source.name,
      sourceId: source.id,
      listRule: searchRule.bookList,
      inputHtmlLength: html.length,
      matchedCount: bookListHtml.length,
      extractionStatus: 'success',
      htmlPreview: html.substring(0, 500)
    };
    parseDebugLogger.logBookListExtraction(successLogParams);

    // 2. 限制每批次解析的书籍数量，避免一次性处理过多
    const MAX_BOOKS_PER_BATCH = 5;
    const totalBooks = Math.min(bookListHtml.length, this.config.maxResultsPerSource);
    let failedCount = 0;

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
        } else {
          failedCount++;
        }
      }

      // 每批次处理后让出主线程，避免阻塞
      if (i + MAX_BOOKS_PER_BATCH < totalBooks) {
        await new Promise<void>(resolve => setTimeout(resolve, 0));
      }
    }

    const parseTime = Date.now() - parseStartTime;
    Logger.info(this.TAG, `解析完成: ${source.name}, 成功 ${books.length}/${totalBooks} 本, 耗时 ${parseTime}ms`);
    
    const parseResultInfo: ParseResultInfo = {
      bookListFound: true,
      bookCount: totalBooks,
      successfulBooks: books.length,
      failedBooks: failedCount
    };
    
    const searchLogParams: SearchDebugParams = {
      sourceName: source.name,
      sourceId: source.id,
      searchUrl: source.legacy.searchUrl || source.url,
      keyword: key,
      responseStatus: 200,
      responseTime: parseTime,
      responseLength: html.length,
      responsePreview: html.substring(0, 500),
      parseResult: parseResultInfo,
      errors: [],
      warnings: failedCount > 0 ? [`${failedCount}本书籍解析失败，可能是字段规则不匹配`] : []
    };
    parseDebugLogger.logSearchDebug(searchLogParams);
    
    return books;
  }

  private generateBookListSuggestions(rule: string, html: string): string[] {
    const suggestions: string[] = [];
    
    if (rule.includes('class.')) {
      suggestions.push('检查CSS类名是否正确，网站可能已更改类名');
    }
    if (rule.startsWith('//')) {
      suggestions.push('XPath规则可能需要调整，建议使用CSS选择器替代');
    }
    if (html.includes('captcha') || html.includes('验证')) {
      suggestions.push('页面可能包含验证码或反爬虫机制');
    }
    if (html.includes('__NEXT_DATA__') || html.includes('window.__')) {
      suggestions.push('页面使用动态加载，内容可能需要JavaScript执行');
    }
    if (html.length < 1000) {
      suggestions.push('响应内容过短，可能未正确获取页面');
    }
    
    if (suggestions.length === 0) {
      suggestions.push('检查规则语法是否正确');
      suggestions.push('查看原始HTML分析页面结构');
      suggestions.push('网站可能已改版，需要更新规则');
    }
    
    return suggestions;
  }

  /**
   * 解析单本书籍
   */
  private async parseSingleBook(
    source: BookSource,
    html: string,
    searchKey: string
  ): Promise<Book | null> {
    const searchRule = source.rules.searchRule;
    const bookParseStartTime = Date.now();

    // 提取书名 - 首先尝试规则，失败时使用智能解析
    let nameResult = await this.extractFieldWithDebug(html, searchRule.name, source, 'name');
    if (!nameResult.value) {
      const smartName = await this.universalParser.parseBookName(html, searchRule.name);
      if (smartName) {
        nameResult = { value: smartName, ruleType: 'css' };
      }
    }
    if (!nameResult.value) {
      Logger.debug(this.TAG, `书名提取失败: 书源=${source.name}, 规则=${searchRule.name}, HTML片段=${html.substring(0, 200)}`);
      return null;
    }

    // 提取作者 - 首先尝试规则，失败时使用智能解析
    let authorResult = await this.extractFieldWithDebug(html, searchRule.author, source, 'author');
    if (!authorResult.value) {
      const smartAuthor = await this.universalParser.parseAuthor(html, searchRule.author);
      if (smartAuthor) {
        authorResult = { value: smartAuthor, ruleType: 'css' };
      }
    }
    Logger.debug(this.TAG, `字段提取: 书源=${source.name}, 书名=${nameResult.value}, 作者=${authorResult.value || '空'}, 作者规则=${searchRule.author}`);

    // 提取封面 - 首先尝试规则，失败时使用智能解析
    let coverResult = await this.extractFieldWithDebug(html, searchRule.cover || '', source, 'cover');
    if (!coverResult.value) {
      const smartCover = await this.universalParser.parseCover(html, searchRule.cover || '');
      if (smartCover) {
        coverResult = { value: smartCover, ruleType: 'css' };
      }
    }
    let cover = coverResult.value;
    if (cover && !cover.startsWith('http')) {
      cover = this.resolveUrl(source.url, cover);
    }

    // 提取简介
    const introResult = await this.extractFieldWithDebug(html, searchRule.intro || '', source, 'intro');

    // 提取书籍 URL
    const bookUrlResult = await this.extractFieldWithDebug(html, searchRule.bookUrl, source, 'bookUrl');
    let bookUrl = bookUrlResult.value;
    if (bookUrl && !bookUrl.startsWith('http')) {
      bookUrl = this.resolveUrl(source.url, bookUrl);
    }
    Logger.debug(this.TAG, `字段提取: 书源=${source.name}, 书籍URL=${bookUrl || '空'}, URL规则=${searchRule.bookUrl}`);

    const parseTime = Date.now() - bookParseStartTime;
    
    const book: Book = {
      id: '',
      name: this.cleanText(nameResult.value),
      author: this.cleanText(authorResult.value) || '未知作者',
      cover: cover || undefined,
      intro: introResult.value || undefined,
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
   * 带调试日志的字段提取
   */
  private async extractFieldWithDebug(
    html: string, 
    rule: string, 
    source: BookSource, 
    fieldName: string
  ): Promise<FieldExtractionResult> {
    const startTime = Date.now();
    const ruleType = this.detectRuleType(rule);
    
    if (!rule) {
      const logParams: FieldExtractionParams = {
        sourceName: source.name,
        sourceId: source.id,
        fieldName,
        rule: '',
        ruleType,
        inputHtml: html.substring(0, 200),
        inputHtmlLength: html.length,
        extractedValue: '',
        extractionStatus: 'empty',
        processingTime: Date.now() - startTime,
        suggestions: ['字段规则为空，请配置提取规则']
      };
      parseDebugLogger.logFieldExtraction(logParams);
      const result: FieldExtractionResult = { value: '', ruleType };
      return result;
    }

    try {
      let value = '';

      // 处理 JS 规则
      if (rule.startsWith('@js:') || rule.includes('<js>')) {
        value = await this.jsEngine.executeRule(html, rule, source.url);
      } else {
        // 先检查缓存
        const cached = parseCache.get(html, rule);
        if (cached && cached.length > 0) {
          value = this.extractTextFromElement(cached[0]);
        } else {
          // 解析规则中的 @ 后缀（如 "a@href" 表示提取 href 属性）
          const parsedRule = this.parseRuleWithAttribute(rule);
          
          // 使用异步 CSS 选择器解析器提取文本内容
          value = await this.asyncCssSelectorParser.extractValue(html, parsedRule.selector, parsedRule.attribute);

          // 缓存解析结果
          if (value) {
            const elements = await this.asyncCssSelectorParser.selectElements(html, parsedRule.selector);
            if (elements.length > 0) {
              parseCache.set(html, rule, elements);
            }
          }
        }
      }

      const processingTime = Date.now() - startTime;
      const status = value && value.trim().length > 0 ? 'success' : 'empty';

      const logParams: FieldExtractionParams = {
        sourceName: source.name,
        sourceId: source.id,
        fieldName,
        rule,
        ruleType,
        inputHtml: html.substring(0, 200),
        inputHtmlLength: html.length,
        extractedValue: value,
        extractionStatus: status,
        processingTime,
        matchedElements: value ? 1 : 0,
        suggestions: status === 'empty' ? this.generateFieldSuggestions(fieldName, rule, html) : []
      };
      parseDebugLogger.logFieldExtraction(logParams);

      const result: FieldExtractionResult = { value: value || '', ruleType };
      return result;

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      const processingTime = Date.now() - startTime;

      const logParams: FieldExtractionParams = {
        sourceName: source.name,
        sourceId: source.id,
        fieldName,
        rule,
        ruleType,
        inputHtml: html.substring(0, 200),
        inputHtmlLength: html.length,
        extractedValue: '',
        extractionStatus: 'error',
        processingTime,
        errorMessage: errorMsg,
        suggestions: ['检查规则语法是否正确', '查看错误详情定位问题']
      };
      parseDebugLogger.logFieldExtraction(logParams);

      Logger.warn(this.TAG, `字段提取异常: ${fieldName}, 书源=${source.name}, 规则=${rule}, 错误=${errorMsg}`);
      const result: FieldExtractionResult = { value: '', ruleType };
      return result;
    }
  }

  /**
   * 解析规则中的 @ 后缀（如 "a@href" 表示提取 href 属性）
   * 返回分离后的选择器和属性名
   */
  private parseRuleWithAttribute(rule: string): RuleParseResult {
    if (!rule) {
      const emptyResult: RuleParseResult = { selector: '' };
      return emptyResult;
    }

    // 处理 @text 伪属性（表示提取文本内容，实际上不需要属性）
    if (rule.endsWith('@text')) {
      const textResult: RuleParseResult = { selector: rule.substring(0, rule.length - 5) };
      return textResult;
    }

    // 查找最后一个 @ 符号（用于属性提取）
    // 需要排除 @css:、@js:、@xpath: 等前缀和 class.、tag.、id. 中的 @
    const lastAtIndex = rule.lastIndexOf('@');
    if (lastAtIndex > 0) {
      const afterAt = rule.substring(lastAtIndex + 1);
      // 检查 @ 后面是否是合法的属性名（字母、数字、下划线、连字符）
      if (/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(afterAt)) {
        // 排除一些特殊情况
        const beforeAt = rule.substring(0, lastAtIndex);
        // 确保不是 @css:、@js: 等前缀
        if (!beforeAt.endsWith('@css') && !beforeAt.endsWith('@js') && !beforeAt.endsWith('@xpath')) {
          const attrResult: RuleParseResult = { selector: beforeAt, attribute: afterAt };
          return attrResult;
        }
      }
    }

    const defaultResult: RuleParseResult = { selector: rule };
    return defaultResult;
  }

  /**
   * 检测规则类型
   */
  private detectRuleType(rule: string): 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js' {
    if (rule.startsWith('@js:') || rule.includes('<js>')) return 'js';
    if (rule.startsWith('//') || rule.startsWith('./')) return 'xpath';
    if (rule.startsWith('$.') || rule.startsWith('$[')) return 'jsonpath';
    if (rule.startsWith('/') || rule.startsWith('##')) return 'regex';
    return 'css';
  }

  /**
   * 生成字段提取建议
   */
  private generateFieldSuggestions(fieldName: string, rule: string, html: string): string[] {
    const suggestions: string[] = [];

    if (rule.includes('@')) {
      const attrMatch = rule.match(/@(\w+)$/);
      if (attrMatch) {
        suggestions.push(`检查属性 ${attrMatch[1]} 是否存在于目标元素中`);
      }
    }

    if (rule.includes('class.')) {
      suggestions.push('检查CSS类名是否正确，网站可能已更改类名');
    }

    if (rule.startsWith('//')) {
      suggestions.push('XPath规则可能需要调整，建议使用CSS选择器替代');
    }

    if (fieldName === 'name') {
      suggestions.push('书名是必填字段，请确保规则正确');
    }

    if (html.length < 100) {
      suggestions.push('HTML内容过短，可能未正确获取页面');
    }

    if (suggestions.length === 0) {
      suggestions.push('检查规则语法是否正确');
      suggestions.push('查看原始HTML分析页面结构');
    }

    return suggestions;
  }

  /**
   * 提取字段（保留原方法以兼容）
   */
  private async extractField(html: string, rule: string, source: BookSource): Promise<string> {
    const result = await this.extractFieldWithDebug(html, rule, source, 'unknown');
    return result.value;
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
   * 聚合搜索结果（去重）
   */
  aggregateResults(results: ISearchResult[]): Book[] {
    const allBooks: Book[] = [];
    const seen = new Set<string>();

    for (let i = 0; i < results.length; i++) {
      const result = results[i];
      if (!result.success) continue;

      const books = result.books;
      for (let j = 0; j < books.length; j++) {
        const book = books[j];
        // 使用书名+作者作为唯一标识
        const key = `${book.name}_${book.author}`;

        if (!seen.has(key)) {
          seen.add(key);
          allBooks.push(book);
        }
      }
    }

    return allBooks;
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
  }
}

export default BookSourceSearchEngine.getInstance();