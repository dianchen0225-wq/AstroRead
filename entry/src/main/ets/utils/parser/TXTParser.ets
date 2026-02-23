/**
 * TXTParser - TXT 小说解析器
 * 自动识别章节、编码，生成书籍和章节信息
 */

import { Book } from '../../models/Book';
import { Chapter } from '../../models/Book';
import { FileManager } from '../file/FileManager';
import { Logger } from '../performance/Logger';

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

export interface TXTChapterRule {
  // 章节标题正则模式
  patterns: RegExp[];
  // 是否使用默认模式
  useDefault: boolean;
}

export class TXTParser {
  private static instance: TXTParser | null = null;
  private readonly TAG = 'TXTParser';

  // 默认章节标题正则（支持多种常见格式）
  private readonly DEFAULT_CHAPTER_PATTERNS = [
    /^\s*第[一二三四五六七八九十百千零\d]+章[\s\S]*$/i,  // 第X章
    /^\s*第[一二三四五六七八九十百千零\d]+节[\s\S]*$/i,  // 第X节
    /^\s*第[一二三四五六七八九十百千零\d]+回[\s\S]*$/i,  // 第X回
    /^\s*第[一二三四五六七八九十百千零\d]+集[\s\S]*$/i,  // 第X集
    /^\s*Chapter\s+\d+[\s\S]*$/i,                          // Chapter X
    /^\s*\d+[\.\s]+[\s\S]+$/i,                              // 1. 标题
    /^\s*[\(（【\[]?[一二三四五六七八九十百千零\d]+[\)）】\]][\s\S]*$/i,  // (1) 标题
    /^\s*正文[\s]*第[一二三四五六七八九十百千零\d]+章[\s\S]*$/i,  // 正文第X章
  ];

  static getInstance(): TXTParser {
    if (!TXTParser.instance) {
      TXTParser.instance = new TXTParser();
    }
    return TXTParser.instance;
  }

  /**
   * 解析 TXT 文件
   * @param filePath 文件路径
   * @param fileName 文件名（用于提取书名）
   */
  async parse(filePath: string, fileName?: string): Promise<TXTParseResult> {
    try {
      Logger.info(this.TAG, `开始解析 TXT: ${filePath}`);

      // 1. 读取文件内容
      const fileManager: FileManager = FileManager.getInstance();
      const content: string = await fileManager.readFileContent(filePath);

      if (!content || content.length === 0) {
        return { success: false, error: '文件内容为空' };
      }

      Logger.info(this.TAG, `文件大小: ${content.length} 字符`);

      // 2. 提取书名
      const bookName = this.extractBookName(filePath, fileName);

      // 3. 分析章节结构
      const chapters = this.analyzeChapters(content);

      if (chapters.length === 0) {
        // 没有识别到章节，将整个文件作为一章
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

      // 4. 创建书籍对象
      const book: Book = {
        id: '',
        name: bookName,
        author: '未知作者',
        cover: undefined,
        intro: this.extractIntro(content),
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

      // 设置章节所属的 bookId（后续更新）
      chapters.forEach((chapter, index) => {
        chapter.index = index;
      });

      Logger.info(this.TAG, `解析完成: ${bookName}, ${chapters.length} 章`);

      return {
        success: true,
        book,
        chapters
      };

    } catch (error) {
      Logger.error(this.TAG, `解析 TXT 失败: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  /**
   * 分析章节结构
   */
  private analyzeChapters(content: string): TXTChapter[] {
    const chapters: TXTChapter[] = [];
    const lines = content.split('\n');

    let currentChapterStart = 0;
    let currentChapterTitle = '';
    let chapterIndex = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();

      // 检查是否是章节标题
      if (this.isChapterTitle(line)) {
        // 保存上一章节
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

        // 开始新章节
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
  private isChapterTitle(line: string): boolean {
    if (!line || line.length > 100) return false;

    // 使用默认正则匹配
    for (const pattern of this.DEFAULT_CHAPTER_PATTERNS) {
      if (pattern.test(line)) {
        return true;
      }
    }

    return false;
  }

  /**
   * 提取书名
   */
  private extractBookName(filePath: string, fileName?: string): string {
    const name = fileName || filePath.split('/').pop() || '未知书籍';
    // 移除扩展名
    return name.replace(/\.txt$/i, '');
  }

  /**
   * 提取简介（前500字符）
   */
  private extractIntro(content: string): string {
    const intro = content.substring(0, 500).replace(/\s+/g, ' ').trim();
    return intro.length >= 500 ? intro + '...' : intro;
  }

  /**
   * 获取章节预览
   */
  getChapterPreview(chapter: TXTChapter, maxLength: number = 100): string {
    if (!chapter.content) return '';

    const preview = chapter.content
      .substring(0, maxLength)
      .replace(/\s+/g, ' ')
      .trim();

    return preview.length >= maxLength ? preview + '...' : preview;
  }

  /**
   * 自定义章节识别规则
   */
  setCustomChapterPatterns(patterns: string[]): void {
    // 将字符串正则转换为 RegExp
    const customPatterns = patterns.map(p => new RegExp(p, 'i'));
    this.DEFAULT_CHAPTER_PATTERNS.unshift(...customPatterns);
  }

  /**
   * 智能识别章节（针对无明确章节标记的长文本）
   */
  private smartChapterSplit(content: string, wordCountPerChapter: number = 3000): TXTChapter[] {
    const chapters: TXTChapter[] = [];
    const totalLength = content.length;
    const estimatedChapters = Math.ceil(totalLength / wordCountPerChapter);

    for (let i = 0; i < estimatedChapters; i++) {
      const start = i * wordCountPerChapter;
      const end = Math.min((i + 1) * wordCountPerChapter, totalLength);

      // 尝试在段落边界分割
      let splitPoint = end;
      const nextNewline = content.indexOf('\n\n', end);
      if (nextNewline !== -1 && nextNewline < end + 200) {
        splitPoint = nextNewline;
      }

      const chapterContent = content.substring(start, splitPoint).trim();

      chapters.push({
        id: i.toString(),
        bookId: '',
        index: i,
        title: `第${i + 1}章`,
        url: '',
        content: chapterContent,
        isVip: false
      });
    }

    return chapters;
  }

  /**
   * 检测文本编码（简化版）
   */
  detectEncoding(buffer: ArrayBuffer): string {
    // 通过检查 BOM 或字符分布来检测编码
    const bytes = new Uint8Array(buffer);

    // UTF-8 BOM
    if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
      return 'utf-8';
    }

    // UTF-16 LE BOM
    if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
      return 'utf-16le';
    }

    // UTF-16 BE BOM
    if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
      return 'utf-16be';
    }

    // 默认 UTF-8
    return 'utf-8';
  }
}

export default TXTParser.getInstance();
