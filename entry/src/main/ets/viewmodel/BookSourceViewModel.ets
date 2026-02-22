/**
 * BookSourceViewModel - 书源视图模型
 * 负责管理书源相关的业务逻辑和状态
 * 所有数据操作委托给 BookSourceManager
 */

import { BookSource, SearchRule, ChapterRule, ContentRule } from '../models/BookSource';
import { PagedBookSourcesResult } from '../utils/database/BookSourceRepository';
import BookSourceManagerInstance, { SearchBooksResult, BookSourceManager } from '../utils/BookSourceManager';
import { Logger } from '../utils/Logger';
import { SecurityScanResult, SecurityRiskLevel } from '../utils/SourceSandbox';
import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';

export interface ImportResult {
  success: boolean;
  message: string;
  count?: number;
}

export interface ExportResult {
  success: boolean;
  message: string;
  filePath?: string;
  count?: number;
}

export interface DeleteResult {
  success: boolean;
  message: string;
  count?: number;
}

export interface SearchRuleRaw {
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
  nextUrl?: string;
}

export interface FindRuleRaw {
  url: string;
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
}

export interface ChapterRuleRaw {
  chapterList: string;
  chapterName: string;
  chapterUrl: string;
  nextUrl?: string;
}

export interface ContentRuleRaw {
  content: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

export interface AstroReadSearchRule {
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
  nextUrl?: string;
}

export interface AstroReadExploreRule {
  url: string;
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
}

export interface AstroReadTocRule {
  chapterList: string;
  chapterName: string;
  chapterUrl: string;
  nextUrl?: string;
}

export interface AstroReadContentRule {
  content: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

export interface BookSourceRawData {
  id?: string;
  name?: string;
  url?: string;
  baseUrl?: string;
  enabled?: boolean;
  header?: string;
  headers?: string;
  searchUrl?: string;
  search?: string;
  searchRule?: SearchRuleRaw;
  findRule?: FindRuleRaw;
  chapterRule?: ChapterRuleRaw;
  contentRule?: ContentRuleRaw;
  ruleType?: string;
  sort?: number;
  lastUpdateTime?: number;
  addTime?: number;
  bookSourceName?: string;
  bookSourceUrl?: string;
  ruleSearch?: AstroReadSearchRule;
  ruleExplore?: AstroReadExploreRule;
  exploreUrl?: string;
  ruleToc?: AstroReadTocRule;
  ruleContent?: AstroReadContentRule;
  customOrder?: number;
}

interface ValidationResult {
  source: BookSource;
  isAvailable: boolean;
  responseTime: number;
  error?: string;
}

export class BookSourceViewModel {
  private static instance: BookSourceViewModel | null = null;
  private bookSources: BookSource[] = [];
  private manager: BookSourceManager = BookSourceManagerInstance;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): BookSourceViewModel {
    if (!BookSourceViewModel.instance) {
      BookSourceViewModel.instance = new BookSourceViewModel();
    }
    return BookSourceViewModel.instance;
  }

  async loadSources(): Promise<BookSource[]> {
    return await this.loadAllBookSources();
  }

  private constructor() {
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.manager.setContext(context);
  }

  async loadEnabledBookSources(): Promise<BookSource[]> {
    try {
      this.bookSources = await this.manager.loadEnabledBookSources();
      return this.bookSources;
    } catch (error) {
      Logger.error('BookSourceViewModel', '加载启用的书源失败');
      throw new Error('加载书源失败');
    }
  }

  async loadAllBookSources(): Promise<BookSource[]> {
    try {
      this.bookSources = await this.manager.loadAllBookSources();
      return this.bookSources;
    } catch (error) {
      Logger.error('BookSourceViewModel', '加载所有书源失败');
      throw new Error('加载书源失败');
    }
  }

  async loadBookSourcesPaged(page: number, pageSize: number): Promise<PagedBookSourcesResult> {
    return await this.manager.getBookSourcesPaged(page, pageSize);
  }

  async getBookSourcesCount(): Promise<number> {
    return await this.manager.getBookSourcesCount();
  }

  async getBookSourceById(id: string): Promise<BookSource | null> {
    return await this.manager.getBookSourceById(id);
  }

  async upsertBookSource(bookSource: BookSource): Promise<void> {
    try {
      if (!bookSource.id || bookSource.id.trim() === '') {
        bookSource.id = util.generateRandomUUID(true);
      }
      this.validateBookSourceData(bookSource);
      await this.manager.upsertBookSource(bookSource);
      await this.loadEnabledBookSources();
    } catch (error) {
      Logger.error('BookSourceViewModel', '添加或更新书源失败');
      throw new Error('添加或更新书源失败');
    }
  }

  async toggleBookSource(id: string, enabled: boolean): Promise<void> {
    await this.manager.toggleBookSource(id, enabled);
    await this.loadEnabledBookSources();
  }

  async batchUpdateBookSourcesStatus(ids: string[], enabled: boolean): Promise<DeleteResult> {
    const result = await this.manager.batchUpdateBookSourcesStatus(ids, enabled);
    await this.loadEnabledBookSources();
    return result as DeleteResult;
  }

