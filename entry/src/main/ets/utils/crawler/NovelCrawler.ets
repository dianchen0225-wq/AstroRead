import { Book, Chapter, ChapterContent } from '../../models/Book';
import { BookSource, BookInfoRule, TocRule, ContentRule } from '../../models/BookSource';
import { ContentParser, ParsedChapterItem } from '../parser/ContentParser';
import { RuleEngine } from '../parser/RuleEngine';
import { CssSelectorParser } from '../parser/CssSelectorParser';
import NetworkAdapter from '../network/NetworkAdapter';
import { CrawlerManager } from './CrawlerManager';
import { RequestThrottler } from './RequestThrottler';
import { CrawlerMonitor } from './CrawlerMonitor';
import { DataValidator, CleaningOptions } from '../validation/DataValidator';
import { Logger } from '../performance/Logger';
import { SafeRegex } from '../security/SafeRegex';
import { IdGenerator } from '../content/IdGenerator';

export interface CrawlProgress {
  phase: 'detail' | 'chapters' | 'content' | 'complete' | 'error';
  totalChapters: number;
  downloadedChapters: number;
  currentChapter: string;
  failedChapters: number;
  skippedChapters: number;
  percent: number;
}

export interface CrawlResult {
  book: Book;
  chapters: Chapter[];
  contents: ChapterContent[];
  errors: CrawlChapterError[];
  totalTime: number;
}

export interface ChapterListResult {
  chapters: Chapter[];
  errors: CrawlChapterError[];
}

export interface DownloadResult {
  book: Book;
  contents: ChapterContent[];
  errors: CrawlChapterError[];
}

export interface ChapterDownloadResult {
  content: string;
  error?: string;
  retryCount: number;
}

export interface SpecificDownloadResult {
  contents: ChapterContent[];
  errors: CrawlChapterError[];
}

export interface CrawlChapterError {
  chapterTitle: string;
  chapterUrl: string;
  error: string;
  retryCount: number;
}

export interface CrawlConfig {
  maxConcurrentChapters: number;
  chapterRetryCount: number;
  retryBaseDelay: number;
  retryMaxDelay: number;
  chapterTimeout: number;
  minContentLength: number;
  skipExistingChapters: boolean;
  enableContentValidation: boolean;
  enableContentCleaning: boolean;
}

const DEFAULT_CRAWL_CONFIG: CrawlConfig = {
  maxConcurrentChapters: 3,
  chapterRetryCount: 3,
  retryBaseDelay: 1000,
  retryMaxDelay: 15000,
  chapterTimeout: 30000,
  minContentLength: 50,
  skipExistingChapters: true,
  enableContentValidation: true,
  enableContentCleaning: true
};

export type CrawlProgressCallback = (progress: CrawlProgress) => void;

export class NovelCrawler {
  private static instance: NovelCrawler | null = null;
  private config: CrawlConfig;
  private crawlerManager: CrawlerManager;
  private throttler: RequestThrottler;
  private monitor: CrawlerMonitor;
  private validator: DataValidator;
  private isCancelled: boolean = false;
  private readonly TAG = 'NovelCrawler';

  private constructor() {
    this.config = DEFAULT_CRAWL_CONFIG;
    this.crawlerManager = CrawlerManager.getInstance();
    this.throttler = RequestThrottler.getInstance();
    this.monitor = CrawlerMonitor.getInstance();
    this.validator = DataValidator.getInstance();
  }

  static getInstance(): NovelCrawler {
    if (!NovelCrawler.instance) {
      NovelCrawler.instance = new NovelCrawler();
    }
    return NovelCrawler.instance;
  }

  setConfig(config: Partial<CrawlConfig>): void {
    if (config.maxConcurrentChapters !== undefined) {
      this.config.maxConcurrentChapters = Math.max(1, config.maxConcurrentChapters);
    }
    if (config.chapterRetryCount !== undefined) {
      this.config.chapterRetryCount = config.chapterRetryCount;
    }
    if (config.retryBaseDelay !== undefined) {
      this.config.retryBaseDelay = config.retryBaseDelay;
    }
    if (config.retryMaxDelay !== undefined) {
      this.config.retryMaxDelay = config.retryMaxDelay;
    }
    if (config.chapterTimeout !== undefined) {
      this.config.chapterTimeout = config.chapterTimeout;
    }
    if (config.minContentLength !== undefined) {
      this.config.minContentLength = config.minContentLength;
    }
    if (config.skipExistingChapters !== undefined) {
      this.config.skipExistingChapters = config.skipExistingChapters;
    }
    if (config.enableContentValidation !== undefined) {
      this.config.enableContentValidation = config.enableContentValidation;
    }
    if (config.enableContentCleaning !== undefined) {
      this.config.enableContentCleaning = config.enableContentCleaning;
    }
  }

