import relationalStore from '@ohos.data.relationalStore';
import { Book } from '../../models/Book';

/**
 * 书籍数据库操作
 */
export class BookRepository {
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 获取所有书籍
   */
  async getAllBooks(): Promise<Book[]> {
    const predicates = new relationalStore.RdbPredicates('book');
    predicates.orderByDesc('last_update_time');

    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const books: Book[] = [];

      while (resultSet.goToNextRow()) {
        const book = this.parseBook(resultSet);
        books.push(book);
      }

      resultSet.close();
      return books;
    } catch (error) {
      console.error(`Failed to query books: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 根据分类获取书籍
   */
  async getBooksByCategory(categoryId: string): Promise<Book[]> {
    try {
      // 先获取该分类下的所有书籍ID
      const relationPredicates = new relationalStore.RdbPredicates('book_category_relation');
      relationPredicates.equalTo('category_id', categoryId);
      
      const relationResultSet = await this.rdbStore.query(relationPredicates, ['book_id']);
      const bookIds: string[] = [];
      
      while (relationResultSet.goToNextRow()) {
        const bookId = relationResultSet.getString(relationResultSet.getColumnIndex('book_id'));
        if (bookId) {
          bookIds.push(bookId);
        }
      }
      relationResultSet.close();

      if (bookIds.length === 0) {
        return [];
      }

      // 根据书籍ID查询书籍信息
      const bookPredicates = new relationalStore.RdbPredicates('book');
      bookPredicates.in('id', bookIds);
      bookPredicates.orderByDesc('last_update_time');

      const bookResultSet = await this.rdbStore.query(bookPredicates, ['*']);
      const books: Book[] = [];

      while (bookResultSet.goToNextRow()) {
        const book = this.parseBook(bookResultSet);
        books.push(book);
      }

      bookResultSet.close();
      return books;
    } catch (error) {
      console.error(`Failed to query books by category: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 解析书籍数据
   */
  private parseBook(resultSet: relationalStore.ResultSet): Book {
    try {
      const idIndex = resultSet.getColumnIndex('id');
      const nameIndex = resultSet.getColumnIndex('name');
      const authorIndex = resultSet.getColumnIndex('author');
      const coverIndex = resultSet.getColumnIndex('cover');
      const introIndex = resultSet.getColumnIndex('intro');
      const kindIndex = resultSet.getColumnIndex('kind');
      const wordCountIndex = resultSet.getColumnIndex('word_count');
      const latestChapterIndex = resultSet.getColumnIndex('latest_chapter');
      const bookSourceIdIndex = resultSet.getColumnIndex('book_source_id');
      const bookSourceNameIndex = resultSet.getColumnIndex('book_source_name');
      const bookUrlIndex = resultSet.getColumnIndex('book_url');
      const lastUpdateTimeIndex = resultSet.getColumnIndex('last_update_time');
      const addTimeIndex = resultSet.getColumnIndex('add_time');
      const readProgressIndex = resultSet.getColumnIndex('read_progress');
      const lastReadChapterIndex = resultSet.getColumnIndex('last_read_chapter');

      return {
        id: resultSet.getString(idIndex) || '',
        name: resultSet.getString(nameIndex) || '',
        author: resultSet.getString(authorIndex) || '',
        cover: resultSet.isColumnNull(coverIndex)
          ? undefined
          : resultSet.getString(coverIndex) || '',
        intro: resultSet.isColumnNull(introIndex)
          ? undefined
          : resultSet.getString(introIndex) || '',
        kind: resultSet.isColumnNull(kindIndex)
          ? undefined
          : resultSet.getString(kindIndex) || '',
        wordCount: resultSet.isColumnNull(wordCountIndex)
          ? undefined
          : resultSet.getLong(wordCountIndex) || 0,
        latestChapter: resultSet.isColumnNull(latestChapterIndex)
          ? undefined
          : resultSet.getString(latestChapterIndex) || '',
        bookSourceId: resultSet.getString(bookSourceIdIndex) || '',
        bookSourceName: resultSet.getString(bookSourceNameIndex) || '',
        bookUrl: resultSet.getString(bookUrlIndex) || '',
        lastUpdateTime: resultSet.getLong(lastUpdateTimeIndex) || 0,
        addTime: resultSet.getLong(addTimeIndex) || 0,
        readProgress: resultSet.getDouble(readProgressIndex) || 0,
        lastReadChapter: resultSet.isColumnNull(lastReadChapterIndex)
          ? undefined
          : resultSet.getString(lastReadChapterIndex) || '',
        lastReadChapterIndex: resultSet.isColumnNull(lastReadChapterIndex)
          ? undefined
          : resultSet.getLong(lastReadChapterIndex) || 0
      };
    } catch (error) {
      console.error(`Failed to parse book: ${error instanceof Error ? error.message : String(error)}`);
      return {
        id: '',
        name: '',
        author: '',
        cover: undefined,
        intro: undefined,
        kind: undefined,
        wordCount: undefined,
        latestChapter: undefined,
        bookSourceId: '',
        bookSourceName: '',
        bookUrl: '',
        lastUpdateTime: 0,
        addTime: 0,
        readProgress: 0,
        lastReadChapter: undefined,
        lastReadChapterIndex: undefined
      };
    }
  }

  /**
   * 插入或更新书籍
   */
  async upsertBook(book: Book): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'id': book.id,
      'name': book.name,
      'author': book.author,
      'cover': book.cover || null,
      'intro': book.intro || null,
      'kind': book.kind || null,
      'word_count': book.wordCount || 0,
      'latest_chapter': book.latestChapter || null,
      'book_source_id': book.bookSourceId,
      'book_source_name': book.bookSourceName,
      'book_url': book.bookUrl,
      'last_update_time': Date.now(),
      'add_time': book.addTime || Date.now(),
      'read_progress': book.readProgress,
      'last_read_chapter': book.lastReadChapter || null
    };

    try {
      // 先尝试更新
      const predicates = new relationalStore.RdbPredicates('book');
      predicates.equalTo('id', book.id);
      const updatedRows = await this.rdbStore.update(valueBucket, predicates);
      
      // 如果更新失败则插入
      if (updatedRows === 0) {
        await this.rdbStore.insert('book', valueBucket);
      }
    } catch (error) {
      console.error(`Failed to upsert book: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 删除书籍
   */
  async deleteBook(bookId: string): Promise<void> {
    try {
      const predicates = new relationalStore.RdbPredicates('book');
      predicates.equalTo('id', bookId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error(`Failed to delete book: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
