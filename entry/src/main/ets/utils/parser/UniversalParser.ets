/**
 * UniversalParser - 通用解析器
 * 支持多种网站结构和反爬机制的解析器
 */

import { Logger } from '../performance/Logger';
import { HTMLParser } from './HTMLParser';
import { AsyncCssSelectorParser } from './AsyncCssSelectorParser';

export interface ParseOptions {
  // 是否尝试多种解析策略
  tryMultipleStrategies?: boolean;
  // 是否处理动态内容
  handleDynamicContent?: boolean;
  // 是否解码HTML实体
  decodeEntities?: boolean;
  // 最大重试次数
  maxRetries?: number;
  // 重试延迟（毫秒）
  retryDelay?: number;
}

export interface ParseStrategy {
  name: string;
  selector: string;
  attribute?: string;
  priority: number;
}

export class UniversalParser {
  private static instance: UniversalParser | null = null;
  private htmlParser: HTMLParser;
  private asyncCssSelectorParser: AsyncCssSelectorParser;
  private readonly TAG = 'UniversalParser';

  // 常见书籍列表选择器策略
  private bookListStrategies: ParseStrategy[] = [
    { name: '标准列表', selector: '.book-list li', priority: 1 },
    { name: '书籍网格', selector: '.book-grid .book-item', priority: 2 },
    { name: '搜索结果', selector: '.search-result .book', priority: 3 },
    { name: '通用列表', selector: 'ul li', priority: 10 },
    { name: '通用div', selector: 'div.book, div.novel', priority: 11 },
  ];

  // 常见书名选择器策略
  private nameStrategies: ParseStrategy[] = [
    { name: '书名链接', selector: 'h3 a, h2 a, .title a', attribute: 'text', priority: 1 },
    { name: '书名文本', selector: '.book-name, .novel-name, .title', attribute: 'text', priority: 2 },
    { name: 'alt属性', selector: 'img', attribute: 'alt', priority: 5 },
  ];

  // 常见作者选择器策略
  private authorStrategies: ParseStrategy[] = [
    { name: '作者链接', selector: '.author a, .writer a', attribute: 'text', priority: 1 },
    { name: '作者文本', selector: '.author, .writer', attribute: 'text', priority: 2 },
  ];

