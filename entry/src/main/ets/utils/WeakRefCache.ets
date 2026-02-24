/**
 * WeakRefCache - 使用 WeakRef 的缓存实现
 * 允许垃圾回收器在内存不足时自动回收缓存对象
 */

import { Logger } from './Logger';
import { CacheConstants, TimeConstants } from '../constants';

interface CacheEntry<V extends object> {
  value: WeakRef<V>;
  key: string;
  timestamp: number;
  accessCount: number;
}

interface CacheStats {
  size: number;
  hitRate: number;
  hitCount: number;
  missCount: number;
}

interface CacheOptions {
  /** 最大缓存大小 */
  maxSize?: number;
  /** 过期时间（毫秒） */
  ttl?: number;
  /** 是否使用强引用（不启用 WeakRef） */
  strongReferences?: boolean;
}

/**
 * 使用 WeakRef 的缓存实现
 * 当内存不足时，垃圾回收器可以回收缓存的对象
 */
export class WeakRefCache<V extends object> {
  private readonly TAG = 'WeakRefCache';
  private cache: Map<string, CacheEntry<V>> = new Map();
  private strongRefs: Map<string, V> = new Map();
  private options: Required<CacheOptions>;
  private cleanupInterval: number = CacheConstants.CLEANUP_INTERVAL;
  private cleanupTimer: number | null = null;
  private hitCount: number = 0;
  private missCount: number = 0;

  constructor(options: CacheOptions = {}) {
    this.options = {
      maxSize: options.maxSize ?? CacheConstants.DEFAULT_MAX_SIZE,
      ttl: options.ttl ?? TimeConstants.FIVE_MINUTES,
      strongReferences: options.strongReferences ?? false
    };

    this.startCleanupTimer();
  }

  /**
   * 设置缓存
   */
  set(key: string, value: V): void {
    try {
      // 清理过期和已被回收的项
      this.cleanup();

      // 如果缓存已满，移除最少使用的项
      if (this.cache.size >= this.options.maxSize) {
        this.evictLRU();
      }

      const entry: CacheEntry<V> = {
        value: new WeakRef(value),
        key,
        timestamp: Date.now(),
        accessCount: 1
      };

      this.cache.set(key, entry);

      // 如果需要强引用，同时存储在 strongRefs 中
      if (this.options.strongReferences) {
        this.strongRefs.set(key, value);
      }

      Logger.debug(this.TAG, `缓存设置: ${key}, 当前大小: ${this.cache.size}`);
    } catch (error) {
      Logger.error(this.TAG, `设置缓存失败: ${error}`);
    }
  }

  /**
   * 获取缓存
   */
  get(key: string): V | null {
    const entry = this.cache.get(key);

    if (!entry) {
      this.missCount++;
      return null;
    }

    // 检查是否过期
    if (Date.now() - entry.timestamp > this.options.ttl) {
      this.delete(key);
      this.missCount++;
      return null;
    }

    // 尝试获取值
    const value = entry.value.deref();

    if (value === undefined) {
      // 值已被垃圾回收
      this.delete(key);
      this.missCount++;
      Logger.debug(this.TAG, `缓存值已被回收: ${key}`);
      return null;
    }

    // 更新访问计数
    entry.accessCount++;
    entry.timestamp = Date.now();
    this.hitCount++;

    Logger.debug(this.TAG, `缓存命中: ${key}, 访问次数: ${entry.accessCount}`);
    return value;
  }

  /**
   * 检查缓存是否存在
   */
  has(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) return false;

    // 检查是否过期
    if (Date.now() - entry.timestamp > this.options.ttl) {
      this.delete(key);
      return false;
    }

    // 检查值是否还存在
    return entry.value.deref() !== undefined;
  }

  /**
   * 删除缓存
   */
  delete(key: string): boolean {
    this.strongRefs.delete(key);
    return this.cache.delete(key);
  }

  /**
   * 清空缓存
   */
  clear(): void {
    this.cache.clear();
    this.strongRefs.clear();
    this.hitCount = 0;
    this.missCount = 0;
    Logger.debug(this.TAG, '缓存已清空');
  }

  /**
   * 获取缓存大小
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * 获取命中率
   */
  getHitRate(): number {
    const total = this.hitCount + this.missCount;
    return total > 0 ? this.hitCount / total : 0;
  }

  /**
   * 获取统计信息
   */
  getStats(): CacheStats {
    return {
      size: this.cache.size,
      hitRate: this.getHitRate(),
      hitCount: this.hitCount,
      missCount: this.missCount
    };
  }

  /**
   * 清理过期和已被回收的缓存项
   */
  private cleanup(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];

    this.cache.forEach((entry, key) => {
      // 检查是否过期
      if (now - entry.timestamp > this.options.ttl) {
        keysToDelete.push(key);
        return;
      }

      // 检查值是否已被回收
      if (entry.value.deref() === undefined) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.delete(key);
    }

    if (keysToDelete.length > 0) {
      Logger.debug(this.TAG, `清理缓存: ${keysToDelete.length} 项`);
    }
  }

  /**
   * 移除最少使用的项 (LRU)
   */
  private evictLRU(): void {
    let lruKey: string | null = null;
    let minAccessCount = Infinity;
    let oldestTime = Infinity;

    this.cache.forEach((entry, key) => {
      // 优先移除访问次数最少的，如果相同则移除最旧的
      if (entry.accessCount < minAccessCount ||
          (entry.accessCount === minAccessCount && entry.timestamp < oldestTime)) {
        minAccessCount = entry.accessCount;
        oldestTime = entry.timestamp;
        lruKey = key;
      }
    });

    if (lruKey) {
      this.delete(lruKey);
      Logger.debug(this.TAG, `LRU移除: ${lruKey}`);
    }
  }

  /**
   * 启动清理定时器
   */
  private startCleanupTimer(): void {
    if (this.cleanupTimer) {
      return;
    }

    this.cleanupTimer = setInterval(() => {
      this.cleanup();
    }, this.cleanupInterval);
  }

  /**
   * 停止清理定时器
   */
  stopCleanupTimer(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
  }

  /**
   * 销毁缓存
   */
  destroy(): void {
    this.stopCleanupTimer();
    this.clear();
    Logger.debug(this.TAG, '缓存已销毁');
  }
}

/**
 * 全局 WeakRefCache 实例工厂
 */
export class WeakRefCacheFactory {
  private static caches: Map<string, WeakRefCache<object>> = new Map();

  /**
   * 获取或创建缓存实例
   */
  static getCache<V extends object>(name: string, options?: CacheOptions): WeakRefCache<V> {
    let cache = WeakRefCacheFactory.caches.get(name) as WeakRefCache<V> | undefined;
    if (!cache) {
      cache = new WeakRefCache<V>(options);
      WeakRefCacheFactory.caches.set(name, cache as WeakRefCache<object>);
    }
    return cache;
  }

  /**
   * 移除缓存实例
   */
  static removeCache(name: string): void {
    const cache = WeakRefCacheFactory.caches.get(name);
    if (cache) {
      cache.destroy();
      WeakRefCacheFactory.caches.delete(name);
    }
  }

  /**
   * 清空所有缓存
   */
  static clearAll(): void {
    WeakRefCacheFactory.caches.forEach(cache => cache.destroy());
    WeakRefCacheFactory.caches.clear();
  }
}
