/**
 * EnhancedSearchResult - 增强版搜索结果模型
 * 包含改进的去重逻辑和相关性评分算法
 */

import { Book } from './Book';
import { Logger } from '../utils/performance/Logger';

export interface PagedSearchResult {
  books: Book[];
  totalCount: number;
  currentPage: number;
  pageSize: number;
  totalPages: number;
  hasMore: boolean;
  sourceStats: SourceSearchStats[];
}

export interface SourceSearchStats {
  sourceId: string;
  sourceName: string;
  resultCount: number;
  success: boolean;
  error?: string;
  responseTime: number;
}

export interface SearchPaginationConfig {
  pageSize: number;
  maxResultsPerSource: number;
  maxTotalResults: number;
  enableDeduplication: boolean;
  sortByRelevance: boolean;
  enableSourceWeight: boolean;
}

export const DEFAULT_PAGINATION_CONFIG: SearchPaginationConfig = {
  pageSize: 15,
  maxResultsPerSource: 20,
  maxTotalResults: 200,
  enableDeduplication: true,
  sortByRelevance: true,
  enableSourceWeight: true
};

export interface SearchProgress {
  totalSources: number;
  completedSources: number;
  currentSource: string;
  foundBooks: number;
  isComplete: boolean;
  newBooks?: Book[];
}

export interface SearchStopCondition {
  maxBooks: number;
  maxTime: number;
  minSources: number;
}

export const DEFAULT_STOP_CONDITION: SearchStopCondition = {
  maxBooks: 50,
  maxTime: 15000,
  minSources: 3
};

export class EnhancedSearchResultBuilder {
  private allBooks: Book[] = [];
  private sourceStats: SourceSearchStats[] = [];
  private config: SearchPaginationConfig;
  private seenKeys: Map<string, Book> = new Map(); // 使用Map以便合并信息
  private searchKeyword?: string;

  constructor(config: SearchPaginationConfig, keyword?: string) {
    this.config = config;
    this.searchKeyword = keyword;
  }

  addSourceResult(
    sourceId: string,
    sourceName: string,
    books: Book[],
    success: boolean,
    error?: string,
    responseTime: number = 0
  ): Book[] {
    const stats: SourceSearchStats = {
      sourceId,
      sourceName,
      resultCount: books.length,
      success,
      error,
      responseTime
    };
    this.sourceStats.push(stats);

    const newBooks: Book[] = [];
    if (success && books.length > 0) {
      for (let i = 0; i < books.length; i++) {
        const book = books[i];
        const key = this.generateBookKey(book);
        
        if (!this.seenKeys.has(key)) {
          this.seenKeys.set(key, book);
          this.allBooks.push(book);
          newBooks.push(book);
        } else {
          // 合并重复书籍的信息
          this.mergeBookInfo(key, book);
        }
      }
    }
    
    return newBooks;
  }

  build(page: number = 1): PagedSearchResult {
    let processedBooks = this.allBooks;

    if (this.config.enableDeduplication) {
      processedBooks = this.deduplicateBooks(processedBooks);
    }

    if (this.config.sortByRelevance) {
      processedBooks = this.sortByRelevance(processedBooks);
    }

    const totalCount = processedBooks.length;
    const totalPages = Math.ceil(totalCount / this.config.pageSize);
    const validPage = Math.max(1, Math.min(page, totalPages || 1));
    const startIndex = (validPage - 1) * this.config.pageSize;
    const endIndex = startIndex + this.config.pageSize;
    const pageBooks = processedBooks.slice(startIndex, endIndex);

    return {
      books: pageBooks,
      totalCount,
      currentPage: validPage,
      pageSize: this.config.pageSize,
      totalPages,
      hasMore: validPage < totalPages,
      sourceStats: this.sourceStats
    };
  }

  /**
   * 生成书籍唯一标识键
   */
  private generateBookKey(book: Book): string {
    // 使用书名+作者+URL作为唯一标识
    const name = book.name?.toLowerCase().trim() || '';
    const author = book.author?.toLowerCase().trim() || '';
    const url = book.bookUrl?.toLowerCase().trim() || '';
    
    return `${name}_${author}_${url}`;
  }

  /**
   * 合并重复书籍的信息
   */
  private mergeBookInfo(key: string, newBook: Book): void {
    const existingBook = this.seenKeys.get(key);
    if (!existingBook) return;

    // 保留更完整的信息
    if (!existingBook.cover && newBook.cover) {
      existingBook.cover = newBook.cover;
    }
    
    if (!existingBook.intro && newBook.intro) {
      existingBook.intro = newBook.intro;
    }
    
    if (!existingBook.author && newBook.author) {
      existingBook.author = newBook.author;
    }
    
    if (!existingBook.kind && newBook.kind) {
      existingBook.kind = newBook.kind;
    }
    
    if (!existingBook.wordCount && newBook.wordCount) {
      existingBook.wordCount = newBook.wordCount;
    }
    
    if (!existingBook.latestChapter && newBook.latestChapter) {
      existingBook.latestChapter = newBook.latestChapter;
    }
  }

