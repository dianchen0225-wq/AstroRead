/**
 * 分页搜索结果模型
 */

import { Book } from './Book';
import { Logger } from '../utils/Logger';

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
}

export const DEFAULT_PAGINATION_CONFIG: SearchPaginationConfig = {
  pageSize: 15,
  maxResultsPerSource: 20,
  maxTotalResults: 200,
  enableDeduplication: true,
  sortByRelevance: true
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
  maxTime: 12000,
  minSources: 2
};

export class SearchResultBuilder {
  private allBooks: Book[] = [];
  private sourceStats: SourceSearchStats[] = [];
  private config: SearchPaginationConfig;
  private seenKeys: Set<string> = new Set();

  constructor(config: SearchPaginationConfig) {
    this.config = config;
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
        
        // 跳过无效书籍
        if (!book.name || book.name.trim().length === 0) {
          continue;
        }
        
        // 生成唯一键（使用更严格的去重规则）
        const normalizedName = this.normalizeText(book.name);
        const normalizedAuthor = this.normalizeText(book.author || '');
        const key = `${normalizedName}_${normalizedAuthor}`;
        
        if (!this.seenKeys.has(key)) {
          this.seenKeys.add(key);
          // 确保书籍有必要的字段
          if (!book.author || book.author.trim().length === 0) {
            book.author = '未知作者';
          }
          this.allBooks.push(book);
          newBooks.push(book);
        }
      }
    }
    
    return newBooks;
  }

  /**
   * 标准化文本用于去重比较
   */
  private normalizeText(text: string): string {
    if (!text) return '';
    return text
      .toLowerCase()
      .trim()
      .replace(/\s+/g, ' ')
      .replace(/[[:punct:]]/g, '');
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

  private deduplicateBooks(books: Book[]): Book[] {
    const seen = new Set<string>();
    const uniqueBooks: Book[] = [];

    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      const key = `${book.name}_${book.author || ''}`.toLowerCase().trim();

      if (!seen.has(key)) {
        seen.add(key);
        uniqueBooks.push(book);
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

    // 封面图片质量
    if (book.cover && book.cover.length > 0) {
      score += 10;
      // 封面URL有效性额外加分
      if (book.cover.startsWith('http')) {
        score += 5;
      }
    }
    
    // 简介完整度
    if (book.intro && book.intro.length > 0) {
      const introLength = book.intro.length;
      score += Math.min(introLength / 50, 10);
    }
    
    // 作者信息
    if (book.author && book.author !== '未知作者') {
      score += 8;
    }
    
    // 字数
    if (book.wordCount && book.wordCount > 0) {
      score += Math.min(book.wordCount / 50000, 15);
    }
    
    // 最新章节
    if (book.latestChapter && book.latestChapter.length > 0) {
      score += 5;
    }
    
    // 分类信息
    if (book.kind && book.kind.length > 0) {
      score += 3;
    }
    
    // 书源可靠性（根据响应时间）
    const sourceStat = this.sourceStats.find(s => s.sourceId === book.bookSourceId);
    if (sourceStat && sourceStat.success) {
      // 响应时间越快，得分越高
      if (sourceStat.responseTime < 1000) {
        score += 10;
      } else if (sourceStat.responseTime < 3000) {
        score += 5;
      } else if (sourceStat.responseTime < 5000) {
        score += 2;
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
}
