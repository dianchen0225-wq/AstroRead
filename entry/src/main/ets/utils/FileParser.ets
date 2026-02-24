import fileIo from '@ohos.file.fs';
import util from '@ohos.util';
import { Book } from '../models/Book';
import { Chapter } from '../models/Book';
import { IdGenerator } from './IdGenerator';
import { Logger } from './Logger';

export class FileParser {
  private static readonly TAG = 'FileParser';
  private static readonly CHUNK_SIZE = 1024 * 1024;
  private static readonly MAX_FILE_SIZE = 100 * 1024 * 1024;

  static async parseTxtFile(filePath: string, bookId: string): Promise<Chapter[]> {
    try {
      const stat = await fileIo.stat(filePath);

      if (stat.size > FileParser.MAX_FILE_SIZE) {
        Logger.warn(FileParser.TAG, `文件过大 (${stat.size} bytes)，将使用流式解析`);
        return FileParser.parseLargeTxtFile(filePath, bookId, stat.size);
      }

      return await FileParser.parseSmallTxtFile(filePath, bookId);
    } catch (error) {
      Logger.error(FileParser.TAG, `解析TXT文件失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  private static async parseSmallTxtFile(filePath: string, bookId: string): Promise<Chapter[]> {
    let file: fileIo.File | null = null;

    try {
      file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(filePath);
      const buffer = new ArrayBuffer(stat.size);
      await fileIo.read(file.fd, buffer);

      const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
      const content = decoder.decodeToString(new Uint8Array(buffer), { stream: false });

      const chapters = FileParser.extractChapters(content, bookId);

      return chapters;
    } finally {
      if (file) {
        try {
          await fileIo.close(file.fd);
        } catch (e) {
          Logger.warn(FileParser.TAG, `关闭文件失败: ${e}`);
        }
      }
    }
  }

  private static async parseLargeTxtFile(filePath: string, bookId: string, fileSize: number): Promise<Chapter[]> {
    let file: fileIo.File | null = null;

    try {
      file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);

      const chapters: Chapter[] = [];
      let order = 0;
      let bufferOffset = 0;
      let remainingContent = '';

      const totalChunks = Math.ceil(fileSize / FileParser.CHUNK_SIZE);

      for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        const currentChunkSize = Math.min(FileParser.CHUNK_SIZE, fileSize - bufferOffset);
        const buffer = new ArrayBuffer(currentChunkSize);

        await fileIo.read(file.fd, buffer, { offset: bufferOffset });
        bufferOffset += currentChunkSize;

        const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
        const chunkContent = decoder.decodeToString(new Uint8Array(buffer), { stream: false });

        const contentToProcess = remainingContent + chunkContent;

        const chapterPattern = /(?:^|\n)(?:第[一二三四五六七八九十百千万\d]+章|第\d+章|Chapter \d+|CHAPTER \d+)[^\n]*/g;
        const matches = Array.from(contentToProcess.matchAll(chapterPattern));

        if (matches.length > 0) {
          const lastMatch = matches[matches.length - 1];
          const lastMatchEnd = (lastMatch.index || 0) + lastMatch[0].length;
          remainingContent = contentToProcess.substring(lastMatchEnd);

          for (const match of matches) {
            const chapterTitle = match[0].trim();

            const chapter: Chapter = {
              id: IdGenerator.generateUUID(),
              bookId: bookId,
              title: chapterTitle,
              url: `local://${bookId}/${order}`,
              order: order++,
              isVip: false
            };
            chapters.push(chapter);
          }
        } else {
          remainingContent = contentToProcess;
        }

        if (remainingContent.length > FileParser.CHUNK_SIZE * 2) {
          remainingContent = remainingContent.substring(remainingContent.length - FileParser.CHUNK_SIZE);
        }

        await FileParser.yieldToMain();
      }

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
    } finally {
      if (file) {
        try {
          await fileIo.close(file.fd);
        } catch (e) {
          Logger.warn(FileParser.TAG, `关闭文件失败: ${e}`);
        }
      }
    }
  }

  private static extractChapters(content: string, bookId: string): Chapter[] {
    const chapterPattern = /(?:^|\n)(?:第[一二三四五六七八九十百千万\d]+章|第\d+章|Chapter \d+|CHAPTER \d+)[^\n]*/g;
    const matches = Array.from(content.matchAll(chapterPattern));

    const chapters: Chapter[] = [];
    let order = 0;

    for (const match of matches) {
      const chapterTitle = match[0].trim();

      const chapter: Chapter = {
        id: IdGenerator.generateUUID(),
        bookId: bookId,
        title: chapterTitle,
        url: `local://${bookId}/${order}`,
        order: order++,
        isVip: false
      };
      chapters.push(chapter);
    }

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
  }

  private static yieldToMain(): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, 0);
    });
  }

  static async readChapterFromTxt(
    filePath: string,
    chapterStart: number,
    chapterEnd: number
  ): Promise<string> {
    let file: fileIo.File | null = null;

    try {
      file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const length = chapterEnd - chapterStart;

      if (length > FileParser.CHUNK_SIZE) {
        return FileParser.readLargeChapter(file.fd, chapterStart, length);
      }

      const buffer = new ArrayBuffer(length);
      await fileIo.read(file.fd, buffer, { offset: chapterStart, length: length });

      const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
      return decoder.decodeToString(new Uint8Array(buffer), { stream: false });
    } catch (error) {
      Logger.error(FileParser.TAG, `读取TXT章节失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    } finally {
      if (file) {
        try {
          await fileIo.close(file.fd);
        } catch (e) {
          Logger.warn(FileParser.TAG, `关闭文件失败: ${e}`);
        }
      }
    }
  }

  private static async readLargeChapter(fd: number, start: number, length: number): Promise<string> {
    const chunks: string[] = [];
    let offset = start;
    let remaining = length;

    while (remaining > 0) {
      const chunkSize = Math.min(FileParser.CHUNK_SIZE, remaining);
      const buffer = new ArrayBuffer(chunkSize);

      await fileIo.read(fd, buffer, { offset: offset, length: chunkSize });

      const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
      chunks.push(decoder.decodeToString(new Uint8Array(buffer), { stream: false }));

      offset += chunkSize;
      remaining -= chunkSize;

      await FileParser.yieldToMain();
    }

    return chunks.join('');
  }

  static async parseEpubFile(_filePath: string, _bookId: string): Promise<Chapter[]> {
    Logger.warn(FileParser.TAG, 'EPUB解析功能尚未实现');
    return [];
  }

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

  static async getFileSize(filePath: string): Promise<number> {
    try {
      const stat = await fileIo.stat(filePath);
      return stat.size;
    } catch (error) {
      Logger.error(FileParser.TAG, `获取文件大小失败: ${error}`);
      return 0;
    }
  }

  static async validateFile(filePath: string): Promise<{ valid: boolean; error?: string }> {
    try {
      const stat = await fileIo.stat(filePath);

      if (stat.size === 0) {
        return { valid: false, error: '文件为空' };
      }

      if (stat.size > FileParser.MAX_FILE_SIZE) {
        return { valid: false, error: `文件过大，最大支持 ${FileParser.MAX_FILE_SIZE / 1024 / 1024}MB` };
      }

      return { valid: true };
    } catch (error) {
      return { valid: false, error: `文件访问失败: ${error}` };
    }
  }
}
