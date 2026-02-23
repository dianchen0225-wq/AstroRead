import { Book } from '../../models/Book';
import { BookSource } from '../../models/BookSource';
import { ImageScrapeManager, BookImageResult, ScrapeProgress, StorageUsageResult } from '../crawler/ImageScrapeManager';
import { ImageScraperService, ImageDownloadResult, ImageScrapeStats } from '../crawler/ImageScraperService';
import { ImageDetector, ImageCandidate } from '../crawler/ImageDetector';
import { Logger } from '../performance/Logger';
import { common } from '@kit.AbilityKit';

export interface CoverMetadata {
  format: string;
  width: number;
  height: number;
  size: number;
}

export interface ImageEnhancedBook extends Book {
  localCoverPath?: string;
  coverMetadata?: CoverMetadata;
  imageScrapeStatus?: 'pending' | 'downloading' | 'completed' | 'failed';
  imageScrapeError?: string;
}

export interface ImageScrapeOptions {
  downloadCovers: boolean;
  detectFromHtml: boolean;
  fallbackToPlaceholder: boolean;
  maxConcurrent: number;
  onProgress?: (bookId: string, status: string, progress: number) => void;
  onComplete?: (book: ImageEnhancedBook) => void;
}

export interface BatchImageResult {
  totalBooks: number;
  successfulDownloads: number;
  failedDownloads: number;
  skippedBooks: number;
  totalBytes: number;
  averageDownloadTime: number;
  results: Map<string, BookImageResult>;
}

export interface BookSourceItem {
  book: Book;
  bookSource: BookSource;
  html?: string;
}

const DEFAULT_OPTIONS: ImageScrapeOptions = {
  downloadCovers: true,
  detectFromHtml: false,
  fallbackToPlaceholder: false,
  maxConcurrent: 3
};

export class SearchImageEnhancer {
  private static instance: SearchImageEnhancer | null = null;
  private imageScrapeManager: ImageScrapeManager;
  private imageScraperService: ImageScraperService;
  private imageDetector: ImageDetector;
  private context: common.UIAbilityContext | null = null;
  private readonly TAG = 'SearchImageEnhancer';

  private constructor() {
    this.imageScrapeManager = ImageScrapeManager.getInstance();
    this.imageScraperService = ImageScraperService.getInstance();
    this.imageDetector = new ImageDetector();
  }

  static getInstance(): SearchImageEnhancer {
    if (!SearchImageEnhancer.instance) {
      SearchImageEnhancer.instance = new SearchImageEnhancer();
    }
    return SearchImageEnhancer.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.imageScrapeManager.setContext(context);
    this.imageScraperService.setContext(context);
  }

  async enhanceBookWithImage(
    book: Book,
    bookSource: BookSource,
    html?: string,
    options?: Partial<ImageScrapeOptions>
  ): Promise<ImageEnhancedBook> {
    const opts: ImageScrapeOptions = this.mergeOptions(DEFAULT_OPTIONS, options);
    const enhancedBook: ImageEnhancedBook = this.createEnhancedBook(book);

    if (!opts.downloadCovers) {
      enhancedBook.imageScrapeStatus = 'completed';
      return enhancedBook;
    }

    try {
      enhancedBook.imageScrapeStatus = 'downloading';
      opts.onProgress?.(book.id, 'downloading', 0);

      let coverUrl = book.cover;

      if (!coverUrl && opts.detectFromHtml && html) {
        const candidates = this.imageDetector.detectBookCoverImages(html, bookSource.url);
        const bestCandidate = this.imageDetector.selectBestImage(candidates);

        if (bestCandidate) {
          coverUrl = bestCandidate.url;
          enhancedBook.cover = coverUrl;
          Logger.info(this.TAG, `Detected cover for "${book.name}": ${coverUrl}`);
        }
      }

      if (!coverUrl) {
        enhancedBook.imageScrapeStatus = 'completed';
        enhancedBook.imageScrapeError = 'No cover URL available';
        opts.onProgress?.(book.id, 'completed', 100);
        return enhancedBook;
      }

      const result = await this.imageScraperService.downloadImage(coverUrl, book.id, 'cover');

      if (result.success && result.localPath) {
        enhancedBook.localCoverPath = result.localPath;
        const metadata: CoverMetadata = {
          format: result.format || 'unknown',
          width: result.width || 0,
          height: result.height || 0,
          size: result.size || 0
        };
        enhancedBook.coverMetadata = metadata;
        enhancedBook.imageScrapeStatus = 'completed';
        opts.onProgress?.(book.id, 'completed', 100);
      } else {
        enhancedBook.imageScrapeStatus = 'failed';
        enhancedBook.imageScrapeError = result.errorMessage || 'Download failed';
        opts.onProgress?.(book.id, 'failed', 0);
      }
    } catch (error) {
      enhancedBook.imageScrapeStatus = 'failed';
      enhancedBook.imageScrapeError = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `Failed to enhance book "${book.name}": ${enhancedBook.imageScrapeError}`);
      opts.onProgress?.(book.id, 'failed', 0);
    }

