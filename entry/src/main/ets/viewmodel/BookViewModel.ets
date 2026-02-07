import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';

/**
 * 书籍视图模型
 * 负责管理书籍相关的业务逻辑和状态
 */
export class BookViewModel {
  private books: Book[] = [];
  private readonly databaseManager = databaseManager;
  private readonly networkManager = NetworkManager.getInstance();

  /**
   * 加载所有书籍
   */
  async loadAllBooks(): Promise<Book[]> {
    try {
      this.books = await this.databaseManager.getAllBooks();
      return this.books;
    } catch (error) {
      console.error('Failed to load books:', error);
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
      console.error('Failed to add book:', error);
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
      console.error('Failed to update read progress:', error);
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
      console.error('Failed to delete book:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 批量删除书籍
   */
  async batchDeleteBooks(bookIds: string[]): Promise<void> {
    try {
      await this.databaseManager.batchDeleteBooks(bookIds);
      await this.loadAllBooks();
    } catch (error) {
      console.error('Failed to batch delete books:', error);
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
      console.error('Failed to get books by category:', error);
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
   * 搜索书籍（从网络书源）
   */
  async searchBooks(keyword: string, bookSources: BookSource[]): Promise<Book[]> {
    try {
      const allResults: Book[] = [];
      
      // 分段搜索书源，每批处理20个书源
      const batchSize = 20;
      for (let i = 0; i < bookSources.length; i += batchSize) {
        const batch = bookSources.slice(i, i + batchSize);
        console.log(`Searching batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(bookSources.length / batchSize)} (${batch.length} sources)`);
        
        // 并行搜索当前批次的书源
        const searchPromises = batch.map(async (source: BookSource) => {
          try {
            return await this.networkManager.searchBook(source, keyword);
          } catch (error) {
            console.error(`Search failed for source ${source.name}:`, error);
            return [];
          }
        });
        
        const resultsArray = await Promise.all(searchPromises);
        resultsArray.forEach((results) => {
          allResults.push(...results);
        });
        
        // 每批次搜索后稍作延迟，避免请求过于频繁
        if (i + batchSize < bookSources.length) {
          await new Promise<void>(resolve => setTimeout(resolve, 1000));
        }
      }
      
      // 去重（基于书名和作者）
      const deduplicated = this.deduplicateBooks(allResults);
      console.log(`Total search results: ${allResults.length}, after deduplication: ${deduplicated.length}`);
      return deduplicated;
    } catch (error) {
      console.error('Failed to search books:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
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
}
