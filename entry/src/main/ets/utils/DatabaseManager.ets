import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { ReadConfig, MarginsConfig } from '../models/ReadConfig';
import { Chapter } from '../models/Book';
import { BookCategory } from '../models/BookCategory';
import { Bookmark } from '../models/Bookmark';

/**
 * 数据库管理器
 */
export class DatabaseManager {
  private rdbStore: relationalStore.RdbStore | null = null;
  private readonly dbName: string = 'AstroRead.db';
  // private readonly dbVersion: number = 1;

  /**
   * 初始化数据库
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: this.dbName,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    
    try {
      const rdbPromise = relationalStore.getRdbStore(context, config);
      this.rdbStore = await rdbPromise;
      await this.createTables();
    } catch (error) {
      console.error('Failed to initialize database:', error);
      this.rdbStore = null;
    }
  }

  /**
   * 创建数据表
   */
  private async createTables(): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    // 创建书源表
    const bookSourceTable = `
      CREATE TABLE IF NOT EXISTS book_source (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        header TEXT,
        search_url TEXT NOT NULL,
        search_rule TEXT NOT NULL,
        find_rule TEXT,
        chapter_rule TEXT NOT NULL,
        content_rule TEXT NOT NULL,
        rule_type TEXT DEFAULT 'jsonpath',
        sort INTEGER DEFAULT 0,
        last_update_time INTEGER,
        add_time INTEGER NOT NULL
      )
    `;

    // 创建书籍表
    const bookTable = `
      CREATE TABLE IF NOT EXISTS book (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        author TEXT,
        cover TEXT,
        intro TEXT,
        kind TEXT,
        word_count INTEGER,
        latest_chapter TEXT,
        book_source_id TEXT NOT NULL,
        book_source_name TEXT,
        book_url TEXT NOT NULL,
        last_update_time INTEGER,
        add_time INTEGER NOT NULL,
        read_progress INTEGER DEFAULT 0,
        last_read_chapter TEXT,
        FOREIGN KEY(book_source_id) REFERENCES book_source(id)
      )
    `;

    // 创建章节表
    const chapterTable = `
      CREATE TABLE IF NOT EXISTS chapter (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        \`order\` INTEGER NOT NULL,
        is_vip INTEGER DEFAULT 0,
        FOREIGN KEY(book_id) REFERENCES book(id)
      )
    `;

    // 创建阅读配置表
    const readConfigTable = `
      CREATE TABLE IF NOT EXISTS read_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        font_size INTEGER DEFAULT 18,
        line_spacing REAL DEFAULT 1.5,
        page_turn_mode TEXT DEFAULT 'cover',
        background_color TEXT DEFAULT '#FFFFFF',
        text_color TEXT DEFAULT '#333333',
        is_night_mode INTEGER DEFAULT 0,
        brightness REAL DEFAULT 0.5,
        auto_scroll INTEGER DEFAULT 0,
        scroll_speed INTEGER DEFAULT 50,
        font_family TEXT DEFAULT 'HarmonyOS Sans',
        margin_top INTEGER DEFAULT 20,
        margin_bottom INTEGER DEFAULT 20,
        margin_left INTEGER DEFAULT 20,
        margin_right INTEGER DEFAULT 20
      )
    `;

    // 创建分类表
    const categoryTable = `
      CREATE TABLE IF NOT EXISTS book_category (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort INTEGER DEFAULT 0,
        create_time INTEGER NOT NULL
      )
    `;

    // 创建书签表
    const bookmarkTable = `
      CREATE TABLE IF NOT EXISTS bookmark (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        content TEXT,
        create_time INTEGER NOT NULL,
        FOREIGN KEY(book_id) REFERENCES book(id)
      )
    `;

    // 创建书籍分类关联表
    const bookCategoryRelationTable = `
      CREATE TABLE IF NOT EXISTS book_category_relation (
        book_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY(book_id, category_id),
        FOREIGN KEY(book_id) REFERENCES book(id),
        FOREIGN KEY(category_id) REFERENCES book_category(id)
      )
    `;

