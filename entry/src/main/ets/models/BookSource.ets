/**
 * 搜索规则
 */
export interface SearchRule {
  bookList: string;              // 书籍列表规则（JSONPath或XPath）
  name: string;                  // 书名规则
  author: string;                // 作者规则
  cover: string | undefined;     // 封面规则
  intro: string | undefined;     // 简介规则
  bookUrl: string;               // 书籍URL规则
  nextUrl: string | undefined;   // 下一页规则
}

/**
 * 发现规则
 */
export interface FindRule {
  url: string;                   // 发现页URL
  bookList: string;              // 书籍列表规则
  name: string;                  // 书名规则
  author: string;                // 作者规则
  cover: string | undefined;     // 封面规则
  intro: string | undefined;     // 简介规则
  bookUrl: string;               // 书籍URL规则
}

/**
 * 章节列表规则
 */
export interface ChapterRule {
  chapterList: string;           // 章节列表规则
  chapterName: string;           // 章节名规则
  chapterUrl: string;            // 章节URL规则
  nextUrl: string | undefined;   // 下一页规则
}

/**
 * 内容规则
 */
export interface ContentRule {
  content: string;               // 内容规则
  nextUrl: string | undefined;   // 下一章规则
  prevUrl: string | undefined;   // 上一章规则
  replaceRule: string | undefined; // 内容替换规则（JSON格式）
}

export type BookSourceStatus = 'unknown' | 'available' | 'unavailable' | 'manual_available' | 'manual_unavailable';

export interface BookSourceValidation {
  lastValidationTime: number;
  responseTime: number;
  successKeyword: string;
  failureReason: string;
}

/**
 * 书源数据模型
 */
export interface BookSource {
  id: string;
  name: string;
  url: string;
  enabled: boolean;
  header: string | undefined;
  searchUrl: string;
  searchRule: SearchRule;
  findRule: FindRule | undefined;
  chapterRule: ChapterRule;
  contentRule: ContentRule;
  ruleType: 'xpath' | 'jsonpath' | 'regex';
  sort: number;
  lastUpdateTime: number;
  addTime: number;
  status?: BookSourceStatus;
  validation?: BookSourceValidation;
  keywordEncoding?: string;
  keywordSeparator?: string;
  advancedQuerySupport?: boolean;
}
