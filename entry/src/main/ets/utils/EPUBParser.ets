/**
 * EPUBParser - EPUB 电子书解析器
 * EPUB 本质是 ZIP + HTML，使用 @ohos.file.fs 和 @ohos.zlib 解压后解析
 */
import zlib from '@ohos.zlib';
import { Logger } from './Logger';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { EntityDecoder } from '../core/utils/EntityDecoder';

export interface EPUBMetadata {
  title: string;
  author: string;
  description?: string;
  cover?: string;
  language?: string;
  publisher?: string;
  publishDate?: string;
}

export interface EPUBChapter {
  id: string;
  title: string;
  href: string;
  content?: string;
  order: number;
}

export interface EPUBResource {
  id: string;
  href: string;
  mediaType: string;
}

export interface EPUBBook {
  metadata: EPUBMetadata;
  chapters: EPUBChapter[];
  spine: string[];
  manifest: Map<string, EPUBResource>;
  basePath: string;
  tocPath?: string;
}

export class EPUBParser {
  private static instance: EPUBParser | null = null;
  private readonly TAG = 'EPUBParser';
  private opfDir: string = '';

  static getInstance(): EPUBParser {
    if (!EPUBParser.instance) {
      EPUBParser.instance = new EPUBParser();
    }
    return EPUBParser.instance;
  }

  async parse(epubPath: string, extractPath: string): Promise<EPUBBook> {
    try {
      Logger.info(this.TAG, `开始解析 EPUB: ${epubPath}`);

      await this.extractEPUB(epubPath, extractPath);

      const opfPath = await this.findOPFPath(extractPath);
      this.opfDir = opfPath.substring(0, opfPath.lastIndexOf('/'));

      const book = await this.parseOPF(opfPath, extractPath);

      if (book.tocPath) {
        const tocFullPath = this.resolvePath(this.opfDir, book.tocPath);
        book.chapters = await this.parseTOC(tocFullPath, book.spine);
      }

      for (const chapter of book.chapters) {
        const contentPath = this.resolvePath(this.opfDir, chapter.href);
        chapter.content = await this.readChapterContent(contentPath);
      }

      Logger.info(this.TAG, `EPUB 解析完成: ${book.metadata.title}, ${book.chapters.length} 章`);
      return book;
    } catch (error) {
      Logger.error(this.TAG, `解析 EPUB 失败: ${error}`);
      throw new Error(`解析 EPUB 失败: ${error}`);
    }
  }

  private async extractEPUB(epubPath: string, extractPath: string): Promise<void> {
    try {
      const options: zlib.Options = {
        level: zlib.CompressLevel.COMPRESS_LEVEL_BEST_SPEED,
        memLevel: zlib.MemLevel.MEM_LEVEL_DEFAULT,
        strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY
      };

      await zlib.decompressFile(epubPath, extractPath, options);
      Logger.info(this.TAG, `EPUB 解压成功: ${extractPath}`);
    } catch (error) {
      Logger.error(this.TAG, `解压 EPUB 失败: ${error}`);
      throw new Error(`解压 EPUB 失败: ${error}`);
    }
  }

  private async findOPFPath(extractPath: string): Promise<string> {
    try {
      const containerPath = `${extractPath}/META-INF/container.xml`;
      const containerContent = await this.readFileContent(containerPath);

      const rootfileMatch = containerContent.match(/rootfile[^>]*full-path=["']([^"']+)["']/i);
      if (rootfileMatch && rootfileMatch[1]) {
        return `${extractPath}/${rootfileMatch[1]}`;
      }
    } catch (error) {
      Logger.warn(this.TAG, `解析 container.xml 失败，尝试默认路径`);
    }

    const defaultPaths = [
      `${extractPath}/OEBPS/content.opf`,
      `${extractPath}/OPS/content.opf`,
      `${extractPath}/content.opf`,
      `${extractPath}/OEBPS/package.opf`,
      `${extractPath}/package.opf`
    ];

    for (const path of defaultPaths) {
      if (this.fileExists(path)) {
        return path;
      }
    }

    throw new Error('未找到 OPF 文件');
  }

