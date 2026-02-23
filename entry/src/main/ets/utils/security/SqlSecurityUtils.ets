/**
 * SqlSecurityUtils - SQL安全工具类
 * 提供SQL注入防护、标识符验证等功能
 */

import { Logger } from "../performance/Logger";

export class SqlSecurityUtils {
  private static readonly TAG = 'SqlSecurityUtils';
  
  // 有效的SQL标识符正则（字母、数字、下划线，不能以数字开头）
  private static readonly VALID_IDENTIFIER_REGEX = /^[a-zA-Z_][a-zA-Z0-9_]*$/;
  
  // SQL关键字黑名单
  private static readonly SQL_KEYWORDS = new Set([
    'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER',
    'TABLE', 'DATABASE', 'INDEX', 'VIEW', 'TRIGGER', 'PROCEDURE',
    'EXEC', 'EXECUTE', 'UNION', 'UNION ALL', 'WHERE', 'FROM', 'JOIN',
    'INNER', 'OUTER', 'LEFT', 'RIGHT', 'FULL', 'CROSS', 'ON', 'AND',
    'OR', 'NOT', 'NULL', 'IS', 'LIKE', 'IN', 'EXISTS', 'BETWEEN',
    'ORDER', 'GROUP', 'HAVING', 'LIMIT', 'OFFSET', 'AS', 'DISTINCT',
    'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'IF', 'WHILE', 'FOR',
    'RETURN', 'GO', 'COMMIT', 'ROLLBACK', 'TRANSACTION', 'SAVEPOINT'
  ]);
  
  // 危险字符模式
  private static readonly DANGEROUS_PATTERNS = [
    /;\s*--/,           // 注释
    /\/\*/,             // 块注释开始
    /\*\//,             // 块注释结束
    /';/,               // 字符串注入
    /"/,                // 双引号
    /\\/,               // 反斜杠
    /\x00/,             // 空字节
    /\x08\x0a\x0d\x1a/, // 特殊字符
  ];

  /**
   * 验证SQL标识符（表名、列名等）
   * @param identifier 标识符
   * @returns 是否有效
   */
  static isValidIdentifier(identifier: string): boolean {
    if (!identifier || identifier.length === 0) {
      return false;
    }
    
    // 长度限制
    if (identifier.length > 128) {
      Logger.warn(SqlSecurityUtils.TAG, `标识符过长: ${identifier.length}`);
      return false;
    }
    
    // 检查是否匹配有效标识符模式
    if (!SqlSecurityUtils.VALID_IDENTIFIER_REGEX.test(identifier)) {
      Logger.warn(SqlSecurityUtils.TAG, `标识符包含非法字符: ${identifier}`);
      return false;
    }
    
    // 检查是否是SQL关键字
    if (SqlSecurityUtils.SQL_KEYWORDS.has(identifier.toUpperCase())) {
      Logger.warn(SqlSecurityUtils.TAG, `标识符是SQL关键字: ${identifier}`);
      return false;
    }
    
    return true;
  }

  /**
   * 转义SQL标识符（添加引号）
   * @param identifier 标识符
   * @returns 转义后的标识符
   */
  static escapeIdentifier(identifier: string): string {
    if (!SqlSecurityUtils.isValidIdentifier(identifier)) {
      throw new Error(`无效的SQL标识符: ${identifier}`);
    }
    
    // SQLite中使用双引号包裹标识符
    return `"${identifier.replace(/"/g, '""')}"`;
  }

  /**
   * 清理表名
   * @param tableName 表名
   * @returns 清理后的表名
   */
  static sanitizeTableName(tableName: string): string {
    if (!tableName) return '';
    
    // 移除危险字符
    let sanitized = tableName.trim();
    
    // 检查危险模式
    for (const pattern of SqlSecurityUtils.DANGEROUS_PATTERNS) {
      if (pattern.test(sanitized)) {
        Logger.warn(SqlSecurityUtils.TAG, `表名包含危险模式: ${tableName}`);
        return '';
      }
    }
    
    // 只允许字母、数字、下划线
    sanitized = sanitized.replace(/[^a-zA-Z0-9_]/g, '');
    
    // 不能以数字开头
    if (/^\d/.test(sanitized)) {
      sanitized = '_' + sanitized;
    }
    
    return sanitized;
  }

