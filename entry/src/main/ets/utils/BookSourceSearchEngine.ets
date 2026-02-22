/**
 * BookSourceSearchEngine - 书源搜索引擎
 * 支持多书源并发搜索、请求频率控制、结果聚合、分页控制
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
import { enhancedSourceHealthManager as sourceHealthManager } from './EnhancedSourceHealthManager';

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

interface ContainerPattern {
  name: string;
  regex: RegExp;
}

export class BookSourceSearchEngine {
  private static instance: BookSourceSearchEngine | null = null;
  private htmlParser: HTMLParser;
  private jsEngine: EnhancedJSEngine;
  private asyncCssSelectorParser: AsyncCssSelectorParser;
  private requestTimestamps: Map<string, number[]> = new Map();
  private pendingTimers: Set<number> = new Set();
  private isCancelled: boolean = false;
  private readonly TAG = 'BookSourceSearchEngine';

  private config: SearchConfig = {
    maxConcurrent: 5,
    requestInterval: 500,
    timeout: 10000,
    maxResultsPerSource: 15
  };

  private paginationConfig: SearchPaginationConfig = DEFAULT_PAGINATION_CONFIG;

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.jsEngine = EnhancedJSEngine.getInstance();
    this.asyncCssSelectorParser = AsyncCssSelectorParser.getInstance();
  }

  static getInstance(): BookSourceSearchEngine {
    if (!BookSourceSearchEngine.instance) {
      BookSourceSearchEngine.instance = new BookSourceSearchEngine();
    }
    return BookSourceSearchEngine.instance;
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
    const THROTTLE_MS = 200;

    const throttledProgressCallback = progressCallback ? (p: SearchProgress) => {
      const now = Date.now();
      if (now - lastProgressUpdate >= THROTTLE_MS || p.isComplete) {
        lastProgressUpdate = now;
        progressCallback(p);
      }
    } : undefined;

    // 记录连续失败次数
    let consecutiveFailures = 0;
    const MAX_CONSECUTIVE_FAILURES = 5;

    const checkStopCondition = (): boolean => {
      const elapsed = Date.now() - startTime;
      const totalBooks = resultBuilder.getTotalCount();
      const successSources = progress.completedSources;

      if (totalBooks >= stopCondition.maxBooks) {
        Logger.info(this.TAG, `智能停止: 已找到${totalBooks}本书，达到最大数量${stopCondition.maxBooks}`);
        return true;
      }

      if (elapsed >= stopCondition.maxTime) {
        Logger.info(this.TAG, `智能停止: 搜索时间${elapsed}ms超过阈值${stopCondition.maxTime}ms`);
        return true;
      }

      if (successSources >= stopCondition.minSources && totalBooks > 0) {
        Logger.info(this.TAG, `智能停止: 已搜索${successSources}个书源，找到${totalBooks}本书`);
        return true;
      }

      // 连续失败过多，提前停止
      if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
        Logger.warn(this.TAG, `智能停止: 连续${consecutiveFailures}个书源失败，可能网络或书源有问题`);
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
          .then((result: SearchResult) => {
            if (shouldStop) return;

            const newBooks = resultBuilder.addSourceResult(
              source.id,
              source.name,
              result.books,
              result.success,
              result.error,
              result.responseTime
            );

            if (result.success && result.books.length > 0) {
              // 成功且找到书，重置连续失败计数
              consecutiveFailures = 0;
              sourceHealthManager.recordSuccess(source.id, source.name, source.url, result.responseTime);
            } else if (result.success && result.books.length === 0) {
              // 成功但找不到书（解析问题），不算失败也不算成功
              consecutiveFailures++;
              Logger.warn(this.TAG, `书源 ${source.name} 返回成功但无结果，可能是解析规则失效`);
            } else {
              // 请求失败
              consecutiveFailures++;
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

            // 增加连续失败计数
            consecutiveFailures++;

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

            // 检查是否需要提前停止
            if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
              shouldStop = true;
              progress.isComplete = true;
              Logger.warn(this.TAG, `连续${consecutiveFailures}个书源失败，提前停止搜索`);
              if (throttledProgressCallback) {
                throttledProgressCallback(this.cloneSearchProgress(progress));
              }
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
    options: SearchOptions
  ): Promise<SearchResult[]> {
    const searchKey = options.key;
    const page = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;

    Logger.info(this.TAG, `开始搜索: "${searchKey}", 书源数: ${sources.length}`);

    const enabledSources = sources.filter((s: BookSource) => s.enabled);

    const results: SearchResult[] = [];
    const executing: Promise<void>[] = [];

    for (let i = 0; i < enabledSources.length; i++) {
      const source = enabledSources[i];

      if (executing.length >= concurrent) {
        await Promise.race(executing);
      }

      await this.checkRateLimit(source.url);

      const promise = this.searchSingleSource(source, searchKey, page)
        .then((result: SearchResult) => {
          results.push(result);
        })
        .catch((error: Error) => {
          Logger.error(this.TAG, `搜索失败: ${source.name}, ${error}`);
          results.push({
            books: [],
            sourceName: source.name,
            sourceUrl: source.url,
            success: false,
            error: String(error),
            responseTime: 0
          });
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

    Logger.info(this.TAG, `搜索完成: ${results.filter((r: SearchResult) => r.success).length}/${sources.length} 成功`);
    return results;
  }

  /**
   * 在单个书源中搜索
   */
  async searchSingleSource(
    source: BookSource,
    key: string,
    page: number = 1
  ): Promise<SearchResult> {
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
    Logger.debug(this.TAG, `书名规则: ${searchRule.name}, 作者规则: ${searchRule.author}, URL规则: ${searchRule.bookUrl}`);

    // 1. 获取书籍列表（使用异步解析避免主线程阻塞）
    const bookListHtml = await this.htmlParser.parseAsync(html, searchRule.bookList);

    if (!bookListHtml || bookListHtml.length === 0) {
      Logger.warn(this.TAG, `解析结果为空: ${source.name}, 列表规则: ${searchRule.bookList}`);
      // 增强调试：保存 HTML 内容用于分析
      const htmlPreview = html.substring(0, 800).replace(/\s+/g, ' ');
      Logger.debug(this.TAG, `HTML前800字符: ${htmlPreview}`);
      // 尝试用简单选择器诊断问题
      const diagnostic = await this.diagnoseHtmlStructure(html);
      Logger.debug(this.TAG, `HTML结构诊断: ${diagnostic}`);
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
      author: this.cleanText(author) || '未知作者',
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
   * 从元素中提取文本 - 增强版，递归提取所有文本
   */
  private extractTextFromElement(element: string): string {
    if (!element) return '';

    // 使用改进的文本提取：移除所有标签，保留内容
    let text = element;

    // 移除 script/style
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

    // 替换 br 为换行
    text = text.replace(/<br\s*\/?>/gi, '\n');

    // 移除所有 HTML 标签
    text = text.replace(/<[^>]+>/g, '');

    // 解码 HTML 实体
    text = this.decodeHtmlEntities(text);

    // 清理空白
    text = text.replace(/\s+/g, ' ').trim();

    return text;
  }

  /**
   * 解码 HTML 实体 - 增强版，支持更多实体
   */
  private decodeHtmlEntities(text: string): string {
    const entities: Record<string, string> = {
      // 基础实体
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&#x27;': "'",
      '&nbsp;': ' ',
      '&#160;': ' ',
      // 中文标点
      '&hellip;': '…',
      '&#8230;': '…',
      // 破折号和连字符
      '&mdash;': '—',
      '&#8212;': '—',
      '&ndash;': '–',
      '&#8211;': '–',
      // 引号
      '&ldquo;': '"',
      '&#8220;': '"',
      '&rdquo;': '"',
      '&#8221;': '"',
      '&lsquo;': "'",
      '&#8216;': "'",
      '&rsquo;': "'",
      '&#8217;': "'",
      // 其他常用实体
      '&copy;': '©',
      '&#169;': '©',
      '&reg;': '®',
      '&#174;': '®',
      '&trade;': '™',
      '&#8482;': '™',
      '&yen;': '¥',
      '&#165;': '¥',
      '&euro;': '€',
      '&#8364;': '€',
      // 数学符号
      '&times;': '×',
      '&#215;': '×',
      '&divide;': '÷',
      '&#247;': '÷',
      '&plusmn;': '±',
      '&#177;': '±',
      // 箭头
      '&larr;': '←',
      '&#8592;': '←',
      '&uarr;': '↑',
      '&#8593;': '↑',
      '&rarr;': '→',
      '&#8594;': '→',
      '&darr;': '↓',
      '&#8595;': '↓',
    };

    let result = text;
    const entityKeys = Object.keys(entities);
    for (const entity of entityKeys) {
      result = result.split(entity).join(entities[entity]);
    }

    // 处理十进制数字实体 &#123;
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      const code = parseInt(dec, 10);
      if (!isNaN(code) && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match;
    });

    // 处理十六进制数字实体 &#x7B;
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
      const code = parseInt(hex, 16);
      if (!isNaN(code) && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match;
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
   * HTML 结构诊断 - 帮助理解页面结构
   */
  private async diagnoseHtmlStructure(html: string): Promise<string> {
    const checks: string[] = [];

    const containerPatterns: ContainerPattern[] = [
      { name: 'div.book', regex: /<div[^>]*class=["'][^"']*book[^"']*["'][^>]*>/i },
      { name: 'div.item', regex: /<div[^>]*class=["'][^"']*item[^"']*["'][^>]*>/i },
      { name: 'div.list', regex: /<div[^>]*class=["'][^"']*list[^"']*["'][^>]*>/i },
      { name: 'li.item', regex: /<li[^>]*class=["'][^"']*item[^"']*["'][^>]*>/i },
      { name: 'tr', regex: /<tr[\s>]/i },
      { name: 'article', regex: /<article[\s>]/i },
      { name: 'section', regex: /<section[\s>]/i }
    ];

    for (const pattern of containerPatterns) {
      const matches = html.match(pattern.regex);
      if (matches) {
        checks.push(`${pattern.name}: ${matches.length}个`);
      }
    }

    // 检查是否有 script 动态渲染
    if (html.includes('<script') && html.includes('document.write')) {
      checks.push('警告: 页面使用JS动态渲染');
    }

    // 检查是否是 JSON 数据
    if (html.trim().startsWith('{') || html.trim().startsWith('[')) {
      checks.push('内容类型: JSON数据');
    }

    // 检查状态码错误页面
    if (html.includes('403') || html.includes('Forbidden')) {
      checks.push('警告: 可能是403错误页面');
    }
    if (html.includes('404') || html.includes('Not Found')) {
      checks.push('警告: 可能是404错误页面');
    }

    return checks.length > 0 ? checks.join(', ') : '未识别到常见模式';
  }

  /**
   * 聚合搜索结果（去重）
   */
  aggregateResults(results: SearchResult[]): Book[] {
    const allBooks: Book[] = [];
    const seen = new Set<string>();

    for (const result of results) {
      if (!result.success) continue;

      for (const book of result.books) {
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
   * 设置配置
   */
  setConfig(config: Partial<SearchConfig>): void {
    this.config.maxConcurrent = config.maxConcurrent ?? this.config.maxConcurrent;
    this.config.requestInterval = config.requestInterval ?? this.config.requestInterval;
    this.config.timeout = config.timeout ?? this.config.timeout;
    this.config.maxResultsPerSource = config.maxResultsPerSource ?? this.config.maxResultsPerSource;
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

export interface SearchConfig {
  maxConcurrent: number;
  requestInterval: number;
  timeout: number;
  maxResultsPerSource: number;
}

export default BookSourceSearchEngine.getInstance();