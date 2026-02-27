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
import { EnhancedSourceHealthManager } from '../EnhancedSourceHealthManager';
import { parseDebugLogger, ParseErrorInfo, ParseResultInfo, FieldExtractionParams, BookListExtractionParams, SearchDebugParams } from '../performance/ParseDebugLogger';
import { searchCache } from './SearchCache';
import { SearchResultValidator } from './SearchResultValidator';
import { SearchQueryParser } from './SearchQueryParser';
import { UniversalParser } from '../parser/UniversalParser';
import { networkDiagnostics, NetworkStatus } from '../NetworkDiagnostics';
import { errorHandlingService, ErrorType, ErrorSeverity, DegradationStrategy, ErrorContext } from '../ErrorHandlingService';

// 为了保持向后兼容，重新导出接口
export { ISearchResult as SearchResult, ISearchOptions as SearchOptions, SearchProgressCallback, BookFoundCallback };

// ==================== 验证相关接口定义 ====================

/**
 * 验证结果接口
 */
interface ValidationResult {
  valid: boolean;
  error?: string;
}

/**
 * 验证错误类
 */
class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * 验证选项接口 - 输入验证
 */
interface InputValidationOptions {
  validateSearchRule?: boolean;
  minKeywordLength?: number;
  maxKeywordLength?: number;
}

/**
 * 验证选项接口 - HTML内容验证
 */
interface HtmlValidationOptions {
  maxSize?: number; // 最大大小限制（字节），默认10MB
  allowEmpty?: boolean; // 是否允许空内容
  checkEncoding?: boolean; // 是否检查编码问题
}

/**
 * 验证选项接口 - 规则验证
 */
interface RuleValidationOptions {
  allowEmpty?: boolean;
  checkSyntax?: boolean;
}

// ==================== 原有接口定义 ====================

interface UrlConfig {
  method: 'GET' | 'POST';
  body?: string;
  headers: Record<string, string>;
}

/**
 * 扩展的搜索规则接口，包含可选字段
 */
interface ExtendedSearchRule {
  bookList: string;
  name: string;
  author: string;
  cover: string | undefined;
  intro: string | undefined;
  bookUrl: string;
  nextUrl: string | undefined;
  checkKeyWord?: string;
  latestChapter?: string;
  wordCount?: string;
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
  private healthManager: EnhancedSourceHealthManager;
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
    this.healthManager = EnhancedSourceHealthManager.getInstance();
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

