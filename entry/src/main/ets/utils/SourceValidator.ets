/**
 * 书源验证器 - 验证书源的有效性和可用性
 * 安全加固版本 - 修复了多个安全漏洞
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
  
  // 安全配置 - 增强安全限制
  private readonly MAX_URL_LENGTH = 2048;
  private readonly MAX_RESPONSE_SIZE = 5 * 1024 * 1024; // 降低到5MB
  private readonly REQUEST_TIMEOUT = 10000; // 10秒
  private readonly MAX_SOURCES_PER_BATCH = 20; // 降低批量处理数量
  private readonly MAX_SEARCH_KEYWORD_LENGTH = 50; // 限制搜索关键词长度
  private readonly MAX_HEADER_KEY_LENGTH = 50; // 限制请求头键名长度
  private readonly MAX_HEADER_VALUE_LENGTH = 500; // 限制请求头值长度
  private readonly MAX_ERROR_MESSAGE_LENGTH = 100; // 限制错误信息长度

  /**
   * 验证书源基本格式 - 增强安全验证
   */
  validateSourceFormat(source: BookSource): ValidationResult {
    const errors: string[] = [];
    
    // 名称验证 - 增强安全检查
    if (!source.name || source.name.trim().length === 0) {
      errors.push('书源名称不能为空');
    } else if (source.name.length > 100) {
      errors.push('书源名称不能超过100个字符');
    } else if (this.containsSuspiciousCharacters(source.name)) {
      errors.push('书源名称包含可疑字符');
    }
    
    // URL验证 - 增强安全检查
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
    
    // 验证请求头格式 - 增强安全检查
    if (source.header) {
      try {
        const headers: Record<string, string> = JSON.parse(source.header);
        if (typeof headers !== 'object' || headers === null) {
          errors.push('请求头格式无效');
        } else {
          // 验证headers key和value长度
          const headerEntries = Object.entries<string>(headers);
          for (let i = 0; i < headerEntries.length; i++) {
            const key = headerEntries[i][0];
            const value = headerEntries[i][1];
            if (typeof key !== 'string' || key.length > this.MAX_HEADER_KEY_LENGTH) {
              errors.push('请求头键名过长');
            }
            if (typeof value !== 'string' || value.length > this.MAX_HEADER_VALUE_LENGTH) {
              errors.push('请求头值过长');
            }
            // 检查可疑的请求头
            if (this.isSuspiciousHeader(key, String(value))) {
              errors.push(`可疑的请求头: ${key}`);
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
   * 验证书源可用性（网络测试）- 增强安全防护
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
      
      // 增强URL验证
      if (!this.isValidUrl(testUrl) || !this.isSafeUrl(testUrl)) {
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: 0,
          error: '测试URL格式无效或不安全'
        };
        return result;
      }
      
      Logger.debug(this.TAG, `开始验证书源可用性：${this.sanitizeLogOutput(source.name)}`);
      
      // 发送测试请求（带超时）
      const networkManager = NetworkManager.getInstance();
      
      // 设置请求头 - 增强安全检查
      const headers: Record<string, string> | undefined = source.header
        ? this.parseHeadersSafely(source.header)
        : undefined;
      
      // 使用Promise.race实现超时控制
      const timeoutPromise = new Promise<AvailabilityResult>((resolve) => {
        setTimeout(() => {
          resolve({
            isAvailable: false,
            responseTime: Date.now() - startTime,
            error: '请求超时'
          });
        }, this.REQUEST_TIMEOUT);
      });
      
      const requestPromise = networkManager.get(testUrl, headers, this.MAX_RESPONSE_SIZE).then((response: string) => {
        const responseTime = Date.now() - startTime;
        
        // 检查响应大小
        if (response && response.length > 0) {
          if (response.length > this.MAX_RESPONSE_SIZE) {
            Logger.warn(this.TAG, `书源${this.sanitizeLogOutput(source.name)}响应过大：${response.length}字节`);
            throw new Error('响应大小超过限制');
          }
          
          Logger.debug(this.TAG, `书源${this.sanitizeLogOutput(source.name)}验证成功，响应时间：${responseTime}ms`);
          const result: AvailabilityResult = {
            isAvailable: true,
            responseTime: responseTime
          };
          return result;
        } else {
          Logger.warn(this.TAG, `书源${this.sanitizeLogOutput(source.name)}返回空内容`);
          const result: AvailabilityResult = {
            isAvailable: false,
            responseTime: responseTime,
            error: '响应内容为空'
          };
          return result;
        }
      }).catch((error: Error) => {
        const responseTime = Date.now() - startTime;
        const errorMessage = this.getSafeErrorMessage(error);
        Logger.error(this.TAG, `书源${this.sanitizeLogOutput(source.name)}验证失败`);
        
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: responseTime,
          error: errorMessage
        };
        return result;
      });
      
      const response = await Promise.race<AvailabilityResult>([requestPromise, timeoutPromise]);
      
      return response;
      
    } catch (error) {
      const responseTime = Date.now() - startTime;
      const errorMessage = this.getSafeErrorMessage(error);
      Logger.error(this.TAG, `书源${this.sanitizeLogOutput(source.name)}验证失败`);
      
      const result: AvailabilityResult = {
        isAvailable: false,
        responseTime: responseTime,
        error: errorMessage
      };
      return result;
    }
  }
  
  /**
   * 批量验证书源（简化版本，避免复杂类型推断）- 增强安全限制
   */
  async validateSourcesBatch(sources: BookSource[]): Promise<BatchValidationResult[]> {
    if (!sources || sources.length === 0) {
      return [];
    }
    
    // 限制批量验证数量 - 增强安全限制
    const sourcesToValidate = sources.slice(0, this.MAX_SOURCES_PER_BATCH);
    
    const results: BatchValidationResult[] = [];
    
    Logger.debug(this.TAG, `开始批量验证${sourcesToValidate.length}个书源`);
    
    // 顺序验证，避免复杂的Promise.allSettled类型推断问题
    for (let i = 0; i < sourcesToValidate.length; i++) {
      const source = sourcesToValidate[i];
      try {
        // 前置安全检查
        if (!this.isSafeSource(source)) {
          Logger.warn(this.TAG, `跳过不安全书源: ${this.sanitizeLogOutput(source.name)}`);
          const batchResult: BatchValidationResult = {
            source: source,
            isAvailable: false,
            responseTime: 0,
            error: '书源包含不安全配置'
          };
          results.push(batchResult);
          continue;
        }
        
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
          await new Promise<void>(resolve => setTimeout(resolve, 2000)); // 增加到2秒延迟
        }
      } catch (error) {
        const errorMessage = this.getSafeErrorMessage(error);
        Logger.error(this.TAG, `书源${this.sanitizeLogOutput(source.name)}验证异常`);
        
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
   * 验证书源搜索功能 - 增强安全验证
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
    
    // 验证搜索关键词 - 增强安全检查
    if (!testKeyword || testKeyword.trim().length === 0 || testKeyword.length > this.MAX_SEARCH_KEYWORD_LENGTH) {
      const result: SearchValidationResult = {
        canSearch: false,
        resultCount: 0,
        error: '无效的搜索关键词'
      };
      return result;
    }
    
    // 检查关键词安全性
    if (this.containsSuspiciousCharacters(testKeyword)) {
      const result: SearchValidationResult = {
        canSearch: false,
        resultCount: 0,
        error: '搜索关键词包含可疑字符'
      };
      return result;
    }
    
    try {
      Logger.debug(this.TAG, `测试书源搜索功能：${this.sanitizeLogOutput(source.name)}`);
      
      // 构建搜索URL
      const searchUrl = this.buildSearchUrl(source.searchUrl, testKeyword);
      
      // 增强URL验证
      if (!this.isValidUrl(searchUrl) || !this.isSafeUrl(searchUrl)) {
        const result: SearchValidationResult = {
          canSearch: false,
          resultCount: 0,
          error: '搜索URL格式无效或不安全'
        };
        return result;
      }
      
      const networkManager = NetworkManager.getInstance();
      const response = await networkManager.get(searchUrl, undefined, this.MAX_RESPONSE_SIZE);
      
      if (response && response.length > 0) {
        // 检查响应大小
        if (response.length > this.MAX_RESPONSE_SIZE) {
          Logger.warn(this.TAG, `搜索响应过大：${response.length}字节`);
          throw new Error('响应大小超过限制');
        }
        
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
   * 构建搜索URL - 增强安全编码
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
   * 检测搜索结果 - 增强安全检查
   */
  private detectSearchResults(content: string): boolean {
    if (!content || content.length === 0) {
      return false;
    }
    
    // 限制内容长度检查 - 增强安全限制
    if (content.length > 5000) {
      content = content.substring(0, 5000);
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
   * URL有效性验证 - 增强安全验证
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
      
      return true;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * URL安全性验证 - 新增SSRF防护
   */
  private isSafeUrl(url: string): boolean {
    try {
      // 防止SSRF攻击，限制本地地址和内部地址
      // HarmonyOS不支持URL类，使用正则表达式验证
      const urlPattern = /^(https?:\/\/)([^\/:]+)(:\d+)?(\/.*)?$/;
      const match = url.match(urlPattern);
      
      if (!match) {
        return false;
      }
      
      const hostname = match[2];
      
      // 禁止的域名和IP地址
      const forbiddenHosts = [
        'localhost', '127.0.0.1', '0.0.0.0', '::1',
        '169.254.169.254', 'metadata.google.internal' // 云服务元数据地址
      ];
      
      // 禁止的内部网络地址
      const internalNetworks = [
        '10.', '172.16.', '172.17.', '172.18.', '172.19.', '172.20.', 
        '172.21.', '172.22.', '172.23.', '172.24.', '172.25.', '172.26.',
        '172.27.', '172.28.', '172.29.', '172.30.', '172.31.', '192.168.'
      ];
      
      if (forbiddenHosts.includes(hostname)) {
        return false;
      }
      
      for (const network of internalNetworks) {
        if (hostname.startsWith(network)) {
          return false;
        }
      }
      
      // 检查是否为公共可访问域名
      const tld = hostname.split('.').pop();
      const commonTlds = ['com', 'org', 'net', 'edu', 'gov', 'cn', 'io', 'dev'];
      if (!tld || !commonTlds.includes(tld)) {
        // 非常见顶级域名，需要额外检查
        return this.isPublicDomain(hostname);
      }
      
      return true;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 检查是否为公共域名 - 新增SSRF防护
   */
  private isPublicDomain(hostname: string): boolean {
    // 这里可以添加更复杂的公共域名验证逻辑
    // 目前简单实现为允许所有非内部地址
    return !hostname.includes('.local') && !hostname.includes('.internal');
  }
  
  /**
   * 检查书源安全性 - 新增安全检查
   */
  private isSafeSource(source: BookSource): boolean {
    // 检查URL安全性
    if (!this.isSafeUrl(source.url) || 
        (source.searchUrl && !this.isSafeUrl(source.searchUrl))) {
      return false;
    }
    
    // 检查请求头安全性
    if (source.header) {
      try {
        const headers: Record<string, string> = JSON.parse(source.header);
        const headerEntries = Object.entries<string>(headers);
        for (let i = 0; i < headerEntries.length; i++) {
          const key = headerEntries[i][0];
          const value = headerEntries[i][1];
          if (this.isSuspiciousHeader(key, String(value))) {
            return false;
          }
        }
      } catch (error) {
        return false;
      }
    }
    
    return true;
  }
  
  /**
   * 检查可疑请求头 - 新增安全防护
   */
  private isSuspiciousHeader(key: string, value: string): boolean {
    const suspiciousKeys = [
      'cookie', 'authorization', 'proxy-authorization', 'x-forwarded-for',
      'x-real-ip', 'referer', 'origin'
    ];
    
    const lowerKey = key.toLowerCase();
    
    if (suspiciousKeys.includes(lowerKey)) {
      return true;
    }
    
    // 检查可疑内容
    if (value.includes('script') || value.includes('javascript') || 
        value.includes('eval') || value.includes('alert')) {
      return true;
    }
    
    return false;
  }
  
  /**
   * 检查可疑字符 - 新增输入验证
   */
  private containsSuspiciousCharacters(input: string): boolean {
    const suspiciousPatterns = [
      /<script/i,
      /javascript:/i,
      /vbscript:/i,
      /onload=/i,
      /onerror=/i,
      /onclick=/i,
      /eval\(/i,
      /alert\(/i
    ];
    
    for (const pattern of suspiciousPatterns) {
      if (pattern.test(input)) {
        return true;
      }
    }
    
    return false;
  }
  
  /**
   * 安全解析请求头 - 增强安全防护
   */
  private parseHeadersSafely(headersString: string): Record<string, string> {
    try {
      const headers: Record<string, string> = JSON.parse(headersString);
      
      // 验证headers对象
      if (typeof headers !== 'object' || headers === null) {
        return {};
      }
      
      const result: Record<string, string> = {};
      
      const headerEntries = Object.entries<string>(headers);
      for (let i = 0; i < headerEntries.length; i++) {
        const key = headerEntries[i][0];
        const value = headerEntries[i][1];
        if (typeof key === 'string' && typeof value === 'string') {
          // 限制header key和value长度
          if (key.length <= this.MAX_HEADER_KEY_LENGTH && 
              value.length <= this.MAX_HEADER_VALUE_LENGTH &&
              !this.isSuspiciousHeader(key, value)) {
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
   * 获取安全的错误信息 - 增强安全限制
   */
  private getSafeErrorMessage(error: object): string {
    if (error && typeof error === 'object') {
      // 检查对象是否有message属性
      const errorObj = error as Record<string, object>;
      if (errorObj['message'] !== undefined) {
        const message = String(errorObj['message']);
        const safeMessage = this.sanitizeString(message);
        return safeMessage.length > this.MAX_ERROR_MESSAGE_LENGTH ? 
               safeMessage.substring(0, this.MAX_ERROR_MESSAGE_LENGTH) + '...' : safeMessage;
      }
    }
    return '未知错误';
  }
  
  /**
   * 字符串清理 - 新增安全防护
   */
  private sanitizeString(str: string): string {
    if (!str) return '';
    
    // 移除控制字符和特殊字符
    return str.replace(/[\x00-\x1F\x7F]/g, '');
  }
  
  /**
   * 日志输出清理 - 新增安全防护
   */
  private sanitizeLogOutput(input: string | undefined): string {
    if (!input) return '';
    
    // 限制日志输出长度，防止敏感信息泄露
    const sanitized = this.sanitizeString(input);
    return sanitized.length > 50 ? sanitized.substring(0, 50) + '...' : sanitized;
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