  getConfig(): CrawlConfig {
    return {
      maxConcurrentChapters: this.config.maxConcurrentChapters,
      chapterRetryCount: this.config.chapterRetryCount,
      retryBaseDelay: this.config.retryBaseDelay,
      retryMaxDelay: this.config.retryMaxDelay,
      chapterTimeout: this.config.chapterTimeout,
      minContentLength: this.config.minContentLength,
      skipExistingChapters: this.config.skipExistingChapters,
      enableContentValidation: this.config.enableContentValidation,
      enableContentCleaning: this.config.enableContentCleaning
    };
  }

  cancel(): void {
    this.isCancelled = true;
    Logger.info(this.TAG, '爬取任务已取消');
  }

  /**
   * 完整爬取流程：从搜索结果的 Book 开始，获取详情、章节列表、章节内容
   */
  async crawlBook(
    book: Book,
    source: BookSource,
    onProgress?: CrawlProgressCallback
  ): Promise<CrawlResult> {
    this.isCancelled = false;
    const startTime = Date.now();
    const errors: CrawlChapterError[] = [];
    const contents: ChapterContent[] = [];
    let chapters: Chapter[] = [];

    this.monitor.startSession();
    Logger.info(this.TAG, `开始爬取: ${book.name}, 书源: ${source.name}`);

    try {
      // Phase 1: 获取书籍详情页并补充信息
      this.reportProgress(onProgress, {
        phase: 'detail',
        totalChapters: 0,
        downloadedChapters: 0,
        currentChapter: '',
        failedChapters: 0,
        skippedChapters: 0,
        percent: 0
      });

      const enrichedBook = await this.fetchBookDetail(book, source);

      // Phase 2: 获取章节列表（支持分页）
      this.reportProgress(onProgress, {
        phase: 'chapters',
        totalChapters: 0,
        downloadedChapters: 0,
        currentChapter: '',
        failedChapters: 0,
        skippedChapters: 0,
        percent: 5
      });

      const chapterListResult = await this.fetchChapterList(
        enrichedBook, source, onProgress
      );
      chapters = chapterListResult.chapters;
      const chapterErrors = chapterListResult.errors;

      for (const ce of chapterErrors) {
        errors.push(ce);
      }

      if (this.isCancelled) {
        Logger.info(this.TAG, '爬取已取消');
        return {
          book: enrichedBook,
          chapters,
          contents,
          errors,
          totalTime: Date.now() - startTime
        };
      }

      enrichedBook.totalChapters = chapters.length;

      // Phase 3: 下载章节内容
      const contentResult = await this.downloadChapters(
        enrichedBook, source, chapters, contents, errors, onProgress
      );

      const finalBook = contentResult.book;
      const finalContents = contentResult.contents;
      const finalErrors = contentResult.errors;

      this.reportProgress(onProgress, {
        phase: 'complete',
        totalChapters: chapters.length,
        downloadedChapters: finalContents.length,
        currentChapter: '',
        failedChapters: finalErrors.length,
        skippedChapters: chapters.length - finalContents.length - finalErrors.length,
        percent: 100
      });

      const totalTime = Date.now() - startTime;
      Logger.info(this.TAG,
        `爬取完成: ${finalBook.name}, 章节 ${finalContents.length}/${chapters.length}, ` +
        `失败 ${finalErrors.length}, 耗时 ${totalTime}ms`
      );

      this.monitor.endSession();

      return {
        book: finalBook,
        chapters,
        contents: finalContents,
        errors: finalErrors,
        totalTime
      };

    } catch (error) {
      const totalTime = Date.now() - startTime;
      Logger.error(this.TAG, `爬取失败: ${error}`);

      this.reportProgress(onProgress, {
        phase: 'error',
        totalChapters: chapters.length,
        downloadedChapters: contents.length,
        currentChapter: '',
        failedChapters: errors.length,
        skippedChapters: 0,
        percent: 0
      });

      this.monitor.endSession();

      const fatalError: CrawlChapterError = {
        chapterTitle: book.name,
        chapterUrl: book.bookUrl,
        error: error instanceof Error ? error.message : String(error),
        retryCount: 0
      };
      errors.push(fatalError);

      return {
        book,
        chapters,
        contents,
        errors,
        totalTime
      };
    }
  }

