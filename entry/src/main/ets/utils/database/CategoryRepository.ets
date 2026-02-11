import relationalStore from '@ohos.data.relationalStore';
import { BookCategory } from '../../models/BookCategory';

/**
 * 书籍分类数据库操作
 */
export class CategoryRepository {
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 获取所有书籍分类
   */
  async getAllBookCategories(): Promise<BookCategory[]> {
    const predicates = new relationalStore.RdbPredicates('book_category');
    predicates.orderByAsc('sort');

    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const categories: BookCategory[] = [];

      while (resultSet.goToNextRow()) {
        const category = this.parseBookCategory(resultSet);
        categories.push(category);
      }

      resultSet.close();
      return categories;
    } catch (error) {
      console.error(`Failed to query book categories: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 添加书籍分类
   */
  async addBookCategory(category: BookCategory): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'id': category.id,
      'name': category.name,
      'sort': category.sort || 0,
      'create_time': Date.now()
    };

    try {
      await this.rdbStore.insert('book_category', valueBucket);
    } catch (error) {
      console.error(`Failed to add book category: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 删除分类
   */
  async deleteCategory(categoryId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book_category');
      predicates.equalTo('id', categoryId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error(`Failed to delete category: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 将书籍添加到分类
   */
  async addBookToCategory(bookId: string, categoryId: string): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'book_id': bookId,
      'category_id': categoryId
    };

    try {
      await this.rdbStore.insert('book_category_relation', valueBucket);
    } catch (error) {
      console.error(`Failed to add book to category: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 从分类移除书籍
   */
  async removeBookFromCategory(bookId: string, categoryId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book_category_relation');
      predicates.equalTo('book_id', bookId);
      predicates.equalTo('category_id', categoryId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error(`Failed to remove book from category: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 解析书籍分类数据
   */
  private parseBookCategory(resultSet: relationalStore.ResultSet): BookCategory {
    try {
      return {
        id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
        name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
        sort: resultSet.getLong(resultSet.getColumnIndex('sort')) || 0,
        createTime: resultSet.getLong(resultSet.getColumnIndex('create_time')) || 0
      };
    } catch (error) {
      console.error(`Failed to parse book category: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        name: '',
        sort: 0,
        createTime: 0
      };
    }
  }
}