  // 常见封面选择器策略
  private coverStrategies: ParseStrategy[] = [
    { name: '封面图片', selector: '.cover img, .book-cover img', attribute: 'src', priority: 1 },
    { name: 'data-src', selector: 'img', attribute: 'data-src', priority: 2 },
    { name: 'data-original', selector: 'img', attribute: 'data-original', priority: 3 },
  ];

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.asyncCssSelectorParser = AsyncCssSelectorParser.getInstance();
  }

  static getInstance(): UniversalParser {
    if (!UniversalParser.instance) {
      UniversalParser.instance = new UniversalParser();
    }
    return UniversalParser.instance;
  }

  /**
   * 智能解析书籍列表
   * 当规则失败时，尝试多种策略
   */
  async parseBookList(
    html: string,
    rule: string,
    options: ParseOptions = {}
  ): Promise<string[]> {
    const opts: ParseOptions = {
      tryMultipleStrategies: options.tryMultipleStrategies ?? true,
      maxRetries: options.maxRetries ?? 2,
      retryDelay: options.retryDelay ?? 100,
      handleDynamicContent: options.handleDynamicContent,
      decodeEntities: options.decodeEntities
    };

    // 首先尝试使用提供的规则
    let results = await this.tryParse(html, rule);
    if (results.length > 0) {
      return results;
    }

    // 如果规则失败且允许尝试多种策略
    if (opts.tryMultipleStrategies) {
      Logger.debug(this.TAG, `规则 "${rule}" 未匹配到结果，尝试备用策略`);

      for (const strategy of this.bookListStrategies) {
        results = await this.tryParse(html, strategy.selector);
        if (results.length > 0) {
          Logger.info(this.TAG, `使用备用策略 "${strategy.name}" 成功匹配 ${results.length} 个元素`);
          return results;
        }
      }
    }

    return [];
  }

  /**
   * 智能解析字段
   * 尝试多种策略提取字段值
   */
  async parseField(
    html: string,
    rule: string,
    fieldName: string,
    strategies: ParseStrategy[],
    options: ParseOptions = {}
  ): Promise<string> {
    const opts: ParseOptions = {
      tryMultipleStrategies: options.tryMultipleStrategies ?? true,
      handleDynamicContent: options.handleDynamicContent,
      decodeEntities: options.decodeEntities,
      maxRetries: options.maxRetries,
      retryDelay: options.retryDelay
    };

    // 首先尝试使用提供的规则
    let value = await this.tryExtract(html, rule);
    if (value && value.trim().length > 0) {
      return this.cleanValue(value);
    }

    // 如果规则失败且允许尝试多种策略
    if (opts.tryMultipleStrategies) {
      Logger.debug(this.TAG, `字段 "${fieldName}" 规则 "${rule}" 未匹配，尝试备用策略`);

      for (const strategy of strategies) {
        value = await this.tryExtract(html, strategy.selector, strategy.attribute);
        if (value && value.trim().length > 0) {
          Logger.debug(this.TAG, `字段 "${fieldName}" 使用备用策略 "${strategy.name}" 成功: ${value.substring(0, 50)}`);
          return this.cleanValue(value);
        }
      }
    }

    return '';
  }

  /**
   * 解析书名
   */
  async parseBookName(html: string, rule: string, options?: ParseOptions): Promise<string> {
    return this.parseField(html, rule, '书名', this.nameStrategies, options);
  }

  /**
   * 解析作者
   */
  async parseAuthor(html: string, rule: string, options?: ParseOptions): Promise<string> {
    return this.parseField(html, rule, '作者', this.authorStrategies, options);
  }

  /**
   * 解析封面
   */
  async parseCover(html: string, rule: string, options?: ParseOptions): Promise<string> {
    return this.parseField(html, rule, '封面', this.coverStrategies, options);
  }

  /**
   * 尝试解析
   */
  private async tryParse(html: string, selector: string): Promise<string[]> {
    try {
      return await this.asyncCssSelectorParser.selectElements(html, selector);
    } catch (error) {
      return [];
    }
  }

  /**
   * 尝试提取值
   */
  private async tryExtract(html: string, selector: string, attribute?: string): Promise<string> {
    try {
      return await this.asyncCssSelectorParser.extractValue(html, selector, attribute);
    } catch (error) {
      return '';
    }
  }

  /**
   * 清理提取的值
   */
  private cleanValue(value: string): string {
    if (!value) return '';

    return value
      .replace(/[\n\r\t]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 检测HTML结构类型
   */
  detectHtmlStructure(html: string): string {
    if (html.includes('__NEXT_DATA__') || html.includes('window.__INITIAL_STATE__')) {
      return 'dynamic';
    }
    if (html.includes('application/json') && html.includes('"data"')) {
      return 'json-embedded';
    }
    if (html.includes('<script') && html.includes('JSON.parse')) {
      return 'script-json';
    }
    return 'static';
  }

  /**
   * 提取嵌入的JSON数据
   */
  extractEmbeddedJson(html: string): Record<string, Object> | null {
    // 尝试提取 __NEXT_DATA__
    const nextDataMatch = html.match(/window\.__NEXT_DATA__\s*=\s*(\{.*?\});/s);
    if (nextDataMatch) {
      try {
        return JSON.parse(nextDataMatch[1]) as Record<string, Object>;
      } catch {
        // ignore
      }
    }

    // 尝试提取 __INITIAL_STATE__
    const initialStateMatch = html.match(/window\.__INITIAL_STATE__\s*=\s*(\{.*?\});/s);
    if (initialStateMatch) {
      try {
        return JSON.parse(initialStateMatch[1]) as Record<string, Object>;
      } catch {
        // ignore
      }
    }

    return null;
  }

  /**
   * 处理反爬机制
   */
  async handleAntiCrawling(html: string): Promise<string> {
    // 检查是否需要解码
    if (html.includes('&amp;') || html.includes('&lt;') || html.includes('&gt;')) {
      html = this.decodeHtmlEntities(html);
    }

    // 检查是否有混淆的JavaScript
    if (html.includes('document.write') || html.includes('eval(')) {
      Logger.warn(this.TAG, '检测到可能的JavaScript混淆');
    }

    return html;
  }

  /**
   * 解码HTML实体
   */
  private decodeHtmlEntities(html: string): string {
    const entities: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
      '&hellip;': '…',
      '&mdash;': '—',
    };

    let result = html;
    const entityKeys = Object.keys(entities);
    const entityValues = Object.values(entities);
    for (let i = 0; i < entityKeys.length; i++) {
      result = result.split(entityKeys[i]).join(entityValues[i]);
    }
    // 处理数字实体
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => String.fromCharCode(parseInt(dec, 10)));
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => String.fromCharCode(parseInt(hex, 16)));

    return result;
  }

  /**
   * 添加自定义策略
   */
  addCustomStrategy(fieldType: 'bookList' | 'name' | 'author' | 'cover', strategy: ParseStrategy): void {
    switch (fieldType) {
      case 'bookList':
        this.bookListStrategies.push(strategy);
        this.bookListStrategies.sort((a, b) => a.priority - b.priority);
        break;
      case 'name':
        this.nameStrategies.push(strategy);
        this.nameStrategies.sort((a, b) => a.priority - b.priority);
        break;
      case 'author':
        this.authorStrategies.push(strategy);
        this.authorStrategies.sort((a, b) => a.priority - b.priority);
        break;
      case 'cover':
        this.coverStrategies.push(strategy);
        this.coverStrategies.sort((a, b) => a.priority - b.priority);
        break;
    }
  }
}

export default UniversalParser.getInstance();
