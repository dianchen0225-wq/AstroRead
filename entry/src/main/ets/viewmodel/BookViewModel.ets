import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import SearchEnhancer from '../utils/SearchEnhancer';
import { Logger } from '../utils/Logger';

/**
 * 书籍视图模型
 * 负责管理书籍相关的业务逻辑和状态
 */
export class BookViewModel {
  private books: Book[] = [];
  private readonly databaseManager = databaseManager;
  private readonly networkManager = NetworkManager.getInstance();
  private readonly searchEnhancer = SearchEnhancer;
  
  // 搜索历史记录
  private searchHistory: string[] = [];

  /**
   * 加载所有书籍
   */
  async loadAllBooks(): Promise<Book[]> {
    try {
      this.books = await this.databaseManager.getAllBooks();
      return this.books;
    } catch (error) {
      Logger.error('BookViewModel', `加载书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 根据ID获取书籍
   */
  async getBookById(bookId: string): Promise<Book | null> {
    const books = await this.loadAllBooks();
    return books.find((book: Book) => book.id === bookId) || null;
  }

  /**
   * 添加书籍
   */
  async addBook(book: Book): Promise<void> {
    try {
      await this.databaseManager.upsertBook(book);
      await this.loadAllBooks();
    } catch (error) {
      Logger.error('BookViewModel', `添加书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 更新书籍阅读进度
   */
  async updateReadProgress(bookId: string, progress: number, chapter?: string): Promise<void> {
    try {
      const book = await this.getBookById(bookId);
      if (book) {
        book.readProgress = progress;
        book.lastReadChapter = chapter;
        await this.databaseManager.upsertBook(book);
      }
    } catch (error) {
      Logger.error('BookViewModel', `更新阅读进度失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 删除书籍
   */
  async deleteBook(bookId: string): Promise<void> {
    try {
      await this.databaseManager.deleteBook(bookId);
      await this.loadAllBooks();
    } catch (error) {
      Logger.error('BookViewModel', `删除书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 批量删除书籍
   */
  async batchDeleteBooks(bookIds: string[]): Promise<void> {
    try {
      for (const bookId of bookIds) {
        await this.databaseManager.deleteBook(bookId);
      }
      await this.loadAllBooks();
    } catch (error) {
      Logger.error('BookViewModel', `批量删除书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 根据分类获取书籍
   */
  async getBooksByCategory(categoryId: string): Promise<Book[]> {
    try {
      return await this.databaseManager.getBooksByCategory(categoryId);
    } catch (error) {
      Logger.error('BookViewModel', `根据分类获取书籍失败：${error}`);
      return [];
    }
  }

  /**
   * 按条件排序书籍
   */
  async sortBooks(books: Book[], sortType: 'name' | 'author' | 'progress' | 'time'): Promise<Book[]> {
    const sorted = [...books];
    
    switch (sortType) {
      case 'name':
        sorted.sort((a, b) => a.name.localeCompare(b.name, 'zh-CN'));
        break;
      case 'author':
        sorted.sort((a, b) => (a.author || '').localeCompare(b.author || '', 'zh-CN'));
        break;
      case 'progress':
        sorted.sort((a, b) => b.readProgress - a.readProgress);
        break;
      case 'time':
        sorted.sort((a, b) => b.lastUpdateTime - a.lastUpdateTime);
        break;
    }
    
    return sorted;
  }

  /**
   * 搜索书籍（从网络书源）- 增强版
   */
  async searchBooks(keyword: string, bookSources: BookSource[]): Promise<Book[]> {
    const startTime = Date.now();
    
    try {
      Logger.info('BookViewModel', `开始搜索书籍："${keyword}"`);
      
      // 保存搜索历史
      this.addToSearchHistory(keyword);
      
      // 使用搜索增强器进行多书源搜索
      const searchFunction = async (searchKeyword: string, source: BookSource): Promise<Book[]> => {
        try {
          return await this.networkManager.searchBook(source, searchKeyword);
        } catch (error) {
          Logger.error('BookViewModel', `书源${source.name}搜索失败：${error}`);
          return [];
        }
      };
      
      const results = await this.searchEnhancer.searchMultipleSources(
        keyword, 
        bookSources, 
        searchFunction
      );
      
      // 验证搜索结果有效性
      const validResults = this.searchEnhancer.validateSearchResults(results);
      
      const duration = Date.now() - startTime;
      Logger.info('BookViewModel', `搜索完成，找到${validResults.length}本有效书籍，耗时${duration}ms`);
      
      return validResults;
      
    } catch (error) {
      Logger.error('BookViewModel', `搜索书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 本地书籍搜索（在已下载的书籍中搜索）
   */
  async searchLocalBooks(keyword: string): Promise<Book[]> {
    try {
      const allBooks = await this.loadAllBooks();
      return this.searchEnhancer.searchBooks(allBooks, keyword);
    } catch (error) {
      Logger.error('BookViewModel', `本地书籍搜索失败：${error}`);
      return [];
    }
  }

  /**
   * 获取搜索建议
   */
  getSearchSuggestions(keyword: string): string[] {
    return this.searchEnhancer.generateSearchSuggestions(keyword, this.searchHistory);
  }

  /**
   * 添加搜索历史
   */
  private addToSearchHistory(keyword: string): void {
    if (!keyword || keyword.trim().length === 0) {
      return;
    }
    
    const trimmedKeyword = keyword.trim();
    
    // 移除重复项
    this.searchHistory = this.searchHistory.filter(item => item !== trimmedKeyword);
    
    // 添加到开头
    this.searchHistory.unshift(trimmedKeyword);
    
    // 限制历史记录数量
    if (this.searchHistory.length > 20) {
      this.searchHistory = this.searchHistory.slice(0, 20);
    }
    
    // 保存到本地存储（实际项目中应该实现）
    this.saveSearchHistory();
  }

  /**
   * 保存搜索历史
   */
  private saveSearchHistory(): void {
    // TODO: 实现搜索历史的本地存储
    Logger.debug('BookViewModel', `搜索历史已更新：${this.searchHistory.join(', ')}`);
  }

  /**
   * 获取搜索历史
   */
  getSearchHistory(): string[] {
    return [...this.searchHistory];
  }

  /**
   * 清除搜索历史
   */
  clearSearchHistory(): void {
    this.searchHistory = [];
    this.saveSearchHistory();
    Logger.info('BookViewModel', '搜索历史已清除');
  }

  /**
   * 去重书籍（基于书名和作者）
   */
  private deduplicateBooks(books: Book[]): Book[] {
    const seen = new Set<string>();
    return books.filter((book: Book) => {
      const key = `${book.name}|${book.author}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }

  /**
   * 判断书籍是否已添加
   */
  async isBookAdded(bookId: string): Promise<boolean> {
    const books = await this.loadAllBooks();
    return books.some((book: Book) => book.id === bookId);
  }
}
