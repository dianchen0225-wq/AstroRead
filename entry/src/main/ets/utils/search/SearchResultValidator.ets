/**
 * SearchResultValidator - 搜索结果验证器
 * 用于验证搜索结果的质量，过滤无效结果，标准化字段
 */

import { Book } from '../../models/Book';
import { Logger } from '../performance/Logger';

export class SearchResultValidator {
  private static readonly TAG = 'SearchResultValidator';
  
  private static minSimilarity: number = 0.1;  // 降低相似度阈值，让更多结果通过
  private static maxIntroLength: number = 500;  // 增加简介长度限制
  private static enableStrictValidation: boolean = false;  // 禁用严格验证

  static validateBook(book: Book, keyword: string): boolean {
    if (!book) {
      Logger.debug(SearchResultValidator.TAG, '书籍对象为空');
      return false;
    }

    if (!SearchResultValidator.validateRequiredFields(book)) {
      return false;
    }

    if (keyword && keyword.trim().length > 0) {
      const similarity = SearchResultValidator.calculateSimilarity(book.name, keyword);
      if (similarity < SearchResultValidator.minSimilarity) {
        Logger.debug(SearchResultValidator.TAG, 
          `相似度过低被过滤: ${book.name}, 相似度: ${similarity.toFixed(2)}, 阈值: ${SearchResultValidator.minSimilarity}`
        );
        return false;
      }
    }

    SearchResultValidator.normalizeFields(book);

    if (SearchResultValidator.enableStrictValidation) {
      if (!SearchResultValidator.validateAdditionalFields(book)) {
        return false;
      }
    }

    return true;
  }

  private static validateRequiredFields(book: Book): boolean {
    if (!book.name || book.name.trim().length === 0) {
      Logger.debug(SearchResultValidator.TAG, '书名缺失被过滤');
      return false;
    }

    if (!book.bookUrl || book.bookUrl.trim().length === 0) {
      Logger.debug(SearchResultValidator.TAG, `书籍URL缺失被过滤: ${book.name}`);
      return false;
    }

    if (!SearchResultValidator.isValidUrl(book.bookUrl)) {
      Logger.debug(SearchResultValidator.TAG, `URL格式无效被过滤: ${book.name}, URL: ${book.bookUrl}`);
      return false;
    }

    return true;
  }

  static calculateSimilarity(str1: string, str2: string): number {
    if (!str1 || !str2) return 0;
    
    const s1 = str1.toLowerCase().trim();
    const s2 = str2.toLowerCase().trim();
    
    if (s1 === s2) return 1.0;
    
    if (s1.startsWith(s2) || s2.startsWith(s1)) return 0.8;
    
    if (s1.includes(s2) || s2.includes(s1)) return 0.6;
    
    const set1 = new Set(s1.split(''));
    const set2 = new Set(s2.split(''));
    
    const intersection = new Set(Array.from(set1).filter(x => set2.has(x)));
    const union = new Set(Array.from(set1));
    set2.forEach(x => union.add(x));
    
    if (union.size === 0) return 0;
    return intersection.size / union.size;
  }

  private static normalizeFields(book: Book): void {
    if (book.name) {
      book.name = SearchResultValidator.normalizeText(book.name);
    }

    if (book.author) {
      book.author = SearchResultValidator.normalizeAuthor(book.author);
    } else {
      book.author = '未知作者';
    }

    if (book.intro) {
      book.intro = SearchResultValidator.normalizeIntro(book.intro);
    }

    if (book.cover) {
      book.cover = SearchResultValidator.normalizeUrl(book.cover);
    }

    if (book.bookUrl) {
      book.bookUrl = SearchResultValidator.normalizeUrl(book.bookUrl);
    }
  }

  private static normalizeText(text: string): string {
    if (!text) return '';
    
    return text
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static normalizeAuthor(author: string): string {
    if (!author) return '未知作者';
    
    let normalized = author.trim();
    
    const prefixes = [
      '作者:', '作者：', '著:', '著：', '作者 ', '作者 ',
      'Author:', 'Author：', 'By:', 'By：', '作者-', '作者-'
    ];
    
    for (let i = 0; i < prefixes.length; i++) {
      const prefix = prefixes[i];
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length).trim();
      }
    }
    