  private async parseOPF(opfPath: string, basePath: string): Promise<EPUBBook> {
    const book: EPUBBook = {
      metadata: {
        title: '未知书名',
        author: '未知作者'
      },
      chapters: [],
      spine: [],
      manifest: new Map<string, EPUBResource>(),
      basePath: basePath
    };

    try {
      const opfContent = await this.readFileContent(opfPath);

      book.metadata.title = this.extractXMLValue(opfContent, 'dc:title') || '未知书名';
      book.metadata.author = this.extractXMLValue(opfContent, 'dc:creator') || '未知作者';
      book.metadata.description = this.extractXMLValue(opfContent, 'dc:description');
      book.metadata.language = this.extractXMLValue(opfContent, 'dc:language');
      book.metadata.publisher = this.extractXMLValue(opfContent, 'dc:publisher');
      book.metadata.publishDate = this.extractXMLValue(opfContent, 'dc:date');
      const manifestRegex = /<item[^>]*id=["']([^"']+)["'][^>]*href=["']([^"']+)["'][^>]*media-type=["']([^"']+)["'][^>]*\/>/gi;
      let manifestMatch: RegExpExecArray | null;
      while ((manifestMatch = manifestRegex.exec(opfContent)) !== null) {
        const resource: EPUBResource = {
          id: manifestMatch[1],
          href: manifestMatch[2],
          mediaType: manifestMatch[3]
        };
        book.manifest.set(resource.id, resource);

        if (resource.mediaType.startsWith('image/') && !book.metadata.cover) {
          const coverIdMatch: RegExpMatchArray | null = opfContent.match(/<meta[^>]*name=["']cover["'][^>]*content=["']([^"']+)["']/i);
          if (coverIdMatch && coverIdMatch[1] === resource.id) {
            book.metadata.cover = resource.href;
          }
        }
      }
      const spineRegex = /<itemref[^>]*idref=["']([^"']+)["'][^>]*\/>/gi;
      let spineMatch: RegExpExecArray | null;
      while ((spineMatch = spineRegex.exec(opfContent)) !== null) {
        book.spine.push(spineMatch[1]);
      }
      const tocMatch: RegExpMatchArray | null = opfContent.match(/<spine[^>]*toc=["']([^"']+)["']/i);
      if (tocMatch && tocMatch[1]) {
        const tocResource = book.manifest.get(tocMatch[1]);
        if (tocResource) {
          book.tocPath = tocResource.href;
        }
      }

      Logger.debug(this.TAG, `OPF 解析完成: ${book.metadata.title}`);
    } catch (error) {
      Logger.error(this.TAG, `解析 OPF 失败: ${error}`);
    }

    return book;
  }

  async parseTOC(tocPath: string, spine: string[]): Promise<EPUBChapter[]> {
    const chapters: EPUBChapter[] = [];

    try {
      const tocContent = await this.readFileContent(tocPath);

      if (tocPath.endsWith('.ncx')) {
        const navPointRegex = /<navPoint[^>]*id=["']([^"']+)["'][^>]*playOrder=["']?(\d+)["']?[^>]*>[\s\S]*?<navLabel>[\s\S]*?<text>([^<]*)<\/text>[\s\S]*?<\/navLabel>[\s\S]*?<content[^>]*src=["']([^"']+)["'][^>]*\/>/gi;
        let match: RegExpExecArray | null;
        while ((match = navPointRegex.exec(tocContent)) !== null) {
          chapters.push({
            id: match[1],
            title: EntityDecoder.decode(match[3]),
            href: match[4].split('#')[0],
            order: parseInt(match[2]) || chapters.length
          });
        }
      } else if (tocPath.endsWith('.xhtml') || tocPath.endsWith('.html')) {
        const liRegex = /<li[^>]*>[\s\S]*?<a[^>]*href=["']([^"']+)["'][^>]*>([^<]*)<\/a>[\s\S]*?<\/li>/gi;
        let match: RegExpExecArray | null;
        let order = 0;
        while ((match = liRegex.exec(tocContent)) !== null) {
          chapters.push({
            id: `nav-${order}`,
            title: EntityDecoder.decode(match[2].trim()),
            href: match[1].split('#')[0],
            order: order++
          });
        }
      }

      Logger.debug(this.TAG, `TOC 解析完成: ${chapters.length} 章`);
    } catch (error) {
      Logger.error(this.TAG, `解析目录失败: ${error}`);
    }

    return chapters;
  }

  private async readChapterContent(contentPath: string): Promise<string> {
    try {
      const html = await this.readFileContent(contentPath);
      return this.parseChapterHtml(html);
    } catch (error) {
      Logger.warn(this.TAG, `读取章节失败: ${contentPath}`);
      return '';
    }
  }

  parseChapterHtml(html: string): string {
    let content = html
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
      .replace(/<!--[\s\S]*?-->/g, '');

    const bodyMatch = content.match(/<body[^>]*>([\s\S]*)<\/body>/i);
    if (bodyMatch) {
      content = bodyMatch[1];
    }

    content = EntityDecoder.cleanHtml(content)
      .replace(/\n\s*\n/g, '\n')
      .trim();

    return content;
  }

  private async readFileContent(path: string): Promise<string> {
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const decoder = new util.TextDecoder('utf-8');
      try {
        return decoder.decode(new Uint8Array(buffer));
      } catch (decodeError) {
        throw new Error(`解码文件失败: ${path}`);
      }
    } catch (error) {
      throw new Error(`读取文件失败: ${path}`);
    }
  }

  private fileExists(path: string): boolean {
    try {
      fs.accessSync(path);
      return true;
    } catch {
      return false;
    }
  }

  private extractXMLValue(xml: string, tagName: string): string {
    const regex = new RegExp(`<${tagName}[^>]*>([^<]*)<\/${tagName}>`, 'i');
    const match = xml.match(regex);
    return match ? EntityDecoder.decode(match[1].trim()) : '';
  }

  private resolvePath(base: string, relative: string): string {
    if (!relative) return base;
    if (relative.startsWith('/')) return relative;
    return `${base}/${relative}`;
  }

  getCoverPath(book: EPUBBook): string | undefined {
    if (book.metadata.cover) {
      return this.resolvePath(this.opfDir || book.basePath, book.metadata.cover);
    }
    return undefined;
  }

  getChapterHtml(book: EPUBBook, chapterIndex: number): string {
    if (chapterIndex >= 0 && chapterIndex < book.chapters.length) {
      return book.chapters[chapterIndex].content || '';
    }
    return '';
  }

  getChapterText(book: EPUBBook, chapterIndex: number): string {
    const html = this.getChapterHtml(book, chapterIndex);
    return this.parseChapterHtml(html);
  }

  destroy(): void {
    EPUBParser.instance = null;
  }
}

export default EPUBParser.getInstance();
