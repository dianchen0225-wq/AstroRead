/**
 * SearchCache - 搜索结果缓存
 * 用于缓存搜索结果，减少重复搜索开销
 */

import { Book } from '../models/Book';
import { Logger } from './Logger';
import { CacheConstants, TimeConstants } from '../constants';

interface CacheEntry {
  books: Book[];
  timestamp: number;
  sourceIds: string[]; // 参与搜索的书源ID
}

export class SearchCache {
  private static instance: SearchCache | null = null;
  private cache: Map<string, CacheEntry> = new Map();
  private readonly TAG = 'SearchCache';

  // 缓存配置
  private maxSize: number = CacheConstants.SEARCH_CACHE_SIZE;
  private ttl: number = TimeConstants.FIVE_MINUTES;
  private cleanupInterval: number = CacheConstants.SEARCH_CLEANUP_INTERVAL;
  private cleanupTimer: number | null = null;

  private constructor() {
    this.startCleanupTimer();
  }

  static getInstance(): SearchCache {
    if (!SearchCache.instance) {
      SearchCache.instance = new SearchCache();
    }
    return SearchCache.instance;
  }

  /**
   * 生成缓存键
   * @param keyword 搜索关键词
   * @param sourceIds 参与搜索的书源ID列表
   * @returns 缓存键
   */
  private generateCacheKey(keyword: string, sourceIds: string[]): string {
    // 规范化关键词
    const normalizedKeyword = keyword.trim().toLowerCase();
    
    // 排序书源ID以确保一致性
    const sortedSourceIds = [...sourceIds].sort();
    
    // 生成哈希键
    const keyData = `${normalizedKeyword}_${sortedSourceIds.join(',')}`;
    
    // 简单哈希函数
    let hash = 0;
    for (let i = 0; i < keyData.length; i++) {
      const char = keyData.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    
    return `search_${Math.abs(hash).toString(16)}`;
  }

  /**
   * 设置缓存
   * @param keyword 搜索关键词
   * @param sourceIds 参与搜索的书源ID列表
   * @param books 搜索结果
   */
  set(keyword: string, sourceIds: string[], books: Book[]): void {
    try {
      this.cleanup();
      
      if (this.cache.size >= this.maxSize) {
        this.evictOldest();
      }
      
      const cacheKey = this.generateCacheKey(keyword, sourceIds);
      const entry: CacheEntry = {
        books: books,
        timestamp: Date.now(),
        sourceIds: [...sourceIds]
      };
      
      this.cache.set(cacheKey, entry);
      Logger.debug(this.TAG, `缓存设置成功: ${cacheKey}, 书籍数量: ${books.length}`);
    } catch (error) {
      Logger.error(this.TAG, `设置缓存失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取缓存
   * @param keyword 搜索关键词
   * @param sourceIds 参与搜索的书源ID列表
   * @returns 缓存结果或null
   */
  get(keyword: string, sourceIds: string[]): Book[] | null {
    try {
      const cacheKey = this.generateCacheKey(keyword, sourceIds);
      const entry = this.cache.get(cacheKey);
      
      if (!entry) {
        Logger.debug(this.TAG, `缓存未命中: ${cacheKey}`);
        return null;
      }
      
      // 检查是否过期
      if (Date.now() - entry.timestamp > this.ttl) {
        this.cache.delete(cacheKey);
        Logger.debug(this.TAG, `缓存已过期: ${cacheKey}`);
        return null;
      }
      
      // 检查书源是否匹配（允许子集匹配）
      const cachedSourceSet = new Set(entry.sourceIds);
      const requestedSourceSet = new Set(sourceIds);
      
      // 如果请求的书源是缓存书源的子集，可以使用缓存
      let isSubset = true;
      for (const sourceId of requestedSourceSet) {
        if (!cachedSourceSet.has(sourceId)) {
          isSubset = false;
          break;
        }
      }
      
      if (!isSubset) {
        Logger.debug(this.TAG, `书源不匹配: ${cacheKey}`);
        return null;
      }
      
      Logger.debug(this.TAG, `缓存命中: ${cacheKey}, 书籍数量: ${entry.books.length}`);
      return [...entry.books]; // 返回副本
    } catch (error) {
      Logger.error(this.TAG, `获取缓存失败: ${error instanceof Error ? error.message : String(error)}`);
      return null;
    }
  }

  /**
   * 清理过期缓存
   */
  private cleanup(): void {
    const now = Date.now();
    let removedCount = 0;
    
    for (const entry of this.cache.entries()) {
      const key: string = entry[0];
      const cacheEntry: CacheEntry = entry[1];
      if (now - cacheEntry.timestamp > this.ttl) {
        this.cache.delete(key);
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      Logger.debug(this.TAG, `清理了 ${removedCount} 个过期缓存条目`);
    }
  }

  /**
   * 淘汰最旧的缓存条目
   */
  private evictOldest(): void {
    if (this.cache.size === 0) return;
    
    let oldestKey: string | null = null;
    let oldestTime = Date.now();
    
    for (const entry of this.cache.entries()) {
      const key: string = entry[0];
      const cacheEntry: CacheEntry = entry[1];
      if (cacheEntry.timestamp < oldestTime) {
        oldestTime = cacheEntry.timestamp;
        oldestKey = key;
      }
    }
    
    if (oldestKey) {
      this.cache.delete(oldestKey);
      Logger.debug(this.TAG, `淘汰最旧缓存: ${oldestKey}`);
    }
  }

  /**
   * 启动定时清理任务
   */
  private startCleanupTimer(): void {
    this.cleanupTimer = Number(setInterval(() => {
      this.cleanup();
    }, this.cleanupInterval));
  }

  /**
   * 停止定时清理任务
   */
  stopCleanupTimer(): void {
    if (this.cleanupTimer !== null) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
  }

  /**
   * 清除所有缓存
   */
  clearAll(): void {
    this.cache.clear();
    Logger.info(this.TAG, '所有缓存已清除');
  }

  /**
   * 获取缓存统计信息
   */
  getStats(): CacheStats {
    const now = Date.now();
    let expiredCount = 0;
    let totalBooks = 0;
    
    for (const entry of this.cache.values()) {
      if (now - entry.timestamp > this.ttl) {
        expiredCount++;
      }
      totalBooks += entry.books.length;
    }
    
    return {
      totalEntries: this.cache.size,
      expiredEntries: expiredCount,
      totalBooks: totalBooks,
      maxSize: this.maxSize,
      ttl: this.ttl
    };
  }

  /**
   * 设置缓存配置
   */
  setConfig(config: Partial<CacheConfig>): void {
    if (config.maxSize !== undefined) {
      this.maxSize = Math.max(10, Math.min(200, config.maxSize));
    }

    if (config.ttl !== undefined) {
      this.ttl = Math.max(TimeConstants.MINUTE, Math.min(TimeConstants.HOUR, config.ttl));
    }

    if (config.cleanupInterval !== undefined) {
      this.cleanupInterval = Math.max(30 * 1000, Math.min(TimeConstants.FIVE_MINUTES, config.cleanupInterval));

      // 重启定时器
      this.stopCleanupTimer();
      this.startCleanupTimer();
    }

    Logger.info(this.TAG,
      `缓存配置已更新: maxSize=${this.maxSize}, ttl=${this.ttl}ms, cleanupInterval=${this.cleanupInterval}ms`
    );
  }
}

export interface CacheStats {
  totalEntries: number;
  expiredEntries: number;
  totalBooks: number;
  maxSize: number;
  ttl: number;
}

export interface CacheConfig {
  maxSize: number;
  ttl: number;
  cleanupInterval: number;
}

export const searchCache = SearchCache.getInstance();