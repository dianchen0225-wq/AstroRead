import { BookCategory } from '../models/BookCategory';
import { databaseManager } from '../utils/DatabaseManager';
import { IdGenerator } from '../utils/IdGenerator';

/**
 * 分类视图模型
 */
export class CategoryViewModel {
  private readonly databaseManager = databaseManager;

  /**
   * 获取所有分类
   */
  async getAllCategories(): Promise<BookCategory[]> {
    try {
      return await this.databaseManager.getAllBookCategories();
    } catch (error) {
      console.error('Failed to load categories:', error);
      return [];
    }
  }

  /**
   * 创建分类
   */
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
      console.error('Failed to create category:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 删除分类
   */
  async deleteCategory(categoryId: string): Promise<void> {
    try {
      await this.databaseManager.deleteCategory(categoryId);
    } catch (error) {
      console.error('Failed to delete category:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 将书籍添加到分类
   */
  async addBookToCategory(bookId: string, categoryId: string): Promise<void> {
    try {
      await this.databaseManager.addBookToCategory(bookId, categoryId);
    } catch (error) {
      console.error('Failed to add book to category:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 从分类移除书籍
   */
  async removeBookFromCategory(bookId: string, categoryId: string): Promise<void> {
    try {
      await this.databaseManager.removeBookFromCategory(bookId, categoryId);
    } catch (error) {
      console.error('Failed to remove book from category:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}
