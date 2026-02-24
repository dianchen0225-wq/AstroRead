/**
 * 书源导入管理器 - 统一管理书源的导入、验证和存储
 * 安全加固版本 - 修复了多个安全漏洞
 */

import { BookSource } from '../models/BookSource';
import BookSourceParser from './BookSourceParser';
import SourceValidator from './SourceValidator';
import { databaseManager } from './DatabaseManager';
import { Logger } from './Logger';
import { util } from '@kit.ArkTS';
import { SecurityUtils } from './SecurityUtils';

/**
 * 导入结果接口
 */
interface ImportResult {
  success: boolean;
  message: string;
  importedCount: number;
  totalCount: number;
  warnings?: string[];
  errors?: string[];
}

/**
 * 安全检查结果接口
 */
interface SafetyCheckResult {
  isSafe: boolean;
  message?: string;
  errors?: string[];
}

/**
 * 验证结果接口
 */
interface ValidationResult {
  validSources: BookSource[];
  warnings: string[];
  errors: string[];
}

/**
 * 更新状态结果接口
 */
interface UpdateStatusResult {
  success: boolean;
  updatedCount: number;
  totalCount: number;
  errors: string[];
}

class SourceImportManager {
  
  private TAG: string = 'SourceImportManager';
  
  private readonly MAX_CONTENT_SIZE = 50 * 1024 * 1024;
  private readonly MAX_SOURCES_PER_IMPORT = 5000;
  private readonly MAX_SOURCES_PER_BATCH = 100;
  private readonly MAX_ERROR_MESSAGE_LENGTH = 100;
  private readonly MAX_SOURCE_NAME_LENGTH = 100;
  private readonly MAX_URL_LENGTH = 2048;
  private readonly MAX_HEADER_LENGTH = 5000;
  private readonly MAX_NESTING_DEPTH = 50;
  private readonly MAX_LINE_COUNT = 100000;
  private sourceCache: Map<string, BookSource> | null = null;
  private importProgressCallback: ((current: number, total: number, message: string) => void) | null = null;
  private isImportCancelled: boolean = false;

  setProgressCallback(callback: (current: number, total: number, message: string) => void): void {
    this.importProgressCallback = callback;
  }

  cancelImport(): void {
    this.isImportCancelled = true;
  }

  private reportProgress(current: number, total: number, message: string): void {
    if (this.importProgressCallback) {
      this.importProgressCallback(current, total, message);
    }
  }

