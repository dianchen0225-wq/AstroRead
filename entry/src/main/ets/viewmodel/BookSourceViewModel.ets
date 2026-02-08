import { BookSource, SearchRule, FindRule, ChapterRule, ContentRule } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { NetworkManager } from '../utils/NetworkManager';
import { IdGenerator } from '../utils/IdGenerator';
import SourceImportManager, { ImportResult as EnhancedImportResult } from '../utils/SourceImportManager';
import SourceValidator from '../utils/SourceValidator';
import BookSourceParser from '../utils/BookSourceParser';
import { Logger } from '../utils/Logger';
import fileio from '@ohos.fileio';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

/**
 * 导入结果接口
 */
export interface ImportResult {
  success: boolean;
  message: string;
  count?: number;
}

/**
 * 导出结果接口
 */
export interface ExportResult {
  success: boolean;
  message: string;
  filePath?: string;
  count?: number;
}

/**
 * 删除结果接口
 */
export interface DeleteResult {
  success: boolean;
  message: string;
  count?: number;
}

/**
 * 搜索规则接口
 */
export interface SearchRuleRaw {
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * 发现规则接口
 */
export interface FindRuleRaw {
  url?: string;
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

/**
 * 章节规则接口
 */
export interface ChapterRuleRaw {
  chapterList?: string;
  list?: string;
  chapterName?: string;
  name?: string;
  chapterUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * 内容规则接口
 */
export interface ContentRuleRaw {
  content?: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

/**
 * AstroRead 搜索规则接口
 */
export interface AstroReadSearchRule {
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * AstroRead 发现规则接口
 */
export interface AstroReadExploreRule {
  url?: string;
  bookList?: string;
  list?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

/**
 * AstroRead 章节规则接口
 */
export interface AstroReadTocRule {
  chapterList?: string;
  list?: string;
  chapterName?: string;
  name?: string;
  chapterUrl?: string;
  url?: string;
  nextUrl?: string;
}

/**
 * AstroRead 内容规则接口
 */
export interface AstroReadContentRule {
  content?: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

/**
 * 书源原始数据接口
 */
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
  // AstroRead 格式字段
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

/**
 * 书源视图模型
 * 负责管理书源相关的业务逻辑和状态
 */
export class BookSourceViewModel {
  private bookSources: BookSource[] = [];
  private readonly databaseManager = databaseManager;
  private readonly sourceImportManager = SourceImportManager;
  private readonly sourceValidator = SourceValidator;
  private context: common.UIAbilityContext | null = null;
  
  // 安全配置
  private readonly MAX_URL_LENGTH = 2048;
  private readonly MAX_FILE_NAME_LENGTH = 255;
  private readonly ALLOWED_FILE_EXTENSIONS = ['json', 'txt'];

  /**
   * 设置上下文
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 加载所有启用的书源
   */
  async loadEnabledBookSources(): Promise<BookSource[]> {
    try {
      this.bookSources = await this.databaseManager.getAllEnabledBookSources();
      return this.bookSources;
    } catch (error) {
      Logger.error('BookSourceViewModel', `加载启用的书源失败`);
      throw new Error('加载书源失败');
    }
  }

  /**
   * 加载所有书源（包括禁用）
   */
  async loadAllBookSources(): Promise<BookSource[]> {
    try {
      // TODO: 实现加载所有书源的方法
      return await this.loadEnabledBookSources();
    } catch (error) {
      Logger.error('BookSourceViewModel', `加载所有书源失败`);
      throw new Error('加载书源失败');
    }
  }

  /**
   * 添加或更新书源
   */
  async upsertBookSource(bookSource: BookSource): Promise<void> {
    try {
      // 验证书源数据
      this.validateBookSourceData(bookSource);
      
      await this.databaseManager.upsertBookSource(bookSource);
      await this.loadEnabledBookSources();
    } catch (error) {
      Logger.error('BookSourceViewModel', `添加或更新书源失败：${error}`);
      throw error;
    }
  }

