import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { IdGenerator } from './IdGenerator';

/**
 * 文件解析器 - 支持本地文件解析
 */
export class FileParser {
  /**
   * 解析TXT文件
   */
  static async parseTxtFile(filePath: string, bookId: string): Promise<Chapter[]> {
    try {
      const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(filePath);
      const buffer = new ArrayBuffer(stat.size);
      await fileIo.read(file.fd, buffer);
      await fileIo.close(file.fd);
      
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const content = decoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
      
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
      console.error('Failed to parse TXT file:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 从TXT文件读取章节内容
   */
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
      
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
    } catch (error) {
      console.error('Failed to read chapter from TXT:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 解析EPUB文件（简化版）
   */
  static async parseEpubFile(filePath: string, bookId: string): Promise<Chapter[]> {
    // TODO: 实现EPUB解析
    // EPUB是一个ZIP压缩包，包含HTML文件
    // 需要使用ZIP解压库和HTML解析器
    
    console.log('EPUB parsing not fully implemented yet');
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
      lastReadChapter: undefined
    };
    return book;
  }
}