  /**
   * 清理列名
   * @param columnName 列名
   * @returns 清理后的列名
   */
  static sanitizeColumnName(columnName: string): string {
    return SqlSecurityUtils.sanitizeTableName(columnName);
  }

  /**
   * 验证列定义
   * @param columnDefinition 列定义
   * @returns 是否有效
   */
  static isValidColumnDefinition(columnDefinition: string): boolean {
    if (!columnDefinition) return false;
    
    // 只允许特定的数据类型和约束
    const allowedPatterns = [
      /^\s*(INTEGER|TEXT|REAL|BLOB|NUMERIC)\s*$/i,
      /^\s*(INTEGER|TEXT|REAL|BLOB|NUMERIC)\s+(PRIMARY\s+KEY|UNIQUE|NOT\s+NULL|DEFAULT\s+[^;]+)\s*$/i,
      /^\s*(INTEGER|TEXT|REAL|BLOB|NUMERIC)\s+\(\s*\d+\s*\)\s*$/i,
    ];
    
    for (const pattern of allowedPatterns) {
      if (pattern.test(columnDefinition)) {
        return true;
      }
    }
    
    Logger.warn(SqlSecurityUtils.TAG, `无效的列定义: ${columnDefinition}`);
    return false;
  }

  /**
   * 构建安全的PRAGMA table_info查询
   * @param tableName 表名
   * @returns 安全的SQL语句
   */
  static buildTableInfoQuery(tableName: string): string {
    const sanitizedTable = SqlSecurityUtils.sanitizeTableName(tableName);
    if (!sanitizedTable) {
      throw new Error(`无效的表名: ${tableName}`);
    }
    
    return `PRAGMA table_info(${SqlSecurityUtils.escapeIdentifier(sanitizedTable)})`;
  }

  /**
   * 构建安全的ALTER TABLE ADD COLUMN语句
   * @param tableName 表名
   * @param columnName 列名
   * @param columnDefinition 列定义
   * @returns 安全的SQL语句
   */
  static buildAddColumnSql(
    tableName: string, 
    columnName: string, 
    columnDefinition: string
  ): string {
    const sanitizedTable = SqlSecurityUtils.sanitizeTableName(tableName);
    const sanitizedColumn = SqlSecurityUtils.sanitizeColumnName(columnName);
    
    if (!sanitizedTable || !sanitizedColumn) {
      throw new Error(`无效的表名或列名: ${tableName}, ${columnName}`);
    }
    
    if (!SqlSecurityUtils.isValidColumnDefinition(columnDefinition)) {
      throw new Error(`无效的列定义: ${columnDefinition}`);
    }
    
    return `ALTER TABLE ${SqlSecurityUtils.escapeIdentifier(sanitizedTable)} ` +
           `ADD COLUMN ${SqlSecurityUtils.escapeIdentifier(sanitizedColumn)} ${columnDefinition}`;
  }

  /**
   * 检查字符串是否包含SQL注入
   * @param input 输入字符串
   * @returns 是否安全
   */
  static isSafeInput(input: string): boolean {
    if (!input) return true;
    
    // 检查危险模式
    for (const pattern of SqlSecurityUtils.DANGEROUS_PATTERNS) {
      if (pattern.test(input)) {
        return false;
      }
    }
    
    // 检查SQL关键字组合
    const upperInput = input.toUpperCase();
    const suspiciousPatterns = [
      /;\s*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)/,
      /UNION\s+SELECT/,
      /EXEC\s*\(/,
      /EXECUTE\s*\(/,
    ];
    
    for (const pattern of suspiciousPatterns) {
      if (pattern.test(upperInput)) {
        return false;
      }
    }
    
    return true;
  }

  /**
   * 参数化查询占位符
   * @param index 参数索引
   * @returns 占位符
   */
  static getParameterPlaceholder(index: number): string {
    return `?${index}`;
  }
}

export default SqlSecurityUtils;
