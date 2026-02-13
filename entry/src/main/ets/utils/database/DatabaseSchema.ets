import relationalStore from '@ohos.data.relationalStore';

/**
 * 数据库表结构定义
 */
export class DatabaseSchema {
  /**
   * 数据库配置
   */
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
      last_read_chapter TEXT
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
      "order" INTEGER DEFAULT 0,
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
          console.error(`Failed to execute SQL: ${sql}, Error: ${sqlError instanceof Error ? sqlError.message : String(sqlError)}`);
          throw (sqlError instanceof Error ? sqlError : new Error(String(sqlError)));
        }
      }
    } catch (error) {
      console.error(`Failed to create tables: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
}