  /**
   * 切换书源启用状态
   */
  async toggleBookSource(id: string, enabled: boolean): Promise<void> {
    try {
      if (!this.isValidUUID(id)) {
        throw new Error('无效的书源ID');
      }
      
      const source = this.bookSources.find((s: BookSource) => s.id === id);
      if (source) {
        source.enabled = enabled;
        await this.databaseManager.upsertBookSource(source);
        await this.loadEnabledBookSources();
      }
    } catch (error) {
      Logger.error('BookSourceViewModel', `切换书源状态失败`);
      throw new Error('切换书源状态失败');
    }
  }

  /**
   * 导入书源（从JSON文件或URL）
   */
  async importBookSources(sources: BookSource[]): Promise<void> {
    try {
      // 验证输入数据
      if (!sources || !Array.isArray(sources)) {
        throw new Error('无效的书源数据');
      }
      
      if (sources.length > 1000) {
        throw new Error('一次最多导入1000个书源');
      }
      
      await this.batchUpsertBookSources(sources);
      await this.loadEnabledBookSources();
    } catch (error) {
      Logger.error('BookSourceViewModel', `导入书源失败`);
      throw error;
    }
  }

  /**
   * 批量添加或更新书源
   */
  async batchUpsertBookSources(sources: BookSource[]): Promise<void> {
    try {
      if (sources.length === 0) {
        return;
      }
      
      // 验证每个书源
      for (const source of sources) {
        this.validateBookSourceData(source);
      }
      
      await this.databaseManager.batchUpsertBookSources(sources);
      Logger.info('BookSourceViewModel', `成功添加/更新${sources.length}个书源`);
    } catch (error) {
      Logger.error('BookSourceViewModel', `批量添加/更新书源失败`);
      throw error;
    }
  }

  /**
   * 批量删除书源
   */
  async batchDeleteBookSources(ids: string[]): Promise<DeleteResult> {
    try {
      if (!ids || !Array.isArray(ids) || ids.length === 0) {
        throw new Error('无效的删除请求');
      }
      
      if (ids.length > 100) {
        throw new Error('一次最多删除100个书源');
      }
      
      // 验证所有ID
      for (const id of ids) {
        if (!this.isValidUUID(id)) {
          throw new Error(`无效的书源ID: ${id}`);
        }
      }
      
      const deletedCount = await this.deleteBookSources(ids);
      await this.loadEnabledBookSources();
      
      const result: DeleteResult = {
        success: true,
        message: `成功删除 ${deletedCount} 个书源`,
        count: deletedCount
      };
      return result;
    } catch (error) {
      Logger.error('BookSourceViewModel', `批量删除书源失败`);
      return {
        success: false,
        message: error instanceof Error ? error.message : '删除失败'
      };
    }
  }

  /**
   * 删除书源（内部方法）
   */
  private async deleteBookSources(ids: string[]): Promise<number> {
    if (this.databaseManager === null || ids.length === 0) {
      return 0;
    }

    try {
      let deletedCount = 0;
      for (const id of ids) {
        const deleted = await this.deleteBookSourceById(id);
        if (deleted) {
          deletedCount++;
        }
      }
      return deletedCount;
    } catch (error) {
      Logger.error('BookSourceViewModel', `删除书源失败`);
      throw new Error('删除书源失败');
    }
  }

  /**
   * 根据ID删除书源（内部方法）
   */
  private async deleteBookSourceById(id: string): Promise<boolean> {
    if (this.databaseManager === null) {
      return false;
    }

    try {
      // 这里需要实现具体的删除逻辑
      // 暂时返回true表示删除成功
      return true;
    } catch (error) {
      Logger.error('BookSourceViewModel', `删除书源失败`);
      return false;
    }
  }

