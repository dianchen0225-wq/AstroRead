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
import { AnalyzeRule } from './AnalyzeRule';
import { ContentProcessor } from './ContentProcessor';
import { ReplaceRule } from '../models/ContentFilter';
import { Logger } from './Logger';
import { EntityDecoder } from '../core/utils/EntityDecoder';
import http from '@ohos.net.http';

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
  precision?: boolean;
}

export type SearchProgressCallback = (progress: SearchProgress) => void;

export interface PreciseSearchResult {
  found: boolean;
  book?: Book;
  source?: BookSource;
}

export interface BookOrigin {
  id: string;
  name: string;
}

export interface BookWithOrigins extends Book {
  origins?: BookOrigin[];
}

export interface ChapterInfo {
  title: string;
  url: string;
  order: number;
}

interface HttpRequestOptions {
  method: http.RequestMethod;
  header?: Record<string, string>;
  extraData?: string;
  connectTimeout?: number;
  readTimeout?: number;
}

export class WebBook {
  private static readonly TAG = 'WebBook';

  static async searchBook(
    source: BookSource,
    key: string,
    page: number = 1,
    filter?: (name: string, author: string) => boolean,
    shouldBreak?: (size: number) => boolean
  ): Promise<Book[]> {
    if (!source.searchUrl) {
      throw new Error(`书源 ${source.name} 未配置搜索URL`);
    }

    const analyzeRule = new AnalyzeRule({ baseUrl: source.url });
    const urlConfig = AnalyzeRule.parseSearchUrl(source.searchUrl, key, page, source.url);
    
    if (!urlConfig.url) {
      throw new Error('无法构建搜索URL');
    }

    Logger.debug(WebBook.TAG, `搜索请求: ${urlConfig.url}, 方法: ${urlConfig.method}`);

    let headersRecord: Record<string, string> | undefined = undefined;
    if (urlConfig.headers) {
      headersRecord = {};
      urlConfig.headers.forEach((value: string, key: string) => {
        headersRecord![key] = value;
      });
    }
    const body = await WebBook.fetchUrl(urlConfig.url, urlConfig.method, urlConfig.body, headersRecord);
    
    return WebBook.parseBookList(source, body, filter, shouldBreak, analyzeRule);
  }

  static async exploreBook(
    source: BookSource,
    url: string
  ): Promise<Book[]> {
    const analyzeRule = new AnalyzeRule({ baseUrl: source.url });
    const body = await WebBook.fetchUrl(url, 'GET');
    
    return WebBook.parseBookList(source, body, undefined, undefined, analyzeRule);
  }

  static async getBookInfo(
    source: BookSource,
    book: Book
  ): Promise<Book> {
    if (!book.bookUrl) {
      throw new Error('书籍URL为空');
    }

    const analyzeRule = new AnalyzeRule({ baseUrl: source.url, book: book });
    const body = await WebBook.fetchUrl(book.bookUrl, 'GET');
    
    analyzeRule.setContent(body, book.bookUrl);
    
    if (source.findRule) {
      if (source.findRule.name) {
        book.name = await analyzeRule.getString(source.findRule.name);
      }
      if (source.findRule.author) {
        book.author = await analyzeRule.getString(source.findRule.author);
      }
      if (source.findRule.cover) {
        book.cover = await analyzeRule.getString(source.findRule.cover, true);
      }
      if (source.findRule.intro) {
        book.intro = await analyzeRule.getString(source.findRule.intro);
      }
    }
    
    book.name = WebBook.cleanText(book.name);
    book.author = WebBook.cleanText(book.author) || '未知作者';
    
    return book;
  }

