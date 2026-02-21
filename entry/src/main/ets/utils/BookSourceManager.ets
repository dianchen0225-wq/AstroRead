/**
 * BookSourceManager - 书源管理器
 * 集成解析、搜索、调试功能
 * 支持 yck.email 等第三方书源格式
 */

import { BookSource } from '../models/BookSource';
import { Book } from '../models/Book';
import BookSourceParser, { BookSourceParser as BookSourceParserClass } from './BookSourceParser';
import { BookSourceSearchEngine, SearchOptions, SearchResult } from './BookSourceSearchEngine';
import { BookSourceDebugger } from './BookSourceDebugger';
import { Logger } from './Logger';
import http from '@ohos.net.http';

type JsonObject = Record<string, string | number | boolean | object | null | undefined>;

export interface YCKRuleSearch {
  bookList?: string;
  name?: string;
  author?: string;
  kind?: string;
  lastChapter?: string;
  introduce?: string;
  coverUrl?: string;
  bookUrl?: string;
}

export interface YCKRuleBookInfo {
  init?: string;
  name?: string;
  author?: string;
  kind?: string;
  lastChapter?: string;
  introduce?: string;
  coverUrl?: string;
  tocUrl?: string;
}

export interface YCKRuleToc {
  chapterList?: string;
  chapterName?: string;
  chapterUrl?: string;
  nextTocUrl?: string;
}

export interface YCKRuleContent {
  content?: string;
  nextContentUrl?: string;
}

export class YCKSourceData {
  bookSourceName: string = '';
  bookSourceUrl: string = '';
  searchUrl: string = '';
  ruleSearch?: YCKRuleSearch;
  ruleBookInfo?: YCKRuleBookInfo;
  ruleToc?: YCKRuleToc;
  ruleContent?: YCKRuleContent;
  header?: string = '';
}

export class BookSourceManager {
  private static instance: BookSourceManager | null = null;
  private parser: BookSourceParserClass;
  private searchEngine: BookSourceSearchEngine;
  private debuggerInstance: BookSourceDebugger;
  private sources: BookSource[] = [];
  private readonly TAG = 'BookSourceManager';
  private constructor() {
    this.parser = BookSourceParser;
    this.searchEngine = BookSourceSearchEngine.getInstance();
    this.debuggerInstance = BookSourceDebugger.getInstance();
  }

  static getInstance(): BookSourceManager {
    if (!BookSourceManager.instance) {
      BookSourceManager.instance = new BookSourceManager();
    }
    return BookSourceManager.instance;
  }

