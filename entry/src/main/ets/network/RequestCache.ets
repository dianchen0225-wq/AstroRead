/**
 * RequestCache - 请求缓存管理器
 * 继承自 BaseCache，缓存 HTTP 响应
 */

import { CacheStats, HttpResponse } from './interfaces/IHttpClient';
import { BaseCache, CacheConfig } from '../core/BaseCache';
import { Logger } from '../utils/Logger';

interface CacheEntryInfo {
  key: string;
  size: number;
  age: number;
  hits: number;
}

export class RequestCache extends BaseCache<HttpResponse> {
  private static instance: RequestCache | null = null;
  protected readonly TAG = 'RequestCache';

  private defaultTTL: number = 5 * 60 * 1000;

  private constructor(config?: Partial<CacheConfig>) {
    super({ maxSize: 100, ttl: 5 * 60 * 1000, ...config });
  }

  static getInstance(): RequestCache {
    if (!RequestCache.instance) {
      RequestCache.instance = new RequestCache();
    }
    return RequestCache.instance;
  }

  /**
   * 生成缓存键
   */
  protected generateKey(
    url: string,
    method: string,
    params?: Record<string, string>,
    body?: string
  ): string {
    const parts = [method.toUpperCase(), url];

    if (params && Object.keys(params).length > 0) {
      const sortedParams = Object.keys(params)
        .sort()
        .map(k => `${k}=${params[k]}`);
      parts.push(sortedParams.join('&'));
    }

    if (body) {
      const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
      parts.push(this.hashString(bodyStr));
    }

    return this.hashString(parts.join('|'));
  }

  /**
   * 静态方法：生成缓存键（兼容旧接口）
   */
  static generateKey(
    url: string,
    method: string,
    params?: Record<string, string>,
    body?: string
  ): string {
    return RequestCache.getInstance().generateKey(url, method, params, body);
  }

  /**
   * 获取缓存的响应
   */
  get(key: string): HttpResponse | null {
    return super.get(key);
  }

  /**
   * 设置缓存
   */
  set(key: string, response: HttpResponse, ttl?: number): void {
    const actualTTL = ttl ?? this.defaultTTL;
    super.set(key, response, actualTTL);
    Logger.debug(this.TAG, `Cache set: ${key}, size: ${this.estimateValueSize(response)} bytes`);
  }

  /**
   * 估算响应大小
   */
  protected estimateValueSize(response: HttpResponse): number {
    try {
      const dataStr = typeof response.data === 'string'
        ? response.data
        : JSON.stringify(response.data);
      return dataStr.length * 2;
    } catch {
      return 1000;
    }
  }

  /**
   * 获取缓存统计（扩展版）
   */
  getStats(): CacheStats {
    const baseStats = super.getStats();

    const entries: CacheEntryInfo[] = this.keys().map(key => {
      const entry = this.cache.get(key);
      return {
        key,
        size: entry?.size ?? 0,
        age: Date.now() - (entry?.timestamp ?? 0),
        hits: entry?.accessCount ?? 0
      };
    });

    return {
      ...baseStats,
      entries
    };
  }

  /**
   * 设置最大缓存大小
   */
  setMaxSize(size: number): void {
    this.setConfig({ maxSize: size });
  }

  /**
   * 设置默认 TTL
   */
  setDefaultTTL(ttl: number): void {
    this.defaultTTL = ttl;
    this.setConfig({ ttl });
  }

  /**
   * 判断是否应该缓存
   */
  shouldCache(method: string, status: number): boolean {
    if (method.toUpperCase() !== 'GET') {
      return false;
    }
    return status >= 200 && status < 300;
  }

  /**
   * 清理过期缓存
   */
  cleanup(): void {
    this.cleanupExpired();
  }
}

export default RequestCache.getInstance();
