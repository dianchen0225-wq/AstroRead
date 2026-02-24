import { Chapter } from '../models/Book';
import { ChapterContent } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { DatabaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import { IdGenerator } from '../utils/IdGenerator';
import { ParsedChapterItem } from '../utils/ContentParser';
import { Logger } from '../utils/Logger';
import { common } from '@kit.AbilityKit';

export interface PagedChaptersResult {
  chapters: Chapter[];
  totalCount: number;
  currentPage: number;
  pageSize: number;
  hasMore: boolean;
}

const DEFAULT_PAGE_SIZE = 100;
const MAX_CHAPTERS_PER_SAVE = 500;
const MAX_CONTENT_CACHE_SIZE = 50;

interface ContentCacheEntry {
  content: ChapterContent;
  timestamp: number;
  accessCount: number;
}

export class ChapterViewModel {
  private readonly databaseManager = DatabaseManager.getInstance();
  private readonly networkManager = NetworkManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private static readonly TAG = 'ChapterViewModel';
  
  private contentCache: Map<string, ContentCacheEntry> = new Map();
  private readonly cacheTTL: number = 30 * 60 * 1000;

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.networkManager.setContext(context);
  }

  /**
   * 清理资源，防止内存泄漏
   * 在页面销毁时调用
   */
  destroy(): void {
    Logger.info(ChapterViewModel.TAG, '销毁 ChapterViewModel，清理资源');
    
    // 清理缓存
    this.clearContentCache();
    
    // 清理 context 引用，防止内存泄漏
    this.context = null;
    
    // 清理 networkManager 的 context 引用
    const nullContext: common.UIAbilityContext | null = null;
    this.networkManager.setContext(nullContext);
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
   * 分页获取章节列表
   */
  async getChaptersPaged(
    bookId: string,
    page: number = 1,
    pageSize: number = DEFAULT_PAGE_SIZE
  ): Promise<PagedChaptersResult> {
    const startTime = Date.now();

    try {
      // 参数边界检查
      const safePage = Math.max(1, Math.floor(page));
      const safePageSize = Math.max(1, Math.min(pageSize, 500)); // 限制最大每页数量

      const allChapters = await this.getChaptersByBookId(bookId);
      const totalCount = allChapters.length;

      // 边界检查：如果总数为0，直接返回空结果
      if (totalCount === 0) {
        return {
          chapters: [],
          totalCount: 0,
          currentPage: safePage,
          pageSize: safePageSize,
          hasMore: false
        };
      }

      const startIndex = (safePage - 1) * safePageSize;
      const endIndex = Math.min(startIndex + safePageSize, totalCount);

      // 边界检查：如果起始索引超出范围，返回空结果
      if (startIndex >= totalCount) {
        return {
          chapters: [],
          totalCount: totalCount,
          currentPage: safePage,
          pageSize: safePageSize,
          hasMore: false
        };
      }

      const chapters = allChapters.slice(startIndex, endIndex);
      const hasMore = endIndex < totalCount;

      const elapsed = Date.now() - startTime;
      Logger.info(ChapterViewModel.TAG, `分页获取章节: 页${safePage}, 每页${safePageSize}, 总数${totalCount}, 耗时${elapsed}ms`);

      return {
        chapters: chapters,
        totalCount: totalCount,
        currentPage: safePage,
        pageSize: safePageSize,
        hasMore: hasMore
      };
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `分页获取章节失败: ${error instanceof Error ? error.message : String(error)}`);
      return {
        chapters: [],
        totalCount: 0,
        currentPage: page,
        pageSize: pageSize,
        hasMore: false
      };
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
    const startTime = Date.now();
    
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

      // 分批保存大量章节
      await this.batchSaveChaptersInBatches(chapters);
      
      const elapsed = Date.now() - startTime;
      Logger.info(ChapterViewModel.TAG, `成功保存 ${chapters.length} 个章节, 总耗时: ${elapsed}ms`);
      
      return chapters;
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `获取章节列表失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to fetch chapters: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 分批保存章节（避免一次性保存过多数据）
   */
  private async batchSaveChaptersInBatches(chapters: Chapter[]): Promise<void> {
    if (chapters.length === 0) return;

    const totalBatches = Math.ceil(chapters.length / MAX_CHAPTERS_PER_SAVE);
    Logger.info(ChapterViewModel.TAG, `分${totalBatches}批保存 ${chapters.length} 个章节`);

    for (let i = 0; i < chapters.length; i += MAX_CHAPTERS_PER_SAVE) {
      const batch = chapters.slice(i, i + MAX_CHAPTERS_PER_SAVE);
      const batchNum = Math.floor(i / MAX_CHAPTERS_PER_SAVE) + 1;
      
      Logger.debug(ChapterViewModel.TAG, `保存第${batchNum}/${totalBatches}批, ${batch.length}个章节`);
      
      try {
        await this.batchUpsertChapters(batch);
      } catch (error) {
        const err = error instanceof Error ? error : new Error(String(error));
        Logger.error(ChapterViewModel.TAG, `第${batchNum}批章节保存失败: ${err.message}`);
        throw err;
      }
      
      if (i + MAX_CHAPTERS_PER_SAVE < chapters.length) {
        await new Promise<void>((resolve, reject) => {
          setTimeout(() => {
            if (!this.context) {
              reject(new Error('Context已销毁'));
              return;
            }
            resolve();
          }, 0);
        });
      }
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
      Logger.info(ChapterViewModel.TAG, `========== 开始获取章节内容 ==========`);
      Logger.info(ChapterViewModel.TAG, `chapterId: ${chapterId}`);
      Logger.info(ChapterViewModel.TAG, `传入的chapterUrl: ${chapterUrl}`);
      Logger.info(ChapterViewModel.TAG, `书源baseUrl: ${bookSource.url}`);

      const cachedContent = this.getFromContentCache(chapterId);
      if (cachedContent) {
        Logger.info(ChapterViewModel.TAG, `从缓存获取章节内容: ${chapterId}`);
        return cachedContent;
      }

      let finalChapterUrl = chapterUrl;
      if (chapterUrl) {
        if (chapterUrl.startsWith('http://') || chapterUrl.startsWith('https://')) {
          finalChapterUrl = chapterUrl;
          Logger.info(ChapterViewModel.TAG, `使用原始绝对路径: ${finalChapterUrl}`);
        } else if (chapterUrl.startsWith('//')) {
          const protocol = bookSource.url.startsWith('https') ? 'https:' : 'http:';
          finalChapterUrl = protocol + chapterUrl;
          Logger.info(ChapterViewModel.TAG, `协议相对路径转换: ${chapterUrl} -> ${finalChapterUrl}`);
        } else {
          finalChapterUrl = this.resolveChapterUrl(bookSource.url, chapterUrl);
          Logger.info(ChapterViewModel.TAG, `相对路径转换: ${chapterUrl} -> ${finalChapterUrl}`);
        }
      }

      if (!finalChapterUrl) {
        throw new Error('章节URL为空，无法获取内容');
      }

      Logger.info(ChapterViewModel.TAG, `最终请求URL: ${finalChapterUrl}`);

      const content = await this.getChapterContentFromNetwork(bookSource, finalChapterUrl);
      
      Logger.info(ChapterViewModel.TAG, `获取内容成功，长度: ${content.length}`);
      Logger.info(ChapterViewModel.TAG, `========== 章节内容获取完成 ==========`);
      
      const result: ChapterContent = {
        chapterId: chapterId,
        content: content,
        nextUrl: undefined,
        prevUrl: undefined
      };
      
      this.setToContentCache(chapterId, result);
      
      return result;
    } catch (error) {
      Logger.error(ChapterViewModel.TAG, `========== 获取章节内容失败 ==========`);
      Logger.error(ChapterViewModel.TAG, `错误: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`Failed to get chapter content: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private getFromContentCache(chapterId: string): ChapterContent | null {
    const entry = this.contentCache.get(chapterId);
    if (!entry) {
      return null;
    }

    if (Date.now() - entry.timestamp > this.cacheTTL) {
      this.contentCache.delete(chapterId);
      return null;
    }

    entry.accessCount++;
    return entry.content;
  }

  private setToContentCache(chapterId: string, content: ChapterContent): void {
    if (this.contentCache.size >= MAX_CONTENT_CACHE_SIZE) {
      this.evictContentCache();
    }

    this.contentCache.set(chapterId, {
      content: content,
      timestamp: Date.now(),
      accessCount: 1
    });
  }

  private evictContentCache(): void {
    let lruKey: string | null = null;
    let lowestScore = Infinity;
    const now = Date.now();

    this.contentCache.forEach((entry, key) => {
      const ageScore = (now - entry.timestamp) / this.cacheTTL;
      const accessScore = 1 / (entry.accessCount + 1);
      const score = ageScore * 0.3 + accessScore * 0.7;

      if (score < lowestScore) {
        lowestScore = score;
        lruKey = key;
      }
    });

    if (lruKey) {
      this.contentCache.delete(lruKey);
      Logger.debug(ChapterViewModel.TAG, `清理章节内容缓存: ${lruKey}`);
    }
  }

  clearContentCache(): void {
    this.contentCache.clear();
    Logger.info(ChapterViewModel.TAG, '章节内容缓存已清空');
  }

  private resolveChapterUrl(baseUrl: string, relativeUrl: string): string {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }

    if (relativeUrl.startsWith('//')) {
      const protocol = baseUrl.startsWith('https') ? 'https:' : 'http:';
      return protocol + relativeUrl;
    }

    const baseMatch = baseUrl.match(/^(https?:\/\/[^/]+)(\/.*)?$/);
    const origin = baseMatch ? baseMatch[1] : '';

    if (relativeUrl.startsWith('/')) {
      return origin + relativeUrl;
    }

    const lastSlashIndex = baseUrl.lastIndexOf('/');
    const basePath = lastSlashIndex >= 0 ? baseUrl.substring(0, lastSlashIndex + 1) : baseUrl;
    return basePath + relativeUrl;
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
    // 空值检查
    if (!currentChapter || !chapters || chapters.length === 0) {
      return null;
    }

    const currentIndex = chapters.findIndex((ch: Chapter) => ch.id === currentChapter.id);

    // 边界检查：未找到当前章节或已是最后一章
    if (currentIndex < 0 || currentIndex >= chapters.length - 1) {
      return null;
    }

    return chapters[currentIndex + 1];
  }

  /**
   * 获取上一章
   */
  async getPrevChapter(currentChapter: Chapter, chapters: Chapter[]): Promise<Chapter | null> {
    // 空值检查
    if (!currentChapter || !chapters || chapters.length === 0) {
      return null;
    }

    const currentIndex = chapters.findIndex((ch: Chapter) => ch.id === currentChapter.id);

    // 边界检查：未找到当前章节或已是第一章
    if (currentIndex <= 0) {
      return null;
    }

    return chapters[currentIndex - 1];
  }

  /**
   * 根据索引安全获取章节
   * @param chapters 章节列表
   * @param index 章节索引
   * @returns 章节对象或null
   */
  getChapterByIndex(chapters: Chapter[], index: number): Chapter | null {
    // 空值检查
    if (!chapters || chapters.length === 0) {
      return null;
    }

    // 边界检查
    const safeIndex = Math.floor(index);
    if (safeIndex < 0 || safeIndex >= chapters.length) {
      Logger.warn(ChapterViewModel.TAG, `章节索引越界: ${safeIndex}, 总数: ${chapters.length}`);
      return null;
    }

    return chapters[safeIndex];
  }

  /**
   * 安全获取章节索引
   * @param chapters 章节列表
   * @param chapterId 章节ID
   * @returns 章节索引，未找到返回-1
   */
  getChapterIndex(chapters: Chapter[], chapterId: string): number {
    if (!chapters || chapters.length === 0 || !chapterId) {
      return -1;
    }
    return chapters.findIndex((ch: Chapter) => ch.id === chapterId);
  }

}