  /**
   * 导入书源 - 支持大规模导入
   */
  async importSources(content: string, format?: string, skipSafetyCheck: boolean = false): Promise<ImportResult> {
    const startTime = Date.now();
    this.isImportCancelled = false;
    
    try {
      Logger.info(this.TAG, '开始导入书源');
      this.reportProgress(0, 100, '验证书源内容...');
      
      if (!content || content.trim().length === 0) {
        return {
          success: false,
          message: '书源内容不能为空',
          importedCount: 0,
          totalCount: 0,
          errors: ['书源内容为空']
        };
      }
      
      if (content.length > this.MAX_CONTENT_SIZE) {
        return {
          success: false,
          message: '书源内容过大',
          importedCount: 0,
          totalCount: 0,
          errors: [`书源内容超过${this.MAX_CONTENT_SIZE / 1024 / 1024}MB限制`]
        };
      }
      
      if (!skipSafetyCheck) {
        const safetyCheck = this.performContentSafetyCheck(content);
        if (!safetyCheck.isSafe) {
          return {
            success: false,
            message: safetyCheck.message || '书源内容包含可疑代码',
            importedCount: 0,
            totalCount: 0,
            errors: safetyCheck.errors || ['检测到潜在的安全威胁']
          };
        }
      } else {
        Logger.warn(this.TAG, '用户选择跳过安全检查，继续导入');
      }

      const detectedFormat = format || BookSourceParser.detectFormat(content);
      
      if (detectedFormat === 'unknown') {
        return {
          success: false,
          message: '无法识别书源格式',
          importedCount: 0,
          totalCount: 0,
          errors: ['书源内容格式无法识别']
        };
      }
      
      this.reportProgress(10, 100, '解析书源数据...');
      const parsedSources = await this.safeParseSources(content, detectedFormat);
      
      if (parsedSources.length === 0) {
        return {
          success: false,
          message: '没有找到有效的书源',
          importedCount: 0,
          totalCount: 0,
          errors: ['解析后没有找到有效书源']
        };
      }
      
      if (parsedSources.length > this.MAX_SOURCES_PER_IMPORT) {
        Logger.warn(this.TAG, `导入书源数量过多，限制为${this.MAX_SOURCES_PER_IMPORT}个`);
        this.truncateSourcesArray(parsedSources, this.MAX_SOURCES_PER_IMPORT);
      }
      
      Logger.debug(this.TAG, `解析到${parsedSources.length}个书源，开始验证`);
      this.reportProgress(20, 100, `验证${parsedSources.length}个书源...`);
      
      const validationResults = await this.validateAndFilterSourcesWithProgress(parsedSources);
      
      if (this.isImportCancelled) {
        return {
          success: false,
          message: '导入已取消',
          importedCount: 0,
          totalCount: parsedSources.length,
          errors: ['用户取消导入']
        };
      }
      
      if (validationResults.validSources.length === 0) {
        return {
          success: false,
          message: '所有书源验证失败',
          importedCount: 0,
          totalCount: parsedSources.length,
          errors: validationResults.errors
        };
      }
      
      this.reportProgress(60, 100, `保存${validationResults.validSources.length}个书源...`);
      const savedCount = await this.saveSourcesWithProgress(validationResults.validSources);
      
      if (this.isImportCancelled) {
        return {
          success: false,
          message: '导入已取消',
          importedCount: savedCount,
          totalCount: parsedSources.length,
          errors: ['用户取消导入']
        };
      }
      
      const duration = Date.now() - startTime;
      Logger.info(this.TAG, `书源导入完成，成功导入${savedCount}/${parsedSources.length}个书源，耗时${duration}ms`);
      this.reportProgress(100, 100, `导入完成，共${savedCount}个书源`);
      
      return {
          success: savedCount > 0,
          message: savedCount > 0 ? 
                  `成功导入${savedCount}个书源` : 
                  '书源导入失败',
          importedCount: savedCount,
          totalCount: parsedSources.length,
          warnings: validationResults.warnings,
          errors: validationResults.errors
      };
      
    } catch (error) {
      const duration = Date.now() - startTime;
      Logger.error(this.TAG, `书源导入异常，耗时${duration}ms`);
      
      return {
        success: false,
        message: '书源导入过程中发生异常',
        importedCount: 0,
        totalCount: 0,
        errors: [this.getSafeErrorMessage(error)]
      };
    }
  }
  
  /**
   * 安全解析书源 - 新增安全防护层
   */
  private async safeParseSources(content: string, format: string): Promise<BookSource[]> {
    try {
      // 在解析前进行额外的安全检查
      if (!this.isValidContentForParsing(content)) {
        Logger.warn(this.TAG, '书源内容不符合解析要求');
        return [];
      }
      
      // 使用解析器解析书源
      const parsedSources = BookSourceParser.parseSources(content, format);
      
      // 对解析结果进行后置安全检查
      const safeSources: BookSource[] = [];
      const sourcesLength = parsedSources.length;
      for (let i = 0; i < sourcesLength; i++) {
        const source = parsedSources[i];
        if (this.isSafeSource(source)) {
          safeSources.push(source);
        }
      }
      
      if (safeSources.length < parsedSources.length) {
        Logger.warn(this.TAG, `过滤掉${parsedSources.length - safeSources.length}个不安全书源`);
      }
      
      return safeSources;
      
    } catch (error) {
      Logger.error(this.TAG, `安全解析书源失败：${this.getSafeErrorMessage(error)}`);
      return [];
    }
  }
  
