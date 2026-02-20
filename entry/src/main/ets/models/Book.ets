/**
 * 书籍数据模型
 */
export interface Book {
  id: string;
  name: string;
  author: string;
  cover: string | undefined;
  intro: string | undefined;
  kind: string | undefined;
  wordCount: number | undefined;
  latestChapter: string | undefined;
  bookSourceId: string;
  bookSourceName: string;
  bookUrl: string;
  lastUpdateTime: number;
  addTime: number;
  readProgress: number;
  lastReadChapter: string | undefined;
  lastReadChapterIndex: number | undefined;
  lastReadTime?: number;
  totalChapters?: number;
  currentChapterIndex?: number;
  currentChapterTitle?: string;
  isInShelf?: boolean;
  sourceStatus?: SourceStatus;
}

/**
 * 书源状态枚举
 */
export enum SourceStatus {
  UNKNOWN = 0,
  VALID = 1,
  INVALID = 2,
  CHECKING = 3
}

/**
 * 书源验证结果
 */
export interface SourceValidationResult {
  bookId: string;
  bookSourceId: string;
  bookSourceName: string;
  status: SourceStatus;
  errorMessage?: string;
}

/**
 * 章节数据模型
 */
export interface Chapter {
  id: string;                    // 章节ID
  bookId: string;                // 书籍ID
  title: string;                 // 章节标题
  url: string;                   // 章节URL
  order: number;                 // 章节序号
  isVip: boolean;                // 是否VIP章节
}

/**
 * 章节内容数据模型
 */
export interface ChapterContent {
  chapterId: string;             // 章节ID
  content: string;               // 章节内容
  nextUrl: string | undefined;   // 下一章URL
  prevUrl: string | undefined;   // 上一章URL
}
