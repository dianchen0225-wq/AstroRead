import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { Book, Chapter, ChapterContent } from '../../models/Book';
import { CrawlResult, CrawlChapterError } from '../crawler/NovelCrawler';
import { DatabaseManager } from '../file/DatabaseManager';
import { DataValidator } from '../validation/DataValidator';
import { IdGenerator } from '../content/IdGenerator';
import { Logger } from '../performance/Logger';

export interface StorageResult {
  success: boolean;
  bookId: string;
  chaptersSaved: number;
  contentsSaved: number;
  errors: string[];
}

export interface ExportOptions {
  format: 'txt' | 'html' | 'json';
  includeMetadata: boolean;
  encoding: string;
  splitChapters: boolean;
  outputDir?: string;
}

export interface CrawlStatus {
  bookId: string;
  bookName: string;
  phase: 'crawling' | 'storing' | 'complete' | 'failed';
  totalChapters: number;
  downloadedChapters: number;
  lastError: string;
  startedAt: number;
  completedAt: number;
}

export interface ValidateStorageResult {
  valid: boolean;
  missingChapters: string[];
  corruptedChapters: string[];
  totalSize: number;
}

export class CrawledBookStorage {
  private static instance: CrawledBookStorage | null = null;
  private dbManager: DatabaseManager;
  private validator: DataValidator;
  private statusMap: Map<string, CrawlStatus> = new Map();
  private readonly TAG = 'CrawledBookStorage';

  private constructor() {
    this.dbManager = DatabaseManager.getInstance();
    this.validator = DataValidator.getInstance();
  }

  static getInstance(): CrawledBookStorage {
    if (!CrawledBookStorage.instance) {
      CrawledBookStorage.instance = new CrawledBookStorage();
    }
    return CrawledBookStorage.instance;
  }

  /**
   * 保存完整爬取结果到数据库
   */
  async saveCrawlResult(result: CrawlResult): Promise<StorageResult> {
    const errors: string[] = [];
    let chaptersSaved = 0;
    let contentsSaved = 0;

    const status = this.statusMap.get(result.book.id);
    if (status) {
      status.phase = 'storing';
    }

    try {
      Logger.info(this.TAG, `保存爬取结果: ${result.book.name}`);

      // 1. 保存书籍信息
      await this.dbManager.upsertBook(result.book);
      Logger.info(this.TAG, `书籍已保存: ${result.book.id}`);

      // 2. 批量保存章节列表
      if (result.chapters.length > 0) {
        try {
          await this.dbManager.batchUpsertChapters(result.chapters);
          chaptersSaved = result.chapters.length;
          Logger.info(this.TAG, `章节列表已保存: ${chaptersSaved} 个`);
        } catch (chError) {
          const msg = `章节列表保存失败: ${chError}`;
          errors.push(msg);
          Logger.error(this.TAG, msg);
        }
      }

      // 3. 保存章节内容到文件系统
      if (result.contents.length > 0) {
        contentsSaved = await this.saveChapterContents(
          result.book.id,
          result.contents
        );
      }

      // 4. 记录错误信息
      if (result.errors.length > 0) {
        Logger.warn(this.TAG, `爬取错误: ${result.errors.length} 个`);
        for (const ce of result.errors) {
          Logger.warn(this.TAG, `  失败章节: ${ce.chapterTitle}, ${ce.error}`);
        }
      }

      if (status) {
        status.phase = 'complete';
        status.completedAt = Date.now();
        status.downloadedChapters = result.contents.length;
      }

      Logger.info(this.TAG,
        `保存完成: 书籍=1, 章节列表=${chaptersSaved}, 内容=${contentsSaved}, 错误=${errors.length}`
      );

      return {
        success: errors.length === 0,
        bookId: result.book.id,
        chaptersSaved,
        contentsSaved,
        errors
      };

    } catch (error) {
      const msg = `保存爬取结果失败: ${error}`;
      errors.push(msg);
      Logger.error(this.TAG, msg);

      if (status) {
        status.phase = 'failed';
        status.lastError = msg;
      }

      return {
        success: false,
        bookId: result.book.id,
        chaptersSaved,
        contentsSaved,
        errors
      };
    }
  }