  /**
   * Phase 1: 获取书籍详情页，补充书籍信息
   */
  private async fetchBookDetail(book: Book, source: BookSource): Promise<Book> {
    if (!book.bookUrl) {
      Logger.warn(this.TAG, '书籍URL为空，跳过详情获取');
      return book;
    }

    const detailUrl = this.resolveUrl(source.url, book.bookUrl);

    try {
      Logger.info(this.TAG, `获取书籍详情: ${detailUrl}`);

      const html = await NetworkAdapter.get(
        detailUrl,
        this.parseCustomHeaders(source.networkConfig?.header)
      );

      if (!html || html.length < 100) {
        Logger.warn(this.TAG, `详情页内容过短，使用已有信息`);
        return book;
      }

      RuleEngine.setContext({ baseUrl: source.url, html: html });

      const bookInfoRule = source.rules.bookInfoRule;
      const enriched = this.cloneBook(book);

      if (bookInfoRule) {
        if (bookInfoRule.name && !book.name) {
          const nameValue = RuleEngine.parseRule(bookInfoRule.name, html);
          if (nameValue) {
            enriched.name = RuleEngine.cleanText(nameValue);
          }
        }

        if (bookInfoRule.author && !book.author) {
          const authorValue = RuleEngine.parseRule(bookInfoRule.author, html);
          if (authorValue) {
            enriched.author = RuleEngine.cleanText(authorValue);
          }
        }

        if (bookInfoRule.coverUrl && !book.cover) {
          const coverValue = RuleEngine.parseRule(bookInfoRule.coverUrl, html);
          if (coverValue) {
            enriched.cover = this.resolveUrl(source.url, coverValue);
          }
        }

        if (bookInfoRule.intro && !book.intro) {
          const introValue = RuleEngine.parseRule(bookInfoRule.intro, html);
          if (introValue) {
            enriched.intro = RuleEngine.cleanText(introValue);
          }
        }

        if (bookInfoRule.lastChapter) {
          const lastChapterValue = RuleEngine.parseRule(bookInfoRule.lastChapter, html);
          if (lastChapterValue) {
            enriched.latestChapter = RuleEngine.cleanText(lastChapterValue);
          }
        }

        if (bookInfoRule.tocUrl) {
          const tocUrlValue = RuleEngine.parseRule(bookInfoRule.tocUrl, html);
          if (tocUrlValue) {
            enriched.bookUrl = this.resolveUrl(source.url, tocUrlValue);
          }
        }
      } else {
        // 如果没有 BookInfoRule，尝试通用提取
        enriched.name = this.tryExtractGeneric(html, book.name,
          ['h1', '.book-name', '.book-title', '.novel-title', 'meta[property="og:novel:book_name"]@content']);
        enriched.author = this.tryExtractGeneric(html, book.author,
          ['.author', '.writer', '.book-author', 'meta[property="og:novel:author"]@content']);
        enriched.cover = this.tryExtractGeneric(html, book.cover || '',
          ['.book-cover img@src', '.novel-cover img@src', 'meta[property="og:image"]@content']);
        enriched.intro = this.tryExtractGeneric(html, book.intro || '',
          ['.intro', '.description', '.book-intro', 'meta[property="og:description"]@content']);
      }

      return enriched;

    } catch (error) {
      Logger.warn(this.TAG, `获取书籍详情失败: ${error}，使用已有信息`);
      return book;
    }
  }

