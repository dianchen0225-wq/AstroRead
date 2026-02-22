/**
 * BookSourceManager - 书源管理器
 * 集成解析、搜索、调试功能
 * 支持 yck.email 等第三方书源格式
 * 作为书源数据的唯一可信源
 */

import { BookSource, SearchRule, ChapterRule, ContentRule } from '../models/BookSource';
import { Book } from '../models/Book';
import BookSourceParser, { BookSourceParser as BookSourceParserClass } from './BookSourceParser';
import { BookSourceSearchEngine, SearchOptions, SearchResult } from './BookSourceSearchEngine';
import { BookSourceDebugger } from './BookSourceDebugger';
import { Logger } from './Logger';
import http from '@ohos.net.http';
import { databaseManager } from './DatabaseManager';
import { enhancedSourceHealthManager } from './EnhancedSourceHealthManager';
import { NetworkManager } from './NetworkManager';
import SourceImportManager from './SourceImportManager';
import SourceValidator from './SourceValidator';
import SourceSandbox, { SecurityScanResult, SecurityRiskLevel } from './SourceSandbox';
import { PagedBookSourcesResult } from './database/BookSourceRepository';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import fileio from '@ohos.fileio';
import { util } from '@kit.ArkTS';

export interface YCKRuleSearch {
  bookList?: string;
  name?: string;
  author?: string;
  coverUrl?: string;
  introduce?: string;
  bookUrl?: string;
}

export interface YCKRuleToc {
  chapterList?: string;
  chapterName?: string;
  chapterUrl?: string;
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
  ruleToc?: YCKRuleToc;
  ruleContent?: YCKRuleContent;
  header?: string = '';
}

export interface BatchUpdateResult {
  success: boolean;
  message: string;
  count?: number;
}

export interface ImportResult {
  success: boolean;
  message: string;
  count?: number;
}

export interface ValidateResultItem {
  source: BookSource;
  isAvailable: boolean;
  responseTime: number;
  error?: string;
}

export interface ExportResult {
  success: boolean;
  message: string;
  filePath?: string;
  count?: number;
}

export interface ExportBookSourceData {
  bookSourceName: string;
  bookSourceUrl: string;
  ruleSearch: SearchRule;
  ruleToc: ChapterRule;
  ruleContent: ContentRule;
  ruleType: string;
  enabled: boolean;
  customOrder: number;
}

export class BookSourceManager {
  private static instance: BookSourceManager | null = null;
  private parser: BookSourceParserClass;
  private searchEngine: BookSourceSearchEngine;
  private debuggerInstance: BookSourceDebugger;
  private sources: BookSource[] = [];
  private context: common.UIAbilityContext | null = null;
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

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async loadAllBookSources(): Promise<BookSource[]> {
    try {
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      this.sources = await bookSourceRepository.getAllBookSources();
      return [...this.sources];
    } catch (error) {
      Logger.error(this.TAG, `加载所有书源失败: ${error}`);
      return [];
    }
  }

  async loadEnabledBookSources(): Promise<BookSource[]> {
    try {
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      this.sources = await bookSourceRepository.getAllEnabledBookSources();
      return [...this.sources];
    } catch (error) {
      Logger.error(this.TAG, `加载启用的书源失败: ${error}`);
      return [];
    }
  }

  async getBookSourceById(id: string): Promise<BookSource | null> {
    try {
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      return await bookSourceRepository.getBookSourceById(id);
    } catch (error) {
      Logger.error(this.TAG, `获取书源失败: ${error}`);
      return null;
    }
  }

  async upsertBookSource(source: BookSource): Promise<void> {
    try {
      if (!source.id || source.id.trim() === '') {
        source.id = util.generateRandomUUID(true);
      }
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      await bookSourceRepository.upsertBookSource(source);
      const index = this.sources.findIndex((s: BookSource) => s.id === source.id);
      if (index !== -1) {
        this.sources[index] = source;
      } else {
        this.sources.push(source);
      }
    } catch (error) {
      Logger.error(this.TAG, `添加或更新书源失败: ${error}`);
      throw new Error(`添加或更新书源失败: ${error}`);
    }
  }

  async batchUpsertBookSources(sources: BookSource[]): Promise<void> {
    try {
      for (const source of sources) {
        if (!source.id || source.id.trim() === '') {
          source.id = util.generateRandomUUID(true);
        }
      }
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      await bookSourceRepository.batchUpsertBookSources(sources);
      await this.loadAllBookSources();
    } catch (error) {
      Logger.error(this.TAG, `批量添加/更新书源失败: ${error}`);
      throw new Error(`批量添加/更新书源失败: ${error}`);
    }
  }

  async toggleBookSource(id: string, enabled: boolean): Promise<void> {
    const source = this.sources.find((s: BookSource) => s.id === id);
    if (source) {
      source.enabled = enabled;
      await this.upsertBookSource(source);
    }
  }

