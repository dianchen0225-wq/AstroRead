/**
 * Copyright (c) 2025 AstroRead Project
 * 数据缓存管理器
 * 实现智能缓存机制，避免重复数据加载
 */
// import { Logger } from './performance/Logger';

export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  version: number;
  isValid: boolean;
}
export interface CacheConfig {
  defaultTTL: number;
  maxEntries: number;
  enableVersionCheck: boolean;
}

export interface CacheStats {
  totalEntries: number;
  validEntries: number;
  expiredEntries: number;
}

const DEFAULT_CACHE_CONFIG: CacheConfig = {
  defaultTTL: 10 * 60 * 1000,
  maxEntries: 300,
  enableVersionCheck: true
};

type DataChangeListener<T> = (data: T, version: number) => void;

export class DataCacheManager {
  private static instance: DataCacheManager | null = null;

  private cache: Map<string, CacheEntry<object>> = new Map();
  private versions: Map<string, number> = new Map();
  private listeners: Map<string, Set<DataChangeListener<object>>> = new Map();
  private config: CacheConfig;
  
  private constructor(config: CacheConfig = DEFAULT_CACHE_CONFIG) {
    this.config = config;
  }
  
  static getInstance(): DataCacheManager {
    if (DataCacheManager.instance === null) {
      DataCacheManager.instance = new DataCacheManager();
    }
    return DataCacheManager.instance;
  }
  
  static destroyInstance(): void {
    if (DataCacheManager.instance !== null) {
      DataCacheManager.instance.clearAll();
      DataCacheManager.instance = null;
    }
  }
  
  /**
   * 获取缓存数据
   */
  get<T>(key: string): T | null {
    const entry = this.cache.get(key) as CacheEntry<T> | undefined;
    if (!entry) {
      // Logger.debug('DataCacheManager', `缓存未命中: ${key}`);
      return null;
    }
    
    if (!entry.isValid || this.isExpired(entry)) {
      // Logger.debug('DataCacheManager', `缓存已过期或无效: ${key}`);
      this.cache.delete(key);
      return null;
    }
    
    // Logger.debug('DataCacheManager', `缓存命中: ${key}, 版本: ${entry.version}`);
    return entry.data;
  }
  
  /**
   * 设置缓存数据
   */
  set<T>(key: string, data: T, ttl?: number): void {
    const currentVersion = this.versions.get(key) || 0;
    const entry: CacheEntry<T> = {
      data: data,
      timestamp: Date.now(),
      version: currentVersion,
      isValid: true
    };

    this.cache.set(key, entry as CacheEntry<object>);

    if (this.cache.size > this.config.maxEntries) {
      this.evictOldest();
    }
    // Logger.debug('DataCacheManager', `缓存已设置: ${key}, 版本: ${currentVersion}`);
  }
  