  /**
   * Phase 2: 获取章节列表（支持分页）
   */
  private async fetchChapterList(
    book: Book,
    source: BookSource,
    onProgress?: CrawlProgressCallback
  ): Promise<ChapterListResult> {
    const chapters: Chapter[] = [];
    const errors: CrawlChapterError[] = [];
    const tocRule = source.rules.tocRule;

    if (!tocRule || !tocRule.chapterList) {
      Logger.warn(this.TAG, `书源 ${source.name} 未配置章节规则`);
      return { chapters, errors };
    }

    let currentUrl = book.bookUrl;
    let pageCount = 0;
    const maxPages = 50; // 最大分页数，防止无限循环

    try {
      while (currentUrl && pageCount < maxPages && !this.isCancelled) {
        pageCount++;
        const fullUrl = this.resolveUrl(source.url, currentUrl);

        Logger.info(this.TAG, `获取章节列表 第${pageCount}页: ${fullUrl}`);

        await this.throttler.acquire(fullUrl);

        const html = await NetworkAdapter.get(
          fullUrl,
          this.parseCustomHeaders(source.networkConfig?.header)
        );

        if (!html || html.length < 100) {
          Logger.warn(this.TAG, `章节列表页${pageCount}内容为空`);
          break;
        }

        RuleEngine.setContext({ baseUrl: source.url, html: html });

        const parsedChapters = ContentParser.parseChapterList(html, source);

        if (parsedChapters.length === 0) {
          Logger.warn(this.TAG, `第${pageCount}页未解析到章节`);
          // 尝试使用 TocRule 中的 nextUrl
          if (tocRule.nextUrl) {
            const nextUrl = RuleEngine.parseRule(tocRule.nextUrl, html);
            if (nextUrl && nextUrl !== currentUrl) {
              currentUrl = this.resolveUrl(source.url, nextUrl);
              continue;
            }
          }
          break;
        }

        const startOrder = chapters.length;
        for (let i = 0; i < parsedChapters.length; i++) {
          const item = parsedChapters[i];
          const chapterId = IdGenerator.generateChapterId(book.id, item.url);

          const chapter: Chapter = {
            id: chapterId,
            bookId: book.id,
            title: item.title,
            url: this.resolveUrl(source.url, item.url),
            order: startOrder + i,
            isVip: item.isVip
          };
          chapters.push(chapter);
        }

        Logger.info(this.TAG, `第${pageCount}页解析到 ${parsedChapters.length} 个章节，累计 ${chapters.length} 个`);

        this.reportProgress(onProgress, {
          phase: 'chapters',
          totalChapters: chapters.length,
          downloadedChapters: 0,
          currentChapter: '',
          failedChapters: 0,
          skippedChapters: 0,
          percent: Math.min(5 + pageCount * 2, 15)
        });

        // 查找下一页
        if (tocRule.nextUrl) {
          const nextUrl = RuleEngine.parseRule(tocRule.nextUrl, html);
          if (nextUrl && nextUrl !== currentUrl && nextUrl.trim().length > 0) {
            currentUrl = this.resolveUrl(source.url, nextUrl);
          } else {
            currentUrl = '';
          }
        } else {
          currentUrl = '';
        }
      }

      Logger.info(this.TAG, `章节列表获取完成: ${chapters.length} 个章节, ${pageCount} 页`);
      return { chapters, errors };

    } catch (error) {
      Logger.error(this.TAG, `获取章节列表失败: ${error}`);
      const ce: CrawlChapterError = {
        chapterTitle: '章节列表',
        chapterUrl: currentUrl,
        error: error instanceof Error ? error.message : String(error),
        retryCount: 0
      };
      errors.push(ce);
      return { chapters, errors };
    }
  }

