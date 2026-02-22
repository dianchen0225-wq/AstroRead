/**
 * AsyncTXTParser - 异步 TXT 小说解析器
 * 使用 TaskPool 将解析任务移至子线程，避免主线程阻塞
 */

import taskpool from '@ohos.taskpool';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { FileManager } from './FileManager';
import { Logger } from './Logger';

const TAG = 'AsyncTXTParser';

export interface TXTParseResult {
  success: boolean;
  book?: Book;
  chapters?: TXTChapter[];
  error?: string;
}

export interface TXTChapter {
  id: string;
  bookId: string;
  index: number;
  title: string;
  url: string;
  content: string;
  isVip: boolean;
}

interface ParseTaskParams {
  content: string;
  filePath: string;
  fileName?: string;
}

interface ParseTaskResult {
  success: boolean;
  book?: Book;
  chapters?: TXTChapter[];
  error?: string;
}

// 默认章节标题正则（支持多种常见格式）
const DEFAULT_CHAPTER_PATTERNS = [
  /^\s*第[一二三四五六七八九十百千零\d]+章[\s\S]*$/i,
  /^\s*第[一二三四五六七八九十百千零\d]+节[\s\S]*$/i,
  /^\s*第[一二三四五六七八九十百千零\d]+回[\s\S]*$/i,
  /^\s*第[一二三四五六七八九十百千零\d]+集[\s\S]*$/i,
  /^\s*Chapter\s+\d+[\s\S]*$/i,
  /^\s*\d+[\.\s]+[\s\S]+$/i,
  /^\s*[\(（【\[]?[一二三四五六七八九十百千零\d]+[\)）】\]][\s\S]*$/i,
  /^\s*正文[\s]*第[一二三四五六七八九十百千零\d]+章[\s\S]*$/i,
];

let taskPoolAvailable: boolean = false;
let taskPoolDisabled: boolean = true;

function isTaskPoolAvailable(): boolean {
  return taskPoolAvailable && !taskPoolDisabled;
}

function markTaskPoolUnavailable(): void {
  taskPoolAvailable = false;
  Logger.warn(TAG, 'TaskPool 不可用，已切换到同步解析模式');
}

/**
 * 在子线程中执行的解析任务
 */
@Concurrent
function parseInWorker(params: ParseTaskParams): ParseTaskResult {
  try {
    const { content, filePath, fileName } = params;

    if (!content || content.length === 0) {
      return { success: false, error: '文件内容为空' };
    }

    // 提取书名
    const bookName = extractBookName(filePath, fileName);

    // 分析章节结构
    const chapters = analyzeChapters(content);

    if (chapters.length === 0) {
      chapters.push({
        id: '0',
        bookId: '',
        index: 0,
        title: '全文',
        url: filePath,
        content: content,
        isVip: false
      });
    }

    // 创建书籍对象
    const book: Book = {
      id: '',
      name: bookName,
      author: '未知作者',
      cover: undefined,
      intro: extractIntro(content),
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookUrl: filePath,
      bookSourceId: 'local_txt',
      bookSourceName: '本地导入',
      lastUpdateTime: Date.now(),
      addTime: Date.now(),
      readProgress: 0,
      lastReadChapter: undefined,
      lastReadChapterIndex: undefined,
      lastReadTime: Date.now(),
      totalChapters: chapters.length,
      currentChapterIndex: 0,
      currentChapterTitle: chapters[0]?.title || '',
      isInShelf: false
    };

    // 设置章节索引
    chapters.forEach((chapter, index) => {
      chapter.index = index;
    });

    return {
      success: true,
      book,
      chapters
    };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      error: errorMsg
    };
  }
}

/**
 * 提取书名
 */
function extractBookName(filePath: string, fileName?: string): string {
  if (fileName) {
    return fileName.replace(/\.txt$/i, '').trim();
  }

  const parts = filePath.split('/');
  const fullName = parts[parts.length - 1];
  return fullName.replace(/\.txt$/i, '').trim();
}

/**
 * 提取简介（前200字）
 */
function extractIntro(content: string): string {
  const intro = content.substring(0, 200).replace(/\n/g, ' ').trim();
  return intro.length > 100 ? intro.substring(0, 100) + '...' : intro;
}

/**
 * 分析章节结构
 */
