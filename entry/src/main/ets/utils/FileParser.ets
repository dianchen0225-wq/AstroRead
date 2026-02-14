import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { IdGenerator } from './IdGenerator';
import { Logger } from './Logger';

export class FileParser {
  private static readonly TAG = 'FileParser';

  static async parseTxtFile(filePath: string, bookId: string): Promise<Chapter[]> {
    try {
      const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(filePath);
      const buffer = new ArrayBuffer(stat.size);
      await fileIo.read(file.fd, buffer);
      await fileIo.close(file.fd);
      
      const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
      const content = decoder.decodeToString(new Uint8Array(buffer), { stream: false });
      
      // 按章节分割（支持多种章节标题格式）
      const chapterPattern = /(?:^|\n)(?:第[一二三四五六七八九十百千万\d]+章|第\d+章|Chapter \d+|CHAPTER \d+)[^\n]*/g;
      const matches = Array.from(content.matchAll(chapterPattern));
      
      const chapters: Chapter[] = [];
      let startIndex = 0;
      let order = 0;
      
      for (const match of matches) {
        const chapterTitle = match[0].trim();
        const chapterStart = match.index || 0;
        
        // 获取上一章的内容
        if (chapterStart > startIndex) {
          const prevContent = content.substring(startIndex, chapterStart).trim();
          if (prevContent.length > 0 && chapters.length > 0) {
            // 更新上一章的内容（这里简化处理，实际可以存储内容）
          }
        }
        
        const chapter: Chapter = {
          id: IdGenerator.generateUUID(),
          bookId: bookId,
          title: chapterTitle,
          url: `local://${bookId}/${order}`,
          order: order++,
          isVip: false
        };
        chapters.push(chapter);
        
        startIndex = chapterStart + chapterTitle.length;
      }
      
      // 处理最后一章
      if (startIndex < content.length) {
        const lastContent = content.substring(startIndex).trim();
        if (lastContent.length > 0 && chapters.length > 0) {
          // 更新最后一章
        }
      }
      
      // 如果没有找到章节，创建单章
      if (chapters.length === 0) {
        const chapter: Chapter = {
          id: IdGenerator.generateUUID(),
          bookId: bookId,
          title: '正文',
          url: `local://${bookId}/0`,
          order: 0,
          isVip: false
        };
        chapters.push(chapter);
      }
      
      return chapters;
    } catch (error) {
      Logger.error(FileParser.TAG, `解析TXT文件失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  static async readChapterFromTxt(
    filePath: string,
    chapterStart: number,
    chapterEnd: number
  ): Promise<string> {
    try {
      const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(chapterEnd - chapterStart);
      await fileIo.read(file.fd, buffer, { offset: chapterStart, length: chapterEnd - chapterStart });
      await fileIo.close(file.fd);
      
      const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
      return decoder.decodeToString(new Uint8Array(buffer), { stream: false });
    } catch (error) {
      Logger.error(FileParser.TAG, `读取TXT章节失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  static async parseEpubFile(_filePath: string, _bookId: string): Promise<Chapter[]> {
    Logger.warn(FileParser.TAG, 'EPUB解析功能尚未实现');
    return [];
  }

  /**
   * 创建本地书籍
   */
  static createLocalBook(filePath: string, fileName: string): Book {
    const bookId = IdGenerator.generateUUID();
    const ext = fileName.split('.').pop()?.toLowerCase() || '';
    
    const book: Book = {
      id: bookId,
      name: fileName.replace(/\.[^/.]+$/, ''),
      author: '本地文件',
      cover: undefined,
      intro: `从本地文件导入 (${ext.toUpperCase()})`,
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookSourceId: 'local',
      bookSourceName: '本地文件',
      bookUrl: filePath,
      lastUpdateTime: Date.now(),
      addTime: Date.now(),
      readProgress: 0,
      lastReadChapter: undefined,
      lastReadChapterIndex: undefined
    };
    return book;
  }
}
