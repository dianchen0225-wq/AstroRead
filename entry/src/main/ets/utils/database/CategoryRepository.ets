import relationalStore from '@ohos.data.relationalStore';
import { BookCategory } from '../../models/BookCategory';
import { Logger } from '../Logger';

export class CategoryRepository {
  private static readonly TAG = 'CategoryRepository';
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 获取所有书籍分类
   */
  async getAllBookCategories(): Promise<BookCategory[]> {
    const predicates = new relationalStore.RdbPredicates('book_category');
    try {
      predicates.orderByAsc('sort');
    } catch (error) {
      Logger.error(CategoryRepository.TAG, `设置排序失败: ${error instanceof Error ? error.message : String(error)}`);
    }

    let resultSet: relationalStore.ResultSet | null = null;
    try {
      resultSet = await this.rdbStore.query(predicates, ['*']);
      const categories: BookCategory[] = [];

      while (resultSet.goToNextRow()) {
        const category = this.parseBookCategory(resultSet);
        categories.push(category);
      }

      return categories;
    } catch (error) {
      Logger.error(CategoryRepository.TAG, `查询书籍分类失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    } finally {
      if (resultSet) {
        try {
          resultSet.close();
        } catch (e) {
          Logger.warn(CategoryRepository.TAG, `关闭resultSet失败: ${e}`);
        }
      }
    }
  }

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
      Logger.error(CategoryRepository.TAG, `添加书籍分类失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async deleteCategory(categoryId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book_category');
      predicates.equalTo('id', categoryId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      Logger.error(CategoryRepository.TAG, `删除分类失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async addBookToCategory(bookId: string, categoryId: string): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'book_id': bookId,
      'category_id': categoryId
    };

    try {
      await this.rdbStore.insert('book_category_relation', valueBucket);
    } catch (error) {
      Logger.error(CategoryRepository.TAG, `添加书籍到分类失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async removeBookFromCategory(bookId: string, categoryId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book_category_relation');
      predicates.equalTo('book_id', bookId);
      predicates.equalTo('category_id', categoryId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      Logger.error(CategoryRepository.TAG, `从分类移除书籍失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private parseBookCategory(resultSet: relationalStore.ResultSet): BookCategory {
    try {
      return {
        id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
        name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
        sort: resultSet.getLong(resultSet.getColumnIndex('sort')) || 0,
        createTime: resultSet.getLong(resultSet.getColumnIndex('create_time')) || 0
      };
    } catch (error) {
      Logger.error(CategoryRepository.TAG, `解析书籍分类数据失败: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        name: '',
        sort: 0,
        createTime: 0
      };
    }
  }
}
