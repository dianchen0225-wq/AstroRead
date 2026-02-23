/**
 * BaseCache - 通用缓存基类
 * 提供 LRU 淘汰策略、TTL 过期机制和统计功能
 */

import { Logger } from '../utils/Logger';

export interface CacheConfig {
  maxSize: number;
  ttl: number;
  enableStats?: boolean;
}

export interface CacheEntry<T> {
  value: T;
  timestamp: number;
  accessCount: number;
  size: number;
}

export interface CacheStats {
  size: number;
  maxSize: number;
  hitRate: number;
  missRate: number;
  hitCount: number;
  missCount: number;
  totalSize: number;
}

export interface CacheEvictionResult {
  evicted: number;
  reason: 'expired' | 'lru' | 'size_limit';
}

const DEFAULT_CONFIG: CacheConfig = {
  maxSize: 100,
  ttl: 5 * 60 * 1000,
  enableStats: true
};

export abstract class BaseCache<T> {
  protected cache: Map<string, CacheEntry<T>> = new Map();
  protected config: CacheConfig;
  protected hitCount: number = 0;
  protected missCount: number = 0;
  protected totalSize: number = 0;

  protected readonly abstract TAG: string;

  constructor(config?: Partial<CacheConfig>) {
    this.config = this.mergeConfig(DEFAULT_CONFIG, config);
  }

  /**
   * 合并配置对象
   */
  private mergeConfig(defaultConfig: CacheConfig, userConfig?: Partial<CacheConfig>): CacheConfig {
    const result: CacheConfig = {
      maxSize: defaultConfig.maxSize,
      ttl: defaultConfig.ttl,
      enableStats: defaultConfig.enableStats
    };
    if (userConfig) {
      if (userConfig.maxSize !== undefined) {
        result.maxSize = userConfig.maxSize;
      }
      if (userConfig.ttl !== undefined) {
        result.ttl = userConfig.ttl;
      }
      if (userConfig.enableStats !== undefined) {
        result.enableStats = userConfig.enableStats;
      }
    }
    return result;
  }

  /**
   * 生成缓存键（子类可重写）
   */
  protected abstract generateKey(...args: ESObject[]): string;

  /**
   * 估算值大小（子类可重写）
   */
  protected estimateValueSize(value: T): number {
    if (typeof value === 'string') {
      return value.length * 2;
    }
    if (value instanceof ArrayBuffer) {
      return value.byteLength;
    }
    try {
      return JSON.stringify(value).length * 2;
    } catch {
      return 100;
    }
  }

