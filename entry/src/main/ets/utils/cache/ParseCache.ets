/**
 * ParseCache - 解析结果缓存管理器
 * 缓存 CSS 选择器解析结果，避免重复解析
 */

import { Logger } from "../performance/Logger";

const TAG = 'ParseCache';

/**
 * 缓存项
 */
interface CacheItem<T> {
  value: T;
  timestamp: number;
  accessCount: number;
}

/**
 * 缓存配置
 */
interface CacheConfig {
  maxSize: number;
  ttl: number;
}

/**
 * 缓存统计结果
 */
export interface CacheStats {
  size: number;
  hitRate: number;
  hitCount: number;
  missCount: number;
}

/**
 * 解析结果缓存管理器
 */
export class ParseCache {
  private static instance: ParseCache | null = null;
  private cache: Map<string, CacheItem<string[]>> = new Map();
  private config: CacheConfig = {
    maxSize: 500,
    ttl: 10 * 60 * 1000
  };
  private hitCount: number = 0;
  private missCount: number = 0;

  static getInstance(): ParseCache {
    if (!ParseCache.instance) {
      ParseCache.instance = new ParseCache();
    }
    return ParseCache.instance;
  }

  /**
   * 生成缓存键
   */
  private generateKey(html: string, selector: string): string {
    const htmlHash = this.simpleHash(html);
    return `${selector}:${htmlHash}`;
  }

  /**
   * 简单的字符串哈希
   */
  private simpleHash(str: string): string {
    let hash = 0;
    const len = str.length;
    for (let i = 0; i < len; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.toString(16);
  }

  /**
   * 获取缓存的解析结果
   */
  get(html: string, selector: string): string[] | null {
    const key = this.generateKey(html, selector);
    const item = this.cache.get(key);

    if (!item) {
      this.missCount++;
      return null;
    }

    // 检查是否过期
    const now = Date.now();
    if (now - item.timestamp > this.config.ttl) {
      this.cache.delete(key);
      this.missCount++;
      return null;
    }

    // 更新访问计数
    item.accessCount++;
    this.hitCount++;

    Logger.debug(TAG, `缓存命中: ${selector}, 访问次数: ${item.accessCount}`);
    return item.value;
  }

  /**
   * 设置缓存
   */
  set(html: string, selector: string, value: string[]): void {
    // 清理过期项
    this.cleanup();

    // 如果缓存已满，移除最少访问的项
    if (this.cache.size >= this.config.maxSize) {
      this.evictLRU();
    }

    const key = this.generateKey(html, selector);
    this.cache.set(key, {
      value,
      timestamp: Date.now(),
      accessCount: 1
    });

    Logger.debug(TAG, `缓存设置: ${selector}, 当前大小: ${this.cache.size}`);
  }

  /**
   * 清理过期缓存项
   */
  private cleanup(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];

    this.cache.forEach((item, key) => {
      if (now - item.timestamp > this.config.ttl) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.cache.delete(key);
    }

    if (keysToDelete.length > 0) {
      Logger.debug(TAG, `清理过期缓存: ${keysToDelete.length} 项`);
    }
  }

  /**
   * 移除最少访问的项 (LRU)
   */
  private evictLRU(): void {
    let minAccess = Infinity;
    let keyToDelete: string | null = null;

    this.cache.forEach((item, key) => {
      if (item.accessCount < minAccess) {
        minAccess = item.accessCount;
        keyToDelete = key;
      }
    });

    if (keyToDelete) {
      this.cache.delete(keyToDelete);
      Logger.debug(TAG, `LRU淘汰: ${keyToDelete}`);
    }
  }

  /**
   * 清空缓存
   */
  clear(): void {
    this.cache.clear();
    this.hitCount = 0;
    this.missCount = 0;
    Logger.info(TAG, '缓存已清空');
  }

  /**
   * 获取缓存统计
   */
  getStats(): CacheStats {
    const total = this.hitCount + this.missCount;
    const hitRate = total > 0 ? this.hitCount / total : 0;
    const stats: CacheStats = {
      size: this.cache.size,
      hitRate: hitRate,
      hitCount: this.hitCount,
      missCount: this.missCount
    };
    return stats;
  }

  /**
   * 设置缓存配置
   */
  setConfig(config: Partial<CacheConfig>): void {
    if (config.maxSize !== undefined) {
      this.config.maxSize = config.maxSize;
    }
    if (config.ttl !== undefined) {
      this.config.ttl = config.ttl;
    }
    Logger.info(TAG, `缓存配置更新: maxSize=${this.config.maxSize}, ttl=${this.config.ttl}`);
  }
}

// 导出单例实例
export const parseCache = ParseCache.getInstance();