  /**
   * 验证并过滤书源 - 带进度回调
   */
  private async validateAndFilterSourcesWithProgress(sources: BookSource[], skipNetworkValidation: boolean = true): Promise<ValidationResult> {
    const validSources: BookSource[] = [];
    const warnings: string[] = [];
    const errors: string[] = [];
    
    await this.initSourceCache();
    
    const total = sources.length;
    let processed = 0;
    
    for (const source of sources) {
      if (this.isImportCancelled) {
        break;
      }
      
      try {
        if (!this.isSafeSource(source)) {
          errors.push(`书源"${this.sanitizeString(source.name)}"包含不安全配置`);
          processed++;
          continue;
        }
        
        const formatResult = SourceValidator.validateSourceFormat(source);
        if (!formatResult.isValid) {
          errors.push(`书源"${this.sanitizeString(source.name)}"格式错误：${formatResult.errors.join(', ')}`);
          processed++;
          continue;
        }
        
        if (!skipNetworkValidation) {
          const availabilityResult = await SourceValidator.validateSourceAvailability(source);
          if (!availabilityResult.isAvailable) {
            warnings.push(`书源"${this.sanitizeString(source.name)}"暂时不可用：${this.sanitizeString(availabilityResult.error || '未知错误')}`);
          }
        }
        
        if (!source.id) {
          source.id = this.generateSourceId(source);
        }
        
        validSources.push(source);
        
      } catch (error) {
        errors.push(`书源"${this.sanitizeString(source.name)}"验证异常：${this.getSafeErrorMessage(error)}`);
      }
      
      processed++;
      if (processed % 50 === 0 || processed === total) {
        const progress = 20 + Math.floor((processed / total) * 40);
        this.reportProgress(progress, 100, `验证进度: ${processed}/${total}`);
      }
    }
    
    return {
      validSources: validSources,
      warnings: warnings,
      errors: errors
    };
  }
  
  /**
   * 初始化书源缓存
   */
  private async initSourceCache(): Promise<void> {
    if (this.sourceCache !== null) {
      return;
    }
    
    this.sourceCache = new Map<string, BookSource>();
    try {
      const allSources = await databaseManager.getAllEnabledBookSources();
      for (const source of allSources) {
        const key = `${source.name}_${source.url}`.toLowerCase();
        this.sourceCache.set(key, source);
      }
      Logger.debug(this.TAG, `缓存了${this.sourceCache.size}个已存在书源`);
    } catch (error) {
      Logger.error(this.TAG, `初始化书源缓存失败`);
    }
  }
  
  /**
   * 保存书源到数据库 - 带进度回调
   */
  private async saveSourcesWithProgress(sources: BookSource[]): Promise<number> {
    if (sources.length === 0) {
      return 0;
    }
    
    await this.initSourceCache();
    let savedCount = 0;
    const now = Date.now();
    const total = sources.length;
    
    for (let i = 0; i < sources.length; i += this.MAX_SOURCES_PER_BATCH) {
      if (this.isImportCancelled) {
        break;
      }
      
      const batch = this.getBatchSlice(sources, i, this.MAX_SOURCES_PER_BATCH);
      
      const savePromises: Promise<void>[] = [];
      
      for (const source of batch) {
        const promise = this.saveSingleSource(source, now).then(() => {
          savedCount++;
        }).catch((err: Error) => {
          Logger.error(this.TAG, `保存书源"${this.sanitizeString(source.name)}"失败`);
        });
        savePromises.push(promise);
      }
      
      await Promise.all(savePromises);
      
      const progress = 60 + Math.floor((savedCount / total) * 35);
      this.reportProgress(progress, 100, `保存进度: ${savedCount}/${total}`);
    }
    
    this.sourceCache = null;
    
    return savedCount;
  }
  