  /**
   * 测试书源有效性
   */
  async testBookSource(bookSource: BookSource): Promise<boolean> {
    try {
      // 验证书源数据
      this.validateBookSourceData(bookSource);
      
      const networkManager = NetworkManager.getInstance();
      
      // 测试搜索功能
      const testKeyword = '测试';
      let searchUrl = bookSource.searchUrl;
      
      if (searchUrl.includes('{{key}}')) {
        searchUrl = searchUrl.replace('{{key}}', encodeURIComponent(testKeyword));
      }
      
      // 验证URL
      if (!this.isValidUrl(searchUrl)) {
        return false;
      }
      
      const headers: Record<string, string> | undefined = bookSource.header
        ? this.parseHeadersSafely(bookSource.header)
        : undefined;
      
      const response = await networkManager.get(searchUrl, headers);
      
      // 检查响应是否有效
      if (response && response.length > 0) {
        return true;
      }
      
      return false;
    } catch (error) {
      Logger.error('BookSourceViewModel', `测试书源有效性失败`);
      return false;
    }
  }

  /**
   * 删除书源
   */
  async deleteBookSource(id: string): Promise<DeleteResult> {
    try {
      return await this.batchDeleteBookSources([id]);
    } catch (error) {
      Logger.error('BookSourceViewModel', `删除书源失败`);
      return {
        success: false,
        message: error instanceof Error ? error.message : '删除失败'
      };
    }
  }

  /**
   * 增强版书源导入功能
   * 支持多种格式：JSON、XML、TXT
   */
  async importBookSource(input: string, format?: string): Promise<ImportResult> {
    try {
      Logger.info('BookSourceViewModel', '开始导入书源');
      
      // 验证输入长度
      if (!input || input.trim().length === 0) {
        throw new Error('书源内容不能为空');
      }
      
      if (input.length > 10 * 1024 * 1024) { // 10MB限制
        throw new Error('书源内容过大，最大支持10MB');
      }
      
      let content = input.trim();
      
      // 如果是URL，先下载内容
      if (this.isValidUrl(content)) {
        Logger.debug('BookSourceViewModel', `从URL下载书源内容`);
        
        const networkManager = NetworkManager.getInstance();
        if (this.context) {
          networkManager.setContext(this.context);
        }
        
        content = await networkManager.getStream(content);
        if (!content || content.trim().length === 0) {
          throw new Error('从URL获取的书源内容为空');
        }
        
        // 验证下载内容大小
        if (content.length > 5 * 1024 * 1024) { // 5MB限制
          throw new Error('下载的书源内容过大');
        }
      }
      
      // 使用增强的书源导入管理器
      const result = await this.sourceImportManager.importSources(content, format);
      
      // 重新加载书源列表
      await this.loadEnabledBookSources();
      
      return {
        success: result.success,
        message: result.message,
        count: result.importedCount
      };
      
    } catch (error) {
      Logger.error('BookSourceViewModel', `导入书源失败`);
      return {
        success: false,
        message: error instanceof Error ? error.message : '导入失败'
      };
    }
  }