function analyzeChapters(content: string): TXTChapter[] {
  const chapters: TXTChapter[] = [];
  const lines = content.split('\n');

  let currentChapterStart = 0;
  let currentChapterTitle = '';
  let chapterIndex = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    if (isChapterTitle(line)) {
      if (currentChapterTitle) {
        const chapterContent = lines
          .slice(currentChapterStart, i)
          .join('\n')
          .trim();

        chapters.push({
          id: chapterIndex.toString(),
          bookId: '',
          index: chapterIndex,
          title: currentChapterTitle,
          url: '',
          content: chapterContent,
          isVip: false
        });

        chapterIndex++;
      }

      currentChapterTitle = line;
      currentChapterStart = i + 1;
    }
  }

  // 保存最后一章
  if (currentChapterTitle) {
    const chapterContent = lines
      .slice(currentChapterStart)
      .join('\n')
      .trim();

    chapters.push({
      id: chapterIndex.toString(),
      bookId: '',
      index: chapterIndex,
      title: currentChapterTitle,
      url: '',
      content: chapterContent,
      isVip: false
    });
  }

  return chapters;
}

/**
 * 检查是否是章节标题
 */
function isChapterTitle(line: string): boolean {
  for (const pattern of DEFAULT_CHAPTER_PATTERNS) {
    if (pattern.test(line)) {
      return true;
    }
  }
  return false;
}

/**
 * 异步 TXT 解析器类
 */
export class AsyncTXTParser {
  private static instance: AsyncTXTParser | null = null;

  private constructor() {}

  static getInstance(): AsyncTXTParser {
    if (!AsyncTXTParser.instance) {
      AsyncTXTParser.instance = new AsyncTXTParser();
    }
    return AsyncTXTParser.instance;
  }

  /**
   * 异步解析 TXT 文件
   * @param filePath 文件路径
   * @param fileName 文件名（可选）
   * @param onProgress 进度回调（可选）
   */
  async parse(
    filePath: string,
    fileName?: string,
    onProgress?: (progress: number) => void
  ): Promise<TXTParseResult> {
    try {
      Logger.info(TAG, `开始异步解析 TXT: ${filePath}`);

      // 1. 读取文件内容（异步）
      onProgress?.(10);
      const fileManager = FileManager.getInstance();
      const content = await fileManager.readFileContent(filePath);

      if (!content || content.length === 0) {
        return { success: false, error: '文件内容为空' };
      }

      Logger.info(TAG, `文件大小: ${content.length} 字符`);
      onProgress?.(30);

      // 2. 在子线程中解析
      if (isTaskPoolAvailable()) {
        try {
          const task = new taskpool.Task(parseInWorker, {
            content,
            filePath,
            fileName
          } as ParseTaskParams);

          onProgress?.(50);
          const result = await taskpool.execute(task) as ParseTaskResult;
          onProgress?.(100);

          if (!result.success) {
            Logger.error(TAG, `TaskPool 解析失败: ${result.error}`);
            // 降级到同步解析
            return this.parseSync(content, filePath, fileName);
          }

          Logger.info(TAG, `TaskPool 解析完成: ${result.book?.name}, ${result.chapters?.length} 章`);
          return result;
        } catch (error) {
          Logger.error(TAG, `TaskPool 执行失败: ${error}`);
          markTaskPoolUnavailable();
          // 降级到同步解析
          return this.parseSync(content, filePath, fileName);
        }
      } else {
        // 同步解析
        onProgress?.(50);
        const result = this.parseSync(content, filePath, fileName);
        onProgress?.(100);
        return result;
      }
    } catch (error) {
      Logger.error(TAG, `解析 TXT 失败: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  /**
   * 同步解析（降级方案）
   */
  private parseSync(content: string, filePath: string, fileName?: string): TXTParseResult {
    try {
      const bookName = extractBookName(filePath, fileName);
      const chapters = analyzeChapters(content);

      if (chapters.length === 0) {
        chapters.push({
          id: '0',
          bookId: '',
          index: 0,
          title: '全文',
          url: filePath,
          content: content,
          isVip: false
        });
      }

      const book: Book = {
        id: '',
        name: bookName,
        author: '未知作者',
        cover: undefined,
        intro: extractIntro(content),
        kind: undefined,
        wordCount: undefined,
        latestChapter: undefined,
        bookUrl: filePath,
        bookSourceId: 'local_txt',
        bookSourceName: '本地导入',
        lastUpdateTime: Date.now(),
        addTime: Date.now(),
        readProgress: 0,
        lastReadChapter: undefined,
        lastReadChapterIndex: undefined,
        lastReadTime: Date.now(),
        totalChapters: chapters.length,
        currentChapterIndex: 0,
        currentChapterTitle: chapters[0]?.title || '',
        isInShelf: false
      };

      chapters.forEach((chapter, index) => {
        chapter.index = index;
      });

      Logger.info(TAG, `同步解析完成: ${bookName}, ${chapters.length} 章`);

      return {
        success: true,
        book,
        chapters
      };
    } catch (error) {
      return { success: false, error: String(error) };
    }
  }
}

// 导出单例实例
export const asyncTXTParser = AsyncTXTParser.getInstance();