    opts.onComplete?.(enhancedBook);
    return enhancedBook;
  }

  async enhanceBooksWithImages(
    books: Book[],
    bookSource: BookSource,
    htmlMap?: Map<string, string>,
    options?: Partial<ImageScrapeOptions>
  ): Promise<ImageEnhancedBook[]> {
    const opts: ImageScrapeOptions = this.mergeOptions(DEFAULT_OPTIONS, options);
    const results: ImageEnhancedBook[] = [];
    let completed = 0;

    const chunks: Book[][] = [];
    for (let i = 0; i < books.length; i += opts.maxConcurrent) {
      chunks.push(books.slice(i, i + opts.maxConcurrent));
    }

    for (const chunk of chunks) {
      const chunkResults = await Promise.all(
        chunk.map(async book => {
          const html = htmlMap?.get(book.bookUrl);
          const bookOptions: ImageScrapeOptions = this.createBookOptions(opts, book.id, books.length, completed);
          return this.enhanceBookWithImage(book, bookSource, html, bookOptions);
        })
      );

      for (const result of chunkResults) {
        results.push(result);
      }
      completed += chunk.length;

      if (chunks.indexOf(chunk) < chunks.length - 1) {
        await this.delay(500);
      }
    }

    return results;
  }

  async batchDownloadCovers(
    books: BookSourceItem[],
    onProgress?: (progress: ScrapeProgress) => void
  ): Promise<BatchImageResult> {
    const results = new Map<string, BookImageResult>();
    let successfulDownloads = 0;
    let failedDownloads = 0;
    let totalBytes = 0;
    let totalTime = 0;

    const unsubscribe = this.imageScrapeManager.onProgress(progress => {
      onProgress?.(progress);
    });

    try {
      for (const item of books) {
        const result = await this.imageScrapeManager.scrapeBookCover(
          item.book,
          item.bookSource,
          item.html
        );

        results.set(item.book.id, result);

        if (result.success) {
          successfulDownloads++;
          totalBytes += result.metadata.size;
          totalTime += result.metadata.downloadTime;
        } else {
          failedDownloads++;
        }
      }
    } finally {
      unsubscribe();
    }

    return {
      totalBooks: books.length,
      successfulDownloads,
      failedDownloads,
      skippedBooks: 0,
      totalBytes,
      averageDownloadTime: successfulDownloads > 0 ? totalTime / successfulDownloads : 0,
      results
    };
  }

  detectCoverFromHtml(html: string, baseUrl: string): ImageCandidate[] {
    return this.imageDetector.detectBookCoverImages(html, baseUrl);
  }

  selectBestCover(candidates: ImageCandidate[]): ImageCandidate | null {
    return this.imageDetector.selectBestImage(candidates);
  }

  async downloadSingleImage(
    url: string,
    bookId: string
  ): Promise<ImageDownloadResult> {
    return this.imageScraperService.downloadImage(url, bookId, 'cover');
  }

  getStats(): ImageScrapeStats {
    return this.imageScraperService.getStats();
  }

  resetStats(): void {
    this.imageScraperService.resetStats();
  }

  async getStorageUsage(): Promise<StorageUsageResult> {
    return this.imageScraperService.getStorageUsage();
  }

  async cleanupOldImages(maxAgeDays: number = 30): Promise<number> {
    return this.imageScraperService.cleanupOldImages(maxAgeDays * 24 * 60 * 60 * 1000);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private mergeOptions(defaults: ImageScrapeOptions, partial?: Partial<ImageScrapeOptions>): ImageScrapeOptions {
    const result: ImageScrapeOptions = {
      downloadCovers: partial?.downloadCovers ?? defaults.downloadCovers,
      detectFromHtml: partial?.detectFromHtml ?? defaults.detectFromHtml,
      fallbackToPlaceholder: partial?.fallbackToPlaceholder ?? defaults.fallbackToPlaceholder,
      maxConcurrent: partial?.maxConcurrent ?? defaults.maxConcurrent,
      onProgress: partial?.onProgress ?? defaults.onProgress,
      onComplete: partial?.onComplete ?? defaults.onComplete
    };
    return result;
  }

  private createEnhancedBook(book: Book): ImageEnhancedBook {
    const enhancedBook: ImageEnhancedBook = {
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
      sourceStatus: book.sourceStatus,
      imageScrapeStatus: 'pending'
    };
    return enhancedBook;
  }

  private createBookOptions(
    opts: ImageScrapeOptions,
    bookId: string,
    totalBooks: number,
    completed: number
  ): ImageScrapeOptions {
    const bookOptions: ImageScrapeOptions = {
      downloadCovers: opts.downloadCovers,
      detectFromHtml: opts.detectFromHtml,
      fallbackToPlaceholder: opts.fallbackToPlaceholder,
      maxConcurrent: opts.maxConcurrent,
      onComplete: opts.onComplete,
      onProgress: (id: string, status: string, progress: number) => {
        opts.onProgress?.(id, status, (completed / totalBooks) * 100 + progress / totalBooks);
      }
    };
    return bookOptions;
  }
}

export function createImageEnhancedSearch(
  context: common.UIAbilityContext
): SearchImageEnhancer {
  const enhancer = SearchImageEnhancer.getInstance();
  enhancer.setContext(context);
  return enhancer;
}
