import { Chapter } from '../models/Book';
import { ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { DatabaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import { IdGenerator } from '../utils/IdGenerator';
import { ParsedChapterItem } from '../utils/ContentParser';
import { Logger } from '../utils/Logger';
import common from '@ohos.app.ability.common';

/**
 * 章节视图模型
 */
export class ChapterViewModel {
  private readonly databaseManager = DatabaseManager.getInstance();
  private readonly networkManager = NetworkManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private static readonly TAG = 'ChapterViewModel';

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.networkManager.setContext(context);
  }

  /**
   * 获取书籍的章节列表
   */
  async getChapters(bookId: string): Promise<Chapter[]> {
    try {
      return await this.getChaptersByBookId(bookId);
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `获取章节失败: ${error instanceof Error ? error.message : String(error)}`);
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
      return await this.databaseManager.getChaptersByBookId(bookId);
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `根据书籍ID获取章节失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 从网络获取章节列表并保存
   */
  async fetchAndSaveChapters(bookId: string, bookSource: BookSource, bookUrl: string): Promise<Chapter[]> {
    try {
      Logger.info(ChapterViewModel.TAG, `开始获取章节，书源: ${bookSource.name}, URL: ${bookUrl}`);
      const chapterList: ParsedChapterItem[] = await this.getChapterList(bookSource, bookUrl);
      Logger.info(ChapterViewModel.TAG, `解析到 ${chapterList.length} 个章节`);
      
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

      await this.batchUpsertChapters(chapters);
      Logger.info(ChapterViewModel.TAG, `成功保存 ${chapters.length} 个章节`);
      
      return chapters;
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `获取章节列表失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to fetch chapters: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async getChapterList(bookSource: BookSource, bookUrl: string): Promise<ParsedChapterItem[]> {
    try {
      const response = await NetworkManager.getInstance().getChapterList(bookSource, bookUrl);
      return response;
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `获取章节列表失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to get chapter list: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
    if (this.databaseManager === null || chapters.length === 0) {
      return;
    }

    try {
      await this.databaseManager.batchUpsertChapters(chapters);
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `批量保存章节失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to batch upsert chapters: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async saveChapters(bookId: string, chapters: Chapter[]): Promise<void> {
    for (const chapter of chapters) {
      chapter.bookId = bookId;
    }
    await this.batchUpsertChapters(chapters);
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
      Logger.error(ChapterViewModel.TAG, `获取章节内容失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to get chapter content: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 从网络获取章节内容（内部方法）
   */
  private async getChapterContentFromNetwork(bookSource: BookSource, chapterUrl: string): Promise<string> {
    try {
      const response = await NetworkManager.getInstance().getChapterContent(bookSource, chapterUrl);
      return response;
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `从网络获取章节内容失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to get chapter content from network: ${error instanceof Error ? error.message : String(error)}`);
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