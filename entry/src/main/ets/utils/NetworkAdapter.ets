/**
 * NetworkAdapter - 网络适配器
 * 统一网络请求入口，内部委托给 HttpClient 实现
 */

import { Logger } from './Logger';
import { HttpClient } from '../network/HttpClient';
import { HttpMethod, HttpRequestConfig, HttpResponse, HttpError, HttpErrorCode } from '../network/interfaces/IHttpClient';
import { userAgentPool, USER_AGENT_POOL } from '../network/UserAgentPool';

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

export class NetworkAdapter {
  private static instance: NetworkAdapter | null = null;
  private readonly TAG = 'NetworkAdapter';
  private httpClient: HttpClient;
  private defaultHeaders: Map<string, string> = new Map();

  private constructor() {
    this.httpClient = HttpClient.getInstance({
      timeout: DEFAULT_TIMEOUT,
      enableLogging: true,
      enableMetrics: true,
      userAgentPool: USER_AGENT_POOL,
      retry: {
        maxRetries: DEFAULT_MAX_RETRIES,
        retryDelay: RETRY_DELAY_BASE,
        retryDelayMultiplier: 2,
        maxRetryDelay: RETRY_DELAY_MAX,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryableErrors: ['TIMEOUT', 'NETWORK_ERROR', 'CONNECTION_ERROR']
      }
    });
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
    this.defaultHeaders.set('Sec-Fetch-Dest', 'document');
    this.defaultHeaders.set('Sec-Fetch-Mode', 'navigate');
    this.defaultHeaders.set('Sec-Fetch-Site', 'none');
    this.defaultHeaders.set('Sec-Fetch-User', '?1');
    this.defaultHeaders.set('DNT', '1');
    this.defaultHeaders.set('sec-ch-ua-mobile', '?0');
    this.defaultHeaders.set('sec-ch-ua-platform', '"Windows"');

    this.defaultHeaders.forEach((value: string, key: string) => {
      this.httpClient.setDefaultHeader(key, value);
    });
  }

  private getRandomUserAgent(): string {
    return userAgentPool.getNextUserAgent();
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
    const currentHeaders: Map<string, string> = new Map();

    if (opts.headers) {
      const keys = Object.keys(opts.headers);
      for (const key of keys) {
        currentHeaders.set(key, opts.headers[key]);
      }
    }

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      if (attempt > 0) {
        const delay = Math.min(RETRY_DELAY_BASE * Math.pow(2, attempt - 1), RETRY_DELAY_MAX);
        Logger.info(this.TAG, `重试请求: ${url}, 第${attempt}次, 等待${delay}ms`);
        await this.sleep(delay);

        currentHeaders.set('User-Agent', this.getRandomUserAgent());
        const languages = ['zh-CN,zh;q=0.9,en;q=0.8', 'zh-CN,zh;q=0.9', 'en-US,en;q=0.9,zh-CN;q=0.8'];
        currentHeaders.set('Accept-Language', languages[attempt % languages.length]);
        if (Math.random() > 0.5) {
          currentHeaders.set('Referer', this.extractReferer(url));
        }
      }

      if (!currentHeaders.has('User-Agent')) {
        currentHeaders.set('User-Agent', this.getRandomUserAgent());
      }
      if (!currentHeaders.has('Referer') && url) {
        const referer = this.extractReferer(url);
        if (referer) {
          currentHeaders.set('Referer', referer);
        }
      }

      try {
        const result = await this.executeHttpClientRequest(url, opts, currentHeaders);
        return result;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        const networkError = this.parseNetworkError(lastError.message);

        if (networkError.type === 'http' && networkError.statusCode === 404) {
          Logger.warn(this.TAG, `404错误，不重试: ${url}`);
          throw lastError;
        }

        if (networkError.type === 'http' && networkError.statusCode === 403) {
          Logger.warn(this.TAG, `403错误，尝试轮换UA和请求头: ${url}, 第${attempt + 1}次`);
          currentHeaders.set('Cache-Control', 'max-age=0');
          currentHeaders.set('sec-ch-ua', '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"');
          continue;
        }

        if (networkError.type === 'timeout' || networkError.type === 'network' || networkError.type === 'dns') {
          Logger.warn(this.TAG, `${networkError.type}错误，准备重试: ${url}`);
          continue;
        }

        if (networkError.type === 'ssl') {
          Logger.error(this.TAG, `SSL错误，不重试: ${url}`);
          throw lastError;
        }

        Logger.warn(this.TAG, `请求失败，准备重试: ${url}, 错误: ${networkError.message}`);
      }
    }

    throw lastError || new Error('Max retries exceeded');
  }

  private async executeHttpClientRequest(
    url: string,
    options: NetworkRequestOptions,
    headers: Map<string, string>
  ): Promise<string> {
    const method = options.method || 'GET';
    const timeout = Math.min(options.timeout || DEFAULT_TIMEOUT, MAX_TIMEOUT);

    const headersRecord: Record<string, string> = {};
    headers.forEach((value: string, key: string) => {
      headersRecord[key] = value;
    });

    const config: HttpRequestConfig = {
      url: url,
      method: method === 'GET' ? HttpMethod.GET : HttpMethod.POST,
      headers: headersRecord,
      timeout: timeout,
      data: options.body || '',
      retry: {
        maxRetries: 1
      }
    };

    Logger.debug(this.TAG, `发起请求: ${url}, 方法: ${method}, 超时: ${timeout}ms`);

    try {
      const response: HttpResponse<string> = await this.httpClient.request<string>(config);
      Logger.debug(this.TAG, `请求完成: ${url}, 状态码: ${response.status}, 响应长度: ${String(response.data).length}`);
      return response.data;
    } catch (error) {
      const httpError = error as HttpError;
      const networkError = this.convertHttpErrorToNetworkError(httpError);
      Logger.error(this.TAG, `请求失败: ${url}, 错误类型: ${networkError.type}, 消息: ${networkError.message}`);
      throw new Error(`NETWORK_ERROR:${JSON.stringify(networkError)}`);
    }
  }

  private convertHttpErrorToNetworkError(error: HttpError): NetworkError {
    switch (error.code) {
      case HttpErrorCode.TIMEOUT:
        return {
          type: 'timeout',
          message: error.message || '请求超时'
        };
      case HttpErrorCode.SSL_ERROR:
        return {
          type: 'ssl',
          message: error.message || 'SSL证书错误'
        };
      case HttpErrorCode.CONNECTION_ERROR:
      case HttpErrorCode.NETWORK_ERROR:
        return {
          type: 'network',
          message: error.message || '网络连接失败'
        };
      case HttpErrorCode.HTTP_ERROR:
        return {
          type: 'http',
          message: error.message || `HTTP错误(${error.status})`,
          statusCode: error.status
        };
      default:
        return {
          type: 'unknown',
          message: error.message || '未知错误'
        };
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
    this.httpClient.setDefaultHeader(key, value);
  }

  removeDefaultHeader(key: string): void {
    this.defaultHeaders.delete(key);
    this.httpClient.removeDefaultHeader(key);
  }

  clearCookies(): void {
    Logger.info(this.TAG, 'Cookies cleared');
  }
}

export default NetworkAdapter.getInstance();