  /**
   * 批量验证书源可用性
   */
  async validateBookSources(sources: BookSource[]): Promise<ValidationResult[]> {
    try {
      if (!sources || sources.length === 0) {
        return [];
      }
      
      if (sources.length > 50) {
        throw new Error('一次最多验证50个书源');
      }
      
      Logger.info('BookSourceViewModel', `开始批量验证${sources.length}个书源`);
      
      const results: ValidationResult[] = await this.sourceValidator.validateSourcesBatch(sources);
      
      // 更新书源状态
      for (const result of results) {
        result.source.enabled = result.isAvailable;
        await this.upsertBookSource(result.source);
      }
      
      Logger.info('BookSourceViewModel', `书源验证完成`);
      return results;
      
    } catch (error) {
      Logger.error('BookSourceViewModel', `批量验证书源失败`);
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
   * 导出书源到文件
   */
  async exportBookSources(fileName: string = 'book_sources.json'): Promise<ExportResult> {
    try {
      if (!this.context) {
        throw new Error('上下文未设置，无法导出文件');
      }

      // 验证文件名
      if (!this.isValidFileName(fileName)) {
        throw new Error('无效的文件名');
      }

      // 获取所有书源
      const allSources = await this.loadAllBookSources();
      
      if (allSources.length === 0) {
        return {
          success: false,
          message: '没有可导出的书源'
        };
      }

      // 转换为导出格式
      const exportData = allSources.map(source => ({
        bookSourceName: source.name,
        bookSourceUrl: source.url,
        ruleSearch: source.searchRule,
        ruleToc: source.chapterRule,
        ruleContent: source.contentRule,
        ruleType: source.ruleType,
        enabled: source.enabled,
        customOrder: source.sort
      }));

      // 创建导出目录
      const filesDir = this.context.filesDir;
      const exportDir = filesDir + '/exports/';
      
      try {
        await fs.access(exportDir);
      } catch (error) {
        await fs.mkdir(exportDir);
      }

      // 写入文件
      const filePath = exportDir + fileName;
      const jsonContent = JSON.stringify(exportData, null, 2);
      
      // 使用文件IO写入文件
      await this.writeFileContent(filePath, jsonContent);

      return {
        success: true,
        message: `导出成功：${allSources.length}个书源`,
        filePath: filePath,
        count: allSources.length
      };
    } catch (error) {
      Logger.error('BookSourceViewModel', `导出书源失败`);
      return {
        success: false,
        message: error instanceof Error ? error.message : '导出失败'
      };
    }
  }

  /**
   * 写入文件内容（内部方法）
   */
  private async writeFileContent(filePath: string, content: string): Promise<void> {
    try {
      // 验证文件路径
      if (!this.isValidFilePath(filePath)) {
        throw new Error('无效的文件路径');
      }
      
      // 使用fs模块写入文件
      await fs.writeText(filePath, content);
    } catch (error) {
      throw new Error(`写入文件失败`);
    }
  }

  /**
   * 验证URL格式
   */
  private isValidUrl(input: string): boolean {
    try {
      if (!input || input.length > this.MAX_URL_LENGTH) {
        return false;
      }
      
      // 更严格的URL验证
      const urlPattern = /^https?:\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:\d{1,5})?(\/[a-zA-Z0-9-._~:/?#[\]@!$&'()*+,;=]*)?$/;
      
      if (!urlPattern.test(input)) {
        return false;
      }
      
      // 验证协议
      if (!input.startsWith('http://') && !input.startsWith('https://')) {
        return false;
      }
      
      // 防止SSRF攻击，限制本地地址
      const hostname = new URL(input).hostname;
      if (this.isLocalAddress(hostname)) {
        return false;
      }
      
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 验证文件名
   */
  private isValidFileName(fileName: string): boolean {
    if (!fileName || fileName.length > this.MAX_FILE_NAME_LENGTH) {
      return false;
    }
    
    // 防止路径遍历攻击
    if (fileName.includes('..') || fileName.includes('/') || fileName.includes('\\')) {
      return false;
    }
    
    // 验证文件扩展名
    const extension = fileName.split('.').pop()?.toLowerCase();
    if (!extension || !this.ALLOWED_FILE_EXTENSIONS.includes(extension)) {
      return false;
    }
    
    // 只允许字母、数字、下划线、连字符和点号
    const fileNamePattern = /^[a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+$/;
    return fileNamePattern.test(fileName);
  }

  /**
   * 验证文件路径
   */
  private isValidFilePath(filePath: string): boolean {
    if (!filePath || filePath.length > 4096) {
      return false;
    }
    
    // 防止路径遍历攻击
    if (filePath.includes('..') || filePath.includes('//') || filePath.includes('\\\\')) {
      return false;
    }
    
    return true;
  }

  /**
   * 检查是否为本地地址
   */
  private isLocalAddress(hostname: string): boolean {
    const localHostnames = ['localhost', '127.0.0.1', '0.0.0.0', '::1'];
    const localNetworks = ['10.', '172.16.', '172.31.', '192.168.'];
    
    if (localHostnames.includes(hostname)) {
      return true;
    }
    
    for (const network of localNetworks) {
      if (hostname.startsWith(network)) {
        return true;
      }
    }
    
    return false;
  }

  /**
   * 验证UUID格式
   */
  private isValidUUID(id: string): boolean {
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidPattern.test(id);
  }

  /**
   * 安全解析JSON
   */
  private parseJsonSafely(jsonString: string): BookSourceRawData | BookSourceRawData[] {
    try {
      // 验证JSON字符串长度
      if (jsonString.length > 10 * 1024 * 1024) {
        throw new Error('JSON数据过大');
      }
      
      return JSON.parse(jsonString);
    } catch (error) {
      // 尝试清理JSON字符串
      const cleanedJson = jsonString
        .replace(/[\x00-\x1F\x7F]/g, '') // 移除控制字符
        .replace(/,\s*}/g, '}') // 修复尾随逗号
        .replace(/,\s*]/g, ']'); // 修复数组尾随逗号
      
      try {
        return JSON.parse(cleanedJson);
      } catch (secondError) {
        throw new Error('JSON格式错误，无法解析书源数据');
      }
    }
  }

  /**
   * 安全解析请求头
   */
  private parseHeadersSafely(headersString: string): Record<string, string> {
    try {
      const headers = JSON.parse(headersString);
      
      // 验证headers对象
      if (typeof headers !== 'object' || headers === null) {
        return {};
      }
      
      const result: Record<string, string> = {};
      
      for (const [key, value] of Object.entries(headers)) {
        if (typeof key === 'string' && typeof value === 'string') {
          // 限制header key和value长度
          if (key.length <= 100 && value.length <= 1000) {
            result[key] = value;
          }
        }
      }
      
      return result;
    } catch (error) {
      Logger.warn('BookSourceViewModel', '解析请求头失败，使用空请求头');
      return {};
    }
  }

  /**
   * 验证书源数据
   */
  private validateBookSourceData(source: BookSource): void {
    if (!source) {
      throw new Error('书源数据不能为空');
    }
    
    if (!source.name || source.name.trim().length === 0) {
      throw new Error('书源名称不能为空');
    }
    
    if (source.name.length > 100) {
      throw new Error('书源名称不能超过100个字符');
    }
    
    if (!source.url || !this.isValidUrl(source.url)) {
      throw new Error('书源URL格式无效');
    }
    
    if (source.searchUrl && !this.isValidUrl(source.searchUrl)) {
      throw new Error('搜索URL格式无效');
    }
    
    if (source.sort && (source.sort < 0 || source.sort > 1000)) {
      throw new Error('排序值必须在0-1000之间');
    }
    
    // 验证规则类型
    if (!['xpath', 'jsonpath', 'regex'].includes(source.ruleType)) {
      throw new Error('无效的规则类型');
    }
  }

  /**
   * 处理书源数组
   */
  private processBookSourceArray(data: BookSourceRawData[]): BookSource[] {
    if (!Array.isArray(data) || data.length === 0) {
      return [];
    }
    
    const bookSources: BookSource[] = [];
    
    // 限制处理数量
    const maxSources = 1000;
    const sourcesToProcess = data.slice(0, maxSources);
    
    // 分段处理大量书源
    const batchSize = 50;
    for (let i = 0; i < sourcesToProcess.length; i += batchSize) {
      const batch = sourcesToProcess.slice(i, i + batchSize);
      Logger.debug('BookSourceViewModel', `处理批次 ${Math.floor(i / batchSize) + 1}/${Math.ceil(sourcesToProcess.length / batchSize)} (${batch.length} 个书源)`);
      
      const batchSources = batch.map((source) => this.createBookSourceFromRaw(source));
      bookSources.push(...batchSources.filter(source => source.name && source.url)); // 过滤无效书源
    }
    
    return bookSources;
  }

  /**
   * 批量导入书源
   */
  private async batchImportBookSources(bookSources: BookSource[]): Promise<void> {
    if (bookSources.length === 0) {
      return;
    }
    
    const importBatchSize = 50;
    for (let i = 0; i < bookSources.length; i += importBatchSize) {
      const batch = bookSources.slice(i, i + importBatchSize);
      Logger.debug('BookSourceViewModel', `导入批次 ${Math.floor(i / importBatchSize) + 1}/${Math.ceil(bookSources.length / importBatchSize)} (${batch.length} 个书源)`);
      await this.batchUpsertBookSources(batch);
      
      // 每批次导入后稍作延迟
      if (i + importBatchSize < bookSources.length) {
        await new Promise<void>(resolve => setTimeout(resolve, 500));
      }
    }
  }

  /**
   * 从原始数据创建书源对象
   */
  private createBookSourceFromRaw(source: BookSourceRawData): BookSource {
    // 映射书源基本信息
    const bookSourceName = source.bookSourceName || source.name || '未知书源';
    const bookSourceUrl = source.bookSourceUrl || source.url || source.baseUrl || '';
    const searchUrl = source.searchUrl || source.search || '';
    const enabled = source.enabled !== false;
    const sort = source.customOrder || source.sort || 0;
    const lastUpdateTime = source.lastUpdateTime || Date.now();
    const addTime = source.addTime || Date.now();
    const header = source.header || source.headers || undefined;

    // 映射搜索规则
    const ruleSearch = source.ruleSearch || source.searchRule || {};
    const searchRule: SearchRule = {
      bookList: ruleSearch.bookList || ruleSearch.list || '',
      name: ruleSearch.name || '',
      author: ruleSearch.author || '',
      cover: ruleSearch.cover || undefined,
      intro: ruleSearch.intro || undefined,
      bookUrl: ruleSearch.bookUrl || ruleSearch.url || '',
      nextUrl: ruleSearch.nextUrl
    };

    // 映射发现规则
    const ruleExplore = source.ruleExplore || source.findRule || {};
    const exploreUrl = source.exploreUrl || ruleExplore.url || '';
    const findRule: FindRule | undefined = exploreUrl ? {
      url: exploreUrl,
      bookList: ruleExplore.bookList || ruleExplore.list || '',
      name: ruleExplore.name || '',
      author: ruleExplore.author || '',
      cover: ruleExplore.cover || undefined,
      intro: ruleExplore.intro || undefined,
      bookUrl: ruleExplore.bookUrl || ruleExplore.url || ''
    } : undefined;

    // 映射章节规则
    const ruleToc = source.ruleToc || source.chapterRule || {};
    const chapterRule: ChapterRule = {
      chapterList: ruleToc.chapterList || ruleToc.list || '',
      chapterName: ruleToc.chapterName || ruleToc.name || '',
      chapterUrl: ruleToc.chapterUrl || ruleToc.url || '',
      nextUrl: ruleToc.nextUrl
    };

    // 映射内容规则
    const ruleContent = source.ruleContent || source.contentRule || {};
    const contentRule: ContentRule = {
      content: ruleContent.content || '',
      nextUrl: ruleContent.nextUrl,
      prevUrl: ruleContent.prevUrl,
      replaceRule: ruleContent.replaceRule
    };

    // 确定规则类型
    let ruleType: 'xpath' | 'jsonpath' | 'regex' = 'xpath';
    if (source.ruleType) {
      if (source.ruleType === 'xpath' || source.ruleType === 'jsonpath' || source.ruleType === 'regex') {
        ruleType = source.ruleType;
      }
    } else {
      // 根据规则内容自动判断
      const allRules = [
        searchRule.bookList, searchRule.name, searchRule.author, searchRule.bookUrl,
        chapterRule.chapterList, chapterRule.chapterName, chapterRule.chapterUrl,
        contentRule.content
      ];
      for (const rule of allRules) {
        if (rule && typeof rule === 'string') {
          if (rule.startsWith('$')) {
            ruleType = 'jsonpath';
            break;
          } else if (rule.startsWith('@js:')) {
            ruleType = 'regex';
            break;
          }
        }
      }
    }

    return {
      id: source.id || IdGenerator.generateUUID(),
      name: bookSourceName,
      url: bookSourceUrl,
      enabled: enabled,
      header: header,
      searchUrl: searchUrl,
      searchRule: searchRule,
      findRule: findRule,
      chapterRule: chapterRule,
      contentRule: contentRule,
      ruleType: ruleType,
      sort: sort,
      lastUpdateTime: lastUpdateTime,
      addTime: addTime
    };
  }
}