  async importBookSources(sources: BookSource[]): Promise<void> {
    try {
      if (!sources || !Array.isArray(sources)) {
        throw new Error('无效的书源数据');
      }
      if (sources.length > 1000) {
        throw new Error('一次最多导入1000个书源');
      }
      for (const source of sources) {
        this.validateBookSourceData(source);
      }
      await this.manager.batchUpsertBookSources(sources);
      await this.loadEnabledBookSources();
    } catch (error) {
      Logger.error('BookSourceViewModel', '导入书源失败');
      throw new Error('导入书源失败');
    }
  }

  async batchUpsertBookSources(sources: BookSource[]): Promise<void> {
    try {
      if (sources.length === 0) return;
      for (const source of sources) {
        this.validateBookSourceData(source);
      }
      await this.manager.batchUpsertBookSources(sources);
      Logger.info('BookSourceViewModel', `成功添加/更新${sources.length}个书源`);
    } catch (error) {
      Logger.error('BookSourceViewModel', '批量添加/更新书源失败');
      throw new Error('批量添加/更新书源失败');
    }
  }

  async batchDeleteBookSources(ids: string[]): Promise<DeleteResult> {
    try {
      if (!ids || !Array.isArray(ids) || ids.length === 0) {
        throw new Error('无效的删除请求');
      }
      if (ids.length > 100) {
        throw new Error('一次最多删除100个书源');
      }
      for (const id of ids) {
        if (!this.isValidUUID(id)) {
          throw new Error('无效的书源ID');
        }
      }
      await this.manager.removeSources(ids);
      await this.loadEnabledBookSources();
      return {
        success: true,
        message: `成功删除 ${ids.length} 个书源`,
        count: ids.length
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : '未知错误';
      Logger.error('BookSourceViewModel', `批量删除书源失败: ${errorMsg}`);
      return { success: false, message: errorMsg };
    }
  }

  async testBookSource(bookSource: BookSource): Promise<boolean> {
    return await this.manager.testBookSource(bookSource);
  }

  async deleteBookSource(id: string): Promise<DeleteResult> {
    return await this.batchDeleteBookSources([id]);
  }

  async importBookSource(input: string, format?: string, skipSafetyCheck: boolean = false): Promise<ImportResult> {
    const result = await this.manager.importBookSource(input, format, skipSafetyCheck);
    await this.loadEnabledBookSources();
    return result as ImportResult;
  }

  async validateBookSources(sources: BookSource[]): Promise<ValidationResult[]> {
    return await this.manager.validateBookSources(sources) as ValidationResult[];
  }

  detectSourceFormat(content: string): string {
    return this.manager.detectSourceFormat(content);
  }

  scanSourceSecurity(content: string): SecurityScanResult {
    return this.manager.scanSourceSecurity(content);
  }

  scanBookSourceSecurity(source: BookSource): SecurityScanResult {
    return this.manager.scanBookSourceSecurity(source);
  }

  scanSourcesSecurityBatch(sources: BookSource[]): Map<string, SecurityScanResult> {
    return this.manager.scanSourcesSecurityBatch(sources);
  }

  getSecurityRiskLevelText(level: SecurityRiskLevel): string {
    return this.manager.getSecurityRiskLevelText(level);
  }

  getSecurityRiskLevelColor(level: SecurityRiskLevel): string {
    return this.manager.getSecurityRiskLevelColor(level);
  }

  async exportBookSources(fileName: string = 'book_sources.json'): Promise<ExportResult> {
    const result = await this.manager.exportBookSources(fileName);
    return result as ExportResult;
  }

  private validateBookSourceData(source: BookSource): void {
    if (!source.name || source.name.trim().length === 0) {
      throw new Error('书源名称不能为空');
    }
    if (!source.url || source.url.trim().length === 0) {
      throw new Error('书源URL不能为空');
    }
    if (source.name.length > 100) {
      throw new Error('书源名称长度不能超过100个字符');
    }
    if (source.url.length > 2048) {
      throw new Error('书源URL长度不能超过2048个字符');
    }
    if (!this.isValidUrl(source.url)) {
      throw new Error('书源URL格式无效');
    }
  }

  private isValidUUID(id: string): boolean {
    if (!id || typeof id !== 'string') return false;
    const trimmedId = id.trim();
    if (trimmedId.length === 0) return false;

    const standardUUIDPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (standardUUIDPattern.test(trimmedId)) return true;

    const customIdPattern = /^[a-zA-Z0-9][a-zA-Z0-9_-]{7,63}$/;
    if (customIdPattern.test(trimmedId)) return true;

    const legacyPattern = /^[a-zA-Z0-9_\-:.@]{8,64}$/;
    if (legacyPattern.test(trimmedId)) return true;

    return false;
  }

  private isValidUrl(url: string): boolean {
    try {
      if (!url || url.length > 2048) return false;
      const urlPattern = /^https?:\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:\d{1,5})?(\/[a-zA-Z0-9-._~:/?#[\]@!$&'()*+,;=]*)?$/;
      return urlPattern.test(url);
    } catch {
      return false;
    }
  }
}

export default BookSourceViewModel.getInstance();