  /**
   * 保存章节内容到文件系统
   */
  private async saveChapterContents(
    bookId: string,
    contents: ChapterContent[]
  ): Promise<number> {
    let saved = 0;
    const context = this.getContext();
    if (!context) {
      Logger.warn(this.TAG, '无法获取应用上下文，跳过文件保存');
      return 0;
    }

    const contentDir = `${context.filesDir}/books/${bookId}/chapters`;

    try {
      // 确保目录存在
      fileIo.mkdirSync(contentDir, true);
    } catch (e) {
      Logger.warn(this.TAG, `创建章节目录失败: ${e}`);
    }

    for (const content of contents) {
      try {
        if (!content.content || content.content.length < 10) {
          continue;
        }

        const sanitizedId = content.chapterId.replace(/[<>:"/\\|?*]/g, '_');
        const filePath = `${contentDir}/${sanitizedId}.txt`;

        const encoder = new util.TextEncoder();
        const data = encoder.encodeInto(content.content);
        const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
        fileIo.writeSync(file.fd, data);
        fileIo.closeSync(file);
        saved++;
      } catch (e) {
        Logger.warn(this.TAG, `保存章节文件失败: ${content.chapterId}, ${e}`);
      }
    }

    Logger.info(this.TAG, `章节文件保存完成: ${saved}/${contents.length}`);
    return saved;
  }

  /**
   * 加载已保存的书籍内容
   */
  async loadBookContent(bookId: string, chapterId: string): Promise<string> {
    const context = this.getContext();
    if (!context) {
      return '';
    }

    const sanitizedId = chapterId.replace(/[<>:"/\\|?*]/g, '_');
    const filePath = `${context.filesDir}/books/${bookId}/chapters/${sanitizedId}.txt`;

    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(filePath);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);

      const decoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(new Uint8Array(buffer));
    } catch (e) {
      Logger.warn(this.TAG, `加载章节文件失败: ${chapterId}, ${e}`);
      return '';
    }
  }

  /**
   * 导出书籍为指定格式
   */
  async exportBook(
    book: Book,
    chapters: Chapter[],
    contents: ChapterContent[],
    options: ExportOptions
  ): Promise<string> {
    const context = this.getContext();
    if (!context) {
      Logger.error(this.TAG, '无法获取应用上下文');
      return '';
    }

    const outputDir = options.outputDir || `${context.filesDir}/export`;
    const sanitizedName = book.name.replace(/[<>:"/\\|?*]/g, '_');
    const extension = options.format === 'html' ? '.html' : options.format === 'json' ? '.json' : '.txt';
    const outputPath = `${outputDir}/${sanitizedName}${extension}`;

    try {
      fileIo.mkdirSync(outputDir, true);

      let output = '';

      if (options.includeMetadata) {
        output += `书名: ${book.name}\n`;
        output += `作者: ${book.author}\n`;
        if (book.intro) {
          output += `简介: ${book.intro}\n`;
        }
        output += `共 ${chapters.length} 章\n`;
        output += `\n${'='.repeat(50)}\n\n`;
      }

      for (const chapter of chapters) {
        output += `\n${chapter.title}\n`;
        output += `${'-'.repeat(40)}\n\n`;

        const content = contents.find(c => c.chapterId === chapter.id);
        if (content) {
          output += content.content;
        } else {
          output += '[内容未下载]\n';
        }

        output += `\n\n`;
      }

      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(output);
      const file = fileIo.openSync(outputPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);

      Logger.info(this.TAG, `导出完成: ${outputPath}, ${output.length} 字符`);
      return outputPath;

    } catch (error) {
      Logger.error(this.TAG, `导出失败: ${error}`);
      return '';
    }
  }

  /**
   * 验证存储的完整性
   */
  async validateStorage(bookId: string): Promise<ValidateStorageResult> {
    const context = this.getContext();
    const missingChapters: string[] = [];
    const corruptedChapters: string[] = [];
    let totalSize = 0;

    if (!context) {
      return { valid: false, missingChapters, corruptedChapters, totalSize };
    }

    const chapters = await this.dbManager.getChaptersByBookId(bookId);
    if (!chapters || chapters.length === 0) {
      return { valid: false, missingChapters, corruptedChapters, totalSize };
    }

    const contentDir = `${context.filesDir}/books/${bookId}/chapters`;

    for (const chapter of chapters) {
      const sanitizedId = chapter.id.replace(/[<>:"/\\|?*]/g, '_');
      const filePath = `${contentDir}/${sanitizedId}.txt`;

      try {
        const stat = fileIo.statSync(filePath);
        totalSize += stat.size;

        if (stat.size < 20) {
          corruptedChapters.push(chapter.title);
        }
      } catch {
        missingChapters.push(chapter.title);
      }
    }

    const valid = missingChapters.length === 0 && corruptedChapters.length === 0;

    Logger.info(this.TAG,
      `存储验证: 有效=${valid}, 缺失=${missingChapters.length}, ` +
      `损坏=${corruptedChapters.length}, 总大小=${totalSize}`
    );

    return { valid, missingChapters, corruptedChapters, totalSize };
  }

  /**
   * 删除已存储的书籍数据
   */
  async deleteBookData(bookId: string): Promise<boolean> {
    const context = this.getContext();
    if (!context) {
      return false;
    }

    try {
      // 删除数据库中的章节
      await this.dbManager.getChapterRepo().deleteChaptersByBookId(bookId);

      // 删除书籍记录
      await this.dbManager.deleteBook(bookId);

      // 删除文件
      const bookDir = `${context.filesDir}/books/${bookId}`;
      this.rmdirSyncRecursive(bookDir);

      this.statusMap.delete(bookId);

      Logger.info(this.TAG, `书籍数据已删除: ${bookId}`);
      return true;

    } catch (error) {
      Logger.error(this.TAG, `删除书籍数据失败: ${error}`);
      return false;
    }
  }

  // ==================== 状态管理 ====================

  getCrawlStatus(bookId: string): CrawlStatus | null {
    return this.statusMap.get(bookId) || null;
  }

  setCrawlStatus(bookId: string, status: Partial<CrawlStatus>): void {
    const existing = this.statusMap.get(bookId);
    if (existing) {
      const updated: CrawlStatus = {
        bookId: status.bookId ?? existing.bookId,
        bookName: status.bookName ?? existing.bookName,
        phase: status.phase ?? existing.phase,
        totalChapters: status.totalChapters ?? existing.totalChapters,
        downloadedChapters: status.downloadedChapters ?? existing.downloadedChapters,
        lastError: status.lastError ?? existing.lastError,
        startedAt: status.startedAt ?? existing.startedAt,
        completedAt: status.completedAt ?? existing.completedAt
      };
      this.statusMap.set(bookId, updated);
    } else {
      const newStatus: CrawlStatus = {
        bookId: bookId,
        bookName: status.bookName || '',
        phase: status.phase || 'crawling',
        totalChapters: status.totalChapters || 0,
        downloadedChapters: status.downloadedChapters || 0,
        lastError: status.lastError || '',
        startedAt: status.startedAt || Date.now(),
        completedAt: status.completedAt || 0
      };
      this.statusMap.set(bookId, newStatus);
    }
  }

  getAllCrawlStatuses(): CrawlStatus[] {
    return Array.from(this.statusMap.values());
  }

  // ==================== 工具方法 ====================

  private contextCache: common.UIAbilityContext | null = null;

  private getContext(): common.UIAbilityContext | null {
    if (this.contextCache) {
      return this.contextCache;
    }

    try {
      const appContext = getContext() as common.UIAbilityContext;
      if (appContext && appContext.filesDir) {
        this.contextCache = appContext;
        return appContext;
      }
    } catch {
      // context not available
    }

    return null;
  }

  private rmdirSyncRecursive(dirPath: string): void {
    try {
      const files = fileIo.listFileSync(dirPath);
      for (const file of files) {
        const fullPath = `${dirPath}/${file}`;
        try {
          const stat = fileIo.statSync(fullPath);
          if (stat.isDirectory()) {
            this.rmdirSyncRecursive(fullPath);
          } else {
            fileIo.unlinkSync(fullPath);
          }
        } catch {
          // skip
        }
      }
      fileIo.rmdirSync(dirPath);
    } catch {
      // directory doesn't exist or can't be accessed
    }
  }
}

export default CrawledBookStorage.getInstance();
