import relationalStore from '@ohos.data.relationalStore';
import { Logger } from '../Logger';

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
    const migrations: string[] = [
      `ALTER TABLE book ADD COLUMN last_read_chapter_index INTEGER DEFAULT 0`
    ];

    for (const sql of migrations) {
      try {
        await rdbStore.executeSql(sql);
        Logger.info(DatabaseSchema.TAG, `数据库迁移成功: ${sql.substring(0, 50)}...`);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        if (errorMsg.includes('duplicate column name') || errorMsg.includes('already exists')) {
          Logger.debug(DatabaseSchema.TAG, `列已存在，跳过迁移`);
        } else {
          Logger.warn(DatabaseSchema.TAG, `数据库迁移警告: ${errorMsg}`);
        }
      }
    }

    await DatabaseSchema.migrateChapterOrderColumn(rdbStore);
  }

  /**
   * 迁移chapter表的order列到chapter_order列
   */
  static async migrateChapterOrderColumn(rdbStore: relationalStore.RdbStore): Promise<void> {
    try {
      const tableInfo = await rdbStore.querySql(`PRAGMA table_info(chapter)`);
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
