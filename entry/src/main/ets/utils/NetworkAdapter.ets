/**
 * NetworkAdapter - 网络适配器
 * 使用鸿蒙原生 @ohos.net.http 实现
 */

import http from '@ohos.net.http';
import { Logger } from './Logger';

export enum NetworkType {
  NATIVE = 'native'
}

export interface NetworkRequestOptions {
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
  timeout?: number;
  charset?: string;
  type?: string;
}

export interface NetworkError {
  type: 'timeout' | 'ssl' | 'dns' | 'http' | 'network' | 'unknown';
  message: string;
  statusCode?: number;
}

const DEFAULT_TIMEOUT = 10000;
const MAX_TIMEOUT = 30000;
const DEFAULT_MAX_RETRIES = 3;
const RETRY_DELAY_BASE = 1000;
const RETRY_DELAY_MAX = 5000;

const DEFAULT_USER_AGENTS: string[] = [
  // Chrome 120+ (Windows)
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.0.0',
  // Chrome (Mac)
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  // Firefox
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0',
  // Safari
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
  // Mobile
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Linux; Android 10; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36 EdgA/119.0.0.0'
];

export class NetworkAdapter {
  private static instance: NetworkAdapter | null = null;
  private readonly TAG = 'NetworkAdapter';
  private defaultHeaders: Map<string, string> = new Map();
  private userAgentIndex: number = 0;

  private constructor() {
    this.initDefaultHeaders();
  }

  private initDefaultHeaders(): void {
    this.defaultHeaders.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8');
    this.defaultHeaders.set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
    this.defaultHeaders.set('Accept-Encoding', 'gzip, deflate');
    this.defaultHeaders.set('Cache-Control', 'no-cache');
    this.defaultHeaders.set('Pragma', 'no-cache');
    this.defaultHeaders.set('Connection', 'keep-alive');
    this.defaultHeaders.set('Upgrade-Insecure-Requests', '1');
    // 新增：更多浏览器特征，绕过反爬虫
    this.defaultHeaders.set('Sec-Fetch-Dest', 'document');
    this.defaultHeaders.set('Sec-Fetch-Mode', 'navigate');
    this.defaultHeaders.set('Sec-Fetch-Site', 'none');
    this.defaultHeaders.set('Sec-Fetch-User', '?1');
    this.defaultHeaders.set('DNT', '1');
    this.defaultHeaders.set('sec-ch-ua-mobile', '?0');
    this.defaultHeaders.set('sec-ch-ua-platform', '"Windows"');
  }

  private getRandomUserAgent(): string {
    const ua = DEFAULT_USER_AGENTS[this.userAgentIndex];
    this.userAgentIndex = (this.userAgentIndex + 1) % DEFAULT_USER_AGENTS.length;
    return ua;
  }

  private extractReferer(url: string): string {
    if (!url) return '';
    
    const protocolEnd = url.indexOf('://');
    if (protocolEnd === -1) return '';
    
    const protocol = url.substring(0, protocolEnd + 3);
    const hostStart = protocolEnd + 3;
    const pathStart = url.indexOf('/', hostStart);
    
    let hostname: string;
    if (pathStart === -1) {
      hostname = url.substring(hostStart);
    } else {
      hostname = url.substring(hostStart, pathStart);
    }
    
    const portIndex = hostname.indexOf(':');
    if (portIndex !== -1) {
      hostname = hostname.substring(0, portIndex);
    }
    
    return `${protocol}${hostname}/`;
  }

  static getInstance(): NetworkAdapter {
    if (!NetworkAdapter.instance) {
      NetworkAdapter.instance = new NetworkAdapter();
    }
    return NetworkAdapter.instance;
  }

  async request(url: string, options?: NetworkRequestOptions): Promise<string> {
    const opts: NetworkRequestOptions = options ?? {};
    const maxRetries = opts.timeout ? 1 : DEFAULT_MAX_RETRIES;

    let lastError: Error | null = null;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      if (attempt > 0) {
        const delay = Math.min(RETRY_DELAY_BASE * Math.pow(2, attempt - 1), RETRY_DELAY_MAX);
        Logger.info(this.TAG, `重试请求: ${url}, 第${attempt}次, 等待${delay}ms`);
        await this.sleep(delay);

        // 轮换 User-Agent 和请求头
        if (!opts.headers) {
          opts.headers = {};
        }
        opts.headers['User-Agent'] = this.getRandomUserAgent();
        // 随机化 Accept-Language 增加多样性
        const languages = ['zh-CN,zh;q=0.9,en;q=0.8', 'zh-CN,zh;q=0.9', 'en-US,en;q=0.9,zh-CN;q=0.8'];
        opts.headers['Accept-Language'] = languages[attempt % languages.length];
        // 添加随机 Referer
        if (Math.random() > 0.5) {
          opts.headers['Referer'] = this.extractReferer(url);
        }
      }

      try {
        const result = await this.nativeRequest(url, opts);
        return result;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        const networkError = this.parseNetworkError(lastError.message);

        // 不可重试的错误类型
        if (networkError.type === 'http' && networkError.statusCode === 404) {
          Logger.warn(this.TAG, `404错误，不重试: ${url}`);
          throw lastError;
        }

        // 403 可能是反爬，尝试轮换 UA 和更多请求头
        if (networkError.type === 'http' && networkError.statusCode === 403) {
          Logger.warn(this.TAG, `403错误，尝试轮换UA和请求头: ${url}, 第${attempt + 1}次`);
          // 添加更多反爬绕过请求头
          if (!opts.headers) {
            opts.headers = {};
          }
          opts.headers['Cache-Control'] = 'max-age=0';
          opts.headers['sec-ch-ua'] = '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"';
          continue;
        }

        // 超时和网络错误可以重试
        if (networkError.type === 'timeout' || networkError.type === 'network' || networkError.type === 'dns') {
          Logger.warn(this.TAG, `${networkError.type}错误，准备重试: ${url}`);
          continue;
        }

        // SSL错误不重试
        if (networkError.type === 'ssl') {
          Logger.error(this.TAG, `SSL错误，不重试: ${url}`);
          throw lastError;
        }

        // 其他错误也重试
        Logger.warn(this.TAG, `请求失败，准备重试: ${url}, 错误: ${networkError.message}`);
      }
    }