  static async getChapterList(
    source: BookSource,
    book: Book
  ): Promise<ChapterInfo[]> {
    if (!source.chapterRule) {
      throw new Error('书源未配置章节规则');
    }

    const tocUrl = book.bookUrl;
    const analyzeRule = new AnalyzeRule({ baseUrl: source.url, book: book });
    const body = await WebBook.fetchUrl(tocUrl, 'GET');
    
    analyzeRule.setContent(body, tocUrl);
    
    const chapterElements = await analyzeRule.getElements(source.chapterRule.chapterList);
    const chapters: ChapterInfo[] = [];
    
    for (let i = 0; i < chapterElements.length; i++) {
      const elementHtml = chapterElements[i];
      analyzeRule.setContent(elementHtml, tocUrl);
      
      const title = await analyzeRule.getString(source.chapterRule.chapterName);
      let url = await analyzeRule.getString(source.chapterRule.chapterUrl, true);
      
      if (title && url) {
        if (!url.startsWith('http')) {
          url = WebBook.resolveUrl(tocUrl, url);
        }
        
        const chapterInfo: ChapterInfo = {
          title: WebBook.cleanText(title),
          url: url,
          order: i
        };
        chapters.push(chapterInfo);
      }
    }
    
    return chapters;
  }

  static async getContent(
    source: BookSource,
    book: Book,
    chapterUrl: string,
    chapterTitle: string,
    replaceRules?: ReplaceRule[]
  ): Promise<string> {
    if (!source.contentRule) {
      throw new Error('书源未配置内容规则');
    }

    const analyzeRule = new AnalyzeRule({ baseUrl: source.url, book: book });
    const body = await WebBook.fetchUrl(chapterUrl, 'GET');
    
    analyzeRule.setContent(body, chapterUrl);
    
    let content = await analyzeRule.getString(source.contentRule.content);
    
    content = EntityDecoder.decode(content);
    content = content.replace(/<br\s*\/?>/gi, '\n');
    content = content.replace(/<p[^>]*>/gi, '\n');
    content = content.replace(/<\/p>/gi, '');
    content = content.replace(/<[^>]+>/g, '');
    
    if (replaceRules && replaceRules.length > 0) {
      const processor = ContentProcessor.getInstance(book.name, book.bookSourceId || '');
      processor.setReplaceRules(replaceRules);
      const processed = processor.processContent(content, chapterTitle);
      content = processed.content.join('\n');
    }
    
    return content;
  }

  static async preciseSearch(
    sources: BookSource[],
    name: string,
    author: string
  ): Promise<PreciseSearchResult> {
    for (const source of sources) {
      if (!source.enabled || !source.searchUrl) {
        continue;
      }
      
      try {
        const books = await WebBook.searchBook(
          source,
          name,
          1,
          (bookName: string, bookAuthor: string) => {
            return bookName === name && bookAuthor === author;
          },
          (size: number) => size > 0
        );
        
        if (books.length > 0) {
          return {
            found: true,
            book: books[0],
            source: source
          };
        }
      } catch (e) {
        const errorMsg = e instanceof Error ? e.message : String(e);
        Logger.warn(WebBook.TAG, `精准搜索失败: ${source.name}, ${errorMsg}`);
      }
    }
    
    return { found: false };
  }

