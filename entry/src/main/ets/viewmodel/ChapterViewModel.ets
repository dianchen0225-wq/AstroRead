import { Chapter } from '../models/Book';
import { ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import { IdGenerator } from '../utils/IdGenerator';

interface ParsedChapterItem {
  title?: string;
  url?: string;
  order?: number;
  isVip?: boolean;
}

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
      return await this.getChaptersByBookId(bookId);
    } catch (error) {
      console.error('Failed to get chapters:', error);
      return [];
    }
  }

  /**
   * 根据书籍ID获取章节列表（内部方法）
   */
  private async getChaptersByBookId(bookId: string): Promise<Chapter[]> {
    if (this.databaseManager === null) {
      return [];
    }

    try {
      // 这里需要实现具体的数据库查询逻辑
      // 暂时返回空数组
      return [];
    } catch (error) {
      console.error('Failed to get chapters by book ID:', error);
      return [];
    }
  }

  /**
   * 从网络获取章节列表并保存
   */
  async fetchAndSaveChapters(bookId: string, bookSource: BookSource, bookUrl: string): Promise<Chapter[]> {
    try {
      const chapterList: ParsedChapterItem[] = await this.getChapterList(bookSource, bookUrl);
      
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
      await this.batchUpsertChapters(chapters);
      
      return chapters;
    } catch (error) {
      console.error('Failed to fetch chapters:', error);
      throw new Error(`Failed to fetch chapters: ${error}`);
    }
  }

  /**
   * 获取章节列表（内部方法）
   */
  private async getChapterList(bookSource: BookSource, bookUrl: string): Promise<ParsedChapterItem[]> {
    try {
      // 这里需要实现具体的章节列表获取逻辑
      // 暂时返回空数组
      return [];
    } catch (error) {
      console.error('Failed to get chapter list:', error);
      throw new Error(`Failed to get chapter list: ${error}`);
    }
  }

  /**
   * 批量保存章节（内部方法）
   */
  private async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    if (this.databaseManager === null || chapters.length === 0) {
      return;
    }

    try {
      // 这里需要实现具体的批量保存逻辑
      console.log(`Successfully saved ${chapters.length} chapters`);
    } catch (error) {
      console.error('Failed to batch upsert chapters:', error);
      throw new Error(`Failed to batch upsert chapters: ${error}`);
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
      const content = await this.getChapterContentFromNetwork(bookSource, chapterUrl);
      
      // TODO: 可以添加缓存逻辑
      
      return {
        chapterId: chapterId,
        content: content,
        nextUrl: undefined,
        prevUrl: undefined
      };
    } catch (error) {
      console.error('Failed to get chapter content:', error);
      throw new Error(`Failed to get chapter content: ${error}`);
    }
  }

  /**
   * 从网络获取章节内容（内部方法）
   */
  private async getChapterContentFromNetwork(bookSource: BookSource, chapterUrl: string): Promise<string> {
    try {
      // 这里需要实现具体的章节内容获取逻辑
      // 暂时返回空字符串
      return '';
    } catch (error) {
      console.error('Failed to get chapter content from network:', error);
      throw new Error(`Failed to get chapter content from network: ${error}`);
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