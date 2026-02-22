/**
 * HttpClientConfig - HTTP客户端配置管理
 * 负责管理默认配置和配置合并
 */

import {
  HttpClientConfig as IHttpClientConfig,
  HttpRequestConfig,
  HttpHeaders,
  HttpHeaderMap,
  HttpResponseType,
  RequestCacheConfig,
  RetryConfig
} from './interfaces/IHttpClient';
import { DEFAULT_USER_AGENT, USER_AGENT_POOL } from './UserAgentPool';

/**
 * 状态码文本映射
 */
const STATUS_TEXT_MAP: Record<number, string> = {
  200: 'OK',
  201: 'Created',
  204: 'No Content',
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  500: 'Internal Server Error'
};
/**
 * 默认配置接口
 */
interface DefaultConfig {
  TIMEOUT: number;
  CONNECT_TIMEOUT: number;
  READ_TIMEOUT: number;
  MAX_REDIRECTS: number;
  MAX_RESPONSE_SIZE: number;
  CACHE_TTL: number;
  MAX_RETRIES: number;
  MAX_METRICS: number;
  DEFAULT_USER_AGENT: string;
}

/**
 * 默认配置
 */
const DEFAULTS: DefaultConfig = {
  TIMEOUT: 30000,
  CONNECT_TIMEOUT: 10000,
  READ_TIMEOUT: 30000,
  MAX_REDIRECTS: 5,
  MAX_RESPONSE_SIZE: 10 * 1024 * 1024,
  CACHE_TTL: 5 * 60 * 1000,
  MAX_RETRIES: 3,
  MAX_METRICS: 100,
  DEFAULT_USER_AGENT: DEFAULT_USER_AGENT
};

/**
 * 内部使用的完整配置接口
 */
export interface InternalConfig {
  baseURL: string;
  timeout: number;
  connectTimeout: number;
  readTimeout: number;
  headers: HttpHeaders;
  withCredentials: boolean;
  maxRedirects: number;
  maxResponseSize: number;
  responseType: HttpResponseType;
  validateStatus: (status: number) => boolean;
  cache: RequestCacheConfig;
  retry: RetryConfig;
  enableLogging: boolean;
  enableMetrics: boolean;
  userAgentPool: string[];
  refererPool: string[];
}

/**
 * 配置管理器
 */
export class ConfigManager {
  private config: InternalConfig;
  private defaultHeaders: Map<string, string> = new Map();

  constructor(config?: IHttpClientConfig) {
    this.config = this.createDefaultConfig(config);
  }

  /**
   * 创建默认配置
   */
  private createDefaultConfig(config?: IHttpClientConfig): InternalConfig {
    return {
      baseURL: config?.baseURL ?? '',
      timeout: config?.timeout ?? DEFAULTS.TIMEOUT,
      connectTimeout: config?.connectTimeout ?? DEFAULTS.CONNECT_TIMEOUT,
      readTimeout: config?.readTimeout ?? DEFAULTS.READ_TIMEOUT,
      headers: config?.headers ?? {},
      withCredentials: config?.withCredentials ?? false,
      maxRedirects: config?.maxRedirects ?? DEFAULTS.MAX_REDIRECTS,
      maxResponseSize: config?.maxResponseSize ?? DEFAULTS.MAX_RESPONSE_SIZE,
      responseType: config?.responseType ?? { type: 'text' },
      validateStatus: config?.validateStatus ?? ((status: number) => status >= 200 && status < 300),
      cache: config?.cache ?? { enabled: true, ttl: DEFAULTS.CACHE_TTL },
      retry: config?.retry ?? { maxRetries: DEFAULTS.MAX_RETRIES },
      enableLogging: config?.enableLogging ?? true,
      enableMetrics: config?.enableMetrics ?? true,
      userAgentPool: config?.userAgentPool ?? USER_AGENT_POOL,
      refererPool: config?.refererPool ?? []
    };
  }

  /**
   * 获取配置
   */
  getConfig(): InternalConfig {
    return this.config;
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<IHttpClientConfig>): void {
    this.config = {
      baseURL: config.baseURL ?? this.config.baseURL,
      timeout: config.timeout ?? this.config.timeout,
      connectTimeout: config.connectTimeout ?? this.config.connectTimeout,
      readTimeout: config.readTimeout ?? this.config.readTimeout,
      headers: config.headers ?? this.config.headers,
      withCredentials: config.withCredentials ?? this.config.withCredentials,
      maxRedirects: config.maxRedirects ?? this.config.maxRedirects,
      maxResponseSize: config.maxResponseSize ?? this.config.maxResponseSize,
      responseType: config.responseType ?? this.config.responseType,
      validateStatus: config.validateStatus ?? this.config.validateStatus,
      cache: config.cache ?? this.config.cache,
      retry: config.retry ?? this.config.retry,
      enableLogging: config.enableLogging ?? this.config.enableLogging,
      enableMetrics: config.enableMetrics ?? this.config.enableMetrics,
      userAgentPool: config.userAgentPool ?? this.config.userAgentPool,
      refererPool: config.refererPool ?? this.config.refererPool
    };
  }

