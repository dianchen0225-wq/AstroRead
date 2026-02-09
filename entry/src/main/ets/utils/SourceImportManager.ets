/**
 * 书源导入管理器 - 统一管理书源的导入、验证和存储
 * 安全加固版本 - 修复了多个安全漏洞
 */

import { BookSource } from '../models/BookSource';
import BookSourceParser from './BookSourceParser';
import SourceValidator from './SourceValidator';
import { databaseManager } from './DatabaseManager';
import { Logger } from './Logger';

class SourceImportManager {
  
  private TAG: string = 'SourceImportManager';
  
  // 安全配置 - 增强安全限制
  private readonly MAX_CONTENT_SIZE = 5 * 1024 * 1024; // 降低到5MB
  private readonly MAX_SOURCES_PER_IMPORT = 500; // 降低导入数量限制
  private readonly MAX_SOURCES_PER_BATCH = 20; // 降低批量处理数量
  private readonly MAX_ERROR_MESSAGE_LENGTH = 100; // 限制错误信息长度
  private readonly MAX_SOURCE_NAME_LENGTH = 100; // 限制书源名称长度

  /**
   * 导入书源 - 增强安全验证
   * @param content 书源内容
   * @param format 格式类型（可选，自动检测）
   * @returns 导入结果
   */
  async importSources(content: string, format?: string): Promise<ImportResult> {
    const startTime = Date.now();
    
    try {
      Logger.info(this.TAG, '开始导入书源');
      
      // 增强输入内容验证
      if (!content || content.trim().length === 0) {
        return {
          success: false,
          message: '书源内容不能为空',
          importedCount: 0,
          totalCount: 0,
          errors: ['书源内容为空']
        };
      }
      
      // 验证内容大小 - 增强安全限制
      if (content.length > this.MAX_CONTENT_SIZE) {
        return {
          success: false,
          message: '书源内容过大',
          importedCount: 0,
          totalCount: 0,
          errors: [`书源内容超过${this.MAX_CONTENT_SIZE / 1024 / 1024}MB限制`]
        };
      }
      
      // 检查内容安全性
      if (this.containsSuspiciousContent(content)) {
        return {
          success: false,
          message: '书源内容包含可疑代码',
          importedCount: 0,
          totalCount: 0,
          errors: ['检测到潜在的安全威胁']
        };
      }
      
      // 自动检测格式
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
      
      // 解析书源
      const parsedSources = BookSourceParser.parseSources(content, detectedFormat);
      
      if (parsedSources.length === 0) {
        return {
          success: false,
          message: '没有找到有效的书源',
          importedCount: 0,
          totalCount: 0,
          errors: ['解析后没有找到有效书源']
        };
      }
      
      // 限制导入数量 - 增强安全限制
      if (parsedSources.length > this.MAX_SOURCES_PER_IMPORT) {
        Logger.warn(this.TAG, `导入书源数量过多，限制为${this.MAX_SOURCES_PER_IMPORT}个`);
        this.truncateSourcesArray(parsedSources, this.MAX_SOURCES_PER_IMPORT);
      }
      
      Logger.debug(this.TAG, `解析到${parsedSources.length}个书源，开始验证`);
      
      // 验证书源 - 增强安全验证
      const validationResults = await this.validateAndFilterSources(parsedSources);
      
      if (validationResults.validSources.length === 0) {
        return {
          success: false,
          message: '所有书源验证失败',
          importedCount: 0,
          totalCount: parsedSources.length,
          errors: validationResults.errors
        };
      }
      
      // 保存到数据库
      const savedCount = await this.saveSources(validationResults.validSources);
      
      const duration = Date.now() - startTime;
      Logger.info(this.TAG, `书源导入完成，成功导入${savedCount}/${parsedSources.length}个书源，耗时${duration}ms`);
      
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
      Logger.error(this.TAG, `书源导入异常`);
      
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
   * 验证并过滤书源 - 增强安全验证
   */
  private async validateAndFilterSources(sources: BookSource[]): Promise<ValidationResult> {
    const validSources: BookSource[] = [];
    const warnings: string[] = [];
    const errors: string[] = [];
    
    for (const source of sources) {
      try {
        // 前置安全检查
        if (!this.isSafeSource(source)) {
          errors.push(`书源"${this.sanitizeString(source.name)}"包含不安全配置`);
          continue;
        }
        
        // 格式验证
        const formatResult = SourceValidator.validateSourceFormat(source);
        if (!formatResult.isValid) {
          errors.push(`书源"${this.sanitizeString(source.name)}"格式错误：${formatResult.errors.join(', ')}`);
          continue;
        }
        
        // 可用性验证
        const availabilityResult = await SourceValidator.validateSourceAvailability(source);
        
        if (!availabilityResult.isAvailable) {
          warnings.push(`书源"${this.sanitizeString(source.name)}"暂时不可用：${this.sanitizeString(availabilityResult.error || '未知错误')}`);
          // 仍然保存，但标记为需要检查
          source.enabled = false;
        }
        
        // 生成唯一ID
        if (!source.id) {
          source.id = this.generateSourceId(source);
        }
        
        validSources.push(source);
        
      } catch (error) {
        errors.push(`书源"${this.sanitizeString(source.name)}"验证异常：${this.getSafeErrorMessage(error)}`);
      }
    }
    
    return {
      validSources: validSources,
      warnings: warnings,
      errors: errors
    };
  }
  
  /**
   * 保存书源到数据库 - 增强错误处理
   */
  private async saveSources(sources: BookSource[]): Promise<number> {
    if (sources.length === 0) {
      return 0;
    }
    
    let savedCount = 0;
    
    // 分批保存，避免数据库压力过大
    for (let i = 0; i < sources.length; i += this.MAX_SOURCES_PER_BATCH) {
      const batch = this.getBatchSlice(sources, i, this.MAX_SOURCES_PER_BATCH);
      
      for (const source of batch) {
        try {
          // 检查是否已存在（基于名称和URL）
          const existingSource = await this.findExistingSource(source);
          
          if (existingSource) {
            // 更新现有书源 - 使用对象合并而不是spread
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
              lastUpdateTime: Date.now(),
              addTime: existingSource.addTime
            };
            
            await databaseManager.upsertBookSource(updatedSource);
            Logger.debug(this.TAG, `更新书源：${this.sanitizeString(source.name)}`);
          } else {
            // 添加新书源
            await databaseManager.upsertBookSource(source);
            Logger.debug(this.TAG, `添加新书源：${this.sanitizeString(source.name)}`);
          }
          
          savedCount++;
          
        } catch (error) {
          Logger.error(this.TAG, `保存书源"${this.sanitizeString(source.name)}"失败`);
        }
      }
      
      // 批次间延迟 - 增强性能保护
      if (i + this.MAX_SOURCES_PER_BATCH < sources.length) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // 增加到1秒延迟
      }
    }
    
    return savedCount;
  }
  