  /**
   * 简单的字符串哈希
   */
  protected hashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }

  /**
   * 获取缓存值
   */
  get(key: string): T | null {
    const entry = this.cache.get(key);

    if (!entry) {
      this.recordMiss();
      return null;
    }

    if (this.isExpired(entry)) {
      this.deleteEntry(key);
      this.recordMiss();
      Logger.debug(this.TAG, `Cache expired: ${key}`);
      return null;
    }

    entry.accessCount++;
    this.recordHit();
    Logger.debug(this.TAG, `Cache hit: ${key}, access count: ${entry.accessCount}`);
    return entry.value;
  }

  /**
   * 设置缓存值
   */
  set(key: string, value: T, ttl?: number): void {
    this.cleanupExpired();

    if (this.cache.size >= this.config.maxSize) {
      this.evictLRU();
    }

    const size = this.estimateValueSize(value);
    const entry: CacheEntry<T> = {
      value,
      timestamp: Date.now(),
      accessCount: 1,
      size
    };

    const existingEntry = this.cache.get(key);
    if (existingEntry) {
      this.totalSize -= existingEntry.size;
    }

    this.cache.set(key, entry);
    this.totalSize += size;

    Logger.debug(this.TAG, `Cache set: ${key}, size: ${size} bytes, total: ${this.cache.size}`);
  }

  /**
   * 检查缓存是否存在
   */
  has(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) return false;

    if (this.isExpired(entry)) {
      this.deleteEntry(key);
      return false;
    }

    return true;
  }

  /**
   * 删除缓存项
   */
  delete(key: string): boolean {
    return this.deleteEntry(key);
  }

  /**
   * 删除缓存项（内部方法）
   */
  private deleteEntry(key: string): boolean {
    const entry = this.cache.get(key);
    if (entry) {
      this.totalSize -= entry.size;
    }
    return this.cache.delete(key);
  }

  /**
   * 清空缓存
   */
  clear(): void {
    this.cache.clear();
    this.totalSize = 0;
    this.hitCount = 0;
    this.missCount = 0;
    Logger.info(this.TAG, 'Cache cleared');
  }

  /**
   * 检查是否过期
   */
  protected isExpired(entry: CacheEntry<T>): boolean {
    return Date.now() - entry.timestamp > this.config.ttl;
  }

  /**
   * 清理过期缓存项
   */
  protected cleanupExpired(): CacheEvictionResult {
    const keysToDelete: string[] = [];

    this.cache.forEach((entry, key) => {
      if (this.isExpired(entry)) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.deleteEntry(key);
    }

    if (keysToDelete.length > 0) {
      Logger.debug(this.TAG, `Cleaned up ${keysToDelete.length} expired entries`);
    }

    return {
      evicted: keysToDelete.length,
      reason: 'expired'
    };
  }

  /**
   * 移除最少访问的项 (LRU)
   */
  protected evictLRU(): CacheEvictionResult {
    let minAccess = Infinity;
    let keyToDelete: string | null = null;

    this.cache.forEach((entry, key) => {
      if (entry.accessCount < minAccess) {
        minAccess = entry.accessCount;
        keyToDelete = key;
      }
    });

    if (keyToDelete) {
      this.deleteEntry(keyToDelete);
      Logger.debug(this.TAG, `LRU eviction: ${keyToDelete}`);
    }

    return {
      evicted: keyToDelete ? 1 : 0,
      reason: 'lru'
    };
  }

  /**
   * 记录命中
   */
  protected recordHit(): void {
    if (this.config.enableStats) {
      this.hitCount++;
    }
  }

  /**
   * 记录未命中
   */
  protected recordMiss(): void {
    if (this.config.enableStats) {
      this.missCount++;
    }
  }

  /**
   * 获取缓存统计
   */
  getStats(): CacheStats {
    const total = this.hitCount + this.missCount;
    const hitRate = total > 0 ? this.hitCount / total : 0;
    const missRate = total > 0 ? this.missCount / total : 0;

    return {
      size: this.cache.size,
      maxSize: this.config.maxSize,
      hitRate,
      missRate,
      hitCount: this.hitCount,
      missCount: this.missCount,
      totalSize: this.totalSize
    };
  }

  /**
   * 设置缓存配置
   */
  setConfig(config: Partial<CacheConfig>): void {
    if (config.maxSize !== undefined) {
      this.config.maxSize = config.maxSize;
      while (this.cache.size > this.config.maxSize) {
        this.evictLRU();
      }
    }
    if (config.ttl !== undefined) {
      this.config.ttl = config.ttl;
    }
    if (config.enableStats !== undefined) {
      this.config.enableStats = config.enableStats;
    }
  }

  /**
   * 获取缓存配置
   */
  getConfig(): CacheConfig {
    return {
      maxSize: this.config.maxSize,
      ttl: this.config.ttl,
      enableStats: this.config.enableStats
    };
  }

  /**
   * 获取缓存大小
   */
  get size(): number {
    return this.cache.size;
  }

  /**
   * 获取所有键
   */
  keys(): string[] {
    return Array.from(this.cache.keys());
  }

  /**
   * 批量删除匹配的键
   */
  deleteByPattern(pattern: string): number {
    const regex = new RegExp(pattern);
    const keysToDelete: string[] = [];

    this.cache.forEach((_, key) => {
      if (regex.test(key)) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.deleteEntry(key);
    }

    return keysToDelete.length;
  }
}

export default BaseCache;
