/**
 * 搜索匹配增强器 - 优化书本搜索匹配算法
 * 提供智能匹配、模糊搜索、权重排序等功能
 */

import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { Logger } from './Logger';

interface MatchedBook {
  book: Book;
  score: number;
}

interface BookWithSource extends Book {
  bookSourceId: string;
  bookSourceName: string;
}

class SearchEnhancer {
  
  private TAG: string = 'SearchEnhancer';
  
  /**
   * 搜索匹配算法
   * @param books 待匹配的书籍列表
   * @param keyword 搜索关键词
   * @param source 书源信息
   * @returns 匹配的书籍列表
   */
  searchBooks(books: Array<Book>, keyword: string, source?: BookSource): Array<Book> {
    if (!books || books.length === 0 || !keyword || keyword.trim().length === 0) {
      return [];
    }
    
    const trimmedKeyword = keyword.trim().toLowerCase();
    const matchedBooks: Array<MatchedBook> = [];
    
    for (const book of books) {
      const score = this.calculateMatchScore(book, trimmedKeyword, source);
      if (score > 0) {
        matchedBooks.push({ book, score });
      }
    }
    
    // 按匹配度排序
    matchedBooks.sort((a: MatchedBook, b: MatchedBook) => b.score - a.score);
    
    Logger.debug(this.TAG, `搜索"${keyword}"匹配到${matchedBooks.length}本书`);
    return matchedBooks.map(item => item.book);
  }
  
  /**
   * 计算匹配分数
   */
  private calculateMatchScore(book: Book, keyword: string, source?: BookSource): number {
    let score = 0;
    
    // 书名匹配（权重最高）
    if (book.name) {
      const nameScore = this.calculateStringMatchScore(book.name.toLowerCase(), keyword);
      score += nameScore * 0.6; // 书名权重60%
    }
    
    // 作者匹配
    if (book.author) {
      const authorScore = this.calculateStringMatchScore(book.author.toLowerCase(), keyword);
      score += authorScore * 0.2; // 作者权重20%
    }
    
    // 简介匹配（使用intro替代description）
    if (book.intro) {
      const introScore = this.calculateStringMatchScore(book.intro.toLowerCase(), keyword);
      score += introScore * 0.1; // 简介权重10%
    }
    
    // 分类匹配（使用kind替代category）
    if (book.kind) {
      const kindScore = this.calculateStringMatchScore(book.kind.toLowerCase(), keyword);
      score += kindScore * 0.1; // 分类权重10%
    }
    
    // 书源权重调整（根据sort字段计算权重）
    if (source) {
      const sourceWeight = this.calculateSourceWeight(source);
      score *= sourceWeight;
    }
    
    return score;
  }
  
  /**
   * 计算书源权重
   */
  private calculateSourceWeight(source: BookSource): number {
    // 基于书源的sort字段计算权重，sort值越大权重越高
    const baseWeight = 1.0;
    const sortBonus = source.sort ? source.sort / 100 : 0; // 最大增加1.0
    const enabledBonus = source.enabled ? 0.2 : 0; // 启用的书源额外权重
    
    return baseWeight + sortBonus + enabledBonus;
  }
  
  /**
   * 计算字符串匹配分数
   */
  private calculateStringMatchScore(text: string, keyword: string): number {
    if (!text || !keyword) return 0;
    
    // 完全匹配
    if (text === keyword) {
      return 1.0;
    }
    
    // 包含匹配
    if (text.includes(keyword)) {
      return 0.8;
    }
    
    // 分词匹配
    const words = keyword.split(/\s+/).filter(word => word.length > 1);
    if (words.length > 1) {
      let wordMatchCount = 0;
      for (const word of words) {
        if (text.includes(word)) {
          wordMatchCount++;
        }
      }
      return wordMatchCount / words.length * 0.6;
    }
    
    // 模糊匹配（编辑距离）
    const fuzzyScore = this.calculateFuzzyMatchScore(text, keyword);
    if (fuzzyScore > 0.5) {
      return fuzzyScore * 0.4;
    }
    
    return 0;
  }
  
  /**
   * 计算模糊匹配分数（基于编辑距离）
   */
  private calculateFuzzyMatchScore(text: string, keyword: string): number {
    const distance = this.calculateLevenshteinDistance(text, keyword);
    const maxLength = Math.max(text.length, keyword.length);
    
    if (maxLength === 0) return 1.0;
    
    return 1.0 - distance / maxLength;
  }
  
