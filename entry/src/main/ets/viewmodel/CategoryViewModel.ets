import { BookCategory } from '../models/BookCategory';
import { databaseManager } from '../utils/DatabaseManager';
import { IdGenerator } from '../utils/IdGenerator';
import { Logger } from '../utils/Logger';

export class CategoryViewModel {
  private static readonly TAG = 'CategoryViewModel';
  private readonly databaseManager = databaseManager;

  async getAllCategories(): Promise<BookCategory[]> {
    try {
      return await this.databaseManager.getAllBookCategories();
    } catch (error) {
      Logger.error(CategoryViewModel.TAG, `加载分类失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  async createCategory(name: string): Promise<BookCategory> {
    try {
      const category: BookCategory = {
        id: IdGenerator.generateUUID(),
        name: name,
        sort: Date.now(),
        createTime: Date.now()
      };
      
      await this.databaseManager.addBookCategory(category);
      return category;
    } catch (error) {
      Logger.error(CategoryViewModel.TAG, `创建分类失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async deleteCategory(categoryId: string): Promise<void> {
    try {
      await this.databaseManager.deleteCategory(categoryId);
    } catch (error) {
      Logger.error(CategoryViewModel.TAG, `删除分类失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async addBookToCategory(bookId: string, categoryId: string): Promise<void> {
    try {
      await this.databaseManager.addBookToCategory(bookId, categoryId);
    } catch (error) {
      Logger.error(CategoryViewModel.TAG, `添加书籍到分类失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  async removeBookFromCategory(bookId: string, categoryId: string): Promise<void> {
    try {
      await this.databaseManager.removeBookFromCategory(bookId, categoryId);
    } catch (error) {
      Logger.error(CategoryViewModel.TAG, `从分类移除书籍失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}
