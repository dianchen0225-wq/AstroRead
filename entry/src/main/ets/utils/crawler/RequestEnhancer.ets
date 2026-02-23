import { Logger } from "../performance/Logger";

interface UserAgentProfile {
  name: string;
  userAgent: string;
  accept: string;
  acceptLanguage: string;
  acceptEncoding: string;
  platform: string;
}

interface EnhancedHeadersOptions {
  useRandomUA: boolean;
  useRandomReferer: boolean;
  baseUrl: string;
}

export interface RequestConfig {
  url: string;
  method: string;
  headers: Map<string, string>;
  body: string;
  timeout: number;
  maxRetries: number;
  retryDelay: number;
  useRandomUA: boolean;
  useRandomReferer: boolean;
}

export interface RequestLog {
  timestamp: number;
  url: string;
  method: string;
  requestHeaders: Map<string, string>;
  requestBody: string;
  responseCode: number;
  responseTime: number;
  responseSize: number;
  error: string;
  retryCount: number;
}

interface LogAnalysis {
  totalRequests: number;
  successRate: number;
  averageResponseTime: number;
  errorTypes: Map<string, number>;
  slowRequests: RequestLog[];
}

const CHROME_WINDOWS: UserAgentProfile = {
  name: 'Chrome_Windows',
  userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
  acceptEncoding: 'gzip, deflate, br',
  platform: 'Windows'
};

const CHROME_MAC: UserAgentProfile = {
  name: 'Chrome_Mac',
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh;q=0.9,en;q=0.8',
  acceptEncoding: 'gzip, deflate, br',
  platform: 'Mac'
};

const FIREFOX_WINDOWS: UserAgentProfile = {
  name: 'Firefox_Windows',
  userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2',
  acceptEncoding: 'gzip, deflate, br',
  platform: 'Windows'
};

const FIREFOX_MAC: UserAgentProfile = {
  name: 'Firefox_Mac',
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2',
  acceptEncoding: 'gzip, deflate, br',
  platform: 'Mac'
};

const EDGE_WINDOWS: UserAgentProfile = {
  name: 'Edge_Windows',
  userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
  acceptEncoding: 'gzip, deflate, br',
  platform: 'Windows'
};

const SAFARI_MAC: UserAgentProfile = {
  name: 'Safari_Mac',
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh-Hans;q=0.9',
  acceptEncoding: 'gzip, deflate',
  platform: 'Mac'
};

const MOBILE_ANDROID: UserAgentProfile = {
  name: 'Mobile_Android',
  userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh;q=0.9,en;q=0.8',
  acceptEncoding: 'gzip, deflate, br',
  platform: 'Android'
};

const MOBILE_IPHONE: UserAgentProfile = {
  name: 'Mobile_iPhone',
  userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  acceptLanguage: 'zh-CN,zh-Hans;q=0.9',
  acceptEncoding: 'gzip, deflate',
  platform: 'iOS'
};

const USER_AGENT_POOL: UserAgentProfile[] = [
  CHROME_WINDOWS,
  CHROME_MAC,
  FIREFOX_WINDOWS,
  FIREFOX_MAC,
  EDGE_WINDOWS,
  SAFARI_MAC,
  MOBILE_ANDROID,
  MOBILE_IPHONE
];

const REFERER_POOL: string[] = [
  'https://www.google.com/',
  'https://www.baidu.com/',
  'https://www.bing.com/',
  'https://www.sogou.com/',
  'https://www.so.com/',
  'https://www.google.com.hk/',
  'https://www.douban.com/',
  'https://www.zhihu.com/'
];

let requestLogs: RequestLog[] = [];
let maxLogs: number = 100;
let lastUAIndex: number = -1;
const TAG: string = 'RequestEnhancer';

const UA_CACHE_TTL = 30 * 60 * 1000;

interface UACacheEntry {
  profile: UserAgentProfile;
  timestamp: number;
}

const domainUACache: Map<string, UACacheEntry> = new Map();

function extractDomain(url: string): string {
  try {
    const match = url.match(/^https?:\/\/([^/:]+)/);
    return match ? match[1].toLowerCase() : '';
  } catch {
    return '';
  }
}

function getCachedUAForDomain(domain: string): UserAgentProfile | null {
  if (!domain) return null;
  
  const cached = domainUACache.get(domain);
  if (cached && Date.now() - cached.timestamp < UA_CACHE_TTL) {
    return cached.profile;
  }
  
  return null;
}

