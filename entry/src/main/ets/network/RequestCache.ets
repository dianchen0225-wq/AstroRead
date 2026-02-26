/**
 * RequestCache - 请求缓存管理器
 * 支持内存缓存和磁盘缓存
 */

import { RequestCacheConfig, CacheStats, HttpResponse } from './interfaces/IHttpClient';
import { Logger } from '../utils/performance/Logger';
interface CacheEntry {
  key: string;
  response: HttpResponse;
  timestamp: number;
  ttl: number;
  hits: number;
  size: number;
  varyHeaders?: Map<string, string>;
}

interface CacheEntryInfo {
  key: string;
  size: number;
  age: number;
  hits: number;
}

export class RequestCache {
  private static instance: RequestCache | null = null;

  private memoryCache: Map<string, CacheEntry> = new Map();
  private maxSize: number = 100;
  private defaultTTL: number = 5 * 60 * 1000;
  private hits: number = 0;
  private misses: number = 0;

  private readonly TAG = 'RequestCache';

  private constructor() {}

  static getInstance(): RequestCache {
    if (!RequestCache.instance) {
      RequestCache.instance = new RequestCache();
    }
    return RequestCache.instance;
  }
  generateKey(url: string, method: string, params?: Map<string, string>, body?: string, varyHeaders?: Map<string, string>): string {
    const parts = [method.toUpperCase(), url];

    if (params && params.size > 0) {
      const sortedParams: string[] = [];
      const keys: string[] = [];
      params.forEach((_, key) => keys.push(key));
      keys.sort();
      for (const k of keys) {
        const v = params.get(k);
        if (v !== undefined) {
          sortedParams.push(`${k}=${v}`);
        }
      }
      parts.push(sortedParams.join('&'));
    }

    if (body) {
      const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
      parts.push(this.hashString(bodyStr));
    }

    if (varyHeaders && varyHeaders.size > 0) {
      const sortedVary: string[] = [];
      const varyKeys: string[] = [];
      varyHeaders.forEach((_, key) => varyKeys.push(key));
      varyKeys.sort();
      for (const k of varyKeys) {
        const v = varyHeaders.get(k);
        if (v !== undefined) {
          sortedVary.push(`${k}=${v}`);
        }
      }
      parts.push('vary:' + sortedVary.join('&'));
    }

    return this.hashString(parts.join('|'));
  }

  static generateKey(url: string, method: string, params?: Record<string, string>, body?: string): string {
    const parts = [method.toUpperCase(), url];

    if (params && Object.keys(params).length > 0) {
      const sortedParams: string[] = [];
      const keys = Object.keys(params).sort();
      for (const k of keys) {
        const v = params[k];
        if (v !== undefined) {
          sortedParams.push(`${k}=${v}`);
        }
      }
      parts.push(sortedParams.join('&'));
    }

    if (body) {
      const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
      parts.push(RequestCache.staticHashString(bodyStr));
    }

    return RequestCache.staticHashString(parts.join('|'));
  }

  private static staticHashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }

  private hashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }

  get(key: string): HttpResponse | null {
    const entry = this.memoryCache.get(key);

    if (!entry) {
      this.misses++;
      return null;
    }

    if (this.isExpired(entry)) {
      this.memoryCache.delete(key);
      this.misses++;
      Logger.debug(this.TAG, `Cache expired: ${key}`);
      return null;
    }

    entry.hits++;
    this.hits++;
    Logger.debug(this.TAG, `Cache hit: ${key}`);
    return entry.response;
  }

  set(key: string, response: HttpResponse, ttl?: number): void {
    if (this.memoryCache.size >= this.maxSize) {
      this.evictLRU();
    }

    const responseSize = this.estimateSize(response);

    const entry: CacheEntry = {
      key,
      response,
      timestamp: Date.now(),
      ttl: ttl ?? this.defaultTTL,
      hits: 0,
      size: responseSize
    };

    this.memoryCache.set(key, entry);
    Logger.debug(this.TAG, `Cache set: ${key}, size: ${responseSize} bytes`);
  }

  delete(key: string): boolean {
    return this.memoryCache.delete(key);
  }

  has(key: string): boolean {
    const entry = this.memoryCache.get(key);
    if (!entry) return false;

    if (this.isExpired(entry)) {
      this.memoryCache.delete(key);
      return false;
    }

    return true;
  }

  clear(): void {
    this.memoryCache.clear();
    this.hits = 0;
    this.misses = 0;
    Logger.info(this.TAG, 'Cache cleared');
  }

  private isExpired(entry: CacheEntry): boolean {
    return Date.now() - entry.timestamp > entry.ttl;
  }

  private evictLRU(): void {
    let lruKey: string | null = null;
    let lruHits = Infinity;

    this.memoryCache.forEach((entry, key) => {
      if (entry.hits < lruHits) {
        lruHits = entry.hits;
        lruKey = key;
      }
    });

    if (lruKey) {
      this.memoryCache.delete(lruKey);
      Logger.debug(this.TAG, `Evicted LRU cache entry: ${lruKey}`);
    }
  }

  private estimateSize(response: HttpResponse): number {
    try {
      const dataStr = typeof response.data === 'string'
        ? response.data
        : JSON.stringify(response.data);
      return dataStr.length * 2;
    } catch {
      return 1000;
    }
  }
  getStats(): CacheStats {
    const entries: CacheEntryInfo[] = Array.from(this.memoryCache.entries()).map((entryPair) => {
      const key = entryPair[0];
      const entry = entryPair[1];
      return {
        key,
        size: entry.size,
        age: Date.now() - entry.timestamp,
        hits: entry.hits
      } as CacheEntryInfo;
    });

    const totalRequests = this.hits + this.misses;

    return {
      size: this.memoryCache.size,
      maxSize: this.maxSize,
      hitRate: totalRequests > 0 ? this.hits / totalRequests : 0,
      missRate: totalRequests > 0 ? this.misses / totalRequests : 0,
      entries
    };
  }

  setMaxSize(size: number): void {
    this.maxSize = size;

    while (this.memoryCache.size > this.maxSize) {
      this.evictLRU();
    }
  }

  setDefaultTTL(ttl: number): void {
    this.defaultTTL = ttl;
  }

  cleanup(): void {
    const expiredKeys: string[] = [];

    this.memoryCache.forEach((entry, key) => {
      if (this.isExpired(entry)) {
        expiredKeys.push(key);
      }
    });

    for (const key of expiredKeys) {
      this.memoryCache.delete(key);
    }

    if (expiredKeys.length > 0) {
      Logger.debug(this.TAG, `Cleaned up ${expiredKeys.length} expired entries`);
    }
  }

  shouldCache(method: string, status: number): boolean {
    if (method.toUpperCase() !== 'GET') {
      return false;
    }

    return status >= 200 && status < 300;
  }
}

export default RequestCache.getInstance();
