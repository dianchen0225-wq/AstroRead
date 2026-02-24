import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { 
  PagedSearchResult, 
  SearchPaginationConfig, 
  DEFAULT_PAGINATION_CONFIG,
  SearchProgress,
  SearchStopCondition,
  DEFAULT_STOP_CONDITION
} from '../models/SearchResult';
import { BookFoundCallback, SearchOptions } from '../utils/BookSourceSearchEngine';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import SearchEnhancer from '../utils/SearchEnhancer';
import { BookSourceSearchEngine } from '../utils/BookSourceSearchEngine';
import { Logger } from '../utils/Logger';
import { IdGenerator } from '../utils/IdGenerator';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const SEARCH_HISTORY_KEY = 'search_history';
const MAX_SEARCH_HISTORY = 20;

export type SearchProgressCallback = (progress: SearchProgress) => void;

/**
 * 书籍视图模型
 * 负责管理书籍相关的业务逻辑和状态
 */
export class BookViewModel {
  private books: Book[] = [];
  private readonly databaseManager = databaseManager;
  private readonly networkManager = NetworkManager.getInstance();
  private readonly searchEnhancer = SearchEnhancer;
  private readonly searchEngine = BookSourceSearchEngine.getInstance();
  private context: common.UIAbilityContext | null = null;
  private preferences: preferences.Preferences | null = null;
  
  private searchHistory: string[] = [];
  private paginationConfig: SearchPaginationConfig = DEFAULT_PAGINATION_CONFIG;
  