  private deduplicateBooks(books: Book[]): Book[] {
    const seen = new Map<string, Book>();
    const uniqueBooks: Book[] = [];

    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      const key = this.generateBookKey(book);

      if (!seen.has(key)) {
        seen.set(key, book);
        uniqueBooks.push(book);
      } else {
        // 合并信息
        this.mergeBookInfo(key, book);
      }
    }

    return uniqueBooks;
  }

  private sortByRelevance(books: Book[]): Book[] {
    return books.sort((a: Book, b: Book) => {
      const scoreA = this.calculateRelevanceScore(a);
      const scoreB = this.calculateRelevanceScore(b);
      return scoreB - scoreA;
    });
  }

  private calculateRelevanceScore(book: Book): number {
    let score = 0;

    // 基础分
    if (book.cover && book.cover.length > 0) {
      score += 10;
    }
    if (book.intro && book.intro.length > 0) {
      score += 5;
    }
    if (book.author && book.author !== '未知作者') {
      score += 5;
    }
    if (book.wordCount && book.wordCount > 0) {
      score += Math.min(book.wordCount / 100000, 10);
    }

    // 关键词匹配度（如果提供关键词）
    if (this.searchKeyword && this.searchKeyword.trim().length > 0) {
      const name = book.name?.toLowerCase() || '';
      const kw = this.searchKeyword.toLowerCase().trim();
      
      if (name === kw) {
        score += 50; // 完全匹配
      } else if (name.startsWith(kw)) {
        score += 30; // 前缀匹配
      } else if (name.includes(kw)) {
        score += 20; // 包含匹配
      }
      
      // 简介中包含关键词
      if (book.intro && book.intro.toLowerCase().includes(kw)) {
        score += 5;
      }
      
      // 作者中包含关键词
      if (book.author && book.author.toLowerCase().includes(kw)) {
        score += 10;
      }
    }

    // 书源质量权重（如果启用）
    if (this.config.enableSourceWeight) {
      try {
        // 动态导入以避免循环依赖
        const sourceHealthManagerModule = import('../utils/SourceHealthManager.js');
        sourceHealthManagerModule.then((module: SourceHealthManagerModule) => {
          const sourceScore = module.sourceHealthManager.getSourceScore(book.bookSourceId);
          const sourceWeight = sourceScore / 100; // 转换为 0-1 权重
          score = score * (0.7 + 0.3 * sourceWeight); // 70%内容分 + 30%书源质量
        }).catch((error: Error) => {
          Logger.debug('EnhancedSearchResultBuilder', `无法获取书源质量: ${error.message}`);
        });
      } catch (error) {
        Logger.debug('EnhancedSearchResultBuilder', `无法获取书源质量: ${(error as Error).message}`);
      }
    }

    return score;
  }

  getTotalCount(): number {
    return this.allBooks.length;
  }

  getSourceStats(): SourceSearchStats[] {
    return this.sourceStats;
  }

  getAllBooks(): Book[] {
    return [...this.allBooks];
  }

  /**
   * 获取去重统计信息
   */
  getDeduplicationStats(): DeduplicationStats {
    const totalProcessed = this.sourceStats.reduce((sum, stats) => sum + stats.resultCount, 0);
    const uniqueCount = this.allBooks.length;
    const duplicateCount = totalProcessed - uniqueCount;
    const deduplicationRate = totalProcessed > 0 ? (duplicateCount / totalProcessed) * 100 : 0;

    return {
      totalProcessed,
      uniqueCount,
      duplicateCount,
      deduplicationRate: Math.round(deduplicationRate * 100) / 100
    };
  }

  /**
   * 获取相关性评分统计
   */
  getRelevanceStats(): RelevanceStats {
    if (this.allBooks.length === 0) {
      return { avgScore: 0, minScore: 0, maxScore: 0 };
    }

    let totalScore = 0;
    let minScore = Number.MAX_SAFE_INTEGER;
    let maxScore = 0;

    for (const book of this.allBooks) {
      const score = this.calculateRelevanceScore(book);
      totalScore += score;
      minScore = Math.min(minScore, score);
      maxScore = Math.max(maxScore, score);
    }

    return {
      avgScore: Math.round((totalScore / this.allBooks.length) * 100) / 100,
      minScore: Math.round(minScore * 100) / 100,
      maxScore: Math.round(maxScore * 100) / 100
    };
  }
}

export interface DeduplicationStats {
  totalProcessed: number;
  uniqueCount: number;
  duplicateCount: number;
  deduplicationRate: number;
}

export interface RelevanceStats {
  avgScore: number;
  minScore: number;
  maxScore: number;
}

/**
 * SourceHealthManager 接口
 * 用于动态导入时的类型定义
 */
interface SourceHealthManager {
  getSourceScore(sourceId: string): number;
}

/**
 * SourceHealthManager 模块接口
 * 用于动态导入时的类型定义
 */
interface SourceHealthManagerModule {
  sourceHealthManager: SourceHealthManager;
}

export default EnhancedSearchResultBuilder;