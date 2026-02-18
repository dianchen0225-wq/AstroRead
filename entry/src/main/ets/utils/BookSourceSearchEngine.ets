/**
 * BookSourceSearchEngine - 书源搜索引擎
 * 支持多书源并发搜索、请求频率控制、结果聚合
 */

import { BookSource } from '../models/BookSource';
import { Book } from '../models/Book';
import NetworkAdapter from './NetworkAdapter';
import { HTMLParser } from './HTMLParser';
import { EnhancedJSEngine } from './EnhancedJSEngine';
import { Logger } from './Logger';

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
}

export class BookSourceSearchEngine {
  private static instance: BookSourceSearchEngine | null = null;
  private htmlParser: HTMLParser;
  private jsEngine: EnhancedJSEngine;
  private requestTimestamps: Map<string, number[]> = new Map();
  private readonly TAG = 'BookSourceSearchEngine';

  private config: SearchConfig = {
    maxConcurrent: 3,
    requestInterval: 1000,
    timeout: 30000,
    maxResultsPerSource: 20
  };

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

  /**
   * 在多个书源中搜索
   */
  async search(
    sources: BookSource[],
    options: SearchOptions
  ): Promise<SearchResult[]> {
    const searchKey = options.key;
    const page = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;

    Logger.info(this.TAG, `开始搜索: "${searchKey}", 书源数: ${sources.length}`);

    // 只使用启用的书源
    const enabledSources = sources.filter((s: BookSource) => s.enabled);

    // 并发控制搜索
    const results: SearchResult[] = [];
    const executing: Promise<void>[] = [];

    for (let i = 0; i < enabledSources.length; i++) {
      const source = enabledSources[i];

      // 控制并发数
      if (executing.length >= concurrent) {
        await Promise.race(executing);
      }

      // 检查请求频率
      await this.checkRateLimit(source.url);

      // 执行搜索
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

    // 等待所有搜索完成
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

      // 1. 构建搜索 URL
      const searchUrl = await this.buildSearchUrl(source, key, page);
      if (!searchUrl) {
        throw new Error('无法构建搜索 URL');
      }

      // 2. 发送搜索请求
      const html = await this.executeSearchRequest(source, searchUrl);

      // 3. 解析搜索结果
      const books = await this.parseSearchResults(source, html, key);

      const responseTime = Date.now() - startTime;

      return {
        books: books.slice(0, this.config.maxResultsPerSource),
        sourceName: source.name,
        sourceUrl: source.url,
        success: true,
        responseTime
      };

    } catch {
      const responseTime = Date.now() - startTime;
      Logger.error(this.TAG, `搜索失败: ${source.name}`);

      return {
        books: [],
        sourceName: source.name,
        sourceUrl: source.url,
        success: false,
        error: '搜索失败',
        responseTime
      };
    }
  }

  /**
   * 构建搜索 URL
   */
  private async buildSearchUrl(source: BookSource, key: string, page: number): Promise<string> {
    if (!source.searchUrl) {
      throw new Error('书源未配置搜索 URL');
    }

    let searchUrl = source.searchUrl;

    // 处理 JS 动态 URL
    if (searchUrl.includes('@js:') || searchUrl.includes('<js>')) {
      const jsCode = searchUrl.replace(/^@js:/, '').replace(/<js>|<\/js>/g, '');
      const result = await this.jsEngine.executeSearchUrl(jsCode, {
        key,
        page,
        baseUrl: source.url
      });
      return result;
    }

    // 替换占位符
    searchUrl = searchUrl
      .replace(/\{\{key\}\}/g, encodeURIComponent(key))
      .replace(/\{\{page\}\}/g, String(page));

    // 处理相对 URL
    if (!searchUrl.startsWith('http')) {
      searchUrl = this.resolveUrl(source.url, searchUrl);
    }

    return searchUrl;
  }

  /**
   * 执行搜索请求
   */
  private async executeSearchRequest(source: BookSource, url: string): Promise<string> {
    const headers: Record<string, string> = {};

    if (source.header) {
      try {
        const customHeaders: Record<string, string> = JSON.parse(source.header);
        const keys = Object.keys(customHeaders);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          headers[key] = customHeaders[key];
        }
      } catch {
        Logger.warn(this.TAG, '解析 header 失败');
      }
    }

    const html = await NetworkAdapter.get(url, headers);
    return html;
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
      throw new Error('书源未配置搜索规则');
    }

    // 1. 获取书籍列表
    const bookListHtml = this.htmlParser.parse(html, searchRule.bookList);

    if (!bookListHtml || bookListHtml.length === 0) {
      return books;
    }

    // 2. 遍历每本书
    for (const bookHtml of bookListHtml) {
      try {
        const book = await this.parseSingleBook(source, bookHtml, key);
        if (book && book.name) {
          books.push(book);
        }
      } catch {
        Logger.warn(this.TAG, '解析单本书失败');
      }
    }

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
    if (!name) return null;

    // 提取作者
    const author = await this.extractField(html, searchRule.author, source);

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

    const book: Book = {
      id: '',  // 由 ViewModel 生成
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

    // 使用 HTML 解析器
    const results = this.htmlParser.parse(html, rule);
    return results[0] || '';
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
   * 延迟
   */
  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, ms));
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