  private isLoading: boolean = false;
  private loadingLock: Promise<void> = Promise.resolve();
  private loadingLockResolver: (() => void) | null = null;

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.networkManager.setContext(context);
    this.initPreferences();
  }

  private async initPreferences(): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      this.preferences = await preferences.getPreferences(this.context, 'book_view_model');
      await this.loadSearchHistoryFromStorage();
    } catch (error) {
      Logger.error('BookViewModel', `初始化偏好设置失败: ${error}`);
    }
  }

  private async loadSearchHistoryFromStorage(): Promise<void> {
    if (!this.preferences) {
      return;
    }
    try {
      const historyJson = await this.preferences.get(SEARCH_HISTORY_KEY, '[]') as string;
      this.searchHistory = JSON.parse(historyJson) as string[];
      Logger.debug('BookViewModel', `从存储加载搜索历史: ${this.searchHistory.length}条`);
    } catch (error) {
      Logger.error('BookViewModel', `加载搜索历史失败: ${error}`);
      this.searchHistory = [];
    }
  }

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

  async getAllBooks(): Promise<Book[]> {
    return this.loadAllBooks();
  }

  /**
   * 根据ID获取书籍
   */
  async getBookById(bookId: string): Promise<Book | null> {
    Logger.info('BookViewModel', `查询书籍: ${bookId}`);
    const books = await this.loadAllBooks();
    Logger.info('BookViewModel', `加载了 ${books.length} 本书籍`);
    const found = books.find((book: Book) => book.id === bookId) || null;
    Logger.info('BookViewModel', `查找结果: ${found ? '找到' : '未找到'}`);
    return found;
  }

  /**
   * 添加书籍
   */
  async addBook(book: Book): Promise<string> {
    try {
      const bookId = book.id || IdGenerator.generateUUID();
      book.id = bookId;
      await this.databaseManager.upsertBook(book);
      await this.loadAllBooks();
      return bookId;
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
    if (this.isLoading) {
      Logger.warn('BookViewModel', '搜索正在进行中，请等待完成');
      return [];
    }
    
    this.isLoading = true;
    this.loadingLock = new Promise<void>((resolve) => {
      this.loadingLockResolver = resolve;
    });
    
    const startTime = Date.now();
    
    try {
      Logger.info('BookViewModel', `开始搜索书籍："${keyword}"`);
      
      await this.addToSearchHistory(keyword);
      
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
      
      const validResults = this.searchEnhancer.validateSearchResults(results);
      
      const duration = Date.now() - startTime;
      Logger.info('BookViewModel', `搜索完成，找到${validResults.length}本有效书籍，耗时${duration}ms`);
      
      return validResults;
      
    } catch (error) {
      Logger.error('BookViewModel', `搜索书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    } finally {
      this.isLoading = false;
      if (this.loadingLockResolver) {
        this.loadingLockResolver();
        this.loadingLockResolver = null;
      }
    }
  }

  /**
   * 分页搜索书籍 - 支持渐进式加载和智能停止
   */
  async searchBooksWithPaging(
    keyword: string, 
    bookSources: BookSource[], 
    page: number = 1,
    progressCallback?: SearchProgressCallback,
    bookFoundCallback?: BookFoundCallback,
    stopCondition?: SearchStopCondition
  ): Promise<PagedSearchResult> {
    const startTime = Date.now();
    
    try {
      Logger.info('BookViewModel', `开始渐进式搜索书籍："${keyword}", 第${page}页`);
      
      await this.addToSearchHistory(keyword);
      
      const searchOptions: SearchOptions = {
        key: keyword,
        page: page,
        pageSize: this.paginationConfig.pageSize,
        maxResultsPerSource: this.paginationConfig.maxResultsPerSource,
        stopCondition: stopCondition || DEFAULT_STOP_CONDITION
      };
      const result = await this.searchEngine.searchWithPaging(
        bookSources,
        searchOptions,
        progressCallback,
        bookFoundCallback
      );
      
      const duration = Date.now() - startTime;
      Logger.info('BookViewModel', 
        `渐进式搜索完成，共${result.totalCount}本书，当前第${result.currentPage}/${result.totalPages}页，耗时${duration}ms`
      );
      
      return result;
      
    } catch (error) {
      Logger.error('BookViewModel', `渐进式搜索书籍失败：${error}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 设置分页配置
   */
  setSearchPaginationConfig(config: Partial<SearchPaginationConfig>): void {
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
    
    this.searchEngine.setPaginationConfig(this.paginationConfig);
    Logger.info('BookViewModel', `分页配置已更新: pageSize=${this.paginationConfig.pageSize}`);
  }

  /**
   * 获取分页配置
   */
  getSearchPaginationConfig(): SearchPaginationConfig {
    const config: SearchPaginationConfig = {
      pageSize: this.paginationConfig.pageSize,
      maxResultsPerSource: this.paginationConfig.maxResultsPerSource,
      maxTotalResults: this.paginationConfig.maxTotalResults,
      enableDeduplication: this.paginationConfig.enableDeduplication,
      sortByRelevance: this.paginationConfig.sortByRelevance
    };
    return config;
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
  private async addToSearchHistory(keyword: string): Promise<void> {
    if (!keyword || keyword.trim().length === 0) {
      return;
    }
    
    const trimmedKeyword = keyword.trim();
    
    this.searchHistory = this.searchHistory.filter(item => item !== trimmedKeyword);
    
    this.searchHistory.unshift(trimmedKeyword);
    
    if (this.searchHistory.length > MAX_SEARCH_HISTORY) {
      this.searchHistory = this.searchHistory.slice(0, MAX_SEARCH_HISTORY);
    }
    
    await this.saveSearchHistory();
  }

  /**
   * 保存搜索历史
   */
  private async saveSearchHistory(): Promise<void> {
    if (!this.preferences) {
      Logger.warn('BookViewModel', '偏好设置未初始化，无法保存搜索历史');
      return;
    }
    try {
      const historyJson = JSON.stringify(this.searchHistory);
      await this.preferences.put(SEARCH_HISTORY_KEY, historyJson);
      await this.preferences.flush();
      Logger.debug('BookViewModel', `搜索历史已保存：${this.searchHistory.length}条`);
    } catch (error) {
      Logger.error('BookViewModel', `保存搜索历史失败: ${error}`);
    }
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
  async clearSearchHistory(): Promise<void> {
    this.searchHistory = [];
    await this.saveSearchHistory();
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

  /**
   * 清理资源，防止内存泄漏
   * 在页面销毁时调用
   */
  destroy(): void {
    Logger.info('BookViewModel', '销毁 BookViewModel，清理资源');
    
    // 清理 context 引用
    this.context = null;
    
    // 清理 preferences 引用
    this.preferences = null;
    
    // 重置加载状态
    this.isLoading = false;
    this.loadingLockResolver = null;
    
    // 清理网络管理器的 context 引用
    this.networkManager.setContext(null);
  }
}