  /**
   * 设置基础URL
   */
  setBaseURL(url: string): void {
    this.config.baseURL = url;
  }

  /**
   * 设置默认请求头
   */
  setDefaultHeader(key: string, value: string): void {
    this.defaultHeaders.set(key, value);
  }

  /**
   * 移除默认请求头
   */
  removeDefaultHeader(key: string): void {
    this.defaultHeaders.delete(key);
  }

  /**
   * 获取默认请求头
   */
  getDefaultHeaders(): Map<string, string> {
    return this.defaultHeaders;
  }

  /**
   * 清空默认请求头
   */
  clearDefaultHeaders(): void {
    this.defaultHeaders.clear();
  }

  /**
   * 合并请求配置
   */
  mergeRequestConfig(requestConfig: HttpRequestConfig): HttpRequestConfig {
    return {
      url: requestConfig.url,
      method: requestConfig.method,
      headers: this.mergeHeaders(requestConfig.headers),
      params: requestConfig.params,
      data: requestConfig.data,
      body: requestConfig.body,
      timeout: requestConfig.timeout ?? this.config.timeout,
      connectTimeout: requestConfig.connectTimeout ?? this.config.connectTimeout,
      readTimeout: requestConfig.readTimeout ?? this.config.readTimeout,
      responseType: requestConfig.responseType ?? this.config.responseType,
      encoding: requestConfig.encoding,
      charset: requestConfig.charset,
      withCredentials: requestConfig.withCredentials ?? this.config.withCredentials,
      maxRedirects: requestConfig.maxRedirects ?? this.config.maxRedirects,
      maxResponseSize: requestConfig.maxResponseSize ?? this.config.maxResponseSize,
      validateStatus: requestConfig.validateStatus ?? this.config.validateStatus,
      signal: requestConfig.signal,
      abortController: requestConfig.abortController,
      cache: requestConfig.cache ?? this.config.cache,
      retry: requestConfig.retry ?? this.config.retry,
      metadata: requestConfig.metadata
    };
  }

  /**
   * 合并请求头
   */
  mergeHeaders(headers?: HttpHeaders | HttpHeaderMap): HttpHeaders {
    const result: HttpHeaders = {};

    // 合并默认头
    this.defaultHeaders.forEach((value, key) => {
      this.setHeaderValue(result, key, value);
    });

    // 合并配置头
    if (headers) {
      if (headers instanceof Map) {
        headers.forEach((value, key) => {
          this.setHeaderValue(result, key, value);
        });
      } else {
        Object.entries(headers).forEach((entry) => {
          const key = entry[0];
          const value = entry[1];
          if (value !== undefined) {
            this.setHeaderValue(result, key, value);
          }
        });
      }
    }

    return result;
  }
  /**
   * 设置请求头值
   */
  private setHeaderValue(result: HttpHeaders, key: string, value: string): void {
    const normalizedKey = key.toLowerCase();
    switch (normalizedKey) {
      case 'content-type':
        result['Content-Type'] = value;
        break;
      case 'accept':
        result.Accept = value;
        break;
      case 'user-agent':
        result['User-Agent'] = value;
        break;
      case 'authorization':
        result.Authorization = value;
        break;
      case 'cookie':
        result.Cookie = value;
        break;
      default:
        // 对于动态属性，使用明确的属性赋值
        if (normalizedKey === 'content-length') {
          result['Content-Length'] = value;
        } else if (normalizedKey === 'content-encoding') {
          result['Content-Encoding'] = value;
        } else if (normalizedKey === 'cache-control') {
          result['Cache-Control'] = value;
        } else if (normalizedKey === 'pragma') {
          result['Pragma'] = value;
        } else {
          // 对于其他动态属性，使用类型断言
          (result as Record<string, string>)[key] = value;
        }
    }
  }

  /**
   * 获取随机User-Agent
   */
  getRandomUserAgent(): string {
    if (this.config.userAgentPool.length > 0) {
      const index = Math.floor(Math.random() * this.config.userAgentPool.length);
      return this.config.userAgentPool[index];
    }
    return DEFAULTS.DEFAULT_USER_AGENT;
  }

  /**
   * 获取状态码文本
   */
  static getStatusText(status: number): string {
    return STATUS_TEXT_MAP[status] ?? 'Unknown';
  }
  /**
   * 获取默认常量
   */
  static getDefaults(): DefaultConfig {
    const result: DefaultConfig = {
      TIMEOUT: DEFAULTS.TIMEOUT,
      CONNECT_TIMEOUT: DEFAULTS.CONNECT_TIMEOUT,
      READ_TIMEOUT: DEFAULTS.READ_TIMEOUT,
      MAX_REDIRECTS: DEFAULTS.MAX_REDIRECTS,
      MAX_RESPONSE_SIZE: DEFAULTS.MAX_RESPONSE_SIZE,
      CACHE_TTL: DEFAULTS.CACHE_TTL,
      MAX_RETRIES: DEFAULTS.MAX_RETRIES,
      MAX_METRICS: DEFAULTS.MAX_METRICS,
      DEFAULT_USER_AGENT: DEFAULTS.DEFAULT_USER_AGENT
    };
    return result;
  }
}

export { DEFAULTS };