  /**
   * 保存单个书源
   */
  private async saveSingleSource(source: BookSource, now: number): Promise<void> {
    const existingSource = this.findExistingSourceFromCache(source);
    
    if (existingSource) {
      const updatedSource: BookSource = {
        id: existingSource.id,
        name: source.name,
        url: source.url,
        enabled: source.enabled,
        header: source.header,
        searchUrl: source.searchUrl,
        searchRule: source.searchRule,
        findRule: source.findRule,
        chapterRule: source.chapterRule,
        contentRule: source.contentRule,
        ruleType: source.ruleType,
        sort: source.sort,
        lastUpdateTime: now,
        addTime: existingSource.addTime
      };
      
      await databaseManager.upsertBookSource(updatedSource);
    } else {
      if (!source.id || source.id.trim() === '') {
        try {
          source.id = util.generateRandomUUID(true);
        } catch (error) {
          Logger.error('SourceImportManager', `生成UUID失败: ${error}`);
          source.id = `source_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        }
      }
      source.addTime = now;
      source.lastUpdateTime = now;
      await databaseManager.upsertBookSource(source);
      
      const key = `${source.name}_${source.url}`.toLowerCase();
      this.sourceCache!.set(key, source);
    }
  }
  
  /**
   * 从缓存查找已存在的书源
   */
  private findExistingSourceFromCache(source: BookSource): BookSource | null {
    if (!this.sourceCache) {
      return null;
    }
    
    const key = `${source.name}_${source.url}`.toLowerCase();
    return this.sourceCache.get(key) || null;
  }
  
  /**
   * 截断书源数组
   */
  private truncateSourcesArray(sources: BookSource[], maxLength: number): void {
    if (sources.length > maxLength) {
      sources.length = maxLength;
    }
  }

  /**
   * 获取限制数量的书源
   */
  private getLimitedSources(sources: BookSource[], maxCount: number): BookSource[] {
    const limitedSources: BookSource[] = [];
    const count = Math.min(sources.length, maxCount);
    for (let i = 0; i < count; i++) {
      limitedSources.push(sources[i]);
    }
    return limitedSources;
  }

  /**
   * 获取批次切片
   */
  private getBatchSlice(sources: BookSource[], start: number, batchSize: number): BookSource[] {
    const batch: BookSource[] = [];
    const end = Math.min(start + batchSize, sources.length);
    for (let j = start; j < end; j++) {
      batch.push(sources[j]);
    }
    return batch;
  }

  /**
   * 生成书源ID - 增强安全性
   */
  private generateSourceId(source: BookSource): string {
    // 基于名称和URL生成唯一ID
    const baseString = `${source.name}_${source.url}`;
    let hash = 0;
    
    for (let i = 0; i < baseString.length; i++) {
      const char = baseString.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    
    return `source_${Math.abs(hash).toString(36)}`;
  }
  
  /**
   * 获取安全的错误信息 - 增强安全限制
   */
  private getSafeErrorMessage(error: string | Error | undefined): string {
    if (typeof error === 'string') {
      // 限制错误信息长度
      const safeMessage = this.sanitizeString(error);
      return safeMessage.length > this.MAX_ERROR_MESSAGE_LENGTH ? 
             safeMessage.substring(0, this.MAX_ERROR_MESSAGE_LENGTH) + '...' : safeMessage;
    } else if (error instanceof Error) {
      const message = String(error.message);
      const safeMessage = this.sanitizeString(message);
      return safeMessage.length > this.MAX_ERROR_MESSAGE_LENGTH ? 
             safeMessage.substring(0, this.MAX_ERROR_MESSAGE_LENGTH) + '...' : safeMessage;
    } else {
      return '未知错误';
    }
  }
  
  /**
   * 字符串清理 - 增强安全防护
   */
  private sanitizeString(str: string | undefined): string {
    if (!str) return '';
    
    // 移除控制字符和特殊字符
    const cleaned = str.replace(/[\x00-\x1F\x7F-\x9F]/g, '')
                      .replace(/[\u2000-\u206F\u2E00-\u2E7F]/g, '');
    
    // 限制字符串长度
    return cleaned.length > this.MAX_SOURCE_NAME_LENGTH ? 
           cleaned.substring(0, this.MAX_SOURCE_NAME_LENGTH) : cleaned;
  }
  
  /**
   * 执行内容安全检查 - 增强安全防护
   * 修复了 JSON 中 JavaScript 代码深度检查不足的问题
   */
  private performContentSafetyCheck(content: string): SafetyCheckResult {
    const errors: string[] = [];
    
    // 检查可疑脚本
    if (this.containsSuspiciousContent(content)) {
      errors.push('检测到可疑脚本代码');
    }
    
    // 检查内容结构
    if (!this.isValidContentStructure(content)) {
      errors.push('内容结构不符合要求');
    }
    
    // 检查编码
    if (!this.isValidEncoding(content)) {
      errors.push('内容编码不符合要求');
    }
    
    // 检查嵌套深度
    if (this.hasExcessiveNesting(content)) {
      errors.push('内容嵌套深度过大');
    }
    
    // 检查特殊字符注入
    if (this.containsDangerousCharacters(content)) {
      errors.push('检测到危险字符');
    }
    
    // 新增：深度检查 JSON 中的 header 字段
    if (this.containsMaliciousHeaders(content)) {
      errors.push('检测到请求头中的恶意代码');
    }
    
    // 新增：检查 JavaScript 代码注入
    if (this.containsJavaScriptInjection(content)) {
      errors.push('检测到 JavaScript 代码注入');
    }
    
    return {
      isSafe: errors.length === 0,
      message: errors.length > 0 ? '书源内容包含安全风险' : undefined,
      errors: errors.length > 0 ? errors : undefined
    };
  }
  
  /**
   * 检查内容安全性 - 增强安全防护
   */
  private containsSuspiciousContent(content: string): boolean {
    // 使用安全的正则表达式模式，避免ReDoS攻击
    // 注意：移除了对模板语法 ${} 和 {{}} 的检测，因为书源中经常使用这些语法
    const suspiciousPatterns = [
      /<(script|iframe|object|embed)[^>]*>/gi,
      /javascript:/gi,
      /vbscript:/gi,
      /on(load|error|click|submit)\s*=/gi,
      /eval\s*\(/gi,
      /alert\s*\(/gi,
      /document\.(cookie|write)/gi,
      /window\.(location|open)/gi,
      /XMLHttpRequest/gi,
      /fetch\s*\(/gi
      // 移除了 /\$\{.*\}/gi 和 /\{\{.*\}\}/gi
      // 因为书源中经常使用 {{key}} 等模板语法，这是正常的
    ];

    for (const pattern of suspiciousPatterns) {
      // 限制正则表达式执行时间
      const startTime = Date.now();
      const result = pattern.test(content);
      const elapsed = Date.now() - startTime;

      // 如果正则表达式执行时间过长，视为可疑
      if (elapsed > 100) {
        return true;
      }

      if (result) {
        return true;
      }
    }

    return false;
  }

  /**
   * 检查危险字符 - 新增安全防护
   */
  private containsDangerousCharacters(content: string): boolean {
    // 检查潜在的注入字符
    const dangerousChars = [
      /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, // 控制字符
      /[\u2028\u2029]/g, // 行分隔符和段落分隔符
      /[\uFEFF]/g, // 零宽空格
      /[\uFFF0-\uFFFF]/g // 特殊用途Unicode字符
    ];
    
    for (const pattern of dangerousChars) {
      if (pattern.test(content)) {
        return true;
      }
    }
    
    return false;
  }
  
  /**
   * 新增：检查请求头中的恶意代码
   */
  private containsMaliciousHeaders(content: string): boolean {
    try {
      type JsonValue = string | number | boolean | null | JsonObject | JsonArray;
      class JsonObject {
        entries: Array<[string, JsonValue]> = [];
        constructor(entries: Array<[string, JsonValue]>) {
          this.entries = entries;
        }
      }
      interface JsonArray extends Array<JsonValue> {}
      
      const parsedRaw: object = JSON.parse(content) as object;
      const parsedEntries: Array<[string, JsonValue]> = Object.entries(parsedRaw) as Array<[string, JsonValue]>;
      const parsed: JsonObject = new JsonObject(parsedEntries);

      const checkHeaders = (obj: JsonValue): boolean => {
        if (!obj || typeof obj !== 'object') return false;

        if (Array.isArray(obj)) {
          for (const item of obj) {
            if (checkHeaders(item)) return true;
          }
          return false;
        }

        const jsonObj = obj as JsonObject;
        const entries = jsonObj.entries;
        for (let i = 0; i < entries.length; i++) {
          const key = entries[i][0];
          const value = entries[i][1];
          if (key.toLowerCase() === 'header' && typeof value === 'string') {
            const maliciousPatterns = [
              /javascript:/gi,
              /vbscript:/gi,
              /eval\s*\(/gi,
              /function\s*\(/gi,
              /=>\s*\{/g,
              /<script/gi,
              /on\w+\s*=/gi,
            ];
            
            for (const pattern of maliciousPatterns) {
              if (pattern.test(value)) {
                Logger.warn(this.TAG, `检测到 header 字段中的恶意代码`);
                return true;
              }
            }
          }
          
          if (typeof value === 'object' && value !== null) {
            if (checkHeaders(value)) return true;
          }
        }
        
        return false;
      };
      
      return checkHeaders(parsed);
    } catch (e) {
      return false;
    }
  }
  
  /**
   * 新增：检查 JavaScript 代码注入
   */
  private containsJavaScriptInjection(content: string): boolean {
    const jsInjectionPatterns = [
      // 函数定义
      /function\s*\w*\s*\([^)]*\)\s*\{/gi,
      // 箭头函数
      /\(\s*\)\s*=>\s*\{/g,
      /\w+\s*=>\s*\{/g,
      // 立即执行函数
      /\(\s*function\s*\(\s*\)\s*\{/gi,
      /\(\s*\)\s*=>/g,
      // 危险的全局对象访问
      /window\s*\.\s*\w+/gi,
      /document\s*\.\s*\w+/gi,
      /globalThis\s*\.\s*\w+/gi,
      // 动态代码执行
      /eval\s*\(/gi,
      /Function\s*\(/gi,
      /setTimeout\s*\(\s*["']/gi,
      /setInterval\s*\(\s*["']/gi,
      // 原型链污染
      /__proto__/g,
      /prototype\s*\.\s*\w+\s*=/g,
      // 构造函数
      /constructor\s*\.\s*\w+/gi,
    ];
    
    for (const pattern of jsInjectionPatterns) {
      if (pattern.test(content)) {
        Logger.warn(this.TAG, `检测到 JavaScript 代码注入模式: ${pattern.source}`);
        return true;
      }
    }
    
    return false;
  }
  
  /**
   * 检查书源安全性 - 增强安全防护
   */
  private isSafeSource(source: BookSource): boolean {
    if (source.name && source.name.length > this.MAX_SOURCE_NAME_LENGTH * 2) {
      return false;
    }
    
    if (!source.url) {
      return false;
    }
    
    if (source.url.length > this.MAX_URL_LENGTH * 2) {
      return false;
    }
    
    if (source.searchUrl && source.searchUrl.length > this.MAX_URL_LENGTH * 2) {
      return false;
    }
    
    if (source.header && source.header.length > this.MAX_HEADER_LENGTH * 2) {
      return false;
    }
    
    if (!this.isValidUrlProtocol(source.url)) {
      return false;
    }
    
    if (source.searchUrl && !this.isValidUrlProtocol(source.searchUrl)) {
      return false;
    }
    
    return true;
  }

  /**
   * 验证URL格式 - 新增安全防护
   */
  private isValidUrlFormat(url: string): boolean {
    try {
      // 简单的URL格式验证
      if (url.includes(' ')) return false;
      if (url.includes('\n') || url.includes('\r') || url.includes('\t')) return false;
      if (url.includes('\\')) return false;
      
      // 检查URL编码
      if (encodeURI(url) !== url && decodeURI(url) !== url) {
        return false;
      }
      
      return true;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 验证URL协议安全性
   */
  private isValidUrlProtocol(url: string): boolean {
    try {
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 验证内容结构
   */
  private isValidContentStructure(content: string): boolean {
    // 检查内容是否为空
    if (!content || content.trim().length === 0) {
      return false;
    }
    
    // 检查内容是否过大
    if (content.length > this.MAX_CONTENT_SIZE) {
      return false;
    }
    
    // 检查行数是否过多（防止DoS攻击）
    const lines = content.split('\n');
    if (lines.length > this.MAX_LINE_COUNT) {
      return false;
    }
    
    return true;
  }
  
  /**
   * 验证编码 - 使用HarmonyOS兼容的方法
   */
  private isValidEncoding(content: string): boolean {
    // 简单的UTF-8兼容性检查
    try {
      // 检查是否包含无效的UTF-8序列
      for (let i = 0; i < content.length; i++) {
        const charCode = content.charCodeAt(i);
        // 基本ASCII字符检查（0-127）
        if (charCode > 127) {
          // 对于非ASCII字符，进行简单的UTF-8连续性检查
          if (charCode >= 0xD800 && charCode <= 0xDFFF) {
            // 代理对检查
            if (i + 1 < content.length) {
              const nextCharCode = content.charCodeAt(i + 1);
              if (nextCharCode >= 0xDC00 && nextCharCode <= 0xDFFF) {
                i++; // 跳过代理对的高位
                continue;
              }
            }
            return false; // 无效的代理对
          }
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 检查嵌套深度
   */
  private hasExcessiveNesting(content: string): boolean {
    // 检查JSON/XML嵌套深度
    let depth = 0;
    let maxDepth = 0;
    
    for (let i = 0; i < content.length; i++) {
      const char = content[i];
      if (char === '{' || char === '[' || char === '<') {
        depth++;
        if (depth > maxDepth) {
          maxDepth = depth;
        }
      } else if (char === '}' || char === ']' || char === '>') {
        depth--;
      }
      
      // 限制最大嵌套深度
      if (maxDepth > this.MAX_NESTING_DEPTH) {
        return true;
      }
    }
    
    return false;
  }
  
  /**
   * 验证内容是否适合解析
   */
  private isValidContentForParsing(content: string): boolean {
    // 检查基本格式
    if (!content || typeof content !== 'string') {
      return false;
    }
    
    // 检查内容长度
    if (content.length < 10 || content.length > this.MAX_CONTENT_SIZE) {
      return false;
    }
    
    // 检查是否包含有效字符
    const validCharCount = content.replace(/[^\x20-\x7E\n\r\t]/g, '').length;
    if (validCharCount < content.length * 0.8) {
      return false; // 超过20%的字符为不可见字符
    }
    
    return true;
  }
  
  /**
   * 批量更新书源状态 - 增强安全限制
   */
  async updateSourcesStatus(sources: BookSource[]): Promise<UpdateStatusResult> {
    const startTime = Date.now();
    
    try {
      if (!sources || sources.length === 0) {
        return {
          success: false,
          updatedCount: 0,
          totalCount: 0,
          errors: ['没有书源需要更新']
        };
      }
      
      // 限制更新数量 - 增强安全限制
      const sourcesToUpdate = this.getLimitedSources(sources, this.MAX_SOURCES_PER_IMPORT);
      
      Logger.info(this.TAG, `开始批量更新${sourcesToUpdate.length}个书源状态`);
      
      const results = await SourceValidator.validateSourcesBatch(sourcesToUpdate);
      
      let updatedCount = 0;
      const updateErrors: string[] = [];
      
      for (const result of results) {
        try {
          // 安全检查
          if (!this.isSafeSource(result.source)) {
            updateErrors.push(`跳过不安全书源: ${this.sanitizeString(result.source.name)}`);
            continue;
          }
          
          result.source.enabled = result.isAvailable;
          
          await databaseManager.upsertBookSource(result.source);
          updatedCount++;
          
        } catch (error) {
          updateErrors.push(`更新书源"${this.sanitizeString(result.source.name)}"失败：${this.getSafeErrorMessage(error)}`);
        }
      }
      
      // 修复：使用duration变量
      const duration = Date.now() - startTime;
      Logger.info(this.TAG, `书源状态更新完成，成功更新${updatedCount}/${sourcesToUpdate.length}个书源，耗时${duration}ms`);
      
      return {
        success: updatedCount > 0,
        updatedCount: updatedCount,
        totalCount: sourcesToUpdate.length,
        errors: updateErrors
      };
      
    } catch (error) {
      // 修复：使用duration变量
      const duration = Date.now() - startTime;
      Logger.error(this.TAG, `书源状态更新异常，耗时${duration}ms`);
      
      return {
        success: false,
        updatedCount: 0,
        totalCount: sources.length,
        errors: [this.getSafeErrorMessage(error)]
      };
    }
  }
  
  /**
   * 导入书源文件 - 增强安全验证
   */
  async importSourceFile(filePath: string): Promise<ImportResult> {
    try {
      // 文件路径安全检查
      if (!this.isSafeFilePath(filePath)) {
        return {
          success: false,
          message: '文件路径不安全',
          importedCount: 0,
          totalCount: 0,
          errors: ['文件路径包含危险字符或格式不正确']
        };
      }
      
      // 读取文件内容
      const content = await this.readFileContent(filePath);
      
      // 调用标准的导入方法
      return await this.importSources(content);
      
    } catch (error) {
      Logger.error(this.TAG, `导入书源文件失败：${this.getSafeErrorMessage(error)}`);

      return {
        success: false,
        message: '书源文件导入失败',
        importedCount: 0,
        totalCount: 0,
        errors: [this.getSafeErrorMessage(error)]
      };
    }
  }

  /**
   * 验证文件路径安全性 - 增强版
   * 修复了路径遍历漏洞，支持多重编码绕过检测
   */
  /**
   * 检查文件路径是否安全
   * 使用SecurityUtils进行深度安全检查，修复路径遍历漏洞
   */
  private isSafeFilePath(filePath: string): boolean {
    // 使用SecurityUtils的深度解码和路径检查
    const decodedPath = SecurityUtils.deepDecodePath(filePath);
    const normalizedPath = SecurityUtils.normalizePath(decodedPath);
    
    // 长度检查
    if (!filePath || filePath.length > 4096) {
      Logger.warn(this.TAG, '文件路径为空或过长');
      return false;
    }

    // 使用SecurityUtils验证扩展名
    if (!SecurityUtils.isAllowedExtension(normalizedPath)) {
      Logger.warn(this.TAG, `文件路径扩展名不合法: ${normalizedPath}`);
      return false;
    }

    // 检查空字符注入
    if (filePath.includes('\0') || filePath.includes('%00')) {
      Logger.warn(this.TAG, '文件路径包含空字节');
      return false;
    }

    // 检查双斜杠
    if (normalizedPath.includes('//') || normalizedPath.includes('\\\\')) {
      Logger.warn(this.TAG, '文件路径包含双斜杠');
      return false;
    }

    // 检查危险的字符和模式
    const dangerousPatterns = [
      /~\//,                     // 用户主目录
      /\$\(/, /\$\{/,            // 命令注入
      /`/,                       // 命令替换
      /\|/,                      // 管道
      /;|&/,                     // 命令分隔符
      />|</,                     // 重定向
      /\x0a|\x0d/,               // 换行符
      /%0a|%0d|%0A|%0D/i,       // URL 编码换行符
    ];

    for (const pattern of dangerousPatterns) {
      if (pattern.test(normalizedPath)) {
        Logger.warn(this.TAG, `文件路径包含危险模式: ${pattern.source}`);
        return false;
      }
    }

    // 检查 Unicode 规范化攻击
    const unicodeDots = /\.\u002e|\u002e\./;
    if (unicodeDots.test(normalizedPath)) {
      Logger.warn(this.TAG, '文件路径包含Unicode点字符攻击');
      return false;
    }

    // 检查路径中的非法字符
    // 只允许字母、数字、下划线、连字符、点、斜杠和冒号 (Windows 盘符)
    const safePathPattern = /^[a-zA-Z0-9_\-./\\:]+$/;
    if (!safePathPattern.test(normalizedPath)) {
      Logger.warn(this.TAG, `文件路径包含非法字符: ${normalizedPath}`);
      return false;
    }

    // 检查绝对路径是否指向允许的目录
    // 禁止访问系统目录
    const forbiddenPaths = [
      '/etc/', '/usr/', '/bin/', '/sbin/', '/lib/', '/lib64/',
      '/boot/', '/dev/', '/proc/', '/sys/', '/root/', '/home/',
      'C:/Windows/', 'C:/Program Files/', 'C:/ProgramData/',
      '/System/', '/Applications/', '/Library/',
    ];
    
    for (const forbidden of forbiddenPaths) {
      if (normalizedPath.toLowerCase().startsWith(forbidden.toLowerCase())) {
        Logger.warn(this.TAG, `文件路径指向禁止访问的系统目录: ${forbidden}`);
        return false;
      }
    }

    return true;
  }

  /**
   * 规范化路径 - 统一处理不同操作系统的路径分隔符
   */
  private normalizePath(filePath: string): string {
    let normalized = filePath.replace(/\\/g, '/');
    
    while (normalized.includes('//')) {
      normalized = normalized.replace(/\/\//g, '/');
    }
    
    while (normalized.includes('/./')) {
      normalized = normalized.replace(/\/\.\//g, '/');
    }
    
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    
    if (normalized.endsWith('/')) {
      normalized = normalized.slice(0, -1);
    }
    
    return normalized;
  }

  /**
   * 读取文件内容 - 增强安全防护
   */
  private async readFileContent(filePath: string): Promise<string> {
    // 这里需要根据实际的HarmonyOS文件API实现
    // 简化实现：返回空字符串
    Logger.info(this.TAG, `读取文件内容：${filePath}`);
    return '';
  }
}

export default new SourceImportManager();
