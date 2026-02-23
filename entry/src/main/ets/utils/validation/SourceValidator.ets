/**
 * 书源验证器 - 验证书源的有效性和可用性
 * 安全加固版本 - 修复了多个安全漏洞
 */

import { BookSource } from '../../models/BookSource';
import { NetworkManager } from '../network/NetworkManager';
import { Logger } from '../performance/Logger';

interface ParsedUrl {
  protocol: string;
  hostname: string;
  port: string;
  pathname: string;
  search: string;
  hash: string;
  href: string;
}

interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

interface AvailabilityResult {
  isAvailable: boolean;
  responseTime: number;
  error?: string;
}

interface BatchValidationResult {
  source: BookSource;
  isAvailable: boolean;
  responseTime: number;
  error?: string;
}

function parseUrl(url: string): ParsedUrl | null {
  try {
    let href = url;
    
    const protocolMatch = href.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):\/\//);
    const protocol = protocolMatch ? protocolMatch[1].toLowerCase() : '';
    
    if (!protocolMatch) {
      return null;
    }
    
    href = href.substring(protocolMatch[0].length);
    
    let hostname = '';
    let port = '';
    let pathname = '/';
    let search = '';
    let hash = '';
    
    const pathIndex = href.indexOf('/');
    const queryIndex = href.indexOf('?');
    const hashIndex = href.indexOf('#');
    
    let hostEnd = href.length;
    if (pathIndex !== -1) hostEnd = Math.min(hostEnd, pathIndex);
    if (queryIndex !== -1) hostEnd = Math.min(hostEnd, queryIndex);
    if (hashIndex !== -1) hostEnd = Math.min(hostEnd, hashIndex);
    
    const hostPart = href.substring(0, hostEnd);
    
    const portIndex = hostPart.lastIndexOf(':');
    if (portIndex !== -1) {
      const possiblePort = hostPart.substring(portIndex + 1);
      if (/^\d+$/.test(possiblePort)) {
        hostname = hostPart.substring(0, portIndex);
        port = possiblePort;
      } else {
        hostname = hostPart;
      }
    } else {
      hostname = hostPart;
    }
    
    if (hostname.startsWith('[') && hostname.endsWith(']')) {
      hostname = hostname.slice(1, -1);
    }
    
    let remaining = href.substring(hostEnd);
    
    const hashIdx = remaining.indexOf('#');
    if (hashIdx !== -1) {
      hash = remaining.substring(hashIdx);
      remaining = remaining.substring(0, hashIdx);
    }
    
    const queryIdx = remaining.indexOf('?');
    if (queryIdx !== -1) {
      search = remaining.substring(queryIdx);
      pathname = remaining.substring(0, queryIdx);
    } else {
      pathname = remaining || '/';
    }
    
    if (!pathname) pathname = '/';
    
    return {
      protocol,
      hostname,
      port,
      pathname,
      search,
      hash,
      href: url
    };
  } catch (e) {
    return null;
  }
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
  private readonly MAX_RESPONSE_SIZE = 5 * 1024 * 1024;
  private readonly REQUEST_TIMEOUT = 10000;
  private readonly MAX_SOURCES_PER_BATCH = 50;
  private readonly MAX_SEARCH_KEYWORD_LENGTH = 50;
  private readonly MAX_HEADER_KEY_LENGTH = 50;
  private readonly MAX_HEADER_VALUE_LENGTH = 500;
  private readonly MAX_ERROR_MESSAGE_LENGTH = 100;

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
    
    if (source.legacy?.searchUrl) {
      let searchUrl: string = source.legacy.searchUrl;
      if (searchUrl.includes('{{key}}')) {
        searchUrl = searchUrl.replace('{{key}}', 'test');
      }
      if (searchUrl.includes('{key}')) {
        searchUrl = searchUrl.replace('{key}', 'test');
      }
      if (!this.isValidUrl(searchUrl)) {
        errors.push('搜索URL格式无效');
      }
    }
    
    // 排序值验证
    if (source.sort && (source.sort < 0 || source.sort > 1000)) {
      errors.push('排序值必须在0-1000之间');
    }
    
    // 规则类型验证
    if (!['xpath', 'jsonpath', 'regex', 'auto'].includes(source.legacy?.ruleType)) {
      errors.push('无效的规则类型');
    }
    
    // 验证请求头格式 - 增强安全检查
    if (source.networkConfig?.header) {
      try {
        const headers: Record<string, string> = JSON.parse(source.networkConfig.header);
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
      let testUrl: string = source.legacy?.searchUrl || source.url;
      if (!testUrl) {
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: 0,
          error: '没有可测试的URL'
        };
        return result;
      }
      
      if (testUrl.includes('{{key}}')) {
        testUrl = testUrl.replace('{{key}}', encodeURIComponent('测试'));
      }
      if (testUrl.includes('{key}')) {
        testUrl = testUrl.replace('{key}', encodeURIComponent('测试'));
      }
      
      if (!this.isValidUrl(testUrl) || !this.isSafeUrl(testUrl)) {
        const result: AvailabilityResult = {
          isAvailable: false,
          responseTime: 0,
          error: '测试URL格式无效或不安全'
        };
        return result;
      }
      
      Logger.debug(this.TAG, `开始验证书源可用性：${this.sanitizeLogOutput(source.name)}`);
      
      const networkManager = NetworkManager.getInstance();
      const headersRecord: Record<string, string> | undefined = source.networkConfig?.header
        ? this.parseHeadersSafely(source.networkConfig.header)
        : undefined;
      
      const headers: Map<string, string> | undefined = headersRecord ? new Map(Object.entries(headersRecord)) : undefined;
      
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
    if (!source.legacy?.searchUrl) {
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
      const searchUrl = this.buildSearchUrl(source.legacy?.searchUrl ?? '', testKeyword);
      
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
    const encodedKeyword = encodeURIComponent(keyword);
    
    if (encodedKeyword.length > 1000) {
      throw new Error('搜索关键词过长');
    }
    
    let searchUrl = searchUrlTemplate;
    if (searchUrl.includes('{{key}}')) {
      searchUrl = searchUrl.replace('{{key}}', encodedKeyword);
    }
    if (searchUrl.includes('{key}')) {
      searchUrl = searchUrl.replace('{key}', encodedKeyword);
    }
    if (searchUrl.includes('{keyword}')) {
      searchUrl = searchUrl.replace('{keyword}', encodedKeyword);
    }
    
    return searchUrl;
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
      
      // 放宽URL验证，只检查基本格式
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return false;
      }
      
      // 检查是否有基本的域名结构
      const urlWithoutProtocol = url.replace(/^https?:\/\//, '');
      if (urlWithoutProtocol.length === 0) {
        return false;
      }
      
      return true;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * URL安全性验证 - 增强SSRF防护
   * 修复了八进制、十六进制IP绕过问题，增加了URL标准化和重定向验证
   */
  private isSafeUrl(url: string): boolean {
    try {
      if (!url || url.length > this.MAX_URL_LENGTH) {
        return false;
      }

      if (!url.match(/^https?:\/\//i)) {
        return false;
      }

      let decodedUrl = url;
      for (let i = 0; i < 3; i++) {
        try {
          const newDecoded = decodeURIComponent(decodedUrl);
          if (newDecoded === decodedUrl) break;
          decodedUrl = newDecoded;
        } catch (e) {
          break;
        }
      }

      const normalizedUrl = parseUrl(decodedUrl);
      if (!normalizedUrl) {
        return false;
      }

      let hostname = normalizedUrl.hostname.toLowerCase().trim();

      hostname = hostname.replace(/\s+/g, '');

      if (hostname.startsWith('[') && hostname.endsWith(']')) {
        hostname = hostname.slice(1, -1);
      }

      if (this.isInternalIPv6(hostname)) {
        return false;
      }

      if (this.isDecimalIP(hostname)) {
        return false;
      }

      if (this.isHexIP(hostname)) {
        return false;
      }

      if (this.isOctalIP(hostname)) {
        return false;
      }

      if (this.isMixedOctalHexIP(hostname)) {
        return false;
      }

      if (this.isDottedDecimalBypass(hostname)) {
        return false;
      }

      const forbiddenHosts = [
        'localhost', '127.0.0.1', '0.0.0.0', '::1', '0:0:0:0:0:0:0:1',
        '169.254.169.254', 'metadata.google.internal', 'metadata.azure.internal',
        '100.100.100.200', 'alibaba.metadata', 'kubernetes.default',
        'kubernetes.default.svc', 'metadata', 'metadata.google',
        'instance-data', 'ec2metadata', 'ec2-metadata'
      ];
      
      if (forbiddenHosts.includes(hostname)) {
        return false;
      }

      if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(hostname)) {
        if (this.isPrivateIP(hostname)) {
          return false;
        }
      }
      
      const internalNetworks = [
        '10.', '172.16.', '172.17.', '172.18.', '172.19.', '172.20.', 
        '172.21.', '172.22.', '172.23.', '172.24.', '172.25.', '172.26.',
        '172.27.', '172.28.', '172.29.', '172.30.', '172.31.', '192.168.',
        '127.', '169.254.', '0.0.', '224.', '225.', '226.', '227.', '228.',
        '229.', '230.', '231.', '232.', '233.', '234.', '235.', '236.',
        '237.', '238.', '239.', '240.', '255.', 'fc', 'fd', 'fe80:', '::'
      ];
      
      for (const network of internalNetworks) {
        if (hostname.startsWith(network)) {
          return false;
        }
      }

      const suspiciousDomains = [
        '.local', '.internal', '.localhost', '.localdomain',
        '.test', '.example', '.invalid', '.home', '.lan',
        'localtest.me', 'nip.io', 'sslip.io', 'xip.io',
        '127.0.0.1.nip.io', '127.0.0.1.sslip.io', '127.0.0.1.xip.io'
      ];

      for (const domain of suspiciousDomains) {
        if (hostname.includes(domain)) {
          return false;
        }
      }

      if (/^0x[0-9a-f]+$/i.test(hostname) || /^[0-9a-f]{8,}$/i.test(hostname)) {
        return false;
      }

      const port = normalizedUrl.port;
      if (port) {
        const forbiddenPorts = ['22', '23', '25', '53', '110', '143', '445', '3306', '3389', '5432', '6379', '8080', '8443', '9200', '9300'];
        if (forbiddenPorts.includes(port)) {
          return false;
        }
      }

      const pathname = normalizedUrl.pathname.toLowerCase();
      const suspiciousPathPatterns = [
        '/metadata', '/instance', '/latest/meta-data',
        '/actuator', '/env', '/configprops', '/heapdump',
        '/.git/', '/.svn/', '/.env', '/config.xml', '/web.config'
      ];
      for (const pattern of suspiciousPathPatterns) {
        if (pathname.includes(pattern)) {
          return false;
        }
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 验证重定向后的 URL 安全性
   * 在跟随重定向时必须调用此方法进行二次验证
   */
  public validateRedirectUrl(originalUrl: string, redirectUrl: string): boolean {
    try {
      const original = parseUrl(originalUrl);
      if (!original) {
        return false;
      }

      let redirectHref = redirectUrl;
      if (!redirectUrl.startsWith('http://') && !redirectUrl.startsWith('https://')) {
        redirectHref = original.protocol + '://' + original.hostname + 
          (original.port ? ':' + original.port : '') + redirectUrl;
      }
      
      const redirect = parseUrl(redirectHref);
      if (!redirect) {
        return false;
      }

      if (original.protocol === 'https' && redirect.protocol === 'http') {
        Logger.warn(this.TAG, '检测到协议降级，禁止重定向');
        return false;
      }

      if (!this.isSafeUrl(redirect.href)) {
        Logger.warn(this.TAG, '重定向后的 URL 未通过安全检查');
        return false;
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 检查是否为混合八进制/十六进制 IP 格式
   * 例如: 0177.0.0.1 (八进制 127.0.0.1)
   */
  private isMixedOctalHexIP(hostname: string): boolean {
    const parts = hostname.split('.');
    if (parts.length !== 4) return false;

    let hasOctal = false;
    let hasHex = false;

    for (const part of parts) {
      // 检查八进制 (以 0 开头且长度大于 1)
      if (part.startsWith('0') && part.length > 1 && /^[0-7]+$/.test(part)) {
        hasOctal = true;
      }
      // 检查十六进制 (以 0x 开头)
      if (part.startsWith('0x') && /^0x[0-9a-f]+$/i.test(part)) {
        hasHex = true;
      }
    }

    return hasOctal || hasHex;
  }

  /**
   * 检查是否为点分十进制绕过
   * 例如: 2130706433 -> 127.0.0.1
   */
  private isDottedDecimalBypass(hostname: string): boolean {
    // 纯数字且长度在 7-10 位之间可能是十进制 IP
    if (/^\d{7,10}$/.test(hostname)) {
      const num = parseInt(hostname, 10);
      // 检查是否在私有 IP 范围内
      // 127.0.0.1 = 2130706433
      // 10.0.0.0 = 167772160
      // 10.255.255.255 = 184549375
      // 172.16.0.0 = 2886729728
      // 172.31.255.255 = 2887778303
      // 192.168.0.0 = 3232235520
      // 192.168.255.255 = 3232301055
      if ((num >= 167772160 && num <= 184549375) ||      // 10.0.0.0/8
          (num >= 2886729728 && num <= 2887778303) ||    // 172.16.0.0/12
          (num >= 3232235520 && num <= 3232301055) ||    // 192.168.0.0/16
          num === 2130706433 || num === 0) {             // 127.0.0.1, 0.0.0.0
        return true;
      }
    }
    return false;
  }

  /**
   * 检查是否为私有IP地址
   */
  private isPrivateIP(ip: string): boolean {
    const parts = ip.split('.').map(Number);
    if (parts.length !== 4) return false;
    
    if (parts[0] === 10) return true;
    if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    if (parts[0] === 192 && parts[1] === 168) return true;
    if (parts[0] === 127) return true;
    if (parts[0] === 169 && parts[1] === 254) return true;
    if (parts[0] === 0) return true;
    if (parts[0] >= 224) return true;
    
    return false;
  }

  /**
   * 检查是否为内部IPv6地址
   */
  private isInternalIPv6(hostname: string): boolean {
    const lowerHostname = hostname.toLowerCase();
    
    if (lowerHostname === '::1' || lowerHostname === '0:0:0:0:0:0:0:1') {
      return true;
    }
    
    if (lowerHostname.startsWith('::') || lowerHostname.startsWith('0:0:')) {
      return true;
    }
    
    if (lowerHostname.startsWith('fc') || lowerHostname.startsWith('fd')) {
      return true;
    }
    
    if (lowerHostname.startsWith('fe80:')) {
      return true;
    }
    
    return false;
  }

  /**
   * 检查是否为十进制IP格式
   */
  private isDecimalIP(hostname: string): boolean {
    if (/^\d{8,}$/.test(hostname)) {
      return true;
    }
    return false;
  }

  /**
   * 检查是否为十六进制IP格式
   */
  private isHexIP(hostname: string): boolean {
    if (/^0x[0-9a-f]{8}$/i.test(hostname)) {
      return true;
    }
    if (/^[0-9a-f]{8}$/i.test(hostname)) {
      return true;
    }
    return false;
  }

  /**
   * 检查是否为八进制IP格式
   */
  private isOctalIP(hostname: string): boolean {
    const parts = hostname.split('.');
    if (parts.length === 4) {
      for (const part of parts) {
        if (part.startsWith('0') && part.length > 1 && /^[0-7]+$/.test(part)) {
          return true;
        }
      }
    }
    return false;
  }
  
  /**
   * 检查是否为公共域名 - 增强SSRF防护
   */
  private isPublicDomain(hostname: string): boolean {
    const suspiciousPatterns = [
      /\.local$/i, /\.internal$/i, /\.localhost$/i, /\.localdomain$/i,
      /\.test$/i, /\.example$/i, /\.invalid$/i,
      /127\.0\.0\.1/i, /localhost/i, /localtest\.me/i, /nip\.io$/i,
      /sslip\.io$/i, /xip\.io$/i, /\.home$/i, /\.lan$/i
    ];
    
    for (const pattern of suspiciousPatterns) {
      if (pattern.test(hostname)) {
        return false;
      }
    }
    
    return true;
  }
  
  /**
   * 检查书源安全性 - 新增安全检查
   */
  private isSafeSource(source: BookSource): boolean {
    // 检查URL安全性
    if (!this.isSafeUrl(source.url) ||
        (source.legacy?.searchUrl && !this.isSafeUrl(source.legacy.searchUrl))) {
      return false;
    }

    // 检查请求头安全性
    if (source.networkConfig?.header) {
      try {
        const headers: Record<string, string> = JSON.parse(source.networkConfig.header);
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
    // 只检查真正危险的请求头，放宽对正常请求头的限制
    const suspiciousKeys = [
      'cookie', 'authorization', 'proxy-authorization'
    ];

    const lowerKey = key.toLowerCase();

    if (suspiciousKeys.includes(lowerKey)) {
      return true;
    }

    // 检查可疑内容 - 只检查真正危险的脚本注入
    if (value.includes('javascript:') || value.includes('vbscript:') ||
        value.includes('eval(') || value.includes('alert(')) {
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
      const errorObj = error;
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
    
    if (source.legacy?.searchUrl) score += 20;
    if (source.rules?.searchRule) score += 15;
    if (source.rules?.tocRule) score += 15;
    if (source.rules?.contentRule) score += 10;
    
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