  /**
   * Phase 3: 下载章节内容（并发控制）
   */
  private async downloadChapters(
    book: Book,
    source: BookSource,
    chapters: Chapter[],
    existingContents: ChapterContent[],
    existingErrors: CrawlChapterError[],
    onProgress?: CrawlProgressCallback
  ): Promise<DownloadResult> {
    const contents: ChapterContent[] = [...existingContents];
    const errors: CrawlChapterError[] = [...existingErrors];
    const maxConcurrent = this.config.maxConcurrentChapters;
    const total = chapters.length;

    const pending = chapters.filter(ch => !ch.isVip);

    let downloaded = 0;
    let failed = 0;
    let skipped = 0;

    Logger.info(this.TAG, `开始下载 ${pending.length} 个章节，并发 ${maxConcurrent}`);

    while (pending.length > 0 && !this.isCancelled) {
      const batch = pending.splice(0, Math.min(maxConcurrent, pending.length));
      const promises: Promise<void>[] = [];

      for (const chapter of batch) {
        const promise = this.downloadChapter(chapter, source)
          .then((result: ChapterDownloadResult) => {
            if (result.content && result.content.length >= this.config.minContentLength) {
              const chapterContent: ChapterContent = {
                chapterId: chapter.id,
                content: result.content,
                nextUrl: undefined,
                prevUrl: undefined
              };
              contents.push(chapterContent);
              downloaded++;
            } else {
              const ce: CrawlChapterError = {
                chapterTitle: chapter.title,
                chapterUrl: chapter.url,
                error: result.error || '内容为空或过短',
                retryCount: result.retryCount
              };
              errors.push(ce);
              failed++;
            }
          })
          .catch((error: Error) => {
            const ce: CrawlChapterError = {
              chapterTitle: chapter.title,
              chapterUrl: chapter.url,
              error: error.message,
              retryCount: this.config.chapterRetryCount
            };
            errors.push(ce);
            failed++;
          });

        promises.push(promise);
      }

      await Promise.all(promises);

      // 更新进度
      const percent = total > 0
        ? 15 + Math.floor(((downloaded + failed + skipped) / total) * 85)
        : 15;

      const currentTitle = batch.length > 0 ? batch[batch.length - 1].title : '';
      this.reportProgress(onProgress, {
        phase: 'content',
        totalChapters: total,
        downloadedChapters: downloaded,
        currentChapter: currentTitle,
        failedChapters: failed,
        skippedChapters: skipped,
        percent: Math.min(percent, 99)
      });
    }

    const enrichedBook = this.cloneBook(book);
    enrichedBook.totalChapters = chapters.length;
    enrichedBook.currentChapterIndex = 0;
    enrichedBook.latestChapter = chapters.length > 0 ? chapters[chapters.length - 1].title : book.latestChapter;
    enrichedBook.lastUpdateTime = Date.now();

    return { book: enrichedBook, contents, errors };
  }

  /**
   * 下载单个章节（含重试）
   */
  private async downloadChapter(
    chapter: Chapter,
    source: BookSource
  ): Promise<ChapterDownloadResult> {
    const maxRetries = this.config.chapterRetryCount;
    let retryCount = 0;

    while (retryCount <= maxRetries && !this.isCancelled) {
      try {
        if (retryCount > 0) {
          const delay = Math.min(
            this.config.retryBaseDelay * Math.pow(2, retryCount - 1),
            this.config.retryMaxDelay
          );
          const jitter = Math.random() * delay * 0.3;
          await this.sleep(delay + jitter);
        }

        await this.throttler.acquire(chapter.url);

        const headers = this.parseCustomHeaders(source.networkConfig?.header);
        const html = await NetworkAdapter.get(chapter.url, headers);

        if (this.crawlerManager.detectBlocking(html)) {
          Logger.warn(this.TAG, `章节被阻止: ${chapter.title}`);
          retryCount++;
          continue;
        }

        RuleEngine.setContext({ baseUrl: source.url, html: html });

        let content = ContentParser.parseChapterContent(html, source);

        if (this.config.enableContentCleaning) {
          content = this.cleanChapterContent(content, source);
        }

        if (this.config.enableContentValidation) {
          if (content.length < this.config.minContentLength) {
            Logger.warn(this.TAG,
              `章节内容过短: ${chapter.title}, ${content.length} 字符`
            );
            retryCount++;
            continue;
          }
        }

        Logger.debug(this.TAG, `章节下载成功: ${chapter.title}, ${content.length} 字符`);
        return { content, retryCount };

      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);

        if (this.crawlerManager.shouldRetry(errorMsg)) {
          retryCount++;
          Logger.warn(this.TAG,
            `章节下载失败，重试 ${retryCount}/${maxRetries}: ${chapter.title}, ${errorMsg}`
          );
        } else {
          Logger.error(this.TAG, `章节下载致命错误: ${chapter.title}, ${errorMsg}`);
          return { content: '', error: errorMsg, retryCount };
        }
      }
    }

