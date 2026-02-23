/**
 * BookSourceManager - 书源管理器
 * 集成解析、搜索、调试功能
 * 支持 yck.email 等第三方书源格式
 */

import { BookSource, BookSourceBuilder } from '../../models/BookSource';
import { Book } from '../../models/Book';
import BookSourceParser, { BookSourceParser as BookSourceParserClass } from '../parser/BookSourceParser';
import { BookSourceSearchEngine } from '../search/BookSourceSearchEngine';
import { 
  ISearchEngine, 
  SearchOptions, 
  SearchResult,
  SearchEngineConfig 
} from '../../core/interfaces/ISearchEngine';
import { BookSourceDebugger } from './BookSourceDebugger';
import { Logger } from '../performance/Logger';
import { http } from '@kit.NetworkKit';

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

interface SourceValidationResult {
  valid: boolean;
  errors: string[];
}

export class BookSourceManager {
  private static instance: BookSourceManager | null = null;
  private parser: BookSourceParserClass;
  private searchEngine: ISearchEngine;
  private debuggerInstance: BookSourceDebugger;
  private sources: BookSource[] = [];
  private readonly TAG = 'BookSourceManager';

  private constructor(searchEngine?: ISearchEngine) {
    this.parser = BookSourceParser;
    // 通过依赖注入传入搜索引擎，或默认使用 BookSourceSearchEngine
    this.searchEngine = searchEngine || BookSourceSearchEngine.getInstance();
    this.debuggerInstance = BookSourceDebugger.getInstance();
  }

  /**
   * 设置搜索引擎（用于依赖注入）
   * @param searchEngine 搜索引擎实例
   */
  setSearchEngine(searchEngine: ISearchEngine): void {
    this.searchEngine = searchEngine;
  }

  /**
   * 获取当前搜索引擎
   */
  getSearchEngine(): ISearchEngine {
    return this.searchEngine;
  }

  static getInstance(): BookSourceManager {
    if (!BookSourceManager.instance) {
      BookSourceManager.instance = new BookSourceManager();
    }
    return BookSourceManager.instance;
  }

  /**
   * 使用指定的搜索引擎获取实例（用于依赖注入）
   * @param searchEngine 搜索引擎实例
   */
  static getInstanceWithEngine(searchEngine: ISearchEngine): BookSourceManager {
    if (!BookSourceManager.instance) {
      BookSourceManager.instance = new BookSourceManager(searchEngine);
    } else {
      BookSourceManager.instance.setSearchEngine(searchEngine);
    }
    return BookSourceManager.instance;
  }

  /**
   * 重置实例（主要用于测试）
   */
  static resetInstance(): void {
    BookSourceManager.instance = null;
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
        const builder = new BookSourceBuilder(
          this.generateId(),
          data.bookSourceName || '未命名书源',
          data.bookSourceUrl || ''
        );

        builder.setSearchUrl(data.searchUrl || '')
          .setRuleType('xpath')
          .setEnabled(true);

        if (data.header) {
          builder.setHeader(data.header);
        }

        if (data.ruleSearch) {
          builder.setSearchRule({
            bookList: data.ruleSearch.bookList || '',
            name: data.ruleSearch.name || '',
            author: data.ruleSearch.author || '',
            cover: data.ruleSearch.coverUrl,
            intro: data.ruleSearch.introduce,
            bookUrl: data.ruleSearch.bookUrl || '',
            nextUrl: undefined
          });
        }

        if (data.ruleToc) {
          builder.setTocRule({
            chapterList: data.ruleToc.chapterList || '',
            chapterName: data.ruleToc.chapterName || '',
            chapterUrl: data.ruleToc.chapterUrl || '',
            nextUrl: data.ruleToc.nextTocUrl
          });
        }

        if (data.ruleContent) {
          builder.setContentRule({
            content: data.ruleContent.content || '',
            nextUrl: data.ruleContent.nextContentUrl,
            prevUrl: undefined,
            replaceRule: undefined
          });
        }

        sources.push(builder.build());
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
    const validation = this.validateSource(source);
    if (!validation.valid) {
      Logger.warn(this.TAG, `书源验证失败: ${validation.errors.join(', ')}`);
      return;
    }
    this.sources.push(source);
  }

  addSources(sources: BookSource[]): number {
    let addedCount = 0;
    for (const source of sources) {
      const validation = this.validateSource(source);
      if (validation.valid) {
        this.sources.push(source);
        addedCount++;
      } else {
        Logger.warn(this.TAG, `书源 "${source.name || '未命名'}" 验证失败: ${validation.errors.join(', ')}`);
      }
    }
    return addedCount;
  }

  private validateSource(source: BookSource): SourceValidationResult {
    const errors: string[] = [];

    if (!source.name || source.name.trim().length === 0) {
      errors.push('书源名称不能为空');
    }

    if (!source.url || source.url.trim().length === 0) {
      errors.push('书源URL不能为空');
    } else {
      if (!source.url.startsWith('http://') && !source.url.startsWith('https://')) {
        errors.push('书源URL格式无效');
      }
    }

    if (!source.legacy.searchUrl || source.legacy.searchUrl.trim().length === 0) {
      errors.push('搜索URL不能为空');
    }

    if (!source.rules.searchRule) {
      errors.push('搜索规则不能为空');
    } else {
      if (!source.rules.searchRule.bookList || source.rules.searchRule.bookList.trim().length === 0) {
        errors.push('搜索规则bookList不能为空');
      }
      if (!source.rules.searchRule.name || source.rules.searchRule.name.trim().length === 0) {
        errors.push('搜索规则name不能为空');
      }
    }

    if (!source.rules.tocRule) {
      errors.push('章节规则不能为空');
    } else {
      if (!source.rules.tocRule.chapterList || source.rules.tocRule.chapterList.trim().length === 0) {
        errors.push('章节规则chapterList不能为空');
      }
    }

    if (!source.rules.contentRule) {
      errors.push('内容规则不能为空');
    } else {
      if (!source.rules.contentRule.content || source.rules.contentRule.content.trim().length === 0) {
        errors.push('内容规则content不能为空');
      }
    }

    return {
      valid: errors.length === 0,
      errors
    };
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
    return this.sources.filter((s: BookSource) => s.metadata.enabled);
  }

  /**
   * 删除书源
   */
  removeSource(id: string): void {
    this.sources = this.sources.filter((s: BookSource) => s.id !== id);
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

    const results: SearchResult[] = await this.searchEngine.search(enabledSources, searchOptions);
    const books: Book[] = this.searchEngine.aggregateResults(results);

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
   * 验证书源（通过调试器）
   */
  validateSourceWithDebugger(source: BookSource) {
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
      yck.searchUrl = s.legacy.searchUrl || '';
      yck.ruleSearch = {
        bookList: s.rules.searchRule?.bookList,
        name: s.rules.searchRule?.name,
        author: s.rules.searchRule?.author,
        coverUrl: s.rules.searchRule?.cover,
        introduce: s.rules.searchRule?.intro,
        bookUrl: s.rules.searchRule?.bookUrl
      };
      yck.ruleToc = {
        chapterList: s.rules.tocRule?.chapterList,
        chapterName: s.rules.tocRule?.chapterName,
        chapterUrl: s.rules.tocRule?.chapterUrl
      };
      yck.ruleContent = {
        content: s.rules.contentRule?.content,
        nextContentUrl: s.rules.contentRule?.nextUrl
      };
      yck.header = s.networkConfig?.header;
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