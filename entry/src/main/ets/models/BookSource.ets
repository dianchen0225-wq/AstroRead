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

/**
 * 书源数据模型
 */
export interface BookSource {
  id: string;                    // 书源ID
  name: string;                  // 书源名称
  url: string;                   // 书源URL
  enabled: boolean;              // 是否启用
  header: string | undefined;    // 请求头（JSON格式）
  searchUrl: string;             // 搜索URL
  searchRule: SearchRule;        // 搜索规则
  findRule: FindRule | undefined; // 发现规则
  chapterRule: ChapterRule;      // 章节规则
  contentRule: ContentRule;      // 内容规则
  ruleType: 'xpath' | 'jsonpath' | 'regex'; // 规则类型
  sort: number;                  // 排序
  lastUpdateTime: number;        // 最后更新时间
  addTime: number;               // 添加时间
}
