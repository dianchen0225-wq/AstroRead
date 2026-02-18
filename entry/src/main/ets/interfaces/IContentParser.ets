/**
 * 核心接口定义
 * 定义内容解析、搜索引擎、网络请求等核心接口
 */

// ==================== 解析器接口 ====================

/**
 * 解析结果
 */
export interface ParseResult {
  text: string;
  html: string;
  attr?: Record<string, string>;
}

/**
 * 内容解析器接口
 */
export interface IContentParser {
  /**
   * 解析 HTML 并提取元素
   * @param html HTML 内容
   * @param rule 解析规则
   * @returns 解析结果数组
   */
  parse(html: string, rule: string): string[];

  /**
   * 解析并返回结构化结果
   */
  parseDetailed(html: string, rule: string): ParseResult[];

  /**
   * 提取纯文本
   */
  extractText(html: string): string;

  /**
   * 解析 URL 拼接规则
   */
  resolveUrl(baseUrl: string, relativeUrl: string): string;
}

/**
 * 书源内容解析器接口
 */
export interface IBookSourceParser {
  /**
   * 解析搜索结果
   */
  parseSearchResult(html: string, bookSource: BookSource): ParsedBookItem[];

  /**
   * 解析章节列表
   */
  parseChapterList(html: string, bookSource: BookSource): ParsedChapterItem[];

  /**
   * 解析章节内容
   */
  parseChapterContent(html: string, bookSource: BookSource): string;

  /**
   * 净化内容
   */
  purifyContent(content: string, replaceRule?: ReplaceRuleConfig): string;
}

/**
 * 规则引擎接口
 */
export interface IRuleEngine {
  /**
   * 解析规则
   */
  parseRule(rule: string, html: string): string;

  /**
   * 解析规则列表
   */
  parseRuleList(rule: string, html: string): string[];

  /**
   * 解析搜索 URL
   */
  parseSearchUrl(searchUrl: string, keyword: string, page: number, baseUrl: string): ParsedUrl;

  /**
   * 设置上下文
   */
  setContext(context: Partial<RuleContext>): void;

  /**
   * 获取上下文
   */
  getContext(): RuleContext;
}

// ==================== 搜索引擎接口 ====================

/**
 * 搜索选项
 */
export interface SearchOptions {
  key: string;
  page?: number;
  timeout?: number;
  concurrent?: number;
  interval?: number;
}

/**
 * 搜索结果
 */
export interface SearchResult {
  books: Book[];
  sourceName: string;
  sourceUrl: string;
  success: boolean;
  error?: string;
  responseTime: number;
}

/**
 * 搜索引擎接口
 */
export interface ISearchEngine {
  /**
   * 多书源搜索
   */
  search(sources: BookSource[], options: SearchOptions): Promise<SearchResult[]>;

  /**
   * 单书源搜索
   */
  searchSingleSource(source: BookSource, key: string, page: number): Promise<SearchResult>;

  /**
   * 聚合结果
   */
  aggregateResults(results: SearchResult[]): Book[];

  /**
   * 设置配置
   */
  setConfig(config: Partial<SearchConfig>): void;
}

/**
 * 书源管理器接口
 */
export interface IBookSourceManager {
  /**
   * 导入书源
   */
  importSources(input: string): Promise<BookSource[]>;

  /**
   * 搜索书籍
   */
  searchBooks(keyword: string, options?: Partial<SearchOptions>): Promise<SearchBooksResult>;

  /**
   * 获取所有书源
   */
  getAllSources(): BookSource[];

  /**
   * 获取启用的书源
   */
  getEnabledSources(): BookSource[];

  /**
   * 添加书源
   */
  addSource(source: BookSource): void;

  /**
   * 删除书源
   */
  removeSource(id: string): void;

  /**
   * 更新书源
   */
  updateSource(source: BookSource): void;

  /**
   * 导出书源
   */
  exportSources(sources?: BookSource[]): string;
}

// ==================== 网络请求接口 ====================

/**
 * 请求配置
 */
export interface RequestConfig {
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  timeout?: number;
  retry?: number;
  retryDelay?: number;
  charset?: string;
}

/**
 * 网络适配器接口
 */
export interface INetworkAdapter {
  /**
   * GET 请求
   */
  get(url: string, config?: RequestConfig): Promise<string>;

  /**
   * POST 请求
   */
  post(url: string, data?: object, config?: RequestConfig): Promise<string>;

  /**
   * 执行书源请求
   */
  executeBookSourceRequest(url: string, options?: BookSourceRequestOptions): Promise<string>;

  /**
   * 设置默认请求头
   */
  setDefaultHeader(key: string, value: string): void;

  /**
   * 移除默认请求头
   */
  removeDefaultHeader(key: string): void;
}

/**
 * 书源请求选项
 */
interface HttpHeaderEntry {
  key: string;
  value: string;
}

export interface BookSourceRequestOptions {
  method?: 'GET' | 'POST';
  headers?: HttpHeaderEntry[];
  body?: string;
  charset?: string;
}

// ==================== 数据模型 ====================

/**
 * 书源模型
 */
export interface BookSource {
  id: string;
  name: string;
  url: string;
  enabled: boolean;
  header?: string;
  searchUrl?: string;
  searchRule?: SearchRule;
  findRule?: string;
  chapterRule?: ChapterRule;
  contentRule?: ContentRule;
  ruleType?: 'xpath' | 'jsonpath' | 'regex';
  sort?: number;
  lastUpdateTime?: number;
  addTime?: number;
}

/**
 * 搜索规则
 */
export interface SearchRule {
  bookList: string;
  name: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
  nextUrl?: string;
}

/**
 * 章节规则
 */
export interface ChapterRule {
  chapterList: string;
  chapterName: string;
  chapterUrl: string;
  nextUrl?: string;
}

/**
 * 内容规则
 */
export interface ContentRule {
  content: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

/**
 * 书籍模型
 */
export interface Book {
  id: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  kind?: string;
  wordCount?: number;
  latestChapter?: string;
  bookSourceId: string;
  bookSourceName: string;
  bookUrl: string;
  lastUpdateTime: number;
  addTime: number;
  readProgress: number;
  lastReadChapter?: string;
  lastReadChapterIndex?: number;
  lastReadTime: number;
  totalChapters: number;
  currentChapterIndex: number;
  currentChapterTitle: string;
  isInShelf: boolean;
}

/**
 * 解析后的书籍项
 */
export interface ParsedBookItem {
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

/**
 * 解析后的章节项
 */
export interface ParsedChapterItem {
  title: string;
  url: string;
  isVip: boolean;
  order: number;
}

/**
 * 替换规则配置
 */
export interface ReplaceRuleConfig {
  removeTags?: string[];
  replace?: ReplaceRuleItem[];
  removeHtmlTags?: boolean;
}

/**
 * 替换规则项
 */
export interface ReplaceRuleItem {
  from: string;
  to: string;
}

/**
 * 规则上下文
 */
export interface RuleContext {
  variables: Map<string, string>;
  baseUrl: string;
  html: string;
}

/**
 * 解析后的 URL
 */
export interface ParsedUrl {
  url: string;
  method: 'GET' | 'POST';
  body?: string;
  headers?: Record<string, string>;
  charset?: string;
}

/**
 * 搜索配置
 */
export interface SearchConfig {
  maxConcurrent: number;
  requestInterval: number;
  timeout: number;
  maxResultsPerSource: number;
}

/**
 * 搜索书籍结果
 */
export interface SearchBooksResult {
  results: SearchResult[];
  books: Book[];
}