    const networkStatus = await networkDiagnostics.quickNetworkCheck();
    if (!networkStatus) {
      Logger.warn(this.TAG, '网络未连接，搜索终止');
      const emptyConfig: SearchPaginationConfig = {
        pageSize: pageSize,
        maxResultsPerSource: maxPerSource,
        maxTotalResults: 0,
        enableDeduplication: true,
        sortByRelevance: true
      };
      const emptyBuilder = new SearchResultBuilder(emptyConfig);
      return emptyBuilder.build(displayPage);
    }

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
      if (!this.healthManager.isSourceEnabled(s.id)) {
        Logger.debug(this.TAG, `跳过已禁用的书源: ${s.name}`);
        return false;
      }
      return true;
    });

    const sortedSources = enabledSources.sort((a: BookSource, b: BookSource) => {
      const scoreA = this.healthManager.getSourceScore(a.id);
      const scoreB = this.healthManager.getSourceScore(b.id);
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
            // 即使 shouldStop 为 true，也要处理已完成请求的结果
            // 智能停止只应阻止发起新请求，不应丢弃已完成的结果

            const newBooks = resultBuilder.addSourceResult(
              source.id,
              source.name,
              result.books,
              result.success,
              result.error,
              result.responseTime
            );
            
            if (result.success) {
              this.healthManager.recordSuccess(source.id, source.name, source.url, result.responseTime);
            } else {
              const networkError = this.parseNetworkError(result.error || '');
              this.healthManager.recordFailure(source.id, source.name, source.url, networkError.type, networkError.message);
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
            // 即使 shouldStop 为 true，也要记录失败结果
            // 智能停止只应阻止发起新请求，不应丢弃已完成的结果

            Logger.error(this.TAG, `搜索失败: ${source.name}, ${error}`);
            
            const networkError = this.parseNetworkError(error.message);
            this.healthManager.recordFailure(source.id, source.name, source.url, networkError.type, networkError.message);
            
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

      const errorContext: ErrorContext = {
        sourceId: source.id,
        sourceName: source.name,
        operation: 'search',
        retryCount: 0,
        maxRetries: 3
      };
      const degradationResult = await errorHandlingService.handleError(
        error instanceof Error ? error : new Error(errorMsg),
        errorContext
      );
      Logger.debug(this.TAG, `错误降级策略: ${degradationResult.strategy}, 消息: ${degradationResult.message}`);

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
   * 改进的编码处理：保留中文字符，只编码特殊字符，空格转为+号
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
      // 验证JS返回的URL格式
      const validatedUrl = this.validateAndFixUrl(result);
      return { url: validatedUrl, config };
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

    // 使用改进的编码方式处理搜索关键词
    const encodedKey = this.encodeSearchKeyword(key);
    const pageStr = String(page);

    searchUrl = searchUrl
      .replace(/\{\{key\}\}/g, encodedKey)
      .replace(/\{\{page\}\}/g, pageStr)
      .replace(/\{key\}/g, encodedKey)
      .replace(/\{page\}/g, pageStr)
      .replace(/<key>/g, encodedKey)
      .replace(/<page>/g, pageStr)
      .replace(/\$key\$/g, encodedKey)
      .replace(/\$page\$/g, pageStr);

    if (config.body) {
      // POST body使用application/x-www-form-urlencoded编码
      const bodyEncodedKey = this.encodeFormData(key);
      config.body = config.body
        .replace(/\{\{key\}\}/g, bodyEncodedKey)
        .replace(/\{\{page\}\}/g, pageStr)
        .replace(/\{key\}/g, bodyEncodedKey)
        .replace(/\{page\}/g, pageStr)
        .replace(/<key>/g, bodyEncodedKey)
        .replace(/<page>/g, pageStr)
        .replace(/\$key\$/g, bodyEncodedKey)
        .replace(/\$page\$/g, pageStr);
      Logger.debug(this.TAG, `POST请求体: ${config.body}`);
    }

    if (!searchUrl.startsWith('http')) {
      searchUrl = this.resolveUrl(source.url, searchUrl);
    }

    // 最终URL格式验证
    const validatedUrl = this.validateAndFixUrl(searchUrl);

    return { url: validatedUrl, config };
  }

  /**
   * 编码搜索关键词 - 用于URL路径或查询参数
   * 保留中文字符，只编码特殊字符，空格转为+号
   */
  private encodeSearchKeyword(keyword: string): string {
    if (!keyword) {
      return '';
    }

    try {
      // 先进行标准encodeURIComponent编码
      let encoded = encodeURIComponent(keyword);

      // 解码中文字符（Unicode范围：\u4e00-\u9fa5）
      // 同时保留已编码的特殊字符
      encoded = encoded.replace(/%([0-9A-Fa-f]{2})/g, (match: string, hex: string): string => {
        const code = parseInt(hex, 16);
        // 中文字符范围：0x4E00-0x9FA5 (CJK统一汉字)
        // 中文标点：0x3000-0x303F
        // 全角字符：0xFF00-0xFFEF
        if ((code >= 0x4E00 && code <= 0x9FA5) ||
            (code >= 0x3000 && code <= 0x303F) ||
            (code >= 0xFF00 && code <= 0xFFEF) ||
            (code >= 0x3400 && code <= 0x4DBF) || // CJK扩展A
            (code >= 0x20000 && code <= 0x2A6DF)) { // CJK扩展B
          return String.fromCharCode(code);
        }
        // 空格转为+号
        if (code === 0x20) {
          return '+';
        }
        return match; // 保持其他字符编码
      });

      return encoded;
    } catch (error) {
      Logger.warn(this.TAG, `编码搜索关键词失败: ${error}，使用原始值`);
      // 失败时进行简单替换
      return keyword.replace(/ /g, '+');
    }
  }

  /**
   * 编码表单数据 - 用于POST body (application/x-www-form-urlencoded)
   * 保留中文字符，空格转为+号，特殊字符编码
   */
  private encodeFormData(value: string): string {
    if (!value) {
      return '';
    }

    try {
      // 对于表单数据，使用类似的编码策略
      let encoded = encodeURIComponent(value);

      // 解码中文字符
      encoded = encoded.replace(/%([0-9A-Fa-f]{2})/g, (match: string, hex: string): string => {
        const code = parseInt(hex, 16);
        // 中文字符和常见Unicode字符
        if ((code >= 0x4E00 && code <= 0x9FA5) ||
            (code >= 0x3000 && code <= 0x303F) ||
            (code >= 0xFF00 && code <= 0xFFEF) ||
            (code >= 0x3400 && code <= 0x4DBF) ||
            (code >= 0x20000 && code <= 0x2A6DF)) {
          return String.fromCharCode(code);
        }
        // 空格转为+号
        if (code === 0x20) {
          return '+';
        }
        return match;
      });

      return encoded;
    } catch (error) {
      Logger.warn(this.TAG, `编码表单数据失败: ${error}，使用原始值`);
      return value.replace(/ /g, '+');
    }
  }

  /**
   * 验证并修复URL格式
   */
  private validateAndFixUrl(url: string): string {
    if (!url) {
      return url;
    }

    try {
      // 检查URL基本格式
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        Logger.warn(this.TAG, `URL缺少协议头: ${url.substring(0, 50)}...`);
        // 尝试修复：添加https://
        url = 'https://' + url;
      }

      // 检查并修复URL中的常见问题
      // 1. 多个连续的斜杠（保留协议后的//）
      url = url.replace(/(https?:\/\/)(\/)+/g, '$1');

      // 2. 检查URL长度
      if (url.length > 8192) {
        Logger.warn(this.TAG, `URL过长(${url.length}字符)，可能导致请求失败`);
      }

      // 3. 验证URL是否可以被解析
      const urlPattern = /^https?:\/\/[^\s<>"{}|\\^`\[\]]+$/;
      if (!urlPattern.test(url)) {
        Logger.warn(this.TAG, `URL包含非法字符: ${url.substring(0, 100)}...`);
        // 尝试清理URL中的非法字符
        url = url.replace(/[\s<>"{}|\\^`\[\]]/g, '');
      }

      return url;
    } catch (error) {
      Logger.error(this.TAG, `URL验证失败: ${error}`);
      return url;
    }
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
   * 获取通用选择器 - 用于降级解析
   */
  private getGenericSelectors(fieldName: string): string[] {
    const selectors: Map<string, string[]> = new Map([
      ['name', [
        'h1 a', 'h2 a', 'h3 a', 'h4 a',
        '.title a', '.book-name a', '.name a',
        'h1', 'h2', 'h3', 'h4',
        '.title', '.book-name', '.name', '.book-title',
        '[class*="title"] a', '[class*="name"] a',
        'a[href*="book"]', 'a[href*="novel"]',
        '.book-item a', '.search-item a', '.list-item a'
      ]],
      ['author', [
        '.author', '.writer', '.pen-name',
        '[class*="author"]', '[class*="writer"]',
        '.book-author', '.book-writer',
        'span[class*="author"]', 'em[class*="author"]',
        '.info .author', '.meta .author'
      ]],
      ['cover', [
        'img[src*="cover"]', 'img[class*="cover"]',
        'img[class*="book"]', '.book-img img',
        '.cover img', 'img:first-child',
        'img[data-src]', 'img[src*="img"]'
      ]],
      ['intro', [
        '.intro', '.summary', '.description', '.brief',
        '[class*="intro"]', '[class*="summary"]', '[class*="desc"]',
        '.book-intro', '.book-summary', '.content-intro',
        'p[class*="intro"]', 'div[class*="intro"]'
      ]],
      ['bookUrl', [
        'a[href*="book"]', 'a[href*="novel"]', 'a[href*="read"]',
        'h1 a', 'h2 a', 'h3 a', '.title a',
        'a:first-child', '.book-item a', '.search-item a'
      ]],
      ['latestChapter', [
        '.latest', '.last-chapter', '.new-chapter',
        '[class*="latest"]', '[class*="last"]',
        '.update', '.recent', '.newest'
      ]],
      ['wordCount', [
        '.word-count', '.words', '.length',
        '[class*="word"]', '[class*="count"]',
        '.size', '.total', '.words-num'
      ]]
    ]);
    return selectors.get(fieldName) || [];
  }

  /**
   * 使用正则表达式提取标题
   */
  private extractTitleByRegex(html: string): string {
    // 常见的标题模式
    const patterns: RegExp[] = [
      /<h[1-6][^>]*>(?:<[^>]+>)*([^<]+)(?:<\/[^>]+>)*<\/h[1-6]>/i,
      /<a[^>]*href=["'][^"']*(?:book|novel|read)[^"']*["'][^>]*>(?:<[^>]+>)*([^<]+)(?:<\/[^>]+>)*<\/a>/i,
      /<[^>]*class=["'][^"']*(?:title|name)[^"']*["'][^>]*>(?:<[^>]+>)*([^<]+)(?:<\/[^>]+>)*<\/[^>]+>/i,
      /title["']?\s*[:=]\s*["']([^"']+)["']/i,
      /alt=["']([^"']+)["']/i
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const title = this.cleanText(match[1]);
        if (title.length > 0 && title.length < 100) {
          return title;
        }
      }
    }
    return '';
  }

  /**
   * 使用正则表达式提取作者
   */
  private extractAuthorByRegex(html: string): string {
    const patterns: RegExp[] = [
      /作者[：:]\s*<[^>]*>([^<]+)</i,
      /writer[="']?\s*[:=]\s*["']([^"']+)["']/i,
      /author[="']?\s*[:=]\s*["']([^"']+)["']/i,
      /<[^>]*class=["'][^"']*author[^"']*["'][^>]*>([^<]+)</i,
      /(?:作者|writer|author)[:\s]+([^<\n]{2,20})/i
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const author = this.cleanText(match[1]);
        if (author.length > 0 && author.length < 50) {
          return author;
        }
      }
    }
    return '';
  }

  /**
   * 使用正则表达式提取封面
   */
  private extractCoverByRegex(html: string, baseUrl: string): string {
    const patterns: RegExp[] = [
      /<img[^>]*src=["']([^"']*(?:cover|book)[^"']*)["'][^>]*>/i,
      /<img[^>]*data-src=["']([^"']+)["'][^>]*>/i,
      /<img[^>]*src=["']([^"']+\.(?:jpg|jpeg|png|webp))["'][^>]*>/i
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        let cover = match[1].trim();
        if (cover && !cover.startsWith('http')) {
          cover = this.resolveUrl(baseUrl, cover);
        }
        return cover;
      }
    }
    return '';
  }

  /**
   * 使用正则表达式提取URL
   */
  private extractUrlByRegex(html: string, baseUrl: string): string {
    const patterns: RegExp[] = [
      /<a[^>]*href=["']([^"']*(?:book|novel|read)[^"']*)["'][^>]*>/i,
      /<a[^>]*href=["']([^"']+)["'][^>]*class=["'][^"']*(?:title|name|book)[^"']*["'][^>]*>/i,
      /<h[1-6][^>]*>\s*<a[^>]*href=["']([^"']+)["'][^>]*>/i
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        let url = match[1].trim();
        if (url && !url.startsWith('http')) {
          url = this.resolveUrl(baseUrl, url);
        }
        return url;
      }
    }
    return '';
  }

  /**
   * 带降级的字段提取 - 三级降级策略
   * 1. 书源规则 -> 2. 通用选择器 -> 3. 正则提取
   */
  private async extractFieldWithFallback(
    html: string,
    rule: string,
    source: BookSource,
    fieldName: string
  ): Promise<FieldExtractionResult> {
    const startTime = Date.now();

    // 第一级：尝试书源规则
    let result = await this.extractFieldWithDebug(html, rule, source, fieldName);
    if (result.value && result.value.trim().length > 0) {
      Logger.debug(this.TAG, `字段提取成功[规则]: ${fieldName}=${result.value.substring(0, 50)}`);
      return result;
    }

    // 第二级：尝试通用选择器
    Logger.debug(this.TAG, `规则提取失败，尝试通用选择器: ${fieldName}, 书源=${source.name}`);
    const genericSelectors = this.getGenericSelectors(fieldName);

    for (const selector of genericSelectors) {
      try {
        const elements = await this.asyncCssSelectorParser.selectElements(html, selector);
        if (elements.length > 0) {
          const value = this.extractTextFromElement(elements[0]);
          if (value && value.trim().length > 0) {
            Logger.debug(this.TAG, `字段提取成功[通用选择器]: ${fieldName}=${value.substring(0, 50)}, selector=${selector}`);
            return { value: value.trim(), ruleType: 'css' };
          }
        }
      } catch (e) {
        // 继续尝试下一个选择器
        continue;
      }
    }

    // 第三级：尝试正则提取
    Logger.debug(this.TAG, `通用选择器失败，尝试正则提取: ${fieldName}, 书源=${source.name}`);
    let regexValue = '';
    switch (fieldName) {
      case 'name':
        regexValue = this.extractTitleByRegex(html);
        break;
      case 'author':
        regexValue = this.extractAuthorByRegex(html);
        break;
      case 'cover':
        regexValue = this.extractCoverByRegex(html, source.url);
        break;
      case 'bookUrl':
        regexValue = this.extractUrlByRegex(html, source.url);
        break;
    }

    if (regexValue && regexValue.trim().length > 0) {
      Logger.debug(this.TAG, `字段提取成功[正则]: ${fieldName}=${regexValue.substring(0, 50)}`);
      return { value: regexValue.trim(), ruleType: 'regex' };
    }

    // 最后尝试 UniversalParser
    if (!regexValue) {
      try {
        let smartValue = '';
        switch (fieldName) {
          case 'name':
            smartValue = await this.universalParser.parseBookName(html, rule);
            break;
          case 'author':
            smartValue = await this.universalParser.parseAuthor(html, rule);
            break;
          case 'cover':
            smartValue = await this.universalParser.parseCover(html, rule);
            break;
        }
        if (smartValue && smartValue.trim().length > 0) {
          Logger.debug(this.TAG, `字段提取成功[智能解析]: ${fieldName}=${smartValue.substring(0, 50)}`);
          return { value: smartValue.trim(), ruleType: 'css' };
        }
      } catch (e) {
        // 智能解析失败，继续
      }
    }

    Logger.debug(this.TAG, `字段提取失败[全部降级策略]: ${fieldName}, 耗时=${Date.now() - startTime}ms`);
    return { value: '', ruleType: 'css' };
  }

  /**
   * 解析单本书籍 - 带多级降级策略
   */
  private async parseSingleBook(
    source: BookSource,
    html: string,
    searchKey: string
  ): Promise<Book | null> {
    const searchRule = source.rules.searchRule;
    const bookParseStartTime = Date.now();

    // 提取书名 - 使用降级策略
    const nameResult = await this.extractFieldWithFallback(html, searchRule.name, source, 'name');
    if (!nameResult.value) {
      Logger.debug(this.TAG, `书名提取失败(所有降级策略): 书源=${source.name}, HTML片段=${html.substring(0, 200)}`);
      return null;
    }

    // 提取作者 - 使用降级策略
    const authorResult = await this.extractFieldWithFallback(html, searchRule.author, source, 'author');
    Logger.debug(this.TAG, `字段提取: 书源=${source.name}, 书名=${nameResult.value}, 作者=${authorResult.value || '空'}`);

    // 提取封面 - 使用降级策略
    const coverResult = await this.extractFieldWithFallback(html, searchRule.cover || '', source, 'cover');
    let cover = coverResult.value;
    if (cover && !cover.startsWith('http')) {
      cover = this.resolveUrl(source.url, cover);
    }

    // 提取简介 - 使用降级策略
    const introResult = await this.extractFieldWithFallback(html, searchRule.intro || '', source, 'intro');

    // 提取书籍 URL - 使用降级策略
    const bookUrlResult = await this.extractFieldWithFallback(html, searchRule.bookUrl, source, 'bookUrl');
    let bookUrl = bookUrlResult.value;
    if (bookUrl && !bookUrl.startsWith('http')) {
      bookUrl = this.resolveUrl(source.url, bookUrl);
    }
    Logger.debug(this.TAG, `字段提取: 书源=${source.name}, 书籍URL=${bookUrl || '空'}`);

    // 提取最新章节 - 使用降级策略
    // 从 searchRule 中获取 latestChapter 规则，如果不存在则使用空字符串
    const extendedRule = searchRule as ExtendedSearchRule;
    const latestChapterRule = extendedRule.latestChapter || '';
    const latestChapterResult = await this.extractFieldWithFallback(
      html,
      latestChapterRule,
      source,
      'latestChapter'
    );

    // 提取字数 - 使用降级策略
    // 从 searchRule 中获取 wordCount 规则，如果不存在则使用空字符串
    const wordCountRule = extendedRule.wordCount || '';
    const wordCountResult = await this.extractFieldWithFallback(
      html,
      wordCountRule,
      source,
      'wordCount'
    );

    const parseTime = Date.now() - bookParseStartTime;
    Logger.debug(this.TAG, `书籍解析完成: ${nameResult.value}, 耗时=${parseTime}ms, 降级策略使用情况: name=${nameResult.ruleType}, author=${authorResult.ruleType}, cover=${coverResult.ruleType}`);

    // 解析字数字符串为数字
    let wordCountNum: number | undefined = undefined;
    if (wordCountResult.value) {
      // 提取数字部分
      const numMatch = wordCountResult.value.match(/[\d,.]+/);
      if (numMatch) {
        const numStr = numMatch[0].replace(/,/g, '');
        wordCountNum = parseInt(numStr, 10);
        if (isNaN(wordCountNum)) {
          wordCountNum = undefined;
        }
      }
    }

    // 清理书名和作者，移除可能的模板代码
    const cleanName = this.cleanText(nameResult.value);
    const cleanAuthor = this.cleanText(authorResult.value) || '未知作者';

    // 过滤掉包含模板代码的无效结果
    if (this.containsTemplateCode(cleanName) || this.containsTemplateCode(cleanAuthor)) {
      Logger.warn(this.TAG, `过滤掉包含模板代码的搜索结果: 书源=${source.name}, 书名=${cleanName}, 作者=${cleanAuthor}`);
      return null;
    }

    const book: Book = {
      id: '',
      name: cleanName,
      author: cleanAuthor,
      cover: cover || undefined,
      intro: introResult.value || undefined,
      kind: undefined,
      wordCount: wordCountNum,
      latestChapter: latestChapterResult.value || undefined,
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
   * 生成轻量级缓存键 - 使用哈希避免内存问题
   * 对大文档只取前1000字符进行哈希
   */
  private generateCacheKey(html: string, rule: string): string {
    // 对大文档只取前1000字符，避免内存问题
    const maxLength = 1000;
    const content = html.length > maxLength ? html.substring(0, maxLength) : html;
    const hash = this.simpleHash(content);
    return `${hash}_${rule}`;
  }

  /**
   * 简单的字符串哈希函数 - 生成轻量级哈希值
   */
  private simpleHash(str: string): number {
    let hash = 0;
    if (str.length === 0) {
      return hash;
    }
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    return Math.abs(hash);
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
        // 生成轻量级缓存键
        const cacheKey = this.generateCacheKey(html, rule);
        // 先检查缓存
        const cached = parseCache.getByKey(cacheKey);
        if (cached && cached.length > 0) {
          value = this.extractTextFromElement(cached[0]);
        } else {
          // 解析规则中的 @ 后缀（如 "a@href" 表示提取 href 属性）
          const parsedRule = this.parseRuleWithAttribute(rule);

          // 使用异步 CSS 选择器解析器提取文本内容
          value = await this.asyncCssSelectorParser.extractValue(html, parsedRule.selector, parsedRule.attribute);

          // 缓存解析结果 - 使用轻量级缓存键
          if (value) {
            const elements = await this.asyncCssSelectorParser.selectElements(html, parsedRule.selector);
            if (elements.length > 0) {
              parseCache.setByKey(cacheKey, elements);
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
   * 
   * 支持的标准格式：
   * - class.name@text / class.name@href / class.name@src
   * - tag.div@text / tag.a@href
   * - id.xxx@text
   * - .class@text / #id@href / tag@text
   * - @css:.class@text
   */
  private parseRuleWithAttribute(rule: string): RuleParseResult {
    if (!rule) {
      return { selector: '' };
    }

    let processedRule = rule.trim();

    // 移除 @css: 前缀
    if (processedRule.startsWith('@css:')) {
      processedRule = processedRule.substring(5).trim();
    }

    // 转换标准格式前缀为标准CSS选择器
    if (processedRule.startsWith('class.')) {
      processedRule = '.' + processedRule.substring(6);
    } else if (processedRule.startsWith('tag.')) {
      processedRule = processedRule.substring(4);
    } else if (processedRule.startsWith('id.')) {
      processedRule = '#' + processedRule.substring(3);
    }

    // 处理 @text 伪属性（表示提取文本内容）
    if (processedRule.endsWith('@text') || processedRule.endsWith('@text()')) {
      const selector = processedRule.replace(/@text\(\)?$/, '');
      return { selector: selector.trim(), attribute: 'text' };
    }

    // 处理 @html 伪属性
    if (processedRule.endsWith('@html') || processedRule.endsWith('@html()')) {
      const selector = processedRule.replace(/@html\(\)?$/, '');
      return { selector: selector.trim(), attribute: 'html' };
    }

    // 查找最后一个 @ 符号（用于属性提取）
    const lastAtIndex = processedRule.lastIndexOf('@');
    if (lastAtIndex > 0) {
      const beforeAt = processedRule.substring(0, lastAtIndex).trim();
      const afterAt = processedRule.substring(lastAtIndex + 1).trim();
      
      // 检查 @ 后面是否是合法的属性名
      if (/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(afterAt)) {
        // 排除规则前缀（不区分大小写）
        const lowerBeforeAt = beforeAt.toLowerCase();
        const invalidPrefixes = ['@css', '@js', '@xpath', '@json', '@regex'];
        const isInvalidPrefix = invalidPrefixes.some(prefix => 
          lowerBeforeAt.endsWith(prefix)
        );
        
        if (!isInvalidPrefix) {
          return { selector: beforeAt, attribute: afterAt };
        }
      }
    }

    // 无属性提取，返回处理后的选择器
    return { selector: processedRule };
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

  // ==================== 输入验证方法 ====================

  /**
   * 统一的输入验证方法
   * 验证书源对象、关键词等输入参数的有效性
   * 
   * @param source - 书源对象
   * @param keyword - 搜索关键词
   * @param options - 可选的验证选项
   * @returns ValidationResult - 验证结果
   */
  validateInput(
    source: BookSource | null | undefined,
    keyword: string | null | undefined,
    options?: InputValidationOptions
  ): ValidationResult {
    // 验证书源对象
    if (!source) {
      return { valid: false, error: '书源对象不能为空' };
    }

    // 验证书源ID
    if (!source.id || source.id.trim().length === 0) {
      return { valid: false, error: '书源ID不能为空' };
    }

    // 验证书源名称
    if (!source.name || source.name.trim().length === 0) {
      return { valid: false, error: '书源名称不能为空' };
    }

    // 验证书源URL
    if (!source.url || source.url.trim().length === 0) {
      return { valid: false, error: '书源URL不能为空' };
    }

    // 验证URL格式
    try {
      const urlPattern = /^https?:\/\/.+/i;
      if (!urlPattern.test(source.url)) {
        return { valid: false, error: `书源URL格式无效: ${source.url}` };
      }
    } catch {
      return { valid: false, error: `书源URL格式验证失败: ${source.url}` };
    }

    // 验证书源是否启用
    if (!source.metadata || !source.metadata.enabled) {
      return { valid: false, error: `书源已禁用: ${source.name}` };
    }

    // 验证搜索关键词
    if (keyword === null || keyword === undefined) {
      return { valid: false, error: '搜索关键词不能为空' };
    }

    const trimmedKeyword = keyword.trim();
    if (trimmedKeyword.length === 0) {
      return { valid: false, error: '搜索关键词不能为空或仅包含空白字符' };
    }

    // 验证关键词长度
    const minLength = options?.minKeywordLength ?? 1;
    const maxLength = options?.maxKeywordLength ?? 100;

    if (trimmedKeyword.length < minLength) {
      return { valid: false, error: `搜索关键词长度不能少于${minLength}个字符` };
    }

    if (trimmedKeyword.length > maxLength) {
      return { valid: false, error: `搜索关键词长度不能超过${maxLength}个字符` };
    }

    // 验证搜索规则（可选）
    if (options?.validateSearchRule !== false) {
      const searchRule = source.rules?.searchRule;
      if (!searchRule) {
        return { valid: false, error: `书源未配置搜索规则: ${source.name}` };
      }

      // 验证必要的搜索规则字段
      if (!searchRule.bookList || searchRule.bookList.trim().length === 0) {
        return { valid: false, error: `书源搜索规则缺少书籍列表规则: ${source.name}` };
      }

      if (!searchRule.name || searchRule.name.trim().length === 0) {
        return { valid: false, error: `书源搜索规则缺少书名规则: ${source.name}` };
      }
    }

    return { valid: true };
  }

  /**
   * HTML内容验证方法
   * 验证HTML内容的有效性和安全性
   * 
   * @param html - HTML内容字符串
   * @param options - 可选的验证选项
   * @returns ValidationResult - 验证结果
   */
  validateHtmlContent(
    html: string | null | undefined,
    options?: HtmlValidationOptions
  ): ValidationResult {
    // 验证HTML内容是否存在
    if (html === null || html === undefined) {
      return { valid: false, error: 'HTML内容不能为空' };
    }

    // 验证HTML内容不为空
    if (html.length === 0) {
      if (options?.allowEmpty) {
        return { valid: true };
      }
      return { valid: false, error: 'HTML内容为空' };
    }

    // 限制HTML内容大小（默认10MB）
    const maxSize = options?.maxSize ?? 10 * 1024 * 1024; // 10MB
    // 使用字符串长度作为大小估算（UTF-16编码，每个字符2字节）
    const htmlSize = html.length * 2; // 估算字节数

    if (htmlSize > maxSize) {
      return {
        valid: false,
        error: `HTML内容大小(${this.formatBytes(htmlSize)})超过限制(${this.formatBytes(maxSize)})`
      };
    }

    // 检查HTML内容是否包含有效的HTML标签
    const hasValidHtmlTags = /<[a-zA-Z][^>]*>/.test(html);
    if (!hasValidHtmlTags) {
      // 如果内容过短，可能是错误响应
      if (html.length < 100) {
        return {
          valid: false,
          error: `HTML内容可能无效（长度:${html.length}），未检测到有效的HTML标签`
        };
      }
    }

    // 检查常见的错误页面标识
    const errorIndicators = [
      '404 not found',
      '403 forbidden',
      '500 internal server error',
      '502 bad gateway',
      '503 service unavailable',
      'access denied',
      'captcha',
      '验证码',
      'access forbidden'
    ];

    const lowerHtml = html.toLowerCase();
    for (const indicator of errorIndicators) {
      if (lowerHtml.includes(indicator)) {
        return {
          valid: false,
          error: `HTML内容可能包含错误页面标识: "${indicator}"`
        };
      }
    }

    // 检查编码问题（可选）
    if (options?.checkEncoding !== false) {
      // 检查是否存在乱码特征
      const garbledPattern = /[\uFFFD\u0000-\u0008\u000B\u000C\u000E-\u001F]/;
      if (garbledPattern.test(html)) {
        return {
          valid: false,
          error: 'HTML内容可能存在编码问题（检测到乱码字符）'
        };
      }
    }

    return { valid: true };
  }

  /**
   * 规则验证方法
   * 验证解析规则的有效性和语法正确性
   * 
   * @param rule - 解析规则字符串
   * @param ruleType - 规则类型（可选，自动检测）
   * @param options - 可选的验证选项
   * @returns ValidationResult - 验证结果
   */
  validateRule(
    rule: string | null | undefined,
    ruleType?: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js',
    options?: RuleValidationOptions
  ): ValidationResult {
    // 验证规则不为空
    if (rule === null || rule === undefined) {
      return { valid: false, error: '规则不能为空' };
    }

    const trimmedRule = rule.trim();

    if (trimmedRule.length === 0) {
      if (options?.allowEmpty) {
        return { valid: true };
      }
      return { valid: false, error: '规则不能为空或仅包含空白字符' };
    }

    // 自动检测规则类型
    const detectedType = ruleType || this.detectRuleType(trimmedRule);

    // 根据规则类型进行特定验证
    if (options?.checkSyntax !== false) {
      const syntaxResult = this.validateRuleSyntax(trimmedRule, detectedType);
      if (!syntaxResult.valid) {
        return syntaxResult;
      }
    }

    // 验证规则长度（防止过长的规则影响性能）
    const maxRuleLength = 5000;
    if (trimmedRule.length > maxRuleLength) {
      return {
        valid: false,
        error: `规则长度(${trimmedRule.length})超过最大限制(${maxRuleLength})`
      };
    }

    return { valid: true };
  }

  /**
   * 验证规则语法
   * 
   * @param rule - 规则字符串
   * @param ruleType - 规则类型
   * @returns ValidationResult - 验证结果
   */
  private validateRuleSyntax(
    rule: string,
    ruleType: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js'
  ): ValidationResult {
    switch (ruleType) {
      case 'css':
        return this.validateCssRule(rule);
      case 'xpath':
        return this.validateXPathRule(rule);
      case 'jsonpath':
        return this.validateJsonPathRule(rule);
      case 'regex':
        return this.validateRegexRule(rule);
      case 'js':
        return this.validateJsRule(rule);
      default:
        return { valid: true };
    }
  }

  /**
   * 验证CSS选择器规则
   */
  private validateCssRule(rule: string): ValidationResult {
    // 移除 @css: 前缀
    let processedRule = rule;
    if (processedRule.startsWith('@css:')) {
      processedRule = processedRule.substring(5).trim();
    }

    // 转换标准格式前缀
    if (processedRule.startsWith('class.')) {
      processedRule = '.' + processedRule.substring(6);
    } else if (processedRule.startsWith('tag.')) {
      processedRule = processedRule.substring(4);
    } else if (processedRule.startsWith('id.')) {
      processedRule = '#' + processedRule.substring(3);
    }

    // 处理属性提取后缀
    const atIndex = processedRule.lastIndexOf('@');
    if (atIndex > 0) {
      const beforeAt = processedRule.substring(0, atIndex).trim();
      const afterAt = processedRule.substring(atIndex + 1).trim();

      // 检查是否是合法的属性名
      if (/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(afterAt)) {
        // 排除规则前缀
        const invalidPrefixes = ['@css', '@js', '@xpath', '@json', '@regex'];
        const isInvalidPrefix = invalidPrefixes.some(prefix =>
          beforeAt.toLowerCase().endsWith(prefix)
        );

        if (!isInvalidPrefix) {
          processedRule = beforeAt;
        }
      }
    }

    // 基本CSS选择器验证
    if (processedRule.length === 0) {
      return { valid: false, error: 'CSS选择器不能为空' };
    }

    // 检查不完整的CSS选择器
    if (/[.#\[\(]$/.test(processedRule)) {
      return { valid: false, error: `CSS选择器不完整: "${processedRule}"` };
    }

    // 检查括号匹配
    const openBrackets = (processedRule.match(/\[/g) || []).length;
    const closeBrackets = (processedRule.match(/\]/g) || []).length;
    if (openBrackets !== closeBrackets) {
      return { valid: false, error: `CSS选择器括号不匹配: "${processedRule}"` };
    }

    // 检查圆括号匹配
    const openParens = (processedRule.match(/\(/g) || []).length;
    const closeParens = (processedRule.match(/\)/g) || []).length;
    if (openParens !== closeParens) {
      return { valid: false, error: `CSS选择器圆括号不匹配: "${processedRule}"` };
    }

    return { valid: true };
  }

  /**
   * 验证XPath规则
   */
  private validateXPathRule(rule: string): ValidationResult {
    // 检查XPath基本语法
    if (!rule.startsWith('//') && !rule.startsWith('./')) {
      return { valid: false, error: `XPath规则必须以"//"或"./"开头: "${rule}"` };
    }

    // 检查括号匹配
    const openParens = (rule.match(/\(/g) || []).length;
    const closeParens = (rule.match(/\)/g) || []).length;
    if (openParens !== closeParens) {
      return { valid: false, error: `XPath规则圆括号不匹配: "${rule}"` };
    }

    // 检查方括号匹配
    const openBrackets = (rule.match(/\[/g) || []).length;
    const closeBrackets = (rule.match(/\]/g) || []).length;
    if (openBrackets !== closeBrackets) {
      return { valid: false, error: `XPath规则方括号不匹配: "${rule}"` };
    }

    return { valid: true };
  }

  /**
   * 验证JSONPath规则
   */
  private validateJsonPathRule(rule: string): ValidationResult {
    // 检查JSONPath基本语法
    if (!rule.startsWith('$')) {
      return { valid: false, error: `JSONPath规则必须以"$"开头: "${rule}"` };
    }

    // 检查括号匹配
    const openBrackets = (rule.match(/\[/g) || []).length;
    const closeBrackets = (rule.match(/\]/g) || []).length;
    if (openBrackets !== closeBrackets) {
      return { valid: false, error: `JSONPath规则方括号不匹配: "${rule}"` };
    }

    return { valid: true };
  }

  /**
   * 验证正则表达式规则
   */
  private validateRegexRule(rule: string): ValidationResult {
    try {
      // 尝试编译正则表达式
      new RegExp(rule);
      return { valid: true };
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : '未知错误';
      return { valid: false, error: `正则表达式语法错误: ${errorMsg}` };
    }
  }

  /**
   * 验证JavaScript规则
   */
  private validateJsRule(rule: string): ValidationResult {
    // 检查JS规则标记
    const hasJsMarker = rule.startsWith('@js:') || rule.includes('<js>');

    if (!hasJsMarker) {
      return { valid: false, error: 'JS规则必须以"@js:"开头或包含"<js>"标签' };
    }

    // 提取JS代码
    let jsCode = rule;
    if (jsCode.startsWith('@js:')) {
      jsCode = jsCode.substring(4).trim();
    }
    jsCode = jsCode.replace(/<js>|<\/js>/g, '').trim();

    if (jsCode.length === 0) {
      return { valid: false, error: 'JS规则代码不能为空' };
    }

    // 基本语法检查（检查括号匹配）
    const openBraces = (jsCode.match(/\{/g) || []).length;
    const closeBraces = (jsCode.match(/\}/g) || []).length;
    if (openBraces !== closeBraces) {
      return { valid: false, error: 'JS规则代码花括号不匹配' };
    }

    const openParens = (jsCode.match(/\(/g) || []).length;
    const closeParens = (jsCode.match(/\)/g) || []).length;
    if (openParens !== closeParens) {
      return { valid: false, error: 'JS规则代码圆括号不匹配' };
    }

    return { valid: true };
  }

  /**
   * 格式化字节大小为人类可读格式
   */
  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  /**
   * 验证并抛出异常（便捷方法）
   * 
   * @param source - 书源对象
   * @param keyword - 搜索关键词
   * @param options - 可选的验证选项
   * @throws ValidationError - 验证失败时抛出
   */
  validateInputOrThrow(
    source: BookSource | null | undefined,
    keyword: string | null | undefined,
    options?: InputValidationOptions
  ): void {
    const result = this.validateInput(source, keyword, options);
    if (!result.valid) {
      throw new ValidationError(result.error || '输入验证失败');
    }
  }

  /**
   * 验证HTML内容并抛出异常（便捷方法）
   * 
   * @param html - HTML内容字符串
   * @param options - 可选的验证选项
   * @throws ValidationError - 验证失败时抛出
   */
  validateHtmlContentOrThrow(
    html: string | null | undefined,
    options?: HtmlValidationOptions
  ): void {
    const result = this.validateHtmlContent(html, options);
    if (!result.valid) {
      throw new ValidationError(result.error || 'HTML内容验证失败');
    }
  }

  /**
   * 验证规则并抛出异常（便捷方法）
   * 
   * @param rule - 解析规则字符串
   * @param ruleType - 规则类型（可选）
   * @param options - 可选的验证选项
   * @throws ValidationError - 验证失败时抛出
   */
  validateRuleOrThrow(
    rule: string | null | undefined,
    ruleType?: 'css' | 'xpath' | 'jsonpath' | 'regex' | 'js',
    options?: RuleValidationOptions
  ): void {
    const result = this.validateRule(rule, ruleType, options);
    if (!result.valid) {
      throw new ValidationError(result.error || '规则验证失败');
    }
  }
}

export default BookSourceSearchEngine.getInstance();
