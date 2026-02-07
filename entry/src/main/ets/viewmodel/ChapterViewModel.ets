import { Chapter } from '../models/Book';
import { ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import { IdGenerator } from '../utils/IdGenerator';
import { ParsedChapterItem } from '../utils/ContentParser';

/**
 * 章节视图模型
 */
export class ChapterViewModel {
  private readonly databaseManager = databaseManager;
  private readonly networkManager = NetworkManager.getInstance();

  /**
   * 获取书籍的章节列表
   */
  async getChapters(bookId: string): Promise<Chapter[]> {
    try {
      return await this.databaseManager.getChaptersByBookId(bookId);
    } catch (error) {
      console.error('Failed to get chapters:', error);
      return [];
    }
  }

  /**
   * 从网络获取章节列表并保存
   */
  async fetchAndSaveChapters(bookId: string, bookSource: BookSource, bookUrl: string): Promise<Chapter[]> {
    try {
      const chapterList: ParsedChapterItem[] = await this.networkManager.getChapterList(bookSource, bookUrl);
      
      // 转换为Chapter对象并保存
      const chapters: Chapter[] = chapterList.map((item: ParsedChapterItem, index: number) => {
        const chapter: Chapter = {
          id: IdGenerator.generateUUID(),
          bookId: bookId,
          title: item.title || '',
          url: item.url || '',
          order: item.order !== undefined ? item.order : index,
          isVip: item.isVip || false
        };
        return chapter;
      });

      // 批量保存章节
      await this.databaseManager.batchUpsertChapters(chapters);
      
      return chapters;
    } catch (error) {
      console.error('Failed to fetch chapters:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 获取章节内容
   */
  async getChapterContent(
    chapterId: string,
    chapterUrl: string,
    bookSource: BookSource
  ): Promise<ChapterContent> {
    try {
      const content = await this.networkManager.getChapterContent(bookSource, chapterUrl);
      
      // TODO: 可以添加缓存逻辑
      
      return {
        chapterId: chapterId,
        content: content,
        nextUrl: undefined,
        prevUrl: undefined
      };
    } catch (error) {
      console.error('Failed to get chapter content:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 获取下一章
   */
  async getNextChapter(currentChapter: Chapter, chapters: Chapter[]): Promise<Chapter | null> {
    const currentIndex = chapters.findIndex((ch: Chapter) => ch.id === currentChapter.id);
    if (currentIndex >= 0 && currentIndex < chapters.length - 1) {
      return chapters[currentIndex + 1];
    }
    return null;
  }

  /**
   * 获取上一章
   */
  async getPrevChapter(currentChapter: Chapter, chapters: Chapter[]): Promise<Chapter | null> {
    const currentIndex = chapters.findIndex((ch: Chapter) => ch.id === currentChapter.id);
    if (currentIndex > 0) {
      return chapters[currentIndex - 1];
    }
    return null;
  }
}