function cacheUAForDomain(domain: string, profile: UserAgentProfile): void {
  if (!domain) return;
  
  if (domainUACache.size > 100) {
    const now = Date.now();
    const keysToDelete: string[] = [];
    domainUACache.forEach((value, key) => {
      if (now - value.timestamp > UA_CACHE_TTL) {
        keysToDelete.push(key);
      }
    });
    keysToDelete.forEach(key => domainUACache.delete(key));
  }
  
  domainUACache.set(domain, { profile: profile, timestamp: Date.now() } as UACacheEntry);
}

export class RequestEnhancer {
  static getRandomUserAgent(): UserAgentProfile {
    let index: number = Math.floor(Math.random() * USER_AGENT_POOL.length);
    let attempts: number = 0;
    while (index === lastUAIndex && USER_AGENT_POOL.length > 1 && attempts < 10) {
      index = Math.floor(Math.random() * USER_AGENT_POOL.length);
      attempts++;
    }
    
    lastUAIndex = index;
    return USER_AGENT_POOL[index];
  }

  static getUserAgentForUrl(url: string): UserAgentProfile {
    const domain = extractDomain(url);
    
    if (domain) {
      const cached = getCachedUAForDomain(domain);
      if (cached) {
        return cached;
      }
      
      const profile = RequestEnhancer.getRandomUserAgent();
      cacheUAForDomain(domain, profile);
      return profile;
    }
    
    return RequestEnhancer.getRandomUserAgent();
  }

  static getRandomReferer(): string {
    const index: number = Math.floor(Math.random() * REFERER_POOL.length);
    return REFERER_POOL[index];
  }

  static buildEnhancedHeaders(
    customHeaders: Map<string, string> | null,
    options: EnhancedHeadersOptions | null
  ): Map<string, string> {
    const headers: Map<string, string> = new Map<string, string>();
    
    const useRandomUA: boolean = options !== null && options.useRandomUA;
    const useRandomReferer: boolean = options !== null && options.useRandomReferer;
    const baseUrl: string = options !== null ? options.baseUrl : '';

    if (useRandomUA) {
      const uaProfile: UserAgentProfile = baseUrl 
        ? RequestEnhancer.getUserAgentForUrl(baseUrl) 
        : RequestEnhancer.getRandomUserAgent();
      headers.set('User-Agent', uaProfile.userAgent);
      headers.set('Accept', uaProfile.accept);
      headers.set('Accept-Language', uaProfile.acceptLanguage);
      headers.set('Accept-Encoding', uaProfile.acceptEncoding);
      headers.set('Sec-CH-UA', '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"');
      headers.set('Sec-CH-UA-Mobile', '?0');
      headers.set('Sec-CH-UA-Platform', `"${uaProfile.platform}"`);
    } else {
      headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      headers.set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
    }

    if (useRandomReferer) {
      if (baseUrl.length > 0) {
        headers.set('Referer', baseUrl);
      } else {
        headers.set('Referer', RequestEnhancer.getRandomReferer());
      }
    } else if (baseUrl.length > 0) {
      headers.set('Referer', baseUrl);
    }

    headers.set('Connection', 'keep-alive');
    headers.set('Cache-Control', 'max-age=0');
    headers.set('Upgrade-Insecure-Requests', '1');

    if (customHeaders !== null) {
      const keys: string[] = Array.from(customHeaders.keys());
      for (let i: number = 0; i < keys.length; i++) {
        const key: string = keys[i];
        headers.set(key, customHeaders.get(key) || '');
      }
    }

    return headers;
  }

  static logRequest(log: RequestLog): void {
    requestLogs.unshift(log);
    
    if (requestLogs.length > maxLogs) {
      requestLogs = requestLogs.slice(0, maxLogs);
    }
    
    const status: string = log.error.length > 0 ? 'FAILED' : log.responseCode === 200 ? 'SUCCESS' : 'HTTP_ERROR';
    Logger.debug(TAG, `[${status}] ${log.method} ${log.url} - ${log.responseTime}ms - ${log.responseSize}bytes${log.retryCount > 0 ? ` (retries: ${log.retryCount})` : ''}`);
  }

  static getRecentLogs(count: number): RequestLog[] {
    const actualCount: number = Math.min(count, requestLogs.length);
    return requestLogs.slice(0, actualCount);
  }

  static clearLogs(): void {
    requestLogs = [];
  }

