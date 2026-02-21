
import { BookSource, SearchRule, ChapterRule, ContentRule } from '../models/BookSource';
import { databaseManager } from '../utils/DatabaseManager';
import { PagedBookSourcesResult } from '../utils/database/BookSourceRepository';
import { NetworkManager } from '../utils/NetworkManager';
import SourceImportManager from '../utils/SourceImportManager';
import SourceValidator from '../utils/SourceValidator';
import BookSourceParser from '../utils/BookSourceParser';
import BookSourceManager, { SearchBooksResult, YCKSourceData } from '../utils/BookSourceManager';
import { Logger } from '../utils/Logger';
import SourceSandbox, { SecurityScanResult, SecurityRiskLevel } from '../utils/SourceSandbox';
import fileio from '@ohos.fileio';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';

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
 * 导出书源数据接口
 */
interface ExportBookSourceData {
  bookSourceName: string;
  bookSourceUrl: string;
  ruleSearch: SearchRule;
  ruleToc: ChapterRule;
  ruleContent: ContentRule;
  ruleType: string;
  enabled: boolean;
  customOrder: number;
}


/**
 * 搜索规则接口
 */
export interface SearchRuleRaw {
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
  nextUrl?: string;
}

/**
 * 发现规则接口
 */
export interface FindRuleRaw {
  url: string;
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
}

/**
 * 章节规则接口
 */
export interface ChapterRuleRaw {
  chapterList: string;
  chapterName: string;
  chapterUrl: string;
  nextUrl?: string;
}

/**
 * 内容规则接口
 */
export interface ContentRuleRaw {
  content: string;
  nextUrl?: string;
  prevUrl?: string;
  replaceRule?: string;
}

/**
 * AstroRead 搜索规则接口
 */
export interface AstroReadSearchRule {
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
  nextUrl?: string;
}

/**
 * AstroRead 发现规则接口
 */
export interface AstroReadExploreRule {
  url: string;
  bookList: string;
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
}

/**
 * AstroRead 章节规则接口
 */
export interface AstroReadTocRule {
  chapterList: string;
  chapterName: string;
  chapterUrl: string;
  nextUrl?: string;
}

/**
 * AstroRead 内容规则接口
 */
