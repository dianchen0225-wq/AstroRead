/**
 * 书源验证器 - 验证书源的有效性和可用性
 */

import { BookSource } from '../models/BookSource';
import { NetworkManager } from './NetworkManager';
import { Logger } from './Logger';

// 验证结果类型定义
interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

// 可用性验证结果类型定义
interface AvailabilityResult {
  isAvailable: boolean;
  responseTime: number;
  error?: string;
}

// 批量验证结果类型定义
interface BatchValidationResult {
  source: BookSource;
  isAvailable: boolean;
  responseTime: number;
  error?: string;
}

// 搜索功能验证结果类型定义
interface SearchValidationResult {
  canSearch: boolean;
  resultCount: number;
  error?: string;
}

class SourceValidator {
  
  private TAG: string = 'SourceValidator';
  
  // 安全配置
  private readonly MAX_URL_LENGTH = 2048;
  private readonly MAX_RESPONSE_SIZE = 10 * 1024 * 1024; // 10MB
  private readonly REQUEST_TIMEOUT = 10000; // 10秒
  private readonly MAX_SOURCES_PER_BATCH = 50;

  /**
   * 验证书源基本格式
   */
  validateSourceFormat(source: BookSource): ValidationResult {
    const errors: string[] = [];
    
    // 名称验证
    if (!source.name || source.name.trim().length === 0) {
      errors.push('书源名称不能为空');
    } else if (source.name.length > 100) {
      errors.push('书源名称不能超过100个字符');
    }
    
    // URL验证
    if (!source.url || !this.isValidUrl(source.url)) {
      errors.push('书源URL格式无效');
    }
    
    // 搜索URL验证（可选）
    if (source.searchUrl && !this.isValidUrl(source.searchUrl)) {
      errors.push('搜索URL格式无效');
    }
    
    // 排序值验证
    if (source.sort && (source.sort < 0 || source.sort > 1000)) {
      errors.push('排序值必须在0-1000之间');
    }
    
    // 规则类型验证
    if (!['xpath', 'jsonpath', 'regex'].includes(source.ruleType)) {
      errors.push('无效的规则类型');
    }
    
    // 验证请求头格式
    if (source.header) {
      try {
        const headers = JSON.parse(source.header);
        if (typeof headers !== 'object' || headers === null) {
          errors.push('请求头格式无效');
        } else {
          // 验证headers key和value长度
          for (const [key, value] of Object.entries(headers)) {
            if (typeof key !== 'string' || key.length > 100) {
              errors.push('请求头键名过长');
            }
            if (typeof value !== 'string' || value.length > 1000) {
              errors.push('请求头值过长');
            }
          }
        }
      } catch (error) {
        errors.push('请求头JSON格式错误');
      }
    }
    
    const result: ValidationResult = {
      isValid: errors.length === 0,
      errors: errors
    };
    
    return result;
  }
  
  /**
   * 验证书源可用性（网络测试）
   */
  async validateSourceAvailability(source: BookSource): Promise<AvailabilityResult> {
    const startTime = Date.now();
    
    try {
      // 测试基础URL
      const testUrl = source.searchUrl || source.url;
      if (!testUrl) {
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: 0,
          error: '没有可测试的URL'
        };
        return result;
      }
      
      // 验证URL
      if (!this.isValidUrl(testUrl)) {
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: 0,
          error: '测试URL格式无效'
        };
        return result;
      }
      
      Logger.debug(this.TAG, `开始验证书源可用性：${source.name}`);
      
      // 发送测试请求（带超时）
      const networkManager = NetworkManager.getInstance();
      
      // 设置请求头
      const headers: Record<string, string> | undefined = source.header
        ? this.parseHeadersSafely(source.header)
        : undefined;
      