  private static async parseBookList(
    source: BookSource,
    body: string,
    filter?: (name: string, author: string) => boolean,
    shouldBreak?: (size: number) => boolean,
    analyzeRule?: AnalyzeRule
  ): Promise<Book[]> {
    const books: Book[] = [];
    const searchRule = source.searchRule;
    
    if (!searchRule || !searchRule.bookList) {
      throw new Error('书源未配置搜索规则');
    }
    
    const rule = analyzeRule || new AnalyzeRule({ baseUrl: source.url });
    rule.setContent(body, source.url);
    
    const bookElements = await rule.getElements(searchRule.bookList);
    
    for (let i = 0; i < bookElements.length; i++) {
      const elementHtml = bookElements[i];
      rule.setContent(elementHtml, source.url);
      
      const name = await rule.getString(searchRule.name);
      const author = await rule.getString(searchRule.author || '');
      
      if (!name) continue;
      
      if (filter && !filter(name, author)) continue;
      
      let cover = await rule.getString(searchRule.cover || '', true);
      if (cover && !cover.startsWith('http')) {
        cover = WebBook.resolveUrl(source.url, cover);
      }
      
      let bookUrl = await rule.getString(searchRule.bookUrl, true);
      if (bookUrl && !bookUrl.startsWith('http')) {
        bookUrl = WebBook.resolveUrl(source.url, bookUrl);
      }
      
      const book: Book = {
        id: '',
        name: WebBook.cleanText(name),
        author: WebBook.cleanText(author) || '未知作者',
        cover: cover || undefined,
        intro: await rule.getString(searchRule.intro || ''),
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
      
      books.push(book);
      
      if (shouldBreak && shouldBreak(books.length)) {
        break;
      }
    }
    
    return books;
  }

  private static async fetchUrl(
    url: string,
    method: 'GET' | 'POST',
    body?: string,
    headers?: Record<string, string>
  ): Promise<string> {
    const httpRequest = http.createHttp();
    
    const defaultHeaders: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
    };
    
    if (headers) {
      const keys = Object.keys(headers);
      for (const key of keys) {
        defaultHeaders[key] = headers[key];
      }
    }
    
    const options: HttpRequestOptions = {
      method: method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
      header: defaultHeaders,
      connectTimeout: 30000,
      readTimeout: 30000
    };
    
    if (method === 'POST' && body) {
      options.extraData = body;
    }
    
    try {
      const response = await httpRequest.request(url, options);
      
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      
      const result = response.result;
      if (typeof result === 'string') {
        return result;
      }
      return String(result);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(WebBook.TAG, `请求失败: ${url}, ${errorMsg}`);
      throw new Error(`请求失败: ${errorMsg}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private static cleanText(text: string): string {
    if (!text) return '';
    return text
      .replace(/[\n\r\t]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static resolveUrl(base: string, relative: string): string {
    if (!relative) return '';
    if (relative.startsWith('http://') || relative.startsWith('https://')) {
      return relative;
    }
    if (relative.startsWith('//')) {
      return 'https:' + relative;
    }
    
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
  }
}

interface SearchEngineConfig {
  maxConcurrent: number;
  requestInterval: number;
  timeout: number;
  maxResultsPerSource: number;
}

function createDefaultSearchConfig(): SearchEngineConfig {
  return {
    maxConcurrent: 3,
    requestInterval: 1000,
    timeout: 30000,
    maxResultsPerSource: 20
  };
}

function createDefaultPaginationConfig(): SearchPaginationConfig {
  return {
    pageSize: DEFAULT_PAGINATION_CONFIG.pageSize,
    maxResultsPerSource: DEFAULT_PAGINATION_CONFIG.maxResultsPerSource,
    maxTotalResults: DEFAULT_PAGINATION_CONFIG.maxTotalResults,
    enableDeduplication: DEFAULT_PAGINATION_CONFIG.enableDeduplication,
    sortByRelevance: DEFAULT_PAGINATION_CONFIG.sortByRelevance
  };
}

function cloneBookAsBookWithOrigins(book: Book): BookWithOrigins {
  const result: BookWithOrigins = {
    id: book.id,
    name: book.name,
    author: book.author,
    cover: book.cover,
    intro: book.intro,
    kind: book.kind,
    wordCount: book.wordCount,
    latestChapter: book.latestChapter,
    bookSourceId: book.bookSourceId,
    bookSourceName: book.bookSourceName,
    bookUrl: book.bookUrl,
    lastUpdateTime: book.lastUpdateTime,
    addTime: book.addTime,
    readProgress: book.readProgress,
    lastReadChapter: book.lastReadChapter,
    lastReadChapterIndex: book.lastReadChapterIndex,
    lastReadTime: book.lastReadTime,
    totalChapters: book.totalChapters,
    currentChapterIndex: book.currentChapterIndex,
    currentChapterTitle: book.currentChapterTitle,
    isInShelf: book.isInShelf,
    origins: []
  };
  return result;
}

function clonePaginationConfig(config: SearchPaginationConfig): SearchPaginationConfig {
  return {
    pageSize: config.pageSize,
    maxResultsPerSource: config.maxResultsPerSource,
    maxTotalResults: config.maxTotalResults,
    enableDeduplication: config.enableDeduplication,
    sortByRelevance: config.sortByRelevance
  };
}

export class SearchEngine {
  private static instance: SearchEngine | null = null;
  private readonly TAG = 'SearchEngine';
  
  private requestTimestamps: Map<string, number[]> = new Map();
  private paginationConfig: SearchPaginationConfig = createDefaultPaginationConfig();
  private config: SearchEngineConfig = createDefaultSearchConfig();

  private constructor() {}

  static getInstance(): SearchEngine {
    if (!SearchEngine.instance) {
      SearchEngine.instance = new SearchEngine();
    }
    return SearchEngine.instance;
  }

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
    const precision = options.precision || false;

    const config: SearchPaginationConfig = {
      pageSize: pageSize,
      maxResultsPerSource: maxPerSource,
      maxTotalResults: this.paginationConfig.maxTotalResults,
      enableDeduplication: this.paginationConfig.enableDeduplication,
      sortByRelevance: this.paginationConfig.sortByRelevance
    };

    const resultBuilder = new SearchResultBuilder(config);
    const enabledSources = sources.filter((s: BookSource) => s.enabled);

    Logger.info(this.TAG, `开始搜索: "${searchKey}", 书源数: ${enabledSources.length}`);

    const progress: SearchProgress = {
      totalSources: enabledSources.length,
      completedSources: 0,
      currentSource: '',
      foundBooks: 0,
      isComplete: false
    };

    const executing: Promise<void>[] = [];

    for (let i = 0; i < enabledSources.length; i++) {
      const source = enabledSources[i];

      if (executing.length >= concurrent) {
        await Promise.race(executing);
      }

      await this.checkRateLimit(source.url);

      const promise = this.searchSingleSource(source, searchKey, 1, precision)
        .then((result: SearchResult) => {
          resultBuilder.addSourceResult(
            source.id,
            source.name,
            result.books,
            result.success,
            result.error,
            result.responseTime
          );

          if (progressCallback) {
            progress.completedSources++;
            progress.currentSource = source.name;
            progress.foundBooks = resultBuilder.getTotalCount();
            progress.isComplete = progress.completedSources >= progress.totalSources;
            progressCallback(progress);
          }
        })
        .catch((error: Error) => {
          Logger.error(this.TAG, `搜索失败: ${source.name}, ${error.message}`);
          resultBuilder.addSourceResult(
            source.id,
            source.name,
            [],
            false,
            error.message,
            0
          );

          if (progressCallback) {
            progress.completedSources++;
            progress.currentSource = source.name;
            progress.foundBooks = resultBuilder.getTotalCount();
            progress.isComplete = progress.completedSources >= progress.totalSources;
            progressCallback(progress);
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
      `搜索完成: 共${pagedResult.totalCount}本书, ` +
      `第${pagedResult.currentPage}/${pagedResult.totalPages}页, ` +
      `成功书源: ${pagedResult.sourceStats.filter((s: SourceSearchStats) => s.success).length}/${enabledSources.length}`
    );

    return pagedResult;
  }

  async search(
    sources: BookSource[],
    options: SearchOptions
  ): Promise<SearchResult[]> {
    const searchKey = options.key;
    const page = options.page || 1;
    const concurrent = options.concurrent || this.config.maxConcurrent;
    const precision = options.precision || false;

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

      const promise = this.searchSingleSource(source, searchKey, page, precision)
        .then((result: SearchResult) => {
          results.push(result);
        })
        .catch((error: Error) => {
          Logger.error(this.TAG, `搜索失败: ${source.name}, ${error.message}`);
          results.push({
            books: [],
            sourceName: source.name,
            sourceUrl: source.url,
            success: false,
            error: error.message,
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

  private async searchSingleSource(
    source: BookSource,
    key: string,
    page: number = 1,
    precision: boolean = false
  ): Promise<SearchResult> {
    const startTime = Date.now();

    try {
      Logger.debug(this.TAG, `开始搜索: ${source.name}, 关键词: ${key}`);

      const filter = precision ? (name: string, author: string) => {
        return name.includes(key) || author.includes(key);
      } : undefined;

      const books = await WebBook.searchBook(source, key, page, filter);

      const responseTime = Date.now() - startTime;

      return {
        books: books.slice(0, this.config.maxResultsPerSource),
        sourceName: source.name,
        sourceUrl: source.url,
        success: true,
        responseTime
      };

    } catch (e) {
      const responseTime = Date.now() - startTime;
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(this.TAG, `搜索失败: ${source.name}, ${errorMsg}`);

      return {
        books: [],
        sourceName: source.name,
        sourceUrl: source.url,
        success: false,
        error: errorMsg,
        responseTime
      };
    }
  }

  aggregateResults(results: SearchResult[], precision: boolean = false, searchKey: string = ''): Book[] {
    const equalBooks: BookWithOrigins[] = [];
    const containsBooks: BookWithOrigins[] = [];
    const otherBooks: BookWithOrigins[] = [];
    const seen = new Map<string, BookWithOrigins>();

    for (const result of results) {
      if (!result.success) continue;

      for (const book of result.books) {
        const key = `${book.name}_${book.author}`.toLowerCase();
        const existingBook = seen.get(key);

        if (existingBook) {
          if (!existingBook.origins) {
            existingBook.origins = [];
          }
          const origin: BookOrigin = {
            id: book.bookSourceId || '',
            name: book.bookSourceName || ''
          };
          existingBook.origins.push(origin);
        } else {
          const bookWithOrigins = cloneBookAsBookWithOrigins(book);
          seen.set(key, bookWithOrigins);

          if (book.name === searchKey || book.author === searchKey) {
            equalBooks.push(bookWithOrigins);
          } else if (book.name.includes(searchKey) || book.author.includes(searchKey)) {
            containsBooks.push(bookWithOrigins);
          } else if (!precision) {
            otherBooks.push(bookWithOrigins);
          }
        }
      }
    }

    const sortByOrigins = (a: BookWithOrigins, b: BookWithOrigins): number => {
      const aCount = a.origins?.length || 1;
      const bCount = b.origins?.length || 1;
      return bCount - aCount;
    };

    equalBooks.sort(sortByOrigins);
    containsBooks.sort(sortByOrigins);
    otherBooks.sort(sortByOrigins);

    const allBooks: Book[] = [];
    for (const book of equalBooks) {
      allBooks.push(book as Book);
    }
    for (const book of containsBooks) {
      allBooks.push(book as Book);
    }
    for (const book of otherBooks) {
      allBooks.push(book as Book);
    }
    
    return allBooks;
  }

  private async checkRateLimit(sourceUrl: string): Promise<void> {
    const now = Date.now();
    const timestamps = this.requestTimestamps.get(sourceUrl) || [];

    const validTimestamps: number[] = [];
    for (const t of timestamps) {
      if (now - t < 1000) {
        validTimestamps.push(t);
      }
    }

    if (validTimestamps.length > 0) {
      const lastRequest = validTimestamps[validTimestamps.length - 1];
      const waitTime = this.config.requestInterval - (now - lastRequest);

      if (waitTime > 0) {
        Logger.debug(this.TAG, `频率限制: 等待 ${waitTime}ms`);
        await this.sleep(waitTime);
      }
    }

    validTimestamps.push(Date.now());
    this.requestTimestamps.set(sourceUrl, validTimestamps);
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, ms));
  }

  setConfig(config: SearchEngineConfig): void {
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
  }

  setPaginationConfig(config: SearchPaginationConfig): void {
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
  }

  getPaginationConfig(): SearchPaginationConfig {
    return clonePaginationConfig(this.paginationConfig);
  }
}

export default SearchEngine;