  /**
   * 导入书源
   * 支持 JSON、URL、yck.email 格式
   */
  async importSources(input: string): Promise<BookSource[]> {
    try {
      // 1. 如果是 URL，先获取内容
      if (input.startsWith('http')) {
        const httpRequest = http.createHttp();
        const response = await httpRequest.request(input, {
          method: http.RequestMethod.GET,
          header: {
            'User-Agent': 'Mozilla/5.0'
          }
        });
        input = response.result as string;
        httpRequest.destroy();
      }

      // 2. 尝试解析为 JSON
      let data: JsonObject;
      try {
        data = JSON.parse(input) as JsonObject;
      } catch (e) {
        // 不是 JSON，尝试其他格式
        return this.parser.parseSources(input, 'txt');
      }

      // 3. 判断格式类型
      if (Array.isArray(data)) {
        // 可能是标准格式或 YCK 格式
        const firstItem = (data as JsonObject[])[0];
        if (firstItem && this.isYCKFormat(firstItem)) {
          return this.parseYCKSources(data as YCKSourceData[]);
        }
        return this.parser.parseSources(input, 'json');
      }

      // 单个书源
      if (this.isYCKFormat(data)) {
        return this.parseYCKSources([this.convertToYCKSourceData(data)]);
      }

      return this.parser.parseSources(input, 'json');
    } catch (error) {
      Logger.error(this.TAG, `导入书源失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 判断是否为 YCK 格式
   */
  private isYCKFormat(data: JsonObject): boolean {
    return data !== null && typeof data === 'object' && (
      data.bookSourceName !== undefined ||
      (data.searchUrl !== undefined && data.ruleSearch !== undefined)
    );
  }

  /**
   * 将 JsonObject 转换为 YCKSourceData
   */
  private convertToYCKSourceData(data: JsonObject): YCKSourceData {
    const result = new YCKSourceData();
    result.bookSourceName = (data.bookSourceName as string) || '';
    result.bookSourceUrl = (data.bookSourceUrl as string) || '';
    result.searchUrl = (data.searchUrl as string) || '';
    result.header = (data.header as string) || '';

    if (data.ruleSearch && typeof data.ruleSearch === 'object') {
      const ruleSearch = data.ruleSearch as Record<string, string | number | boolean | object | null | undefined>;
      result.ruleSearch = {
        bookList: ruleSearch.bookList as string | undefined,
        name: ruleSearch.name as string | undefined,
        author: ruleSearch.author as string | undefined,
        kind: ruleSearch.kind as string | undefined,
        lastChapter: ruleSearch.lastChapter as string | undefined,
        introduce: ruleSearch.introduce as string | undefined,
        coverUrl: ruleSearch.coverUrl as string | undefined,
        bookUrl: ruleSearch.bookUrl as string | undefined
      };
    }

    if (data.ruleBookInfo && typeof data.ruleBookInfo === 'object') {
      const ruleBookInfo = data.ruleBookInfo as Record<string, string | number | boolean | object | null | undefined>;
      result.ruleBookInfo = {
        init: ruleBookInfo.init as string | undefined,
        name: ruleBookInfo.name as string | undefined,
        author: ruleBookInfo.author as string | undefined,
        kind: ruleBookInfo.kind as string | undefined,
        lastChapter: ruleBookInfo.lastChapter as string | undefined,
        introduce: ruleBookInfo.introduce as string | undefined,
        coverUrl: ruleBookInfo.coverUrl as string | undefined,
        tocUrl: ruleBookInfo.tocUrl as string | undefined
      };
    }

    if (data.ruleToc && typeof data.ruleToc === 'object') {
      const ruleToc = data.ruleToc as Record<string, string | number | boolean | object | null | undefined>;
      result.ruleToc = {
        chapterList: ruleToc.chapterList as string | undefined,
        chapterName: ruleToc.chapterName as string | undefined,
        chapterUrl: ruleToc.chapterUrl as string | undefined,
        nextTocUrl: ruleToc.nextTocUrl as string | undefined
      };
    }

    if (data.ruleContent && typeof data.ruleContent === 'object') {
      const ruleContent = data.ruleContent as Record<string, string | number | boolean | object | null | undefined>;
      result.ruleContent = {
        content: ruleContent.content as string | undefined,
        nextContentUrl: ruleContent.nextContentUrl as string | undefined
      };
    }

    return result;
  }

  /**
   * 解析 YCK 格式书源
   * https://www.yck.email/yuedu/tools/index/id/shuyuan.html
   */
  private parseYCKSources(yckData: YCKSourceData[]): BookSource[] {
    const sources: BookSource[] = [];

    for (const data of yckData) {
      try {
        const source: BookSource = {
          id: this.generateId(),
          name: data.bookSourceName || '未命名书源',
          url: data.bookSourceUrl || '',
          enabled: true,
          header: data.header || undefined,
          searchUrl: data.searchUrl || '',
          searchRule: {
            bookList: data.ruleSearch?.bookList || '',
            name: data.ruleSearch?.name || '',
            author: data.ruleSearch?.author || '',
            cover: data.ruleSearch?.coverUrl || '',
            intro: data.ruleSearch?.introduce || '',
            bookUrl: data.ruleSearch?.bookUrl || '',
            nextUrl: ''
          },
          findRule: undefined,
          chapterRule: {
            chapterList: data.ruleToc?.chapterList || '',
            chapterName: data.ruleToc?.chapterName || '',
            chapterUrl: data.ruleToc?.chapterUrl || '',
            nextUrl: data.ruleToc?.nextTocUrl || ''
          },
          contentRule: {
            content: data.ruleContent?.content || '',
            nextUrl: data.ruleContent?.nextContentUrl || '',
            prevUrl: undefined,
            replaceRule: undefined
          },
          ruleType: 'xpath',
          sort: 1,
          lastUpdateTime: Date.now(),
          addTime: Date.now()
        };

        sources.push(source);
      } catch (error) {
        Logger.warn(this.TAG, `解析 YCK 书源失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    Logger.info(this.TAG, `成功解析 ${sources.length} 个 YCK 格式书源`);
    return sources;
  }

  /**
   * 生成唯一 ID
   */
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }

  /**
   * 添加书源
   */
  addSource(source: BookSource): void {
    this.sources.push(source);
  }

  /**
   * 批量添加书源
   */
  addSources(sources: BookSource[]): void {
    for (const source of sources) {
      this.sources.push(source);
    }
  }

  /**
   * 获取所有书源
   */
  getAllSources(): BookSource[] {
    return [...this.sources];
  }

  /**
   * 获取启用的书源
   */
  getEnabledSources(): BookSource[] {
    return this.sources.filter((s: BookSource) => s.enabled);
  }

  /**
   * 删除书源
   */
  removeSource(id: string): void {
    this.sources = this.sources.filter((s: BookSource) => s.id !== id);
  }

  /**
   * 批量删除书源
   */
  async removeSources(ids: string[]): Promise<void> {
    // 从内存中移除
    this.sources = this.sources.filter((s: BookSource) => !ids.includes(s.id));
    
    // 从数据库中删除
    try {
      const bookSourceRepository = await BookSourceRepository.getInstance();
      await bookSourceRepository.deleteBookSources(ids);
    } catch (error) {
      Logger.error(this.TAG, `批量删除书源失败: ${error instanceof Error ? error.message : String(error)}`);
      // 如果数据库操作失败，回滚内存中的更改
      throw error;
    }
  }

  /**
   * 更新书源
   */
  updateSource(source: BookSource): void {
    const index = this.sources.findIndex((s: BookSource) => s.id === source.id);
    if (index !== -1) {
      this.sources[index] = source;
    }
  }

  /**
   * 搜索书籍
   */
  async searchBooks(
    keyword: string,
    options: Partial<SearchOptions> = {}
  ): Promise<SearchBooksResult> {
    const enabledSources = this.getEnabledSources();

    const searchOptions: SearchOptions = {
      key: keyword,
      page: options.page ?? 1,
      concurrent: options.concurrent ?? 3,
      interval: options.interval ?? 1000,
      timeout: options.timeout ?? 30000
    };

    const results = await this.searchEngine.search(enabledSources, searchOptions);
    const books = this.searchEngine.aggregateResults(results);

    return { results, books };
  }

  /**
   * 从指定书源搜索
   */
  async searchFromSource(
    sourceId: string,
    keyword: string,
    page: number = 1
  ): Promise<SearchResult> {
    const source = this.sources.find((s: BookSource) => s.id === sourceId);
    if (!source) {
      throw new Error('书源不存在');
    }

    return this.searchEngine.searchSingleSource(source, keyword, page);
  }

  /**
   * 调试书源 - 搜索
   */
  async debugSearch(source: BookSource, keyword: string) {
    return this.debuggerInstance.testSearch(source, keyword);
  }

  /**
   * 调试书源 - 章节列表
   */
  async debugChapters(source: BookSource, bookUrl: string) {
    return this.debuggerInstance.testChapterList(source, bookUrl);
  }

  /**
   * 调试书源 - 正文内容
   */
  async debugContent(source: BookSource, chapterUrl: string) {
    return this.debuggerInstance.testContent(source, chapterUrl);
  }

  /**
   * 验证书源
   */
  validateSource(source: BookSource) {
    return this.debuggerInstance.validateSource(source);
  }

  /**
   * 导出书源为 JSON
   */
  exportSources(sources?: BookSource[]): string {
    const toExport = sources || this.sources;
    return JSON.stringify(toExport, null, 2);
  }

  /**
   * 导出为 YCK 格式
   */
  exportToYCKFormat(sources?: BookSource[]): string {
    const toExport = sources || this.sources;
    const yckData: YCKSourceData[] = toExport.map((s: BookSource) => {
      const yck = new YCKSourceData();
      yck.bookSourceName = s.name;
      yck.bookSourceUrl = s.url;
      yck.searchUrl = s.searchUrl || '';
      yck.ruleSearch = {
        bookList: s.searchRule?.bookList,
        name: s.searchRule?.name,
        author: s.searchRule?.author,
        coverUrl: s.searchRule?.cover,
        introduce: s.searchRule?.intro,
        bookUrl: s.searchRule?.bookUrl
      };
      yck.ruleToc = {
        chapterList: s.chapterRule?.chapterList,
        chapterName: s.chapterRule?.chapterName,
        chapterUrl: s.chapterRule?.chapterUrl
      };
      yck.ruleContent = {
        content: s.contentRule?.content,
        nextContentUrl: s.contentRule?.nextUrl
      };
      yck.header = s.header;
      return yck;
    });

    return JSON.stringify(yckData, null, 2);
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.searchEngine.clearCache();
  }
}

export interface SearchBooksResult {
  results: SearchResult[];
  books: Book[];
}

export default BookSourceManager.getInstance();