      // 使用Promise.race实现超时控制
      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('请求超时')), this.REQUEST_TIMEOUT);
      });
      
      const requestPromise = networkManager.get(testUrl, headers, this.MAX_RESPONSE_SIZE);
      
      const response = await Promise.race([requestPromise, timeoutPromise]);
      
      const responseTime = Date.now() - startTime;
      
      if (response && response.length > 0) {
        Logger.debug(this.TAG, `书源${source.name}验证成功，响应时间：${responseTime}ms`);
        const result: AvailabilityResult = {
          isAvailable: true,
          responseTime: responseTime
        };
        return result;
      } else {
        Logger.warn(this.TAG, `书源${source.name}返回空内容`);
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: responseTime,
          error: '响应内容为空'
        };
        return result;
      }
      
    } catch (error) {
      const responseTime = Date.now() - startTime;
      const errorMessage = this.getSafeErrorMessage(error);
      Logger.error(this.TAG, `书源${source.name}验证失败`);
      
      const result: AvailabilityResult = {
        isAvailable: false,
        responseTime: responseTime,
        error: errorMessage
      };
      return result;
    }
  }
  
  /**
   * 批量验证书源（简化版本，避免复杂类型推断）
   */
  async validateSourcesBatch(sources: BookSource[]): Promise<BatchValidationResult[]> {
    if (!sources || sources.length === 0) {
      return [];
    }
    
    // 限制批量验证数量
    const sourcesToValidate = sources.slice(0, this.MAX_SOURCES_PER_BATCH);
    
    const results: BatchValidationResult[] = [];
    
    Logger.debug(this.TAG, `开始批量验证${sourcesToValidate.length}个书源`);
    
    // 顺序验证，避免复杂的Promise.allSettled类型推断问题
    for (let i = 0; i < sourcesToValidate.length; i++) {
      const source = sourcesToValidate[i];
      try {
        const availabilityResult = await this.validateSourceAvailability(source);
        const batchResult: BatchValidationResult = {
          source: source,
          isAvailable: availabilityResult.isAvailable,
          responseTime: availabilityResult.responseTime,
          error: availabilityResult.error
        };
        results.push(batchResult);
        
        // 短暂延迟，避免请求过于密集
        if (i < sourcesToValidate.length - 1) {
          await new Promise(resolve => setTimeout(resolve, 1000)); // 增加到1秒延迟
        }
      } catch (error) {
        const errorMessage = this.getSafeErrorMessage(error);
        Logger.error(this.TAG, `书源${source.name}验证异常`);
        
        const batchResult: BatchValidationResult = {
          source: source,
          isAvailable: false,
          responseTime: 0,
          error: errorMessage
        };
        results.push(batchResult);
      }
    }
    
    const successCount = results.reduce((count, r) => r.isAvailable ? count + 1 : count, 0);
    Logger.debug(this.TAG, `批量验证完成，成功：${successCount}/${sourcesToValidate.length}`);
    return results;
  }
  
  /**
   * 验证书源搜索功能
   */
  async validateSearchFunction(source: BookSource, testKeyword: string = '测试'): Promise<SearchValidationResult> {
    if (!source.searchUrl) {
      const result: SearchValidationResult = {
        canSearch: false,
        resultCount: 0,
        error: '书源没有配置搜索URL'
      };
      return result;
    }
    
    // 验证搜索关键词
    if (!testKeyword || testKeyword.trim().length === 0 || testKeyword.length > 100) {
      const result: SearchValidationResult = {
        canSearch: false,
        resultCount: 0,
        error: '无效的搜索关键词'
      };
      return result;
    }
    
    try {
      Logger.debug(this.TAG, `测试书源搜索功能：${source.name}`);
      
      // 构建搜索URL
      const searchUrl = this.buildSearchUrl(source.searchUrl, testKeyword);
      
      // 验证搜索URL
      if (!this.isValidUrl(searchUrl)) {
        const result: SearchValidationResult = {
          canSearch: false,
          resultCount: 0,
          error: '搜索URL格式无效'
        };
        return result;
      }
      
      const networkManager = NetworkManager.getInstance();
      const response = await networkManager.get(searchUrl, undefined, this.MAX_RESPONSE_SIZE);
      
      if (response && response.length > 0) {
        const hasResults = this.detectSearchResults(response);
        
        const result: SearchValidationResult = {
          canSearch: true,
          resultCount: hasResults ? 1 : 0
        };
        return result;
      } else {
        const result: SearchValidationResult = {
          canSearch: false,
          resultCount: 0,
          error: '搜索请求失败，响应内容为空'
        };
        return result;
      }
      
    } catch (error) {
      const errorMessage = this.getSafeErrorMessage(error);
      Logger.error(this.TAG, `书源搜索功能验证失败`);
      
      const result: SearchValidationResult = {
        canSearch: false,
        resultCount: 0,
        error: errorMessage
      };
      return result;
    }
  }
  
  /**
   * 构建搜索URL
   */
  private buildSearchUrl(searchUrlTemplate: string, keyword: string): string {
    // 安全编码关键词
    const encodedKeyword = encodeURIComponent(keyword);
    
    // 验证编码后的长度
    if (encodedKeyword.length > 1000) {
      throw new Error('搜索关键词过长');
    }
    
    return searchUrlTemplate.replace('{keyword}', encodedKeyword);
  }
  
  /**
   * 检测搜索结果
   */
  private detectSearchResults(content: string): boolean {
    if (!content || content.length === 0) {
      return false;
    }
    
    // 限制内容长度检查
    if (content.length > 10000) {
      content = content.substring(0, 10000);
    }
    
    const indicators = ['book', '小说', 'novel', 'title', '书名', '作者'];
    
    for (const indicator of indicators) {
      if (content.toLowerCase().includes(indicator)) {
        return true;
      }
    }
    
    return false;
  }
  
  /**
   * URL有效性验证
   */
  private isValidUrl(url: string): boolean {
    try {
      if (!url || url.length > this.MAX_URL_LENGTH) {
        return false;
      }
      
      // 更严格的URL验证
      const urlPattern = /^https?:\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:\d{1,5})?(\/[a-zA-Z0-9-._~:/?#[\]@!$&'()*+,;=]*)?$/;
      
      if (!urlPattern.test(url)) {
        return false;
      }
      
      // 验证协议
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return false;
      }
      
      // 防止SSRF攻击，限制本地地址
      const hostname = new URL(url).hostname;
      if (this.isLocalAddress(hostname)) {
        return false;
      }
      
      return true;
    } catch (error) {
      return false;
    }
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
      Logger.warn(this.TAG, '解析请求头失败，使用空请求头');
      return {};
    }
  }
  
  /**
   * 获取安全的错误信息
   */
  private getSafeErrorMessage(error: any): string {
    if (typeof error === 'string') {
      // 限制错误信息长度
      return error.length > 200 ? error.substring(0, 200) + '...' : error;
    } else if (error && error.message) {
      const message = String(error.message);
      return message.length > 200 ? message.substring(0, 200) + '...' : message;
    } else {
      return '未知错误';
    }
  }
  
  /**
   * 计算书源质量评分
   */
  calculateSourceQualityScore(source: BookSource, availabilityResult?: AvailabilityResult): number {
    let score = 0;
    
    if (source.name && source.url) {
      score += 30;
    }
    
    if (source.searchUrl) score += 20;
    if (source.searchRule) score += 15;
    if (source.chapterRule) score += 15;
    if (source.contentRule) score += 10;
    
    if (availabilityResult) {
      if (availabilityResult.isAvailable) {
        score += 10;
        if (availabilityResult.responseTime < 1000) {
          score += 10;
        } else if (availabilityResult.responseTime < 3000) {
          score += 5;
        }
      }
    }
    
    if (source.sort) {
      score += (source.sort / 1000) * 10;
    }
    
    return Math.min(score, 100);
  }
}

export default new SourceValidator();