  async testBookSource(bookSource: BookSource): Promise<boolean> {
    try {
      if (!bookSource || !bookSource.searchUrl) {
        return false;
      }

      const networkManager = NetworkManager.getInstance();
      if (this.context) {
        networkManager.setContext(this.context);
      }

      const testKeywords = ['斗罗大陆', 'test', 'a'];
      const headers: Map<string, string> | undefined = bookSource.header
        ? this.parseHeadersToMap(bookSource.header)
        : undefined;

      for (const testKeyword of testKeywords) {
        let searchUrl = bookSource.searchUrl
          .replace(/\{\{key\}\}/g, encodeURIComponent(testKeyword))
          .replace(/\{\{page\}\}/g, '1')
          .replace(/\{key\}/g, encodeURIComponent(testKeyword))
          .replace(/\{page\}/g, '1');

        if (!searchUrl.startsWith('http')) continue;

        try {
          const response = await networkManager.get(searchUrl, headers);
          if (response && response.length > 50) {
            return true;
          }
        } catch {
          continue;
        }
      }
      return false;
    } catch (error) {
      Logger.error(this.TAG, `测试书源有效性失败: ${error}`);
      return false;
    }
  }

  private parseHeadersToMap(header: string): Map<string, string> | undefined {
    try {
      const headers = JSON.parse(header) as Record<string, string>;
      const map = new Map<string, string>();
      const keys = Object.keys(headers);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        map.set(key, String(headers[key]));
      }
      return map;
    } catch {
      return undefined;
    }
  }

  /**
   * 导入书源（已废弃，请使用 importBookSource）
   * 内部委托给 importBookSource 实现安全导入
   * @deprecated 请使用 importBookSource 方法获取更详细的导入结果
   */
  async importSources(input: string): Promise<BookSource[]> {
    const result = await this.importBookSource(input);
    if (result.success && result.count && result.count > 0) {
      return this.sources;
    }
    return [];
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
    if (!ids || ids.length === 0) {
      return;
    }

    try {
      // 1. 先从数据库删除，确保数据库操作成功
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      await bookSourceRepository.deleteBookSources(ids);
      
      // 2. 数据库删除成功后，再更新内存缓存
      this.sources = this.sources.filter((s: BookSource) => !ids.includes(s.id));
      
      // 3. 清理健康度管理器中已删除书源的记录
      enhancedSourceHealthManager.removeRecords(ids);
      
      Logger.info(this.TAG, `成功批量删除 ${ids.length} 个书源`);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `批量删除书源失败: ${errorMsg}`);
      // 重新加载书源列表以确保内存和数据库同步
      await this.reloadSources();
      if (error instanceof Error) {
        throw error;
      } else {
        throw new Error(String(error));
      }
    }
  }
  
  /**
   * 重新加载书源列表（用于错误恢复）
   */
  private async reloadSources(): Promise<void> {
    try {
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      this.sources = await bookSourceRepository.getAllBookSources();
      Logger.info(this.TAG, `重新加载了 ${this.sources.length} 个书源`);
    } catch (error) {
      Logger.error(this.TAG, `重新加载书源失败: ${error}`);
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

  /**
   * 分页加载书源
   */
  async getBookSourcesPaged(page: number, pageSize: number): Promise<PagedBookSourcesResult> {
    try {
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      return await bookSourceRepository.getBookSourcesPaged(page, pageSize);
    } catch (error) {
      Logger.error(this.TAG, `分页加载书源失败: ${error}`);
      return { sources: [], total: 0 };
    }
  }

  /**
   * 获取书源总数
   */
  async getBookSourcesCount(): Promise<number> {
    try {
      const bookSourceRepository = databaseManager.getBookSourceRepo();
      return await bookSourceRepository.getBookSourcesCount();
    } catch (error) {
      Logger.error(this.TAG, `获取书源数量失败: ${error}`);
      return 0;
    }
  }

  /**
   * 批量更新书源状态
   */
  async batchUpdateBookSourcesStatus(ids: string[], enabled: boolean): Promise<BatchUpdateResult> {
    try {
      if (!ids || ids.length === 0) {
        const result: BatchUpdateResult = { success: false, message: '没有选择任何书源' };
        return result;
      }

      let updatedCount = 0;
      for (const id of ids) {
        const source = this.sources.find((s: BookSource) => s.id === id);
        if (source) {
          source.enabled = enabled;
          await this.upsertBookSource(source);
          updatedCount++;
        }
      }

      const result: BatchUpdateResult = {
        success: true,
        message: `成功更新 ${updatedCount} 个书源状态`,
        count: updatedCount
      };
      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : '未知错误';
      Logger.error(this.TAG, `批量更新书源状态失败: ${errorMsg}`);
      const result: BatchUpdateResult = { success: false, message: errorMsg };
      return result;
    }
  }

  /**
   * 增强版书源导入功能
   */
  async importBookSource(input: string, format?: string, skipSafetyCheck: boolean = false): Promise<ImportResult> {
    try {
      Logger.info(this.TAG, '开始导入书源');

      if (!input || input.trim().length === 0) {
        throw new Error('书源内容不能为空');
      }

      if (input.length > 10 * 1024 * 1024) {
        throw new Error('书源内容过大，最大支持10MB');
      }

      let content = input.trim();

      if (this.isValidUrl(content)) {
        Logger.debug(this.TAG, '从URL下载书源内容');
        const networkManager = NetworkManager.getInstance();
        if (this.context) {
          networkManager.setContext(this.context);
        }
        content = await networkManager.get(content);
        if (!content || content.trim().length === 0) {
          throw new Error('从URL获取的书源内容为空');
        }
      }

      const result = await SourceImportManager.importSources(content, format, skipSafetyCheck);
      await this.loadAllBookSources();

      const importResult: ImportResult = {
        success: result.success,
        message: result.message,
        count: result.importedCount
      };
      return importResult;
    } catch (error) {
      Logger.error(this.TAG, `导入书源失败: ${error}`);
      const importResult: ImportResult = {
        success: false,
        message: error instanceof Error ? error.message : '导入失败'
      };
      return importResult;
    }
  }

  /**
   * 批量验证书源可用性
   */
  async validateBookSources(sources: BookSource[]): Promise<ValidateResultItem[]> {
    try {
      if (!sources || sources.length === 0) {
        return [];
      }

      if (sources.length > 50) {
        throw new Error('一次最多验证50个书源');
      }

      Logger.info(this.TAG, `开始批量验证${sources.length}个书源`);
      const results = await SourceValidator.validateSourcesBatch(sources);

      for (const result of results) {
        result.source.enabled = result.isAvailable;
        await this.upsertBookSource(result.source);
      }

      Logger.info(this.TAG, '书源验证完成');
      return results;
    } catch (error) {
      Logger.error(this.TAG, `批量验证书源失败: ${error}`);
      return [];
    }
  }

  /**
   * 检测书源格式
   */
  detectSourceFormat(content: string): string {
    return BookSourceParser.detectFormat(content);
  }

  /**
   * 扫描书源安全
   */
  scanSourceSecurity(content: string): SecurityScanResult {
    return SourceSandbox.scanSourceContent(content);
  }

  /**
   * 扫描书源安全
   */
  scanBookSourceSecurity(source: BookSource): SecurityScanResult {
    return SourceSandbox.scanBookSource(source);
  }

  /**
   * 批量扫描书源安全
   */
  scanSourcesSecurityBatch(sources: BookSource[]): Map<string, SecurityScanResult> {
    return SourceSandbox.scanSourcesBatch(sources);
  }

  /**
   * 获取安全风险等级文本
   */
  getSecurityRiskLevelText(level: SecurityRiskLevel): string {
    return SourceSandbox.getRiskLevelText(level);
  }

  /**
   * 获取安全风险等级颜色
   */
  getSecurityRiskLevelColor(level: SecurityRiskLevel): string {
    return SourceSandbox.getRiskLevelColor(level);
  }

  /**
   * 导出书源到文件
   */
  async exportBookSources(fileName: string = 'book_sources.json'): Promise<ExportResult> {
    try {
      if (!this.context) {
        throw new Error('上下文未设置，无法导出文件');
      }

      const allSources = await this.loadAllBookSources();

      if (allSources.length === 0) {
        const result: ExportResult = { success: false, message: '没有可导出的书源' };
        return result;
      }

      const exportData: ExportBookSourceData[] = allSources.map((source: BookSource): ExportBookSourceData => {
        const item: ExportBookSourceData = {
          bookSourceName: source.name,
          bookSourceUrl: source.url,
          ruleSearch: source.searchRule,
          ruleToc: source.chapterRule,
          ruleContent: source.contentRule,
          ruleType: source.ruleType,
          enabled: source.enabled,
          customOrder: source.sort
        };
        return item;
      });

      const filesDir = this.context.filesDir;
      const exportDir = filesDir + '/exports/';

      try {
        await fs.access(exportDir);
      } catch {
        await fs.mkdir(exportDir);
      }

      const filePath = exportDir + fileName;
      const jsonContent = JSON.stringify(exportData, null, 2);

      const fd = await fileio.open(filePath, 0o2 | 0o100);
      await fileio.write(fd, jsonContent);
      await fileio.close(fd);

      const result: ExportResult = {
        success: true,
        message: `导出成功：${allSources.length}个书源`,
        filePath: filePath,
        count: allSources.length
      };
      return result;
    } catch (error) {
      Logger.error(this.TAG, `导出书源失败: ${error}`);
      const result: ExportResult = {
        success: false,
        message: error instanceof Error ? error.message : '导出失败'
      };
      return result;
    }
  }

  private isValidUrl(input: string): boolean {
    try {
      if (!input || input.length > 2048) {
        return false;
      }
      const urlPattern = /^https?:\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:\d{1,5})?(\/[a-zA-Z0-9-._~:/?#[\]@!$&'()*+,;=]*)?$/;
      if (!urlPattern.test(input)) {
        return false;
      }
      return input.startsWith('http://') || input.startsWith('https://');
    } catch {
      return false;
    }
  }
}

export interface SearchBooksResult {
  results: SearchResult[];
  books: Book[];
}

export default BookSourceManager.getInstance();