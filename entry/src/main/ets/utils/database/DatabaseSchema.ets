import { relationalStore } from '@kit.ArkData';
import { Logger } from '../performance/Logger';
import { SqlSecurityUtils } from '../security/SqlSecurityUtils';

export class DatabaseSchema {
  private static readonly TAG = 'DatabaseSchema';

  static readonly DB_CONFIG: relationalStore.StoreConfig = {
    name: 'AstroRead.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };

  /**
   * 数据库表创建语句
   */
  static readonly TABLE_SQL: string[] = [
    // 书籍表
    `CREATE TABLE IF NOT EXISTS book (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      author TEXT,
      cover TEXT,
      intro TEXT,
      kind TEXT,
      word_count INTEGER DEFAULT 0,
      latest_chapter TEXT,
      book_source_id TEXT,
      book_source_name TEXT,
      book_url TEXT,
      last_update_time INTEGER DEFAULT 0,
      add_time INTEGER DEFAULT 0,
      read_progress REAL DEFAULT 0,
      last_read_chapter TEXT,
      last_read_chapter_index INTEGER DEFAULT 0
    )`,
    
    // 书源表
    `CREATE TABLE IF NOT EXISTS book_source (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      enabled INTEGER DEFAULT 1,
      header TEXT,
      search_url TEXT,
      search_rule TEXT,
      find_rule TEXT,
      chapter_rule TEXT,
      content_rule TEXT,
      rule_type TEXT DEFAULT 'xpath',
      sort INTEGER DEFAULT 0,
      last_update_time INTEGER DEFAULT 0,
      add_time INTEGER DEFAULT 0
    )`,
    
    // 阅读配置表
    `CREATE TABLE IF NOT EXISTS read_config (
      id TEXT PRIMARY KEY,
      font_size INTEGER DEFAULT 16,
      line_spacing REAL DEFAULT 1.5,
      page_turn_mode TEXT DEFAULT 'cover',
      background_color TEXT DEFAULT '#FFFFFF',
      text_color TEXT DEFAULT '#333333',
      is_night_mode INTEGER DEFAULT 0,
      brightness REAL DEFAULT 0.5,
      auto_scroll INTEGER DEFAULT 0,
      scroll_speed INTEGER DEFAULT 50,
      font_family TEXT DEFAULT 'HarmonyOS Sans',
      margins TEXT,
      volume_key_page_turn INTEGER DEFAULT 1,
      click_page_turn INTEGER DEFAULT 1,
      update_time INTEGER DEFAULT 0
    )`,
    
    // 章节表
    `CREATE TABLE IF NOT EXISTS chapter (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      title TEXT NOT NULL,
      url TEXT NOT NULL,
      chapter_order INTEGER DEFAULT 0,
      is_vip INTEGER DEFAULT 0,
      FOREIGN KEY (book_id) REFERENCES book (id) ON DELETE CASCADE
    )`,
    
    // 书签表
    `CREATE TABLE IF NOT EXISTS bookmark (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      chapter_id TEXT NOT NULL,
      chapter_title TEXT NOT NULL,
      content TEXT,
      create_time INTEGER DEFAULT 0,
      FOREIGN KEY (book_id) REFERENCES book (id) ON DELETE CASCADE
    )`,
    
    // 书籍分类表
    `CREATE TABLE IF NOT EXISTS book_category (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      sort INTEGER DEFAULT 0,
      create_time INTEGER DEFAULT 0
    )`,
    
    // 书籍分类关联表
    `CREATE TABLE IF NOT EXISTS book_category_relation (
      book_id TEXT NOT NULL,
      category_id TEXT NOT NULL,
      PRIMARY KEY (book_id, category_id),
      FOREIGN KEY (book_id) REFERENCES book (id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES book_category (id) ON DELETE CASCADE
    )`
  ];

    /**
     * 索引创建语句
     * 用于提升查询性能
     */
    static readonly INDEX_SQL: string[] = [
      // book 表索引
      'CREATE INDEX IF NOT EXISTS idx_book_source_id ON book (book_source_id)',
      'CREATE INDEX IF NOT EXISTS idx_book_name ON book (name)',
      'CREATE INDEX IF NOT EXISTS idx_book_author ON book (author)',
      'CREATE INDEX IF NOT EXISTS idx_book_add_time ON book (add_time)',

      // book_source 表索引
      'CREATE INDEX IF NOT EXISTS idx_book_source_enabled ON book_source (enabled)',
      'CREATE INDEX IF NOT EXISTS idx_book_source_name ON book_source (name)',
      'CREATE INDEX IF NOT EXISTS idx_book_source_sort ON book_source (sort)',

      // chapter 表索引
      'CREATE INDEX IF NOT EXISTS idx_chapter_book_id ON chapter (book_id)',
      'CREATE INDEX IF NOT EXISTS idx_chapter_order ON chapter (chapter_order)',
      'CREATE INDEX IF NOT EXISTS idx_chapter_url ON chapter (url)',

      // bookmark 表索引
      'CREATE INDEX IF NOT EXISTS idx_bookmark_book_id ON bookmark (book_id)',
      'CREATE INDEX IF NOT EXISTS idx_bookmark_chapter_id ON bookmark (chapter_id)',
      'CREATE INDEX IF NOT EXISTS idx_bookmark_create_time ON bookmark (create_time)',

      // book_category_relation 表索引
      'CREATE INDEX IF NOT EXISTS idx_category_relation_book ON book_category_relation (book_id)',
      'CREATE INDEX IF NOT EXISTS idx_category_relation_category ON book_category_relation (category_id)'
    ];

  /**
   * 创建所有数据库表
   */
  static async createTables(rdbStore: relationalStore.RdbStore): Promise<void> {
    try {
      for (const sql of DatabaseSchema.TABLE_SQL) {
        try {
          await rdbStore.executeSql(sql);
        } catch (sqlError) {
          Logger.error(DatabaseSchema.TAG, `执行SQL失败: ${sql}, 错误: ${sqlError instanceof Error ? sqlError.message : String(sqlError)}`);
          throw (sqlError instanceof Error ? sqlError : new Error(String(sqlError)));
        }
      }
    } catch (error) {
      Logger.error(DatabaseSchema.TAG, `创建数据表失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 数据库迁移 - 为已有表添加缺失的列
   */
  static async migrateDatabase(rdbStore: relationalStore.RdbStore): Promise<void> {
    // 检查并添加 last_read_chapter_index 列（如果不存在）
    await DatabaseSchema.addColumnIfNotExists(rdbStore, 'book', 'last_read_chapter_index', 'INTEGER DEFAULT 0');

    // 执行其他迁移
    await DatabaseSchema.migrateChapterOrderColumn(rdbStore);
  }

  /**
   * 检查列是否存在，如果不存在则添加
   * 使用SqlSecurityUtils防止SQL注入
   */
  private static async addColumnIfNotExists(
    rdbStore: relationalStore.RdbStore,
    tableName: string,
    columnName: string,
    columnDefinition: string
  ): Promise<void> {
    try {
      // 使用SqlSecurityUtils构建安全的查询
      const safeTableInfoQuery = SqlSecurityUtils.buildTableInfoQuery(tableName);
      const tableInfo = await rdbStore.querySql(safeTableInfoQuery);
      const columnNames: string[] = [];
      while (tableInfo.goToNextRow()) {
        const nameIndex = tableInfo.getColumnIndex('name');
        columnNames.push(tableInfo.getString(nameIndex));
      }
      tableInfo.close();

      if (columnNames.includes(columnName)) {
        Logger.debug(DatabaseSchema.TAG, `表 ${tableName} 的列 ${columnName} 已存在，跳过添加`);
        return;
      }

      // 使用SqlSecurityUtils构建安全的ALTER TABLE语句
      const sql = SqlSecurityUtils.buildAddColumnSql(tableName, columnName, columnDefinition);
      await rdbStore.executeSql(sql);
      Logger.info(DatabaseSchema.TAG, `成功为表 ${tableName} 添加列 ${columnName}`);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      // 如果是重复列错误，静默忽略（可能是并发导致的竞态条件）
      if (errorMsg.includes('duplicate column name') || errorMsg.includes('already exists')) {
        Logger.debug(DatabaseSchema.TAG, `列 ${columnName} 已存在（并发添加），跳过`);
      } else {
        Logger.warn(DatabaseSchema.TAG, `添加列 ${columnName} 失败: ${errorMsg}`);
      }
    }
  }

  /**
   * 迁移chapter表的order列到chapter_order列
   * 使用SqlSecurityUtils防止SQL注入
   */
  static async migrateChapterOrderColumn(rdbStore: relationalStore.RdbStore): Promise<void> {
    try {
      // 使用SqlSecurityUtils构建安全的查询
      const safeTableInfoQuery = SqlSecurityUtils.buildTableInfoQuery('chapter');
      const tableInfo = await rdbStore.querySql(safeTableInfoQuery);
      const columnNames: string[] = [];
      while (tableInfo.goToNextRow()) {
        const nameIndex = tableInfo.getColumnIndex('name');
        columnNames.push(tableInfo.getString(nameIndex));
      }
      tableInfo.close();

      const hasOldColumn = columnNames.includes('order');
      const hasNewColumn = columnNames.includes('chapter_order');

      if (hasOldColumn && !hasNewColumn) {
        Logger.info(DatabaseSchema.TAG, '开始迁移chapter表: order -> chapter_order');
        await rdbStore.executeSql(`ALTER TABLE chapter ADD COLUMN chapter_order INTEGER DEFAULT 0`);
        await rdbStore.executeSql(`UPDATE chapter SET chapter_order = "order" WHERE chapter_order = 0`);
        Logger.info(DatabaseSchema.TAG, 'chapter表迁移完成');
      } else if (!hasOldColumn && !hasNewColumn) {
        Logger.info(DatabaseSchema.TAG, '添加chapter_order列');
        await rdbStore.executeSql(`ALTER TABLE chapter ADD COLUMN chapter_order INTEGER DEFAULT 0`);
      }
    } catch (error) {
      Logger.warn(DatabaseSchema.TAG, `chapter表迁移警告: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