  /**
   * 检查缓存是否存在且有效
   */
  has(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) {
      return false;
    }
    return entry.isValid && !this.isExpired(entry);
  }
  
  /**
   * 使缓存失效
   */
  invalidate(key: string): void {
    const entry = this.cache.get(key);
    if (entry) {
      entry.isValid = false;
    // Logger.debug('DataCacheManager', `缓存已失效: ${key}`);
    }
  }
  
  /**
   * 更新数据版本（数据变更时调用）
   */
  updateVersion(key: string): number {
    const currentVersion = this.versions.get(key) || 0;
    const newVersion = currentVersion + 1;
    this.versions.set(key, newVersion);
    
    this.invalidate(key);
    
    this.notifyListeners(key, newVersion);
    // Logger.info('DataCacheManager', `数据版本更新: ${key}, 新版本: ${newVersion}`);
    return newVersion;
  }
  
  /**
   * 获取当前数据版本
   */
  getVersion(key: string): number {
    return this.versions.get(key) || 0;
  }
  
  /**
   * 检查缓存版本是否与当前版本匹配
   */
  isVersionValid(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) {
      return false;
    }
    const currentVersion = this.versions.get(key) || 0;
    return entry.version === currentVersion;
  }
  
  /**
   * 添加数据变更监听器
   */
  addListener<T>(key: string, listener: DataChangeListener<T>): void {
    if (!this.listeners.has(key)) {
      this.listeners.set(key, new Set());
    }
    this.listeners.get(key)!.add(listener as DataChangeListener<object>);
  }

  /**
   * 移除数据变更监听器
   */
  removeListener<T>(key: string, listener: DataChangeListener<T>): void {
    const listeners = this.listeners.get(key);
    if (listeners) {
      listeners.delete(listener as DataChangeListener<object>);
    }
  }
  
  /**
   * 通知所有监听器
   */
  private notifyListeners(key: string, version: number): void {
    const listeners = this.listeners.get(key);
    if (listeners) {
      const entry = this.cache.get(key);
      if (entry) {
        listeners.forEach(listener => {
          try {
            listener(entry.data, version);
          } catch (error) {
          // Logger.error('DataCacheManager', `监听器执行失败: ${error}`);
          }
        });
      }
    }
  }
  
  /**
   * 获取或加载数据（核心方法）
   * 如果缓存有效则返回缓存，否则执行加载函数
   */
  async getOrLoad<T>(key: string, loader: () => Promise<T>, forceRefresh: boolean = false): Promise<T> {
    if (!forceRefresh && this.has(key) && this.isVersionValid(key)) {
      const cached = this.get<T>(key);
      if (cached !== null) {
        // Logger.debug('DataCacheManager', `使用缓存数据: ${key}`);
        return cached;
      }
    }
    // Logger.info('DataCacheManager', `加载数据: ${key}`);
    const data = await loader();
    this.set(key, data);
    
    return data;
  }
  
  /**
   * 强制刷新缓存
   */
  async refresh<T>(key: string, loader: () => Promise<T>): Promise<T> {
    return this.getOrLoad(key, loader, true);
  }
  
  /**
   * 清除指定缓存
   */
  delete(key: string): void {
    this.cache.delete(key);
    // Logger.debug('DataCacheManager', `缓存已删除: ${key}`);
  }
  
  /**
   * 清除所有缓存
   */
  clearAll(): void {
    this.cache.clear();
    // Logger.info('DataCacheManager', '所有缓存已清除');
  }
  
  /**
   * 清除指定前缀的缓存
   */
  clearByPrefix(prefix: string): void {
    const keysToDelete: string[] = [];
    this.cache.forEach((_, key) => {
      if (key.startsWith(prefix)) {
        keysToDelete.push(key);
      }
    });
    keysToDelete.forEach(key => this.cache.delete(key));
    // Logger.info('DataCacheManager', `已清除 ${keysToDelete.length} 个前缀为 ${prefix} 的缓存`);
  }
  /**
   * 获取缓存统计信息
   */
  getStats(): CacheStats {
    let validEntries = 0;
    let expiredEntries = 0;
    
    this.cache.forEach(entry => {
      if (entry.isValid && !this.isExpired(entry)) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    });
    
    return {
      totalEntries: this.cache.size,
      validEntries: validEntries,
      expiredEntries: expiredEntries
    };
  }
  
  /**
   * 检查缓存条目是否过期
   */
  private isExpired<T>(entry: CacheEntry<T>): boolean {
    const age = Date.now() - entry.timestamp;
    return age > this.config.defaultTTL;
  }
  
  /**
   * 淘汰最旧的缓存条目
   */
  private evictOldest(): void {
    let oldestKey: string | null = null;
    let oldestTimestamp = Infinity;
    
    this.cache.forEach((entry, key) => {
      if (entry.timestamp < oldestTimestamp) {
        oldestTimestamp = entry.timestamp;
        oldestKey = key;
      }
    });
    if (oldestKey !== null) {
      this.cache.delete(oldestKey);
      // Logger.debug('DataCacheManager', `淘汰最旧缓存: ${oldestKey}`);
    }
  }
}
export interface CacheKeysType {
  ALL_BOOKS: string;
  BOOK_PREFIX: string;
  BOOK_SOURCES: string;
  CHAPTERS_PREFIX: string;
  CHAPTER_CONTENT_PREFIX: string;
  READ_CONFIG: string;
  CATEGORIES: string;
  BOOKMARKS_PREFIX: string;
  SEARCH_HISTORY: string;
}

export const dataCacheManager = DataCacheManager.getInstance();
export const CacheKeys: CacheKeysType = {
  ALL_BOOKS: 'cache:all_books',
  BOOK_PREFIX: 'cache:book:',
  BOOK_SOURCES: 'cache:book_sources',
  CHAPTERS_PREFIX: 'cache:chapters:',
  CHAPTER_CONTENT_PREFIX: 'cache:chapter_content:',
  READ_CONFIG: 'cache:read_config',
  CATEGORIES: 'cache:categories',
  BOOKMARKS_PREFIX: 'cache:bookmarks:',
  SEARCH_HISTORY: 'cache:search_history'
};