    const suffixes = ['著', '作者', 'author', 'by'];
    for (let i = 0; i < suffixes.length; i++) {
      const suffix = suffixes[i];
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length).trim();
      }
    }
    
    normalized = normalized
      .replace(/[【】\[\]()（）]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    
    return normalized || '未知作者';
  }

  private static normalizeIntro(intro: string): string {
    if (!intro) return '';
    
    let normalized = intro;
    
    normalized = normalized.replace(/<[^>]+>/g, '');
    
    normalized = SearchResultValidator.decodeHtmlEntities(normalized);
    
    normalized = normalized.replace(/\s+/g, ' ').trim();
    
    if (normalized.length > SearchResultValidator.maxIntroLength) {
      normalized = normalized.substring(0, SearchResultValidator.maxIntroLength) + '...';
    }
    
    return normalized;
  }

  private static normalizeUrl(url: string): string {
    if (!url) return '';
    
    let normalized = url.trim();
    
    if (normalized.startsWith('//')) {
      normalized = 'https:' + normalized;
    }
    
    return normalized;
  }

  private static isValidUrl(url: string): boolean {
    if (!url) return false;
    
    const urlPattern = /^(https?:\/\/)?([\w-]+\.)+[\w-]+(\/[\w-./?%&=]*)?$/;
    return urlPattern.test(url);
  }

  private static validateAdditionalFields(book: Book): boolean {
    if (book.name.length > 100) {
      Logger.debug(SearchResultValidator.TAG, `书名过长被过滤: ${book.name.substring(0, 30)}...`);
      return false;
    }
    
    if (book.author && book.author.length > 50) {
      Logger.debug(SearchResultValidator.TAG, `作者名过长被过滤: ${book.author.substring(0, 20)}...`);
      return false;
    }
    
    if (book.intro && book.intro.length > 500) {
      Logger.debug(SearchResultValidator.TAG, `简介过长: ${book.name}, 长度: ${book.intro.length}`);
    }
    
    return true;
  }

  static validateBooks(books: Book[], keyword: string): Book[] {
    const validBooks: Book[] = [];
    let filteredCount = 0;
    
    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      
      const bookCopy: Book = {
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
      
      if (SearchResultValidator.validateBook(bookCopy, keyword)) {
        validBooks.push(bookCopy);
      } else {
        filteredCount++;
      }
    }
    
    if (filteredCount > 0) {
      Logger.info(SearchResultValidator.TAG, 
        `验证完成: 原始 ${books.length} 本, 有效 ${validBooks.length} 本, 过滤 ${filteredCount} 本`
      );
    }
    
    return validBooks;
  }

  private static decodeHtmlEntities(text: string): string {
    let result = text;
    
    const entityList: [string, string][] = [
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
    ];
    
    for (let i = 0; i < entityList.length; i++) {
      const entity = entityList[i][0];
      const replacement = entityList[i][1];
      result = result.split(entity).join(replacement);
    }
    
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });
    
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });
    
    return result;
  }

  static setConfig(config: Partial<ValidatorConfig>): void {
    if (config.minSimilarity !== undefined) {
      SearchResultValidator.minSimilarity = Math.max(0, Math.min(1, config.minSimilarity));
    }
    
    if (config.maxIntroLength !== undefined) {
      SearchResultValidator.maxIntroLength = Math.max(50, Math.min(1000, config.maxIntroLength));
    }
    
    if (config.enableStrictValidation !== undefined) {
      SearchResultValidator.enableStrictValidation = config.enableStrictValidation;
    }
    
    Logger.info(SearchResultValidator.TAG, 
      `验证配置已更新: minSimilarity=${SearchResultValidator.minSimilarity}, ` +
      `maxIntroLength=${SearchResultValidator.maxIntroLength}, ` +
      `strictValidation=${SearchResultValidator.enableStrictValidation}`
    );
  }

  static getValidationStats(originalCount: number, validCount: number): ValidationStats {
    const filteredCount = originalCount - validCount;
    const passRate = originalCount > 0 ? (validCount / originalCount) * 100 : 100;
    
    const stats: ValidationStats = {
      originalCount: originalCount,
      validCount: validCount,
      filteredCount: filteredCount,
      passRate: Math.round(passRate * 100) / 100
    };
    return stats;
  }
}

export interface ValidatorConfig {
  minSimilarity: number;
  maxIntroLength: number;
  enableStrictValidation: boolean;
}

export interface ValidationStats {
  originalCount: number;
  validCount: number;
  filteredCount: number;
  passRate: number;
}
