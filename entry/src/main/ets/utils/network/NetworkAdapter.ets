/**
 * NetworkAdapter - 网络适配器
 * 使用鸿蒙原生 @ohos.net.http 实现
 */

import { http } from '@kit.NetworkKit';
import { Logger } from "../performance/Logger";

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
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1'
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
    const maxRetries = options?.timeout ? 1 : DEFAULT_MAX_RETRIES;

    let lastError: Error | null = null;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      // 每次重试都深拷贝请求选项，避免状态累积
      const opts = this.cloneRequestOptions(options);

      if (attempt > 0) {
        const delay = Math.min(RETRY_DELAY_BASE * Math.pow(2, attempt - 1), RETRY_DELAY_MAX);
        Logger.info(this.TAG, `重试请求: ${url}, 第${attempt}次, 等待${delay}ms`);
        await this.sleep(delay);

        // 轮换 User-Agent
        opts.headers = opts.headers ?? {};
        opts.headers['User-Agent'] = this.getRandomUserAgent();
      }

      try {
        const result = await this.nativeRequest(url, opts);
        return result;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        const networkError = this.parseNetworkError(lastError.message);

        // 判断是否应该重试
        if (!this.shouldRetryError(networkError)) {
          Logger.warn(this.TAG, `${networkError.type}错误(状态码:${networkError.statusCode})，不重试: ${url}`);
          throw lastError;
        }

        // 如果是最后一次尝试，则抛出错误
        if (attempt === maxRetries - 1) {
          Logger.error(this.TAG, `达到最大重试次数，放弃请求: ${url}`);
          throw lastError;
        }

        Logger.warn(this.TAG, `${networkError.type}错误，准备重试: ${url}, 消息: ${networkError.message}`);
      }
    }

    throw lastError || new Error('Max retries exceeded');
  }

  /**
   * 深拷贝请求选项
   */
  private cloneRequestOptions(options?: NetworkRequestOptions): NetworkRequestOptions {
    const cloned: NetworkRequestOptions = {
      method: options?.method ?? 'GET',
      body: options?.body,
      timeout: options?.timeout,
      charset: options?.charset,
      type: options?.type
    };

    // 深拷贝 headers，避免状态累积
    if (options?.headers) {
      const headersCopy: Record<string, string> = {};
      const keys = Object.keys(options.headers);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        headersCopy[key] = options.headers[key];
      }
      cloned.headers = headersCopy;
    }

    return cloned;
  }

  /**
   * 判断是否应该重试错误
   * @param error 网络错误对象
   * @returns true 表示应该重试，false 表示不应该重试
   */
  private shouldRetryError(error: NetworkError): boolean {
    switch (error.type) {
      case 'timeout':
      case 'dns':
      case 'network':
        // 超时、DNS解析失败、网络连接错误可以重试
        return true;

      case 'ssl':
        // SSL证书错误不重试
        return false;

      case 'http':
        // HTTP状态码判断
        const statusCode = error.statusCode ?? 0;

        // 429 Too Many Requests 可以重试（限流）
        if (statusCode === 429) {
          return true;
        }

        // 4xx 客户端错误不重试（除了429）
        if (statusCode >= 400 && statusCode < 500) {
          return false;
        }

        // 5xx 服务器错误可以重试
        if (statusCode >= 500) {
          return true;
        }

        return false;

      case 'unknown':
      default:
        // 未知错误默认不重试
        return false;
    }
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