  /**
   * 查找已存在的书源 - 增强错误处理
   */
  private async findExistingSource(source: BookSource): Promise<BookSource | null> {
    try {
      // 这里需要根据实际的数据访问方法实现
      // 简化实现：基于名称和URL匹配
      const allSources: BookSource[] = await databaseManager.getAllEnabledBookSources();
      
      for (let i = 0; i < allSources.length; i++) {
        if (allSources[i].name === source.name || allSources[i].url === source.url) {
          return allSources[i];
        }
      }
      return null;
      
    } catch (error) {
      Logger.error(this.TAG, `查找已存在书源失败`);
      return null;
    }
  }
  
  /**
   * 截断书源数组 - 避免泛型类型推断问题
   */
  private truncateSourcesArray(sources: BookSource[], maxLength: number): void {
    if (sources.length > maxLength) {
      sources.length = maxLength;
    }
  }

  /**
   * 获取限制数量的书源 - 避免泛型类型推断问题
   */
  private getLimitedSources(sources: BookSource[], maxCount: number): BookSource[] {
    const limitedSources: BookSource[] = [];
    for (let i = 0; i < Math.min(sources.length, maxCount); i++) {
      limitedSources.push(sources[i]);
    }
    return limitedSources;
  }

  /**
   * 获取批次切片 - 避免泛型类型推断问题
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
    const cleaned = str.replace(/[\x00-\x1F\x7F]/g, '');
    
    // 限制字符串长度
    return cleaned.length > this.MAX_SOURCE_NAME_LENGTH ? 
           cleaned.substring(0, this.MAX_SOURCE_NAME_LENGTH) : cleaned;
  }
  
  /**
   * 检查内容安全性 - 新增安全防护
   */
  private containsSuspiciousContent(content: string): boolean {
    const suspiciousPatterns = [
      /<script[^>]*>[\s\S]*?<\/script>/gi,
      /javascript:/gi,
      /vbscript:/gi,
      /onload\s*=/gi,
      /onerror\s*=/gi,
      /onclick\s*=/gi,
      /eval\s*\(/gi,
      /alert\s*\(/gi,
      /document\.cookie/gi,
      /window\.location/gi,
      /XMLHttpRequest/gi,
      /fetch\s*\(/gi
    ];
    
    for (const pattern of suspiciousPatterns) {
      if (pattern.test(content)) {
        return true;
      }
    }
    
    return false;
  }
  
  /**
   * 检查书源安全性 - 新增安全防护
   */
  private isSafeSource(source: BookSource): boolean {
    // 检查名称长度
    if (source.name && source.name.length > this.MAX_SOURCE_NAME_LENGTH) {
      return false;
    }
    
    // 检查URL安全性
    if (!source.url || source.url.length > 2048) {
      return false;
    }
    
    // 检查搜索URL安全性
    if (source.searchUrl && source.searchUrl.length > 2048) {
      return false;
    }
    
    // 检查请求头安全性
    if (source.header && source.header.length > 5000) {
      return false;
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
      
      const duration = Date.now() - startTime;
      Logger.info(this.TAG, `书源状态更新完成，成功更新${updatedCount}/${sourcesToUpdate.length}个书源，耗时${duration}ms`);
      
      return {
        success: updatedCount > 0,
        updatedCount: updatedCount,
        totalCount: sourcesToUpdate.length,
        errors: updateErrors
      };
      
    } catch (error) {
      Logger.error(this.TAG, `批量更新书源状态异常`);
      
      return {
        success: false,
        updatedCount: 0,
        totalCount: sources.length || 0,
        errors: [this.getSafeErrorMessage(error)]
      };
    }
  }
  
  /**
   * 导入书源文件 - 新增安全方法
   */
  async importSourceFile(filePath: string): Promise<ImportResult> {
    try {
      // 验证文件路径安全性
      if (!this.isSafeFilePath(filePath)) {
        return {
          success: false,
          message: '文件路径不安全',
          importedCount: 0,
          totalCount: 0,
          errors: ['检测到不安全的文件路径']
        };
      }
      
      // 这里需要实现文件读取逻辑
      // 由于文件操作需要特定API，这里留空供后续实现
      
      return {
        success: false,
        message: '文件导入功能暂未实现',
        importedCount: 0,
        totalCount: 0,
        errors: ['文件导入功能正在开发中']
      };
      
    } catch (error) {
      Logger.error(this.TAG, `导入书源文件异常`);
      
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
   * 检查文件路径安全性 - 新增安全防护
   */
  private isSafeFilePath(filePath: string): boolean {
    // 禁止的路径模式
    const forbiddenPatterns = [
      /\.\.\//g, // 禁止上级目录引用
      /\/etc\//g, // 禁止系统目录
      /\/system\//g,
      /\/data\/local\//g
    ];
    
    for (const pattern of forbiddenPatterns) {
      if (pattern.test(filePath)) {
        return false;
      }
    }
    
    // 限制文件路径长度
    if (filePath.length > 500) {
      return false;
    }
    
    return true;
  }
}

// 导入结果类型
export interface ImportResult {
  success: boolean;
  message: string;
  importedCount: number;
  totalCount: number;
  warnings?: string[];
  errors?: string[];
}

// 验证结果类型
interface ValidationResult {
  validSources: BookSource[];
  warnings: string[];
  errors: string[];
}

// 更新状态结果类型
export interface UpdateStatusResult {
  success: boolean;
  updatedCount: number;
  totalCount: number;
  errors?: string[];
}

export default new SourceImportManager();