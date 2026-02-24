import { LocalBook, LocalChapter, TxtParseResult, LocalBookMetadata } from '../models/LocalBook';
import { Logger } from './Logger';
import { IdGenerator } from './IdGenerator';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export class LocalFileParser {
  private static readonly TAG = 'LocalFileParser';
  private static readonly CHAPTER_PATTERNS: string[] = [
    '第[零一二三四五六七八九十百千万0-9]+[章节回集卷部篇][\\s\\S]{0,20}',
    'Chapter\\s*[0-9]+[\\s\\S]{0,20}',
    '[0-9]+[\\.、][\\s\\S]{0,30}',
    '【[\\s\\S]{1,20}】'
  ];

  static async parseTxtFile(filePath: string, context: common.UIAbilityContext): Promise<TxtParseResult> {
    Logger.info(LocalFileParser.TAG, `解析TXT文件: ${filePath}`);
    
    try {
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      
      const buffer = new ArrayBuffer(fileSize);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      
      let content: string;
      try {
        const decoder = new util.TextDecoder('utf-8');
        content = decoder.decodeToString(new Uint8Array(buffer));
      } catch (e) {
        const decoder = new util.TextDecoder('gbk');
        content = decoder.decodeToString(new Uint8Array(buffer));
      }
      
      const fileName = filePath.split('/').pop() || '未知书籍';
      const bookName = fileName.replace(/\.txt$/i, '');
      
      const chapters = this.splitIntoChapters(content, bookName);
      
      const book: LocalBook = {
        id: IdGenerator.generateUUID(),
        name: bookName,
        author: '本地导入',
        filePath: filePath,
        fileType: 'txt',
        fileSize: fileSize,
        bookSourceId: 'local',
        bookSourceName: '本地文件',
        bookUrl: filePath,
        addTime: Date.now(),
        lastUpdateTime: Date.now(),
        readProgress: 0
      };
      
      Logger.info(LocalFileParser.TAG, `解析完成，共 ${chapters.length} 章`);
      
      return { book, chapters };
    } catch (error) {
      Logger.error(LocalFileParser.TAG, `解析TXT失败: ${error}`);
      throw new Error(`解析TXT文件失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private static splitIntoChapters(content: string, bookName: string): LocalChapter[] {
    const chapters: LocalChapter[] = [];
    
    for (const pattern of this.CHAPTER_PATTERNS) {
      try {
        const regex = new RegExp(`^${pattern}$`, 'gm');
        const matches = content.match(regex);
        
        if (matches && matches.length >= 3) {
          Logger.info(LocalFileParser.TAG, `使用章节模式: ${pattern}, 匹配到 ${matches.length} 章`);
          
          let lastIndex = 0;
          const chapterPositions: { title: string; startIndex: number }[] = [];
          
          let match;
          const globalRegex = new RegExp(`^${pattern}$`, 'gm');
          while ((match = globalRegex.exec(content)) !== null) {
            chapterPositions.push({
              title: match[0].trim(),
              startIndex: match.index
            });
          }
          
          for (let i = 0; i < chapterPositions.length; i++) {
            const current = chapterPositions[i];
            const next = chapterPositions[i + 1];
            const endIndex = next ? next.startIndex : content.length;
            
            const chapterContent = content.substring(current.startIndex, endIndex).trim();
            
            chapters.push({
              id: IdGenerator.generateUUID(),
              bookId: '',
              title: current.title,
              url: `local://${current.startIndex}`,
              order: i,
              isVip: false,
              startIndex: current.startIndex,
              endIndex: endIndex,
              content: chapterContent
            });
          }
          
          break;
        }
      } catch (e) {
        Logger.warn(LocalFileParser.TAG, `章节模式匹配失败: ${pattern}`);
      }
    }
    
    if (chapters.length === 0) {
      Logger.info(LocalFileParser.TAG, '未检测到章节，创建单章节');
      const chunkSize = 50000;
      const totalChunks = Math.ceil(content.length / chunkSize);
      
      for (let i = 0; i < totalChunks; i++) {
        const startIndex = i * chunkSize;
        const endIndex = Math.min((i + 1) * chunkSize, content.length);
        const chunkContent = content.substring(startIndex, endIndex);
        
        chapters.push({
          id: IdGenerator.generateUUID(),
          bookId: '',
          title: i === 0 ? bookName : `${bookName} (${i + 1})`,
          url: `local://${startIndex}`,
          order: i,
          isVip: false,
          startIndex: startIndex,
          endIndex: endIndex,
          content: chunkContent
        });
      }
    }
    
    return chapters;
  }

  static async getFileList(context: common.UIAbilityContext, extension: string): Promise<string[]> {
    const files: string[] = [];
    
    try {
      const downloadPath = context.filesDir + '/Download';
      const documentsPath = context.filesDir + '/Documents';
      
      const paths = [downloadPath, documentsPath];
      
      for (const path of paths) {
        try {
          const dirFiles = fs.listFileSync(path);
          for (const file of dirFiles) {
            if (file.toLowerCase().endsWith(extension.toLowerCase())) {
              files.push(`${path}/${file}`);
            }
          }
        } catch (e) {
          Logger.warn(LocalFileParser.TAG, `无法访问目录: ${path}`);
        }
      }
    } catch (error) {
      Logger.error(LocalFileParser.TAG, `获取文件列表失败: ${error}`);
    }
    
    return files;
  }

  static async scanLocalBooks(context: common.UIAbilityContext): Promise<string[]> {
    const txtFiles = await this.getFileList(context, '.txt');
    const epubFiles = await this.getFileList(context, '.epub');
    return [...txtFiles, ...epubFiles];
  }
}

