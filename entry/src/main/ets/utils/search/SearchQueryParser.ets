/**
 * SearchQueryParser - 搜索查询解析器
 * 支持高级搜索语法：引号短语、减号排除、字段限定等
 */

import { Logger } from "../performance/Logger";
import { util } from '@kit.ArkTS';

export interface ParsedQuery {
  original: string;                    // 原始查询
  keywords: string[];                  // 普通关键词
  exclude: string[];                   // 排除关键词（-keyword）
  exactPhrases: string[];              // 精确短语（"phrase"）
  fieldQueries: Map<string, string>;   // 字段限定（field:value）
  isAdvanced: boolean;                 // 是否包含高级语法
  normalized: string;                  // 规范化后的查询（用于缓存键）
}

export interface QueryEncodingConfig {
  encoding: 'urlencode' | 'base64' | 'double-urlencode' | 'none';
  separator: string;                   // 多关键词分隔符
  supportAdvanced: boolean;            // 是否支持高级语法
}

export class SearchQueryParser {
  private static readonly TAG = 'SearchQueryParser';
  
  // 默认配置
  private static defaultConfig: QueryEncodingConfig = {
    encoding: 'urlencode',
    separator: '+',
    supportAdvanced: false
  };

  /**
   * 解析搜索查询
   */
  static parse(query: string): ParsedQuery {
    const result: ParsedQuery = {
      original: query,
      keywords: [],
      exclude: [],
      exactPhrases: [],
      fieldQueries: new Map(),
      isAdvanced: false,
      normalized: ''
    };

    if (!query || query.trim().length === 0) {
      result.normalized = '';
      return result;
    }

    let remainingQuery = query.trim();
    
    // 1. 解析双引号内的精确短语
    result.exactPhrases = SearchQueryParser.extractExactPhrases(remainingQuery);
    remainingQuery = SearchQueryParser.removeExactPhrases(remainingQuery);
    
    // 2. 解析减号排除的关键词
    result.exclude = SearchQueryParser.extractExcludeTerms(remainingQuery);
    remainingQuery = SearchQueryParser.removeExcludeTerms(remainingQuery);
    
    // 3. 解析字段限定查询
    result.fieldQueries = SearchQueryParser.extractFieldQueries(remainingQuery);
    remainingQuery = SearchQueryParser.removeFieldQueries(remainingQuery);
    
    // 4. 剩余部分作为普通关键词
    result.keywords = SearchQueryParser.extractKeywords(remainingQuery);
    
    // 5. 判断是否为高级查询
    result.isAdvanced = result.exactPhrases.length > 0 || 
                       result.exclude.length > 0 || 
                       result.fieldQueries.size > 0;
    
    // 6. 生成规范化查询（用于缓存键）
    result.normalized = SearchQueryParser.normalizeQuery(result);
    
    Logger.debug(SearchQueryParser.TAG, 
      `查询解析完成: 原始="${query}", ` +
      `关键词=${result.keywords.length}, ` +
      `排除=${result.exclude.length}, ` +
      `短语=${result.exactPhrases.length}, ` +
      `字段=${result.fieldQueries.size}, ` +
      `高级=${result.isAdvanced}`
    );
    
    return result;
  }