  static analyzeLogs(): LogAnalysis {
    const logs: RequestLog[] = requestLogs;
    const totalRequests: number = logs.length;
    
    if (totalRequests === 0) {
      const emptyResult: LogAnalysis = {
        totalRequests: 0,
        successRate: 0,
        averageResponseTime: 0,
        errorTypes: new Map<string, number>(),
        slowRequests: []
      };
      return emptyResult;
    }

    let successCount: number = 0;
    let totalResponseTime: number = 0;
    const errorTypes: Map<string, number> = new Map<string, number>();
    const slowRequests: RequestLog[] = [];

    for (let i: number = 0; i < logs.length; i++) {
      const log: RequestLog = logs[i];
      if (log.responseCode === 200) {
        successCount++;
      }
      
      if (log.responseTime > 0) {
        totalResponseTime += log.responseTime;
        if (log.responseTime > 5000) {
          slowRequests.push(log);
        }
      }
      
      if (log.error.length > 0) {
        const errorType: string = RequestEnhancer.categorizeError(log.error);
        const currentCount: number = errorTypes.get(errorType) || 0;
        errorTypes.set(errorType, currentCount + 1);
      }
    }

    const result: LogAnalysis = {
      totalRequests: totalRequests,
      successRate: successCount / totalRequests,
      averageResponseTime: totalResponseTime / totalRequests,
      errorTypes: errorTypes,
      slowRequests: slowRequests
    };
    return result;
  }

  private static categorizeError(error: string): string {
    const errorLower: string = error.toLowerCase();
    
    if (errorLower.includes('timeout')) {
      return 'TIMEOUT';
    }
    if (errorLower.includes('ssl') || errorLower.includes('certificate')) {
      return 'SSL_ERROR';
    }
    if (errorLower.includes('network') || errorLower.includes('connection')) {
      return 'NETWORK_ERROR';
    }
    if (errorLower.includes('403') || errorLower.includes('forbidden')) {
      return 'FORBIDDEN';
    }
    if (errorLower.includes('404') || errorLower.includes('not found')) {
      return 'NOT_FOUND';
    }
    if (errorLower.includes('429') || errorLower.includes('too many')) {
      return 'RATE_LIMITED';
    }
    if (errorLower.includes('500') || errorLower.includes('server')) {
      return 'SERVER_ERROR';
    }
    
    return 'UNKNOWN';
  }

  static generateDiagnosticReport(): string {
    const analysis: LogAnalysis = RequestEnhancer.analyzeLogs();
    const recentLogs: RequestLog[] = RequestEnhancer.getRecentLogs(10);
    
    let report: string = '========== 网络请求诊断报告 ==========\n';
    report += `生成时间: ${new Date().toLocaleString()}\n\n`;
    
    report += '--- 统计摘要 ---\n';
    report += `总请求数: ${analysis.totalRequests}\n`;
    report += `成功率: ${(analysis.successRate * 100).toFixed(1)}%\n`;
    report += `平均响应时间: ${analysis.averageResponseTime.toFixed(0)}ms\n`;
    
    if (analysis.errorTypes.size > 0) {
      report += '\n--- 错误类型分布 ---\n';
      const errorTypeKeys: string[] = Array.from(analysis.errorTypes.keys());
      for (let i: number = 0; i < errorTypeKeys.length; i++) {
        const type: string = errorTypeKeys[i];
        const count: number = analysis.errorTypes.get(type) || 0;
        report += `${type}: ${count}次 (${((count / analysis.totalRequests) * 100).toFixed(1)}%)\n`;
      }
    }
    
    if (analysis.slowRequests.length > 0) {
      report += `\n--- 慢请求 (>5秒) ---\n`;
      const maxSlow: number = Math.min(5, analysis.slowRequests.length);
      for (let i: number = 0; i < maxSlow; i++) {
        const log: RequestLog = analysis.slowRequests[i];
        report += `${log.url} - ${log.responseTime}ms\n`;
      }
    }
    
    report += '\n--- 最近请求 ---\n';
    for (let i: number = 0; i < recentLogs.length; i++) {
      const log: RequestLog = recentLogs[i];
      const status: string = log.responseCode > 0 ? String(log.responseCode) : (log.error.length > 0 ? 'ERR' : 'N/A');
      const urlPreview: string = log.url.length > 60 ? log.url.substring(0, 60) : log.url;
      report += `[${status}] ${log.method} ${urlPreview}...\n`;
    }
    
    report += '\n========================================';
    return report;
  }
}
