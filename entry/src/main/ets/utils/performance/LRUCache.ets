import { Logger } from './Logger';

/**
 * 缓存条目
 */
interface CacheEntry<V> {
  value: V;
  timestamp: number;
  ttl: number;
  accessCount: number;
}

/**
 * 缓存统计信息
 */
export interface CacheStats {
  hits: number;
  misses: number;
  hitRate: number;
  size: number;
  capacity: number;
}

/**
 * LRU缓存类
 * 支持泛型键值对，自动淘汰最久未使用的条目
 */
export class LRUCache<K, V> {
  private cache: Map<K, CacheEntry<V>>;
  private capacity: number;
  private defaultTTL: number;
  private hits: number = 0;
  private misses: number = 0;

  constructor(capacity: number, defaultTTL: number = 30 * 60 * 1000) {
    this.cache = new Map();
    this.capacity = capacity;
    this.defaultTTL = defaultTTL;
  }

  /**
   * 获取缓存值
   * @param key 缓存键
   * @returns 缓存值，不存在或已过期返回null
   */
  get(key: K): V | null {
    const entry = this.cache.get(key);
    if (!entry) {
      this.misses++;
      return null;
    }

    // 检查是否过期
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      this.misses++;
      return null;
    }

    // 更新访问时间和次数
    entry.timestamp = Date.now();
    entry.accessCount++;
    this.hits++;

    return entry.value;
  }

  /**
   * 设置缓存值
   * @param key 缓存键
   * @param value 缓存值
   * @param ttl 过期时间（毫秒），默认使用构造函数传入的defaultTTL
   */
  set(key: K, value: V, ttl?: number): void {
    // 如果缓存已满，淘汰最久未使用的条目
    if (this.cache.size >= this.capacity) {
      this.evict();
    }

    this.cache.set(key, {
      value: value,
      timestamp: Date.now(),
      ttl: ttl ?? this.defaultTTL,
      accessCount: 1
    });
  }

  /**
   * 删除缓存条目
   * @param key 缓存键
   * @returns 是否删除成功
   */
  delete(key: K): boolean {
    return this.cache.delete(key);
  }

  /**
   * 清空所有缓存
   */
  clear(): void {
    this.cache.clear();
    this.hits = 0;
    this.misses = 0;
  }

  /**
   * 获取缓存大小
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * 获取缓存统计信息
   */
  getStats(): CacheStats {
    const total = this.hits + this.misses;
    return {
      hits: this.hits,
      misses: this.misses,
      hitRate: total > 0 ? this.hits / total : 0,
      size: this.cache.size,
      capacity: this.capacity
    };
  }

  /**
   * 淘汰最久未使用的条目
   */
  private evict(): void {
    let lruKey: K | null = null;
    let lowestScore = Infinity;
    const now = Date.now();

    this.cache.forEach((entry, key) => {
      const ageScore = (now - entry.timestamp) / entry.ttl;
      const accessScore = 1 / (entry.accessCount + 1);
      const score = ageScore * 0.3 + accessScore * 0.7;

      if (score < lowestScore) {
        lowestScore = score;
        lruKey = key;
      }
    });

    if (lruKey !== null) {
      this.cache.delete(lruKey);
      Logger.debug('LRUCache', `淘汰缓存条目: ${String(lruKey)}`);
    }
  }
  /**
   * 获取所有缓存键
   */
  keys(): K[] {
    return Array.from(this.cache.keys());
  }

  /**
   * 清理过期缓存
   */
  cleanExpired(): void {
    const now = Date.now();
    let cleaned = 0;

    this.cache.forEach((entry, key) => {
      if (now - entry.timestamp > entry.ttl) {
        this.cache.delete(key);
        cleaned++;
      }
    });

    if (cleaned > 0) {
      Logger.debug('LRUCache', `清理过期缓存: ${cleaned}条`);
    }
  }
}
