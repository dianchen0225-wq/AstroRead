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
  SearchProgress
} from '../models/SearchResult';
import NetworkAdapter, { NetworkError } from './NetworkAdapter';
import { HTMLParser } from './HTMLParser';
import { CssSelectorParser } from './CssSelectorParser';
import { EnhancedJSEngine } from './EnhancedJSEngine';
import { Logger } from './Logger';
import { sourceHealthManager } from './SourceHealthManager';

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
}

export type SearchProgressCallback = (progress: SearchProgress) => void;

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

export class BookSourceSearchEngine {
  private static instance: BookSourceSearchEngine | null = null;
  private htmlParser: HTMLParser;
  private jsEngine: EnhancedJSEngine;
  private requestTimestamps: Map<string, number[]> = new Map();
  private pendingTimers: Set<number> = new Set();
  private isCancelled: boolean = false;
  private readonly TAG = 'BookSourceSearchEngine';

  private config: SearchConfig = {
    maxConcurrent: 5,
    requestInterval: 500,
    timeout: 10000,
    maxResultsPerSource: 20
  };

  private paginationConfig: SearchPaginationConfig = DEFAULT_PAGINATION_CONFIG;

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.jsEngine = EnhancedJSEngine.getInstance();
  }

  static getInstance(): BookSourceSearchEngine {
    if (!BookSourceSearchEngine.instance) {
      BookSourceSearchEngine.instance = new BookSourceSearchEngine();
    }
    return BookSourceSearchEngine.instance;
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
   * 分页搜索 - 支持多书源并发搜索并返回分页结果
   */
  async searchWithPaging(
    sources: BookSource[],
    options: SearchOptions,
    progressCallback?: SearchProgressCallback
  ): Promise<PagedSearchResult> {
    const searchKey = options.key;
    const displayPage = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;
    const pageSize = options.pageSize || this.paginationConfig.pageSize;
    const maxPerSource = options.maxResultsPerSource || this.paginationConfig.maxResultsPerSource;

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

    Logger.info(this.TAG, `开始分页搜索: "${searchKey}", 书源数: ${sortedSources.length}, 每页: ${pageSize}`);

    const progress: SearchProgress = {
      totalSources: sortedSources.length,
      completedSources: 0,
      currentSource: '',
      foundBooks: 0,
      isComplete: false
    };

    let lastProgressUpdate = 0;
    const THROTTLE_MS = 200;
    const throttledProgressCallback = progressCallback ? (p: SearchProgress) => {
      const now = Date.now();
      if (now - lastProgressUpdate >= THROTTLE_MS || p.isComplete) {
        lastProgressUpdate = now;
        progressCallback(p);
      }
    } : undefined;

    const executing: Promise<void>[] = [];
    const mutex = this.createMutex();

    for (let i = 0; i < sortedSources.length; i++) {
      const source = sortedSources[i];

      if (executing.length >= concurrent) {
        await Promise.race(executing);
      }

      await this.checkRateLimit(source.url);

      const promise = this.searchSingleSource(source, searchKey, 1)
        .then((result: SearchResult) => {
          resultBuilder.addSourceResult(
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

          if (throttledProgressCallback) {
            progress.completedSources++;
            progress.currentSource = source.name;
            progress.foundBooks = resultBuilder.getTotalCount();
            progress.isComplete = progress.completedSources >= progress.totalSources;
            throttledProgressCallback(progress);
          }
        })
        .catch((error: Error) => {
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

          if (throttledProgressCallback) {
            progress.completedSources++;
            progress.currentSource = source.name;
            progress.foundBooks = resultBuilder.getTotalCount();
            progress.isComplete = progress.completedSources >= progress.totalSources;
            throttledProgressCallback(progress);
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

    await Promise.all(executing);

    const pagedResult = resultBuilder.build(displayPage);

    Logger.info(this.TAG, 
      `分页搜索完成: 共${pagedResult.totalCount}本书, ` +
      `第${pagedResult.currentPage}/${pagedResult.totalPages}页, ` +
      `成功书源: ${pagedResult.sourceStats.filter((s: SourceSearchStats) => s.success).length}/${enabledSources.length}`
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

    // 1. 获取书籍列表
    const bookListHtml = this.htmlParser.parse(html, searchRule.bookList);

    if (!bookListHtml || bookListHtml.length === 0) {
      Logger.warn(this.TAG, `解析结果为空: ${source.name}, 列表规则: ${searchRule.bookList}`);
      Logger.debug(this.TAG, `HTML前500字符: ${html.substring(0, 500)}`);
      return books;
    }

    Logger.info(this.TAG, `解析到 ${bookListHtml.length} 个书籍块: ${source.name}`);

    // 2. 遍历每本书
    for (let i = 0; i < bookListHtml.length; i++) {
      const bookHtml = bookListHtml[i];
      try {
        const book = await this.parseSingleBook(source, bookHtml, key);
        if (book && book.name) {
          books.push(book);
          Logger.debug(this.TAG, `解析书籍成功: ${book.name} - ${book.author || '未知作者'}`);
        } else {
          Logger.debug(this.TAG, `第 ${i + 1} 个书籍块解析返回空`);
        }
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        Logger.warn(this.TAG, `解析第 ${i + 1} 本书失败: ${errorMsg}`);
      }
    }

    Logger.info(this.TAG, `解析完成: ${source.name}, 成功 ${books.length}/${bookListHtml.length} 本`);
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

    // 使用 CSS 选择器解析器提取文本内容
    const text = CssSelectorParser.extractValue(html, rule);
    return text || '';
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