/**
 * 书源导入管理器 - 统一管理书源的导入、验证和存储
 */

import { BookSource } from '../models/BookSource';
import BookSourceParser from './BookSourceParser';
import SourceValidator from './SourceValidator';
import { DatabaseManager } from './DatabaseManager';
import { Logger } from './Logger';

class SourceImportManager {
  
  private TAG: string = 'SourceImportManager';
  
  // 安全配置
  private readonly MAX_CONTENT_SIZE = 10 * 1024 * 1024; // 10MB
  private readonly MAX_SOURCES_PER_IMPORT = 1000;
  private readonly MAX_SOURCES_PER_BATCH = 50;

  /**
   * 导入书源
   * @param content 书源内容
   * @param format 格式类型（可选，自动检测）
   * @returns 导入结果
   */
  async importSources(content: string, format?: string): Promise<ImportResult> {
    const startTime = Date.now();
    
    try {
      Logger.info(this.TAG, '开始导入书源');
      
      // 验证输入内容
      if (!content || content.trim().length === 0) {
        return {
          success: false,
          message: '书源内容不能为空',
          importedCount: 0,
          totalCount: 0,
          errors: ['书源内容为空']
        };
      }
      
      // 验证内容大小
      if (content.length > this.MAX_CONTENT_SIZE) {
        return {
          success: false,
          message: '书源内容过大',
          importedCount: 0,
          totalCount: 0,
          errors: [`书源内容超过${this.MAX_CONTENT_SIZE / 1024 / 1024}MB限制`]
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
      
      // 限制导入数量
      if (parsedSources.length > this.MAX_SOURCES_PER_IMPORT) {
        Logger.warn(this.TAG, `导入书源数量过多，限制为${this.MAX_SOURCES_PER_IMPORT}个`);
        parsedSources.splice(this.MAX_SOURCES_PER_IMPORT);
      }
      
      Logger.debug(this.TAG, `解析到${parsedSources.length}个书源，开始验证`);
      
      // 验证书源
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
   * 验证并过滤书源
   */
  private async validateAndFilterSources(sources: Array<BookSource>): Promise<ValidationResult> {
    const validSources: Array<BookSource> = [];
    const warnings: Array<string> = [];
    const errors: Array<string> = [];
    
    for (const source of sources) {
      try {
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
   * 保存书源到数据库
   */
  private async saveSources(sources: Array<BookSource>): Promise<number> {
    if (sources.length === 0) {
      return 0;
    }
    
    let savedCount = 0;
    
    // 分批保存，避免数据库压力过大
    for (let i = 0; i < sources.length; i += this.MAX_SOURCES_PER_BATCH) {
      const batch = sources.slice(i, i + this.MAX_SOURCES_PER_BATCH);
      
      for (const source of batch) {
        try {
          // 检查是否已存在（基于名称和URL）
          const existingSource = await this.findExistingSource(source);
          
          if (existingSource) {
            // 更新现有书源
            await DatabaseManager.updateBookSource({
              ...existingSource,
              ...source,
              lastUpdateTime: Date.now()
            });
            Logger.debug(this.TAG, `更新书源：${this.sanitizeString(source.name)}`);
          } else {
            // 添加新书源
            await DatabaseManager.addBookSource(source);
            Logger.debug(this.TAG, `添加新书源：${this.sanitizeString(source.name)}`);
          }
          
          savedCount++;
          
        } catch (error) {
          Logger.error(this.TAG, `保存书源"${this.sanitizeString(source.name)}"失败`);
        }
      }
      
      // 批次间延迟
      if (i + this.MAX_SOURCES_PER_BATCH < sources.length) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }
    
    return savedCount;
  }
  
  /**
   * 查找已存在的书源
   */
  private async findExistingSource(source: BookSource): Promise<BookSource | null> {
    try {
      // 这里需要根据实际的数据访问方法实现
      // 简化实现：基于名称和URL匹配
      const allSources = await DatabaseManager.getAllBookSources();
      
      return allSources.find(existing => 
        existing.name === source.name || 
        existing.url === source.url
      ) || null;
      
    } catch (error) {
      Logger.error(this.TAG, `查找已存在书源失败`);
      return null;
    }
  }
  
  /**
   * 生成书源ID
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
   * 获取安全的错误信息
   */
  private getSafeErrorMessage(error: any): string {
    if (typeof error === 'string') {
      // 限制错误信息长度
      return this.sanitizeString(error).substring(0, 200);
    } else if (error && error.message) {
      const message = String(error.message);
      return this.sanitizeString(message).substring(0, 200);
    } else {
      return '未知错误';
    }
  }
  
  /**
   * 字符串清理
   */
  private sanitizeString(str: string | undefined): string {
    if (!str) return '';
    
    // 移除控制字符和特殊字符
    return str.replace(/[\x00-\x1F\x7F]/g, '').substring(0, 100);
  }
  
  /**
   * 批量更新书源状态
   */
  async updateSourcesStatus(sources: Array<BookSource>): Promise<UpdateStatusResult> {
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
      
      // 限制更新数量
      const sourcesToUpdate = sources.slice(0, this.MAX_SOURCES_PER_IMPORT);
      
      Logger.info(this.TAG, `开始批量更新${sourcesToUpdate.length}个书源状态`);
      
      const results = await SourceValidator.validateSourcesBatch(sourcesToUpdate);
      
      let updatedCount = 0;
      const updateErrors: Array<string> = [];
      
      for (const result of results) {
        try {
          result.source.enabled = result.isAvailable;
          
          await DatabaseManager.updateBookSource(result.source);
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
}

// 导入结果类型
export interface ImportResult {
  success: boolean;
  message: string;
  importedCount: number;
  totalCount: number;
  warnings?: Array<string>;
  errors?: Array<string>;
}

// 验证结果类型
interface ValidationResult {
  validSources: Array<BookSource>;
  warnings: Array<string>;
  errors: Array<string>;
}

// 更新状态结果类型
export interface UpdateStatusResult {
  success: boolean;
  updatedCount: number;
  totalCount: number;
  errors?: Array<string>;
}

export default new SourceImportManager();