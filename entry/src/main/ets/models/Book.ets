/**
 * 书籍数据模型
 */
export interface Book {
  id: string;                    // 书籍ID
  name: string;                  // 书名
  author: string;                // 作者
  cover: string | undefined;     // 封面URL
  intro: string | undefined;     // 简介
  kind: string | undefined;      // 分类
  wordCount: number | undefined; // 字数
  latestChapter: string | undefined; // 最新章节
  bookSourceId: string;          // 书源ID
  bookSourceName: string;        // 书源名称
  bookUrl: string;               // 书籍URL
  lastUpdateTime: number;        // 最后更新时间
  addTime: number;               // 添加时间
  readProgress: number;          // 阅读进度（百分比 0-100）
  lastReadChapter: string | undefined; // 最后阅读章节名称
  lastReadChapterIndex: number | undefined; // 最后阅读章节索引
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
