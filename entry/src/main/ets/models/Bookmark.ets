/**
 * 书签数据模型
 */
export interface Bookmark {
  id: string;                    // 书签ID
  bookId: string;                // 书籍ID
  chapterId: string;             // 章节ID
  chapterTitle: string;          // 章节标题
  content: string;               // 书签位置的内容片段
  createTime: number;            // 创建时间
}