    try {
      await this.rdbStore.executeSql(bookSourceTable);
      await this.rdbStore.executeSql(bookTable);
      await this.rdbStore.executeSql(chapterTable);
      await this.rdbStore.executeSql(readConfigTable);
      await this.rdbStore.executeSql(categoryTable);
      await this.rdbStore.executeSql(bookmarkTable);
      await this.rdbStore.executeSql(bookCategoryRelationTable);
    } catch (error) {
      console.error('Failed to create tables:', error);
    }
  }

  /**
   * 插入或更新书源
   */
  async upsertBookSource(bookSource: BookSource): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    const valueBucket: relationalStore.ValuesBucket = {
      'id': bookSource.id,
      'name': bookSource.name,
      'url': bookSource.url,
      'enabled': bookSource.enabled ? 1 : 0,
      'header': bookSource.header || null,
      'search_url': bookSource.searchUrl,
      'search_rule': JSON.stringify(bookSource.searchRule),
      'find_rule': bookSource.findRule ? JSON.stringify(bookSource.findRule) : null,
      'chapter_rule': JSON.stringify(bookSource.chapterRule),
      'content_rule': JSON.stringify(bookSource.contentRule),
      'rule_type': bookSource.ruleType,
      'sort': bookSource.sort,
      'last_update_time': bookSource.lastUpdateTime,
      'add_time': bookSource.addTime
    };

    try {
      await this.rdbStore.insert('book_source', valueBucket);
    } catch (error) {
      console.error('Failed to insert book source:', error);
    }
  }

  /**
   * 批量插入或更新书源
   */
  async batchUpsertBookSources(bookSources: BookSource[]): Promise<void> {
    if (this.rdbStore === null || bookSources.length === 0) {
      return;
    }

    try {
      // 开始事务
      this.rdbStore.beginTransaction();
      
      for (const bookSource of bookSources) {
        const valueBucket: relationalStore.ValuesBucket = {
          'id': bookSource.id,
          'name': bookSource.name,
          'url': bookSource.url,
          'enabled': bookSource.enabled ? 1 : 0,
          'header': bookSource.header || null,
          'search_url': bookSource.searchUrl,
          'search_rule': JSON.stringify(bookSource.searchRule),
          'find_rule': bookSource.findRule ? JSON.stringify(bookSource.findRule) : null,
          'chapter_rule': JSON.stringify(bookSource.chapterRule),
          'content_rule': JSON.stringify(bookSource.contentRule),
          'rule_type': bookSource.ruleType,
          'sort': bookSource.sort,
          'last_update_time': bookSource.lastUpdateTime,
          'add_time': bookSource.addTime
        };

        try {
          await this.rdbStore.insert('book_source', valueBucket);
        } catch (error) {
          console.error('Failed to insert book source:', error);
          // 继续处理下一个书源，不中断整个批量操作
        }
      }

      // 提交事务
      this.rdbStore.commit();
      console.log(`Successfully batch upserted ${bookSources.length} book sources`);
    } catch (error) {
      console.error('Failed to batch upsert book sources:', error);
      // 回滚事务
      if (this.rdbStore) {
        try {
          this.rdbStore.rollback(0);
        } catch (rollbackError) {
          console.error('Failed to rollback transaction:', rollbackError);
        }
      }
    }
  }

  /**
   * 查询所有启用的书源
   */
  async getAllEnabledBookSources(): Promise<BookSource[]> {
    if (this.rdbStore === null) {
      return [];
    }

    const predicates = new relationalStore.RdbPredicates('book_source');
    predicates.equalTo('enabled', 1);
    predicates.orderByAsc('sort');

    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookSources: BookSource[] = [];

      while (resultSet.goToNextRow()) {
        const bookSource = this.parseBookSource(resultSet);
        bookSources.push(bookSource);
      }

      resultSet.close();
      return bookSources;
    } catch (error) {
      console.error('Failed to query book sources:', error);
      return [];
    }
  }

  /**
   * 解析书源数据
   */
  private parseBookSource(resultSet: relationalStore.ResultSet): BookSource {
    try {
      return {
        id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
        name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
        url: resultSet.getString(resultSet.getColumnIndex('url')) || '',
        enabled: resultSet.getLong(resultSet.getColumnIndex('enabled')) === 1,
        header: resultSet.getString(resultSet.getColumnIndex('header')) || '',
        searchUrl: resultSet.getString(resultSet.getColumnIndex('search_url')) || '',
        searchRule: JSON.parse(resultSet.getString(resultSet.getColumnIndex('search_rule')) || '{}'),
        findRule: resultSet.isColumnNull(resultSet.getColumnIndex('find_rule')) 
          ? undefined 
          : JSON.parse(resultSet.getString(resultSet.getColumnIndex('find_rule')) || '{}'),
        chapterRule: JSON.parse(resultSet.getString(resultSet.getColumnIndex('chapter_rule')) || '{}'),
        contentRule: JSON.parse(resultSet.getString(resultSet.getColumnIndex('content_rule')) || '{}'),
        ruleType: (resultSet.getString(resultSet.getColumnIndex('rule_type')) || 'jsonpath') as 'xpath' | 'jsonpath' | 'regex',
        sort: resultSet.getLong(resultSet.getColumnIndex('sort')) || 0,
        lastUpdateTime: resultSet.getLong(resultSet.getColumnIndex('last_update_time')) || 0,
        addTime: resultSet.getLong(resultSet.getColumnIndex('add_time')) || 0
      };
    } catch (error) {
      console.error('Failed to parse book source:', error);
      return {
        id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
        name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
        url: resultSet.getString(resultSet.getColumnIndex('url')) || '',
        enabled: resultSet.getLong(resultSet.getColumnIndex('enabled')) === 1,
        header: resultSet.getString(resultSet.getColumnIndex('header')) || '',
        searchUrl: resultSet.getString(resultSet.getColumnIndex('search_url')) || '',
        searchRule: {
          bookList: '',
          name: '',
          author: '',
          cover: undefined,
          intro: undefined,
          bookUrl: '',
          nextUrl: undefined
        },
        findRule: undefined,
        chapterRule: {
          chapterList: '',
          chapterName: '',
          chapterUrl: '',
          nextUrl: undefined
        },
        contentRule: {
          content: '',
          nextUrl: undefined,
          prevUrl: undefined,
          replaceRule: undefined
        },
        ruleType: 'jsonpath',
        sort: 0,
        lastUpdateTime: 0,
        addTime: 0
      };
    }
  }

  /**
   * 插入或更新书籍
   */
  async upsertBook(book: Book): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    const valueBucket: relationalStore.ValuesBucket = {
      'id': book.id,
      'name': book.name,
      'author': book.author || null,
      'cover': book.cover || null,
      'intro': book.intro || null,
      'kind': book.kind || null,
      'word_count': book.wordCount || null,
      'latest_chapter': book.latestChapter || null,
      'book_source_id': book.bookSourceId,
      'book_source_name': book.bookSourceName || null,
      'book_url': book.bookUrl,
      'last_update_time': book.lastUpdateTime,
      'add_time': book.addTime,
      'read_progress': book.readProgress,
      'last_read_chapter': book.lastReadChapter || null
    };

    try {
      await this.rdbStore.insert('book', valueBucket);
    } catch (error) {
      console.error('Failed to insert book:', error);
    }
  }

  /**
   * 查询所有书籍
   */
  async getAllBooks(): Promise<Book[]> {
    if (this.rdbStore === null) {
      return [];
    }

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
      console.error('Failed to query books:', error);
      return [];
    }
  }

  /**
   * 解析书籍数据
   */
  private parseBook(resultSet: relationalStore.ResultSet): Book {
    try {
      return {
        id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
        name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
        author: resultSet.getString(resultSet.getColumnIndex('author')) || '',
        cover: resultSet.isColumnNull(resultSet.getColumnIndex('cover')) 
          ? undefined 
          : resultSet.getString(resultSet.getColumnIndex('cover')) || '',
        intro: resultSet.isColumnNull(resultSet.getColumnIndex('intro')) 
          ? undefined 
          : resultSet.getString(resultSet.getColumnIndex('intro')) || '',
        kind: resultSet.isColumnNull(resultSet.getColumnIndex('kind')) 
          ? undefined 
          : resultSet.getString(resultSet.getColumnIndex('kind')) || '',
        wordCount: resultSet.isColumnNull(resultSet.getColumnIndex('word_count')) 
          ? undefined 
          : resultSet.getLong(resultSet.getColumnIndex('word_count')) || 0,
        latestChapter: resultSet.isColumnNull(resultSet.getColumnIndex('latest_chapter')) 
          ? undefined 
          : resultSet.getString(resultSet.getColumnIndex('latest_chapter')) || '',
        bookSourceId: resultSet.getString(resultSet.getColumnIndex('book_source_id')) || '',
        bookSourceName: resultSet.getString(resultSet.getColumnIndex('book_source_name')) || '',
        bookUrl: resultSet.getString(resultSet.getColumnIndex('book_url')) || '',
        lastUpdateTime: resultSet.getLong(resultSet.getColumnIndex('last_update_time')) || 0,
        addTime: resultSet.getLong(resultSet.getColumnIndex('add_time')) || 0,
        readProgress: resultSet.getLong(resultSet.getColumnIndex('read_progress')) || 0,
        lastReadChapter: resultSet.isColumnNull(resultSet.getColumnIndex('last_read_chapter')) 
          ? undefined 
          : resultSet.getString(resultSet.getColumnIndex('last_read_chapter')) || ''
      };
    } catch (error) {
      console.error('Failed to parse book:', error);
      return {
        id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
        name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
        author: resultSet.getString(resultSet.getColumnIndex('author')) || '',
        cover: undefined,
        intro: undefined,
        kind: undefined,
        wordCount: undefined,
        latestChapter: undefined,
        bookSourceId: resultSet.getString(resultSet.getColumnIndex('book_source_id')) || '',
        bookSourceName: resultSet.getString(resultSet.getColumnIndex('book_source_name')) || '',
        bookUrl: resultSet.getString(resultSet.getColumnIndex('book_url')) || '',
        lastUpdateTime: 0,
        addTime: 0,
        readProgress: 0,
        lastReadChapter: undefined
      };
    }
  }

  /**
   * 获取或创建阅读配置
   */
  async getOrCreateReadConfig(): Promise<ReadConfig> {
    if (this.rdbStore === null) {
      throw new Error('Database not initialized');
    }

    try {
      const predicates = new relationalStore.RdbPredicates('read_config');
      const resultSet = await this.rdbStore.query(predicates, ['*']);

      if (resultSet.goToFirstRow()) {
        const config = this.parseReadConfig(resultSet);
        resultSet.close();
        return config;
      }

      resultSet.close();
      
      // 创建默认配置
      const defaultConfig: relationalStore.ValuesBucket = {
        'font_size': 18,
        'line_spacing': 1.5,
        'page_turn_mode': 'cover',
        'background_color': '#FFFFFF',
        'text_color': '#333333',
        'is_night_mode': 0,
        'brightness': 0.5,
        'auto_scroll': 0,
        'scroll_speed': 50,
        'font_family': 'HarmonyOS Sans',
        'margin_top': 20,
        'margin_bottom': 20,
        'margin_left': 20,
        'margin_right': 20
      };

      await this.rdbStore.insert('read_config', defaultConfig);
      return await this.getOrCreateReadConfig();
    } catch (error) {
      console.error('Failed to get or create read config:', error);
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * 解析阅读配置
   */
  private parseReadConfig(resultSet: relationalStore.ResultSet): ReadConfig {
    try {
      const margins: MarginsConfig = {
        top: resultSet.getLong(resultSet.getColumnIndex('margin_top')) || 20,
        bottom: resultSet.getLong(resultSet.getColumnIndex('margin_bottom')) || 20,
        left: resultSet.getLong(resultSet.getColumnIndex('margin_left')) || 20,
        right: resultSet.getLong(resultSet.getColumnIndex('margin_right')) || 20
      };
      
      return {
        fontSize: resultSet.getLong(resultSet.getColumnIndex('font_size')) || 18,
        lineSpacing: resultSet.getDouble(resultSet.getColumnIndex('line_spacing')) || 1.5,
        pageTurnMode: (resultSet.getString(resultSet.getColumnIndex('page_turn_mode')) || 'cover') as 'cover' | 'slide' | 'scroll' | 'simulation',
        backgroundColor: resultSet.getString(resultSet.getColumnIndex('background_color')) || '#FFFFFF',
        textColor: resultSet.getString(resultSet.getColumnIndex('text_color')) || '#333333',
        isNightMode: resultSet.getLong(resultSet.getColumnIndex('is_night_mode')) === 1,
        brightness: resultSet.getDouble(resultSet.getColumnIndex('brightness')) || 0.5,
        autoScroll: resultSet.getLong(resultSet.getColumnIndex('auto_scroll')) === 1,
        scrollSpeed: resultSet.getLong(resultSet.getColumnIndex('scroll_speed')) || 50,
        fontFamily: resultSet.getString(resultSet.getColumnIndex('font_family')) || 'HarmonyOS Sans',
        margins: margins
      };
    } catch (error) {
      console.error('Failed to parse read config:', error);
      return {
        fontSize: 18,
        lineSpacing: 1.5,
        pageTurnMode: 'cover',
        backgroundColor: '#FFFFFF',
        textColor: '#333333',
        isNightMode: false,
        brightness: 0.5,
        autoScroll: false,
        scrollSpeed: 50,
        fontFamily: 'HarmonyOS Sans',
        margins: {
          top: 20,
          bottom: 20,
          left: 20,
          right: 20
        }
      };
    }
  }

  /**
   * 更新阅读配置
   */
  async updateReadConfig(config: ReadConfig): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    const valueBucket: relationalStore.ValuesBucket = {
      'font_size': config.fontSize,
      'line_spacing': config.lineSpacing,
      'page_turn_mode': config.pageTurnMode,
      'background_color': config.backgroundColor,
      'text_color': config.textColor,
      'is_night_mode': config.isNightMode ? 1 : 0,
      'brightness': config.brightness,
      'auto_scroll': config.autoScroll ? 1 : 0,
      'scroll_speed': config.scrollSpeed,
      'font_family': config.fontFamily,
      'margin_top': config.margins.top,
      'margin_bottom': config.margins.bottom,
      'margin_left': config.margins.left,
      'margin_right': config.margins.right
    };

    try {
      const predicates = new relationalStore.RdbPredicates('read_config');
      await this.rdbStore.update(valueBucket, predicates);
    } catch (error) {
      console.error('Failed to update read config:', error);
    }
  }

  /**
   * 删除书籍
   */
  async deleteBook(bookId: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const predicates = new relationalStore.RdbPredicates('book');
      predicates.equalTo('id', bookId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error('Failed to delete book:', error);
    }
  }

  /**
   * 批量删除书籍
   */
  async batchDeleteBooks(bookIds: string[]): Promise<void> {
    if (this.rdbStore === null || bookIds.length === 0) {
      return;
    }

    try {
      for (const bookId of bookIds) {
        await this.deleteBook(bookId);
      }
    } catch (error) {
      console.error('Failed to batch delete books:', error);
    }
  }

  /**
   * 根据分类查询书籍
   */
  async getBooksByCategory(categoryId: string): Promise<Book[]> {
    if (this.rdbStore === null) {
      return [];
    }

    try {
      const predicates = new relationalStore.RdbPredicates('book_category_relation');
      predicates.equalTo('category_id', categoryId);
      
      const resultSet = await this.rdbStore.query(predicates, ['book_id']);
      const bookIds: string[] = [];
      
      while (resultSet.goToNextRow()) {
        const bookId = resultSet.getString(resultSet.getColumnIndex('book_id'));
        if (bookId) {
          bookIds.push(bookId);
        }
      }
      resultSet.close();

      if (bookIds.length === 0) {
        return [];
      }

      const bookPredicates = new relationalStore.RdbPredicates('book');
      bookPredicates.in('id', bookIds);
      bookPredicates.orderByDesc('last_update_time');

      const bookResultSet = await this.rdbStore.query(bookPredicates, ['*']);
      const books: Book[] = [];

      while (bookResultSet.goToNextRow()) {
        books.push(this.parseBook(bookResultSet));
      }
      bookResultSet.close();

      return books;
    } catch (error) {
      console.error('Failed to get books by category:', error);
      return [];
    }
  }

  /**
   * 添加分类
   */
  async addCategory(category: BookCategory): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'id': category.id,
        'name': category.name,
        'sort': category.sort,
        'create_time': category.createTime
      };

      await this.rdbStore.insert('book_category', valueBucket);
    } catch (error) {
      console.error('Failed to add category:', error);
    }
  }

  /**
   * 获取所有分类
   */
  async getAllCategories(): Promise<BookCategory[]> {
    if (this.rdbStore === null) {
      return [];
    }

    try {
      const predicates = new relationalStore.RdbPredicates('book_category');
      predicates.orderByAsc('sort');

      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const categories: BookCategory[] = [];

      while (resultSet.goToNextRow()) {
        const category: BookCategory = {
          id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
          name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
          sort: resultSet.getLong(resultSet.getColumnIndex('sort')) || 0,
          createTime: resultSet.getLong(resultSet.getColumnIndex('create_time')) || 0
        };
        categories.push(category);
      }
      resultSet.close();

      return categories;
    } catch (error) {
      console.error('Failed to get all categories:', error);
      return [];
    }
  }

  /**
   * 删除分类
   */
  async deleteCategory(categoryId: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const predicates = new relationalStore.RdbPredicates('book_category');
      predicates.equalTo('id', categoryId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error('Failed to delete category:', error);
    }
  }

  /**
   * 将书籍添加到分类
   */
  async addBookToCategory(bookId: string, categoryId: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'book_id': bookId,
        'category_id': categoryId
      };

      await this.rdbStore.insert('book_category_relation', valueBucket);
    } catch (error) {
      console.error('Failed to add book to category:', error);
    }
  }

  /**
   * 从分类移除书籍
   */
  async removeBookFromCategory(bookId: string, categoryId: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const predicates = new relationalStore.RdbPredicates('book_category_relation');
      predicates.equalTo('book_id', bookId);
      predicates.equalTo('category_id', categoryId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error('Failed to remove book from category:', error);
    }
  }

  /**
   * 插入或更新章节
   */
  async upsertChapter(chapter: Chapter): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'id': chapter.id,
        'book_id': chapter.bookId,
        'title': chapter.title,
        'url': chapter.url,
        'order': chapter.order,
        'is_vip': chapter.isVip ? 1 : 0
      };

      await this.rdbStore.insert('chapter', valueBucket);
    } catch (error) {
      console.error('Failed to upsert chapter:', error);
    }
  }

  /**
   * 批量插入章节
   */
  async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    if (this.rdbStore === null || chapters.length === 0) {
      return;
    }

    try {
      for (const chapter of chapters) {
        await this.upsertChapter(chapter);
      }
    } catch (error) {
      console.error('Failed to batch upsert chapters:', error);
    }
  }

  /**
   * 获取书籍的章节列表
   */
  async getChaptersByBookId(bookId: string): Promise<Chapter[]> {
    if (this.rdbStore === null) {
      return [];
    }

    try {
      const predicates = new relationalStore.RdbPredicates('chapter');
      predicates.equalTo('book_id', bookId);
      predicates.orderByAsc('order');

      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const chapters: Chapter[] = [];

      while (resultSet.goToNextRow()) {
        const chapter: Chapter = {
          id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
          bookId: resultSet.getString(resultSet.getColumnIndex('book_id')) || '',
          title: resultSet.getString(resultSet.getColumnIndex('title')) || '',
          url: resultSet.getString(resultSet.getColumnIndex('url')) || '',
          order: resultSet.getLong(resultSet.getColumnIndex('order')) || 0,
          isVip: resultSet.getLong(resultSet.getColumnIndex('is_vip')) === 1
        };
        chapters.push(chapter);
      }
      resultSet.close();

      return chapters;
    } catch (error) {
      console.error('Failed to get chapters by book id:', error);
      return [];
    }
  }

  /**
   * 添加书签
   */
  async addBookmark(bookmark: Bookmark): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'id': bookmark.id,
        'book_id': bookmark.bookId,
        'chapter_id': bookmark.chapterId,
        'chapter_title': bookmark.chapterTitle,
        'content': bookmark.content,
        'create_time': bookmark.createTime
      };

      await this.rdbStore.insert('bookmark', valueBucket);
    } catch (error) {
      console.error('Failed to add bookmark:', error);
    }
  }

  /**
   * 获取书籍的所有书签
   */
  async getBookmarksByBookId(bookId: string): Promise<Bookmark[]> {
    if (this.rdbStore === null) {
      return [];
    }

    try {
      const predicates = new relationalStore.RdbPredicates('bookmark');
      predicates.equalTo('book_id', bookId);
      predicates.orderByDesc('create_time');

      const resultSet = await this.rdbStore.query(predicates, ['*']);
      const bookmarks: Bookmark[] = [];

      while (resultSet.goToNextRow()) {
        const bookmark: Bookmark = {
          id: resultSet.getString(resultSet.getColumnIndex('id')) || '',
          bookId: resultSet.getString(resultSet.getColumnIndex('book_id')) || '',
          chapterId: resultSet.getString(resultSet.getColumnIndex('chapter_id')) || '',
          chapterTitle: resultSet.getString(resultSet.getColumnIndex('chapter_title')) || '',
          content: resultSet.getString(resultSet.getColumnIndex('content')) || '',
          createTime: resultSet.getLong(resultSet.getColumnIndex('create_time')) || 0
        };
        bookmarks.push(bookmark);
      }
      resultSet.close();

      return bookmarks;
    } catch (error) {
      console.error('Failed to get bookmarks by book id:', error);
      return [];
    }
  }

  /**
   * 删除书签
   */
  async deleteBookmark(bookmarkId: string): Promise<void> {
    if (this.rdbStore === null) {
      return;
    }

    try {
      const predicates = new relationalStore.RdbPredicates('bookmark');
      predicates.equalTo('id', bookmarkId);
      await this.rdbStore.delete(predicates);
    } catch (error) {
      console.error('Failed to delete bookmark:', error);
    }
  }
}

// 单例实例
export const databaseManager = new DatabaseManager();
