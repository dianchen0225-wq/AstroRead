/**
 * AstroReadFacade - 统一接口层
 * 作为内容解析和搜索引擎的统一访问入口
 * 提供标准化的接口调用方式
 */

import { HTMLParser, ParseResult } from '../utils/parser/HTMLParser';
import { ContentParser, ParsedBookItem, ParsedChapterItem, ReplaceRuleConfig } from '../utils/parser/ContentParser';
import { RuleEngine, RuleContext, ParsedUrl } from '../utils/parser/RuleEngine';
import { BookSourceManager, SearchBooksResult } from '../utils/validation/BookSourceManager';
import { BookSourceSearchEngine, SearchOptions, SearchResult, SearchConfig } from '../utils/search/BookSourceSearchEngine';
import NetworkAdapter, { NetworkRequestOptions } from '../utils/network/NetworkAdapter';
import { BookSource } from '../models/BookSource';
import { DebugResult, ValidationResult } from '../utils/validation/BookSourceDebugger';

export class AstroReadFacade {
  private static instance: AstroReadFacade | null = null;

  private htmlParser: HTMLParser;
  private sourceManager: BookSourceManager;
  private searchEngine: BookSourceSearchEngine;

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.sourceManager = BookSourceManager.getInstance();
    this.searchEngine = BookSourceSearchEngine.getInstance();
  }

  static getInstance(): AstroReadFacade {
    if (!AstroReadFacade.instance) {
      AstroReadFacade.instance = new AstroReadFacade();
    }
    return AstroReadFacade.instance;
  }

  // ==================== HTML 解析接口 ====================

  /**
   * 解析 HTML 并提取元素
   * @param html HTML 内容
   * @param rule 解析规则（支持 XPath、CSS Selector、JSONPath、正则）
   * @returns 解析结果数组
   */
  parseHtml(html: string, rule: string): string[] {
    return this.htmlParser.parse(html, rule);
  }

  /**
   * 解析 HTML 并返回结构化结果
   */
  parseHtmlDetailed(html: string, rule: string): ParseResult[] {
    return this.htmlParser.parseDetailed(html, rule);
  }

  /**
   * 提取纯文本（移除 HTML 标签）
   */
  extractText(html: string): string {
    return this.htmlParser.extractText(html);
  }

  /**
   * 解析 URL（处理相对路径）
   */
  resolveUrl(baseUrl: string, relativeUrl: string): string {
    return this.htmlParser.resolveUrl(baseUrl, relativeUrl);
  }

  // ==================== 书源内容解析接口 ====================

  /**
   * 解析搜索结果
   */
  parseSearchResult(html: string, source: BookSource): ParsedBookItem[] {
    return ContentParser.parseSearchResult(html, source);
  }

  /**
   * 解析章节列表
   */
  parseChapterList(html: string, source: BookSource): ParsedChapterItem[] {
    return ContentParser.parseChapterList(html, source);
  }

  /**
   * 解析章节内容
   */
  parseChapterContent(html: string, source: BookSource): string {
    return ContentParser.parseChapterContent(html, source);
  }

  /**
   * 净化内容（移除广告、格式化）
   */
  purifyContent(content: string, replaceRule?: ReplaceRuleConfig): string {
    return ContentParser.purifyContent(content, replaceRule);
  }

  // ==================== 规则执行接口 ====================

  /**
   * 执行解析规则
   */
  executeRule(rule: string, html: string): string {
    return RuleEngine.parseRule(rule, html);
  }

  /**
   * 执行解析规则（返回列表）
   */
  executeRuleList(rule: string, html: string): string[] {
    return RuleEngine.parseRuleList(rule, html);
  }

  /**
   * 解析搜索 URL
   */
  parseSearchUrl(searchUrl: string, keyword: string, page: number, baseUrl: string): ParsedUrl {
    return RuleEngine.parseSearchUrl(searchUrl, keyword, page, baseUrl);
  }

  /**
   * 设置规则上下文
   */
  setRuleContext(context: Partial<RuleContext>): void {
    RuleEngine.setContext(context);
  }

  /**
   * 获取规则上下文
   */
  getRuleContext(): RuleContext {
    return RuleEngine.getContext();
  }

  /**
   * 存储变量
   */
  putVariable(key: string, value: string): void {
    RuleEngine.putVariable(key, value);
  }

  /**
   * 获取变量
   */
  getVariable(key: string): string {
    return RuleEngine.getVariable(key);
  }

  // ==================== 书源管理接口 ====================

  /**
   * 导入书源
   * @param input JSON 字符串、URL 或 TXT 格式
   */
  async importSources(input: string): Promise<BookSource[]> {
    return this.sourceManager.importSources(input);
  }

  /**
   * 获取所有书源
   */
  getAllSources(): BookSource[] {
    return this.sourceManager.getAllSources();
  }

  /**
   * 获取启用的书源
   */
  getEnabledSources(): BookSource[] {
    return this.sourceManager.getEnabledSources();
  }

  /**
   * 添加书源
   */
  addSource(source: BookSource): void {
    this.sourceManager.addSource(source);
  }

  /**
   * 批量添加书源
   */
  addSources(sources: BookSource[]): void {
    this.sourceManager.addSources(sources);
  }

  /**
   * 删除书源
   */
  removeSource(id: string): void {
    this.sourceManager.removeSource(id);
  }

  /**
   * 更新书源
   */
  updateSource(source: BookSource): void {
    this.sourceManager.updateSource(source);
  }

  /**
   * 导出书源为 JSON
   */
  exportSources(sources?: BookSource[]): string {
    return this.sourceManager.exportSources(sources);
  }

  /**
   * 导出书源为 YCK 格式
   */
  exportToYCKFormat(sources?: BookSource[]): string {
    return this.sourceManager.exportToYCKFormat(sources);
  }

  // ==================== 搜索接口 ====================

  /**
   * 搜索书籍
   * @param keyword 搜索关键词
   * @param options 搜索选项
   */
  async searchBooks(keyword: string, options?: Partial<SearchOptions>): Promise<SearchBooksResult> {
    return this.sourceManager.searchBooks(keyword, options);
  }

  /**
   * 从指定书源搜索
   */
  async searchFromSource(sourceId: string, keyword: string, page: number = 1): Promise<SearchResult> {
    return this.sourceManager.searchFromSource(sourceId, keyword, page);
  }

  /**
   * 设置搜索配置
   */
  setSearchConfig(config: Partial<SearchConfig>): void {
    this.searchEngine.setConfig(config);
  }

  // ==================== 调试接口 ====================

  /**
   * 调试书源 - 搜索
   */
  async debugSearch(source: BookSource, keyword: string): Promise<DebugResult> {
    return this.sourceManager.debugSearch(source, keyword);
  }

  /**
   * 调试书源 - 章节列表
   */
  async debugChapters(source: BookSource, bookUrl: string): Promise<DebugResult> {
    return this.sourceManager.debugChapters(source, bookUrl);
  }

  /**
   * 调试书源 - 正文内容
   */
  async debugContent(source: BookSource, chapterUrl: string): Promise<DebugResult> {
    return this.sourceManager.debugContent(source, chapterUrl);
  }

  validateSource(source: BookSource): ValidationResult {
    return this.sourceManager.validateSource(source);
  }

  async get(url: string, headers?: Record<string, string>): Promise<string> {
    return NetworkAdapter.get(url, headers);
  }

  async post(url: string, body?: string, headers?: Record<string, string>): Promise<string> {
    return NetworkAdapter.post(url, body ?? '', headers);
  }

  async executeBookSourceRequest(
    url: string,
    options?: NetworkRequestOptions
  ): Promise<string> {
    return NetworkAdapter.request(url, options);
  }

  setDefaultHeader(key: string, value: string): void {
    NetworkAdapter.setDefaultHeader(key, value);
  }

  removeDefaultHeader(key: string): void {
    NetworkAdapter.removeDefaultHeader(key);
  }

  cleanText(text: string): string {
    return RuleEngine.cleanText(text);
  }

  clearCache(): void {
    this.sourceManager.clearCache();
    this.searchEngine.clearCache();
    RuleEngine.clearContext();
    if (this.htmlParser && typeof this.htmlParser.clearCache === 'function') {
      this.htmlParser.clearCache();
    }
  }

  destroy(): void {
    this.clearCache();
    if (this.sourceManager && typeof this.sourceManager.destroy === 'function') {
      this.sourceManager.destroy();
    }
    if (this.searchEngine && typeof this.searchEngine.destroy === 'function') {
      this.searchEngine.destroy();
    }
    AstroReadFacade.instance = null;
  }
}

export default AstroReadFacade.getInstance();
