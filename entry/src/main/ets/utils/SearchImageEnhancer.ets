import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ImageScrapeManager, BookImageResult, ScrapeProgress } from './ImageScrapeManager';
import { ImageScraperService, ImageDownloadResult, ImageScrapeStats } from './ImageScraperService';
import { ImageDetector, ImageCandidate } from './ImageDetector';
import { Logger } from './Logger';
import common from '@ohos.app.ability.common';

export interface ImageEnhancedBook extends Book {
  localCoverPath?: string;
  coverMetadata?: {
    format: string;
    width: number;
    height: number;
    size: number;
  };
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
    const opts = { ...DEFAULT_OPTIONS, ...options };
    const enhancedBook: ImageEnhancedBook = {
      ...book,
      imageScrapeStatus: 'pending'
    };

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
        enhancedBook.coverMetadata = {
          format: result.format || 'unknown',
          width: result.width || 0,
          height: result.height || 0,
          size: result.size || 0
        };
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
    const opts = { ...DEFAULT_OPTIONS, ...options };
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
          return this.enhanceBookWithImage(book, bookSource, html, {
            ...opts,
            onProgress: (bookId, status, progress) => {
              opts.onProgress?.(bookId, status, (completed / books.length) * 100 + progress / books.length);
            }
          });
        })
      );

      results.push(...chunkResults);
      completed += chunk.length;

      if (chunks.indexOf(chunk) < chunks.length - 1) {
        await this.delay(500);
      }
    }

    return results;
  }

  async batchDownloadCovers(
    books: Array<{ book: Book; bookSource: BookSource; html?: string }>,
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

  async getStorageUsage(): Promise<{ totalSize: number; imageCount: number; bookCount: number }> {
    return this.imageScraperService.getStorageUsage();
  }

  async cleanupOldImages(maxAgeDays: number = 30): Promise<number> {
    return this.imageScraperService.cleanupOldImages(maxAgeDays * 24 * 60 * 60 * 1000);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export function createImageEnhancedSearch(
  context: common.UIAbilityContext
): SearchImageEnhancer {
  const enhancer = SearchImageEnhancer.getInstance();
  enhancer.setContext(context);
  return enhancer;
}