  /**
   * 提取精确短语（双引号内）
   */
  private static extractExactPhrases(query: string): string[] {
    const phrases: string[] = [];
    const regex = /"([^"]+)"/g;
    let match: RegExpExecArray | null;
    
    while ((match = regex.exec(query)) !== null) {
      const phrase = match[1].trim();
      if (phrase.length > 0) {
        phrases.push(phrase);
      }
    }
    
    return phrases;
  }

  /**
   * 移除精确短语
   */
  private static removeExactPhrases(query: string): string {
    return query.replace(/"[^"]+"/g, '').trim();
  }

  /**
   * 提取排除关键词（减号开头）
   */
  private static extractExcludeTerms(query: string): string[] {
    const excludeTerms: string[] = [];
    const regex = /-(\S+)/g;
    let match: RegExpExecArray | null;
    
    while ((match = regex.exec(query)) !== null) {
      const term = match[1].trim();
      if (term.length > 0) {
        excludeTerms.push(term);
      }
    }
    
    return excludeTerms;
  }

  /**
   * 移除排除关键词
   */
  private static removeExcludeTerms(query: string): string {
    return query.replace(/-\S+/g, '').trim();
  }

  /**
   * 提取字段限定查询（field:value）
   */
  private static extractFieldQueries(query: string): Map<string, string> {
    const fieldQueries = new Map<string, string>();
    const regex = /(\w+):\s*([^\s]+)/g;
    let match: RegExpExecArray | null;
    
    while ((match = regex.exec(query)) !== null) {
      const field = match[1].toLowerCase();
      const value = match[2].trim();
      
      if (field && value) {
        fieldQueries.set(field, value);
      }
    }
    
    return fieldQueries;
  }

  /**
   * 移除字段限定查询
   */
  private static removeFieldQueries(query: string): string {
    return query.replace(/\w+:\s*[^\s]+/g, '').trim();
  }

  /**
   * 提取普通关键词
   */
  private static extractKeywords(query: string): string[] {
    return query
      .split(/\s+/)
      .map(term => term.trim())
      .filter(term => term.length > 0);
  }

  /**
   * 规范化查询（用于生成缓存键）
   */
  private static normalizeQuery(parsed: ParsedQuery): string {
    const parts: string[] = [];
    
    // 添加普通关键词（按字母排序）
    if (parsed.keywords.length > 0) {
      const sortedKeywords = [...parsed.keywords].sort();
      parts.push(`keywords:${sortedKeywords.join(',')}`);
    }
    
    // 添加精确短语（按字母排序）
    if (parsed.exactPhrases.length > 0) {
      const sortedPhrases = [...parsed.exactPhrases].sort();
      parts.push(`phrases:${sortedPhrases.join(',')}`);
    }
    
    // 添加排除关键词（按字母排序）
    if (parsed.exclude.length > 0) {
      const sortedExclude = [...parsed.exclude].sort();
      parts.push(`exclude:${sortedExclude.join(',')}`);
    }
    
    // 添加字段查询（按键排序）
    if (parsed.fieldQueries.size > 0) {
      const fieldEntries = Array.from(parsed.fieldQueries.entries());
      fieldEntries.sort((a, b) => a[0].localeCompare(b[0]));
      const sortedFields: string[] = [];
      for (let i = 0; i < fieldEntries.length; i++) {
        const field = fieldEntries[i][0];
        const value = fieldEntries[i][1];
        sortedFields.push(`${field}:${value}`);
      }
      parts.push(`fields:${sortedFields.join(',')}`);
    }
    
    return parts.join('|');
  }

  /**
   * 根据书源配置编码查询
   */
  static encodeQuery(query: string, config: QueryEncodingConfig): string {
    const parsed = SearchQueryParser.parse(query);
    
    if (!config.supportAdvanced && parsed.isAdvanced) {
      Logger.debug(SearchQueryParser.TAG, '书源不支持高级语法，降级为简单查询');
      return SearchQueryParser.encodeSimpleQuery(parsed.keywords, config);
    }
    
    switch (config.encoding) {
      case 'urlencode':
        return SearchQueryParser.encodeUrlQuery(parsed, config);
      case 'base64':
        return SearchQueryParser.encodeBase64Query(parsed, config);
      case 'double-urlencode':
        return SearchQueryParser.encodeDoubleUrlQuery(parsed, config);
      case 'none':
        return SearchQueryParser.encodePlainQuery(parsed, config);
      default:
        return SearchQueryParser.encodeUrlQuery(parsed, config);
    }
  }


  /**
   * 编码简单查询（不支持高级语法）
   */
  private static encodeSimpleQuery(keywords: string[], config: QueryEncodingConfig): string {
    const encodedKeywords = keywords.map(k => SearchQueryParser.encodeKeyword(k, config.encoding));
    return encodedKeywords.join(config.separator);
  }

  /**
   * 编码URL查询
   */
  private static encodeUrlQuery(parsed: ParsedQuery, config: QueryEncodingConfig): string {
    const parts: string[] = [];
    
    // 普通关键词
    if (parsed.keywords.length > 0) {
      const encodedKeywords = parsed.keywords.map(k => SearchQueryParser.encodeKeyword(k, 'urlencode'));
      parts.push(encodedKeywords.join(config.separator));
    }
    
    // 精确短语（用引号包裹）
    if (parsed.exactPhrases.length > 0) {
      const encodedPhrases = parsed.exactPhrases.map(p => `"${encodeURIComponent(p)}"`);
      parts.push(encodedPhrases.join(' '));
    }
    
    // 排除关键词
    if (parsed.exclude.length > 0) {
      const encodedExclude = parsed.exclude.map(e => `-${encodeURIComponent(e)}`);
      parts.push(encodedExclude.join(' '));
    }
    
    // 字段查询
    if (parsed.fieldQueries.size > 0) {
      const fieldParts: string[] = [];
      const entries = Array.from(parsed.fieldQueries.entries());
      for (let i = 0; i < entries.length; i++) {
        const field = entries[i][0];
        const value = entries[i][1];
        fieldParts.push(`${field}:${encodeURIComponent(value)}`);
      }
      parts.push(fieldParts.join(' '));
    }
    
    return parts.join(' ');
  }


  /**
   * 编码Base64查询
   */
  private static encodeBase64Query(parsed: ParsedQuery, config: QueryEncodingConfig): string {
    const queryString = SearchQueryParser.encodePlainQuery(parsed, config);
    try {
      const encoder = new util.Base64Helper();
      return encoder.encodeToStringSync(new Uint8Array(queryString.split('').map(c => c.charCodeAt(0))));
    } catch (e) {
      Logger.error(SearchQueryParser.TAG, `Base64编码失败: ${e}`);
      return encodeURIComponent(queryString);
    }
  }

  /**
   * 编码双重URL编码查询
   */
  private static encodeDoubleUrlQuery(parsed: ParsedQuery, config: QueryEncodingConfig): string {
    const queryString = SearchQueryParser.encodePlainQuery(parsed, config);
    return encodeURIComponent(encodeURIComponent(queryString));
  }

  /**
   * 编码纯文本查询
   */
  private static encodePlainQuery(parsed: ParsedQuery, config: QueryEncodingConfig): string {
    const parts: string[] = [];
    
    // 普通关键词
    if (parsed.keywords.length > 0) {
      parts.push(parsed.keywords.join(config.separator));
    }
    
    // 精确短语
    if (parsed.exactPhrases.length > 0) {
      parts.push(parsed.exactPhrases.map(p => `"${p}"`).join(' '));
    }
    
    // 排除关键词
    if (parsed.exclude.length > 0) {
      parts.push(parsed.exclude.map(e => `-${e}`).join(' '));
    }
    
    // 字段查询
    if (parsed.fieldQueries.size > 0) {
      const fieldParts: string[] = [];
      const entries = Array.from(parsed.fieldQueries.entries());
      for (let i = 0; i < entries.length; i++) {
        const field = entries[i][0];
        const value = entries[i][1];
        fieldParts.push(`${field}:${value}`);
      }
      parts.push(fieldParts.join(' '));
    }
    
    return parts.join(' ');
  }

  /**
   * 编码单个关键词
   */
  private static encodeKeyword(keyword: string, encoding: string): string {
    switch (encoding) {
      case 'urlencode':
      case 'double-urlencode':
        return encodeURIComponent(keyword);
      case 'base64': {
        try {
          const encoder = new util.Base64Helper();
          return encoder.encodeToStringSync(new Uint8Array(keyword.split('').map(c => c.charCodeAt(0))));
        } catch (e) {
          Logger.error(SearchQueryParser.TAG, `Base64编码关键词失败: ${e}`);
          return encodeURIComponent(keyword);
        }
      }
      case 'none':
        return keyword;
      default:
        return encodeURIComponent(keyword);
    }
  }

  /**
   * 安全过滤用户输入
   */
  static sanitizeInput(query: string): string {
    if (!query) return '';
    
    let sanitized: string = query.replace(/[\x00-\x1F\x7F]/g, '');
    
    if (sanitized.length > 200) {
      sanitized = sanitized.substring(0, 200);
      Logger.warn(SearchQueryParser.TAG, `查询过长，已截断至200字符`);
    }
    
    sanitized = sanitized.replace(/\s+/g, ' ').trim();
    
    return sanitized;
  }

  /**
   * 检查查询是否为空
   */
  static isEmptyQuery(parsed: ParsedQuery): boolean {
    return parsed.keywords.length === 0 && 
           parsed.exactPhrases.length === 0 && 
           parsed.fieldQueries.size === 0;
  }

  /**
   * 获取查询摘要（用于日志）
   */
  static getQuerySummary(parsed: ParsedQuery): string {
    const parts: string[] = [];
    
    if (parsed.keywords.length > 0) {
      parts.push(`关键词: ${parsed.keywords.join(', ')}`);
    }
    
    if (parsed.exactPhrases.length > 0) {
      parts.push(`短语: ${parsed.exactPhrases.map(p => `"${p}"`).join(', ')}`);
    }
    
    if (parsed.exclude.length > 0) {
      parts.push(`排除: ${parsed.exclude.map(e => `-${e}`).join(', ')}`);
    }
    
    if (parsed.fieldQueries.size > 0) {
      const entries = Array.from(parsed.fieldQueries.entries());
      const fields: string[] = [];
      for (let i = 0; i < entries.length; i++) {
        const field = entries[i][0];
        const value = entries[i][1];
        fields.push(`${field}:${value}`);
      }
      parts.push(`字段: ${fields.join(', ')}`);
    }
    
    return parts.join(' | ');
  }

  /**
   * 设置默认配置
   */
  static setDefaultConfig(config: Partial<QueryEncodingConfig>): void {
    if (config.encoding !== undefined) {
      SearchQueryParser.defaultConfig.encoding = config.encoding;
    }
    if (config.separator !== undefined) {
      SearchQueryParser.defaultConfig.separator = config.separator;
    }
    if (config.supportAdvanced !== undefined) {
      SearchQueryParser.defaultConfig.supportAdvanced = config.supportAdvanced;
    }
    
    Logger.info(SearchQueryParser.TAG, 
      `查询解析器配置已更新: encoding=${SearchQueryParser.defaultConfig.encoding}, ` +
      `separator=${SearchQueryParser.defaultConfig.separator}, ` +
      `supportAdvanced=${SearchQueryParser.defaultConfig.supportAdvanced}`
    );
  }

  /**
   * 获取默认配置
   */
  static getDefaultConfig(): QueryEncodingConfig {
    return {
      encoding: SearchQueryParser.defaultConfig.encoding,
      separator: SearchQueryParser.defaultConfig.separator,
      supportAdvanced: SearchQueryParser.defaultConfig.supportAdvanced
    };
  }

  /**
   * 测试查询解析
   */
  static testParse(query: string): void {
    const parsed = SearchQueryParser.parse(query);
    
    Logger.debug(SearchQueryParser.TAG, `测试解析: "${query}"`);
    Logger.debug(SearchQueryParser.TAG, `- 原始查询: ${parsed.original}`);
    Logger.debug(SearchQueryParser.TAG, `- 普通关键词: ${parsed.keywords.join(', ')}`);
    Logger.debug(SearchQueryParser.TAG, `- 精确短语: ${parsed.exactPhrases.map(p => `"${p}"`).join(', ')}`);
    Logger.debug(SearchQueryParser.TAG, `- 排除关键词: ${parsed.exclude.map(e => `-${e}`).join(', ')}`);
    
    if (parsed.fieldQueries.size > 0) {
      const entries = Array.from(parsed.fieldQueries.entries());
      const fields: string[] = [];
      for (let i = 0; i < entries.length; i++) {
        const field = entries[i][0];
        const value = entries[i][1];
        fields.push(`${field}:${value}`);
      }
      Logger.debug(SearchQueryParser.TAG, `- 字段查询: ${fields.join(', ')}`);
    }
    
    Logger.debug(SearchQueryParser.TAG, `- 是否高级查询: ${parsed.isAdvanced}`);
    Logger.debug(SearchQueryParser.TAG, `- 规范化查询: ${parsed.normalized}`);
    
    // 测试不同编码方式
    const configs: QueryEncodingConfig[] = [
      { encoding: 'urlencode', separator: '+', supportAdvanced: true },
      { encoding: 'urlencode', separator: '%20', supportAdvanced: false },
      { encoding: 'base64', separator: '+', supportAdvanced: true },
      { encoding: 'none', separator: ' ', supportAdvanced: true }
    ];
    
    for (let i = 0; i < configs.length; i++) {
      const config = configs[i];
      const encoded = SearchQueryParser.encodeQuery(query, config);
      Logger.debug(SearchQueryParser.TAG, `- 编码 (${config.encoding}): ${encoded}`);
    }
  }
}