    return {
      content: '',
      error: `超过最大重试次数 ${maxRetries}`,
      retryCount
    };
  }

  /**
   * 清理章节内容
   */
  private cleanChapterContent(content: string, source: BookSource): string {
    if (!content) {
      return '';
    }

    const cleaningOpts: CleaningOptions = {
      stripHtmlTags: false,
      normalizeWhitespace: true,
      removeScripts: true,
      removeStyles: true,
      removeComments: true,
      decodeEntities: true,
      trimContent: true,
      removeEmptyLines: true,
      maxLineLength: 5000
    };

    let cleaned = this.validator.cleanContent(content, cleaningOpts);

    return cleaned;
  }

  /**
   * 仅获取章节列表（不下载内容）
   */
  async fetchChaptersOnly(
    book: Book,
    source: BookSource,
    onProgress?: CrawlProgressCallback
  ): Promise<ChapterListResult> {
    this.isCancelled = false;
    return this.fetchChapterList(book, source, onProgress);
  }

  /**
   * 仅下载指定章节内容
   */
  async downloadSpecificChapters(
    book: Book,
    source: BookSource,
    targetChapters: Chapter[],
    onProgress?: CrawlProgressCallback
  ): Promise<SpecificDownloadResult> {
    this.isCancelled = false;
    const contents: ChapterContent[] = [];
    const errors: CrawlChapterError[] = [];

    this.monitor.startSession();

    const result = await this.downloadChapters(
      book, source, targetChapters, contents, errors, onProgress
    );

    this.monitor.endSession();

    return { contents: result.contents, errors: result.errors };
  }

  /**
   * 快速爬取：直接从URL开始（无需搜索）
   */
  async crawlFromUrl(
    bookUrl: string,
    bookName: string,
    source: BookSource,
    onProgress?: CrawlProgressCallback
  ): Promise<CrawlResult> {
    const book: Book = {
      id: IdGenerator.generateBookId(source.id, bookUrl),
      name: bookName,
      author: '',
      cover: undefined,
      intro: undefined,
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookSourceId: source.id,
      bookSourceName: source.name,
      bookUrl: bookUrl,
      lastUpdateTime: Date.now(),
      addTime: Date.now(),
      readProgress: 0,
      lastReadChapter: undefined,
      lastReadChapterIndex: undefined
    };

    return this.crawlBook(book, source, onProgress);
  }

  // ==================== 工具方法 ====================

  private cloneBook(book: Book): Book {
    return {
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
      sourceStatus: book.sourceStatus
    };
  }

  private resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (!relativeUrl) {
      return '';
    }
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    if (relativeUrl.startsWith('//')) {
      return 'https:' + relativeUrl;
    }

    let base = baseUrl;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    if (relativeUrl.startsWith('/')) {
      const protocolEnd = base.indexOf('://');
      if (protocolEnd === -1) {
        return relativeUrl;
      }
      const hostStart = protocolEnd + 3;
      const pathStart = base.indexOf('/', hostStart);
      const host = pathStart === -1 ? base.substring(hostStart) : base.substring(hostStart, pathStart);
      const protocol = base.substring(0, protocolEnd + 3);
      return protocol + host + relativeUrl;
    }

    const lastSlash = base.lastIndexOf('/');
    const basePath = lastSlash > base.indexOf('://') + 2 ? base.substring(0, lastSlash + 1) : base + '/';
    return basePath + relativeUrl;
  }

  private parseCustomHeaders(headerStr?: string): Record<string, string> {
    const headers: Record<string, string> = {};
    if (!headerStr) {
      return headers;
    }

    try {
      const parsed = JSON.parse(headerStr) as Record<string, string>;
      const keys = Object.keys(parsed);
      for (const key of keys) {
        headers[key] = parsed[key];
      }
    } catch {
      // header 不是 JSON，可能是键值对格式
      const lines = headerStr.split(/[\n\r]+/);
      for (const line of lines) {
        const colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          const key = line.substring(0, colonIndex).trim();
          const value = line.substring(colonIndex + 1).trim();
          if (key && value) {
            headers[key] = value;
          }
        }
      }
    }

    return headers;
  }

  private tryExtractGeneric(html: string, defaultValue: string, selectors: string[]): string {
    if (defaultValue) {
      return defaultValue;
    }

    for (const selector of selectors) {
      try {
        const value = CssSelectorParser.extractValue(html, selector);
        if (value && value.trim().length > 0) {
          return RuleEngine.cleanText(value);
        }
      } catch {
        // continue
      }
    }

    return defaultValue;
  }

  private reportProgress(
    callback: CrawlProgressCallback | undefined,
    progress: CrawlProgress
  ): void {
    if (callback) {
      try {
        callback(progress);
      } catch (e) {
        Logger.warn(this.TAG, `进度回调异常: ${e}`);
      }
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export default NovelCrawler.getInstance();