  /**
   * 计算编辑距离（Levenshtein距离）
   */
  private calculateLevenshteinDistance(str1: string, str2: string): number {
    const matrix: number[][] = [];
    
    // 初始化矩阵
    for (let i = 0; i <= str2.length; i++) {
      matrix[i] = [i];
    }
    
    for (let j = 0; j <= str1.length; j++) {
      matrix[0][j] = j;
    }
    
    // 填充矩阵
    for (let i = 1; i <= str2.length; i++) {
      for (let j = 1; j <= str1.length; j++) {
        if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1, // 替换
            matrix[i][j - 1] + 1,     // 插入
            matrix[i - 1][j] + 1      // 删除
          );
        }
      }
    }
    
    return matrix[str2.length][str1.length];
  }
  
  /**
   * 智能搜索建议
   */
  generateSearchSuggestions(keyword: string, searchHistory: Array<string>): Array<string> {
    const suggestions: Array<string> = [];
    
    if (!keyword || keyword.trim().length === 0) {
      return suggestions;
    }
    
    const trimmedKeyword = keyword.trim().toLowerCase();
    
    // 从搜索历史中获取建议
    for (const historyItem of searchHistory) {
      if (historyItem.toLowerCase().includes(trimmedKeyword) && 
          historyItem !== trimmedKeyword) {
        suggestions.push(historyItem);
      }
    }
    
    // 去重并限制数量
    const uniqueSuggestions = Array.from(new Set(suggestions));
    return uniqueSuggestions.slice(0, 5); // 最多返回5个建议
  }
  
  /**
   * 多书源搜索聚合
   */
  async searchMultipleSources(
    keyword: string, 
    sources: Array<BookSource>,
    searchFunction: (keyword: string, source: BookSource) => Promise<Array<Book>>
  ): Promise<Array<Book>> {
    const allResults: Array<Book> = [];
    const enabledSources = sources.filter(source => source.enabled);
    
    Logger.debug(this.TAG, `开始在${enabledSources.length}个书源中搜索"${keyword}"`);
    
    // 并行搜索所有启用的书源
    const searchPromises = enabledSources.map(async (source) => {
      try {
        const results = await searchFunction(keyword, source);
        // 为搜索结果添加书源信息（创建新对象避免修改原对象）
        return results.map(book => {
          const bookWithSource: BookWithSource = {
            id: book.id,
            name: book.name,
            author: book.author,
            cover: book.cover,
            intro: book.intro,
            kind: book.kind,
            wordCount: book.wordCount,
            latestChapter: book.latestChapter,
            bookSourceId: source.id,
            bookSourceName: source.name,
            bookUrl: book.bookUrl,
            lastUpdateTime: book.lastUpdateTime,
            addTime: book.addTime,
            readProgress: book.readProgress,
            lastReadChapter: book.lastReadChapter
          };
          return bookWithSource;
        });
      } catch (error) {
        Logger.error(this.TAG, `书源${source.name}搜索失败：${JSON.stringify(error)}`);
        return [];
      }
    });
    
    const resultsArray = await Promise.allSettled(searchPromises);
    
    // 合并结果
    for (const result of resultsArray) {
      if (result.status === 'fulfilled') {
        allResults.push(...result.value);
      }
    }
    
    // 去重（基于书名和作者）
    const uniqueResults = this.removeDuplicateBooks(allResults);
    
    // 按匹配度排序
    const sortedResults = this.searchBooks(uniqueResults, keyword);
    
    Logger.debug(this.TAG, `多书源搜索完成，共找到${sortedResults.length}本唯一书籍`);
    return sortedResults;
  }
  
  /**
   * 去除重复书籍
   */
  private removeDuplicateBooks(books: Array<Book>): Array<Book> {
    const seen = new Set<string>();
    const uniqueBooks: Array<Book> = [];
    
    for (const book of books) {
      const key = `${book.name}_${book.author}`.toLowerCase().replace(/\s+/g, '');
      if (!seen.has(key)) {
        seen.add(key);
        uniqueBooks.push(book);
      }
    }
    
    return uniqueBooks;
  }
  
  /**
   * 验证搜索结果有效性
   */
  validateSearchResults(books: Array<Book>): Array<Book> {
    return books.filter(book => {
      return book && 
             book.name && 
             book.name.trim().length > 0 &&
             book.author &&
             book.author.trim().length > 0;
    });
  }
}

export default new SearchEnhancer();