    throw lastError || new Error('Max retries exceeded');
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async get(url: string, headers?: Record<string, string>): Promise<string> {
    const opts: NetworkRequestOptions = {
      method: 'GET',
      headers: headers
    };
    return this.request(url, opts);
  }

  async post(url: string, body: string, headers?: Record<string, string>): Promise<string> {
    const opts: NetworkRequestOptions = {
      method: 'POST',
      body: body,
      headers: headers
    };
    return this.request(url, opts);
  }

  private async nativeRequest(url: string, options: NetworkRequestOptions): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void) => {
      const httpRequest = http.createHttp();

      const method: 'GET' | 'POST' = options.method || 'GET';
      const headers: Record<string, string> = options.headers || {};
      
      if (!headers['User-Agent']) {
        headers['User-Agent'] = this.getRandomUserAgent();
      }
      
      if (!headers['Referer'] && url) {
        const referer = this.extractReferer(url);
        if (referer) {
          headers['Referer'] = referer;
        }
      }
      
      this.defaultHeaders.forEach((value: string, key: string) => {
        if (!headers[key]) {
          headers[key] = value;
        }
      });

      const timeout = Math.min(options.timeout || DEFAULT_TIMEOUT, MAX_TIMEOUT);
      
      const requestOptions: http.HttpRequestOptions = {
        method: method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: headers,
        extraData: options.body || '',
        readTimeout: timeout,
        connectTimeout: timeout,
      };

      Logger.debug(this.TAG, `发起请求: ${url}, 方法: ${method}, 超时: ${timeout}ms`);

      httpRequest.request(url, requestOptions, (err: Error | null, data: http.HttpResponse) => {
        if (!err && data) {
          const responseCode = data.responseCode;
          const result = data.result.toString();
          Logger.debug(this.TAG, `请求完成: ${url}, 状态码: ${responseCode}, 响应长度: ${result.length}`);
          
          if (responseCode >= 200 && responseCode < 300) {
            resolve(result);
          } else if (responseCode === 403) {
            const networkError: NetworkError = {
              type: 'http',
              message: '访问被拒绝(403)，可能触发了反爬机制',
              statusCode: 403
            };
            reject(new Error(`NETWORK_ERROR:${JSON.stringify(networkError)}`));
          } else if (responseCode === 404) {
            const networkError: NetworkError = {
              type: 'http',
              message: '页面不存在(404)',
              statusCode: 404
            };
            reject(new Error(`NETWORK_ERROR:${JSON.stringify(networkError)}`));
          } else if (responseCode >= 500) {
            const networkError: NetworkError = {
              type: 'http',
              message: `服务器错误(${responseCode})`,
              statusCode: responseCode
            };
            reject(new Error(`NETWORK_ERROR:${JSON.stringify(networkError)}`));
          } else {
            reject(new Error(`HTTP ${responseCode}: ${result.substring(0, 200)}`));
          }
        } else {
          const errorMsg = err?.message || 'Unknown error';
          const lowerErrorMsg = errorMsg.toLowerCase();
          
          let networkError: NetworkError;
          
          if (lowerErrorMsg.includes('timeout') || lowerErrorMsg.includes('timed out')) {
            networkError = {
              type: 'timeout',
              message: `请求超时(${timeout}ms)`
            };
          } else if (lowerErrorMsg.includes('ssl') || lowerErrorMsg.includes('certificate') || lowerErrorMsg.includes('cert')) {
            networkError = {
              type: 'ssl',
              message: 'SSL证书错误'
            };
          } else if (lowerErrorMsg.includes('resolve') || lowerErrorMsg.includes('dns') || lowerErrorMsg.includes('host')) {
            networkError = {
              type: 'dns',
              message: '域名解析失败'
            };
          } else if (lowerErrorMsg.includes('network') || lowerErrorMsg.includes('connection')) {
            networkError = {
              type: 'network',
              message: '网络连接失败'
            };
          } else {
            networkError = {
              type: 'unknown',
              message: errorMsg
            };
          }
          
          Logger.error(this.TAG, `请求失败: ${url}, 错误类型: ${networkError.type}, 消息: ${networkError.message}`);
          reject(new Error(`NETWORK_ERROR:${JSON.stringify(networkError)}`));
        }
        httpRequest.destroy();
      });
    });
  }

  parseNetworkError(errorMsg: string): NetworkError {
    if (errorMsg.startsWith('NETWORK_ERROR:')) {
      try {
        const jsonStr = errorMsg.substring('NETWORK_ERROR:'.length);
        return JSON.parse(jsonStr) as NetworkError;
      } catch {
        // ignore
      }
    }
    return {
      type: 'unknown',
      message: errorMsg
    };
  }

  setDefaultHeader(key: string, value: string): void {
    this.defaultHeaders.set(key, value);
  }

  removeDefaultHeader(key: string): void {
    this.defaultHeaders.delete(key);
  }

  clearCookies(): void {
    Logger.info(this.TAG, 'Cookies cleared (no-op for native HTTP)');
  }
}

export default NetworkAdapter.getInstance();