export interface AstroReadContentRule {
  content: string;
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
  private readonly bookSourceManager = BookSourceManager;
  private context: common.UIAbilityContext | null = null;
  
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
      Logger.error('BookSourceViewModel', '加载启用的书源失败');
      throw new Error('加载书源失败');
    }
  }

  /**
   * 加载所有书源（包括禁用）
   */
  async loadAllBookSources(): Promise<BookSource[]> {
    try {
      this.bookSources = await this.databaseManager.getAllBookSources();
      return this.bookSources;
    } catch (error) {
      Logger.error('BookSourceViewModel', '加载所有书源失败');
      throw new Error('加载书源失败');
    }
  }

  /**
   * 分页加载书源
   */
  async loadBookSourcesPaged(page: number, pageSize: number): Promise<PagedBookSourcesResult> {
    try {
      const result = await this.databaseManager.getBookSourcesPaged(page, pageSize);
      return result;
    } catch (error) {
      Logger.error('BookSourceViewModel', '分页加载书源失败');
      throw new Error('加载书源失败');
    }
  }

  /**
   * 获取书源总数
   */
  async getBookSourcesCount(): Promise<number> {
    try {
      return await this.databaseManager.getBookSourcesCount();
    } catch (error) {
      Logger.error('BookSourceViewModel', '获取书源数量失败');
      return 0;
    }
  }


  /**
   * 根据ID获取书源
   */
  async getBookSourceById(id: string): Promise<BookSource | null> {
    try {
      return await this.databaseManager.getBookSourceById(id);
    } catch (error) {
      Logger.error('BookSourceViewModel', '获取书源失败');
      return null;
    }
  }
  /**
   * 添加或更新书源
   */
  async upsertBookSource(bookSource: BookSource): Promise<void> {
    try {
      // 确保书源有唯一ID
      if (!bookSource.id || bookSource.id.trim() === '') {
        bookSource.id = util.generateRandomUUID(true);
        Logger.debug('BookSourceViewModel', `为书源生成新ID: ${bookSource.name} -> ${bookSource.id}`);
      }
      
      // 验证书源数据
      this.validateBookSourceData(bookSource);
      
      await this.databaseManager.upsertBookSource(bookSource);
      await this.loadEnabledBookSources();
    } catch (error) {
      Logger.error('BookSourceViewModel', '添加或更新书源失败');
      throw new Error('添加或更新书源失败');
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
      Logger.error('BookSourceViewModel', '切换书源状态失败');
      throw new Error('切换书源状态失败');
    }
  }

  /**
   * 批量更新书源状态
   */
  async batchUpdateBookSourcesStatus(ids: string[], enabled: boolean): Promise<DeleteResult> {
    try {
      if (!ids || ids.length === 0) {
        return {
          success: false,
          message: '没有选择任何书源'
        };
      }

      // 验证所有ID
      for (const id of ids) {
        if (!this.isValidUUID(id)) {
          throw new Error(`无效的书源ID: ${id}`);
        }
      }

      let updatedCount = 0;
      for (const id of ids) {
        const source = this.bookSources.find((s: BookSource) => s.id === id);
        if (source) {
          source.enabled = enabled;
          await this.databaseManager.upsertBookSource(source);
          updatedCount++;
        }
      }

      await this.loadEnabledBookSources();
      
      return {
        success: true,
        message: `成功更新 ${updatedCount} 个书源状态`,
        count: updatedCount
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : '未知错误';
      Logger.error('BookSourceViewModel', `批量更新书源状态失败: ${errorMsg}`);
      return {
        success: false,
        message: `批量更新书源状态失败: ${errorMsg}`
      };
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
      Logger.error('BookSourceViewModel', '导入书源失败');
      throw new Error('导入书源失败');
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
      Logger.error('BookSourceViewModel', '批量添加/更新书源失败');
      throw new Error('批量添加/更新书源失败');
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
          throw new Error('无效的书源ID');
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
      const errorMsg = error instanceof Error ? error.message : '未知错误';
      Logger.error('BookSourceViewModel', `批量删除书源失败: ${errorMsg}`);
      return {
        success: false,
        message: errorMsg
      };
    }
  }

  /**
   * 删除书源（内部方法）
   */
  private async deleteBookSources(ids: string[]): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }

    try {
      // 使用BookSourceManager的批量删除功能
      const bookSourceManager = BookSourceManager.getInstance();
      await bookSourceManager.removeSources(ids);
      return ids.length; // 成功删除的数量就是传入的ID数量
    } catch (error) {
      Logger.error('BookSourceViewModel', `批量删除书源失败: ${error instanceof Error ? error.message : String(error)}`);
      throw new Error(`批量删除书源失败: ${error instanceof Error ? error.message : String(error)}`);
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
      await this.databaseManager.deleteBookSource(id);
      return true;
    } catch (error) {
      Logger.error('BookSourceViewModel', '删除书源失败');
      return false;
    }
  }

  /**
   * 测试书源有效性
   */
  async testBookSource(bookSource: BookSource): Promise<boolean> {
    try {
      if (!bookSource) {
        Logger.warn('BookSourceViewModel', '书源数据为空');
        return false;
      }

      if (!bookSource.searchUrl) {
        Logger.warn('BookSourceViewModel', '书源没有配置搜索URL');
        return false;
      }

      const networkManager = NetworkManager.getInstance();
      if (this.context) {
        networkManager.setContext(this.context);
      }

      // 使用多个测试关键词，提高验证成功率
      const testKeywords = ['斗罗大陆', '斗破苍穹', '凡人修仙传', 'test', 'a'];
      const headersRecord: Record<string, string> | undefined = bookSource.header
        ? this.parseHeadersSafely(bookSource.header)
        : undefined;
      const headers: Map<string, string> | undefined = headersRecord
        ? this.recordToMap(headersRecord)
        : undefined;

      Logger.info('BookSourceViewModel', `开始验证书源: ${bookSource.name}`);

      // 尝试多个关键词
      for (const testKeyword of testKeywords) {
        let searchUrl = bookSource.searchUrl;

        // 替换关键词占位符
        searchUrl = searchUrl
          .replace(/\{\{key\}\}/g, encodeURIComponent(testKeyword))
          .replace(/\{\{page\}\}/g, '1')
          .replace(/\{key\}/g, encodeURIComponent(testKeyword))
          .replace(/\{page\}/g, '1')
          .replace(/<key>/g, encodeURIComponent(testKeyword))
          .replace(/<page>/g, '1')
          .replace(/\$key\$/g, encodeURIComponent(testKeyword))
          .replace(/\$page\$/g, '1');

        // 放宽URL验证，允许更多格式
        if (!searchUrl.startsWith('http://') && !searchUrl.startsWith('https://')) {
          Logger.debug('BookSourceViewModel', `搜索URL格式无效，跳过: ${searchUrl}`);
          continue;
        }

        try {
          Logger.debug('BookSourceViewModel', `尝试关键词 "${testKeyword}" 验证: ${bookSource.name}`);
          const response = await networkManager.get(searchUrl, headers);

          // 放宽验证条件：只要响应非空且长度大于50就认为成功
          if (response && response.length > 50) {
            Logger.info('BookSourceViewModel', `书源验证成功: ${bookSource.name}, 关键词: ${testKeyword}, 响应长度: ${response.length}`);
            return true;
          }
        } catch (e) {
          const errorMsg = e instanceof Error ? e.message : String(e);
          Logger.debug('BookSourceViewModel', `关键词 "${testKeyword}" 验证失败: ${errorMsg}`);
          // 继续尝试下一个关键词
        }
      }

      Logger.warn('BookSourceViewModel', `书源验证失败: ${bookSource.name}`);
      return false;
    } catch (error) {
      Logger.error('BookSourceViewModel', `测试书源有效性失败: ${error instanceof Error ? error.message : '未知错误'}`);
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
      Logger.error('BookSourceViewModel', '删除书源失败');
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
  async importBookSource(input: string, format?: string, skipSafetyCheck: boolean = false): Promise<ImportResult> {
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
        Logger.debug('BookSourceViewModel', '从URL下载书源内容');
        
        const networkManager = NetworkManager.getInstance();
        if (this.context) {
          networkManager.setContext(this.context);
        }
        
        content = await networkManager.get(content);
        if (!content || content.trim().length === 0) {
          throw new Error('从URL获取的书源内容为空');
        }
        
        // 验证下载内容大小
        if (content.length > 5 * 1024 * 1024) { // 5MB限制
          throw new Error('下载的书源内容过大');
        }
      }
      
      // 使用增强的书源导入管理器
      const result = await this.sourceImportManager.importSources(content, format, skipSafetyCheck);
      
      // 重新加载书源列表
      await this.loadEnabledBookSources();
      
      return {
        success: result.success,
        message: result.message,
        count: result.importedCount
      };
      
    } catch (error) {
      Logger.error('BookSourceViewModel', '导入书源失败');
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
      
      Logger.info('BookSourceViewModel', '书源验证完成');
      return results;
      
    } catch (error) {
      Logger.error('BookSourceViewModel', '批量验证书源失败');
      return [];
    }
  }

  /**
   * 检测书源格式
   */
  detectSourceFormat(content: string): string {
    return BookSourceParser.detectFormat(content);
  }

  scanSourceSecurity(content: string): SecurityScanResult {
    return SourceSandbox.scanSourceContent(content);
  }

  scanBookSourceSecurity(source: BookSource): SecurityScanResult {
    return SourceSandbox.scanBookSource(source);
  }

  scanSourcesSecurityBatch(sources: BookSource[]): Map<string, SecurityScanResult> {
    return SourceSandbox.scanSourcesBatch(sources);
  }

  getSecurityRiskLevelText(level: SecurityRiskLevel): string {
    return SourceSandbox.getRiskLevelText(level);
  }

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

      // 转换为导出格式，提供默认值
      const exportData: ExportBookSourceData[] = allSources.map(source => {
        const exportItem: ExportBookSourceData = {
          bookSourceName: source.name,
          bookSourceUrl: source.url,
          ruleSearch: source.searchRule,
          ruleToc: source.chapterRule,
          ruleContent: source.contentRule,
          ruleType: source.ruleType,
          enabled: source.enabled,
          customOrder: source.sort
        };
        return exportItem;
      });

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
      
      // 使用文件IO写入文件 - 修复：使用正确的API
      await this.writeFileContent(filePath, jsonContent);

      return {
        success: true,
        message: `导出成功：${allSources.length}个书源`,
        filePath: filePath,
        count: allSources.length
      };
    } catch (error) {
      Logger.error('BookSourceViewModel', '导出书源失败');
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
      
      // 使用fileio模块写入文件 - 修复：使用正确的API
      const fd = await fileio.open(filePath, 0o2 | 0o100); // READ_WRITE | CREATE
      await fileio.write(fd, content);
      await fileio.close(fd);
    } catch (error) {
      throw new Error('写入文件失败');
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
      const hostname = this.extractHostname(input);
      if (this.isLocalAddress(hostname)) {
        return false;
      }
      
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 提取主机名
   */
  private extractHostname(url: string): string {
    try {
      // 简化版URL解析，避免使用URL构造函数
      const match = url.match(/^https?:\/\/([^\/:]+)/);
      return match ? match[1] : '';
    } catch (error) {
      return '';
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
   * 验证书源数据
   */
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

  /**
   * 验证UUID格式 - 增强版
   * 支持标准UUID格式和自定义安全ID格式
   */
  private isValidUUID(id: string): boolean {
    if (!id || typeof id !== 'string') {
      return false;
    }
    
    const trimmedId = id.trim();
    if (trimmedId.length === 0) {
      return false;
    }

    const standardUUIDPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (standardUUIDPattern.test(trimmedId)) {
      return true;
    }

    const customIdPattern = /^[a-zA-Z0-9][a-zA-Z0-9_-]{7,63}$/;
    if (customIdPattern.test(trimmedId)) {
      return true;
    }

    const legacyPattern = /^[a-zA-Z0-9_\-:.@]{8,64}$/;
    if (legacyPattern.test(trimmedId)) {
      return true;
    }

    return false;
  }

  /**
   * 安全解析headers
   */
  private parseHeadersSafely(headerStr: string): Record<string, string> | undefined {
    try {
      if (!headerStr || headerStr.trim().length === 0) {
        return undefined;
      }
      
      const parsed = JSON.parse(headerStr) as Record<string, string>;
      if (typeof parsed === 'object' && parsed !== null) {
        const result: Record<string, string> = {};
        const keys = Object.keys(parsed);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          result[key] = String(parsed[key]);
        }
        return result;
      }
      return undefined;
    } catch (error) {
      Logger.warn('BookSourceViewModel', `解析headers失败: ${error instanceof Error ? error.message : '未知错误'}`);
      return undefined;
    }
  }

  /**
   * 将Record转换为Map
   */
  private recordToMap(record: Record<string, string>): Map<string, string> {
    const map = new Map<string, string>();
    const keys = Object.keys(record);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      map.set(key, record[key]);
    }
    return map;
  }
}