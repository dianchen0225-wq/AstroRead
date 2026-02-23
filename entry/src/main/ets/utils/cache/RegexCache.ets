/**
 * RegexCache - 正则表达式缓存
 * 避免重复创建 RegExp 对象，提升性能
 */

import { Logger } from "../performance/Logger";

interface CacheEntry {
  regex: RegExp;
  lastAccess: number;
  hitCount: number;
}

interface PatternEntry {
  pattern: string;
  flags?: string;
}

export interface RegexCacheStats {
  size: number;
  maxSize: number;
  hits: number;
  misses: number;
  hitRate: number;
}

/**
 * 正则表达式缓存管理器
 */
export class RegexCache {
  private static instance: RegexCache | null = null;
  private cache: Map<string, CacheEntry> = new Map();
  private maxSize: number;
  private hits: number = 0;
  private misses: number = 0;
  private readonly TAG = 'RegexCache';

  private constructor(maxSize: number = 50) {
    this.maxSize = maxSize;
  }

  static getInstance(): RegexCache {
    if (!RegexCache.instance) {
      RegexCache.instance = new RegexCache();
    }
    return RegexCache.instance;
  }

  /**
   * 获取或创建正则表达式
   */
  get(pattern: string, flags?: string): RegExp | null {
    const key = this.createKey(pattern, flags);

    const entry = this.cache.get(key);
    if (entry) {
      entry.lastAccess = Date.now();
      entry.hitCount++;
      this.hits++;
      return entry.regex;
    }

    this.misses++;

    // 创建新的正则表达式
    try {
      const regex = new RegExp(pattern, flags);
      this.set(key, regex);
      return regex;
    } catch (e) {
      Logger.warn(this.TAG, `Invalid regex pattern: ${pattern}`);
      return null;
    }
  }

  /**
   * 缓存正则表达式
   */
  private set(key: string, regex: RegExp): void {
    // 如果缓存已满，移除最少使用的条目
    if (this.cache.size >= this.maxSize) {
      this.evictLRU();
    }

    this.cache.set(key, {
      regex,
      lastAccess: Date.now(),
      hitCount: 0
    });
  }

  /**
   * 移除最少使用的条目
   */
  private evictLRU(): void {
    let oldestKey: string | null = null;
    let oldestAccess = Infinity;
    let lowestHitCount = Infinity;

    this.cache.forEach((entry, key) => {
      // 优先移除访问次数少且最久未访问的
      if (entry.hitCount < lowestHitCount ||
          (entry.hitCount === lowestHitCount && entry.lastAccess < oldestAccess)) {
        oldestKey = key;
        oldestAccess = entry.lastAccess;
        lowestHitCount = entry.hitCount;
      }
    });

    if (oldestKey) {
      this.cache.delete(oldestKey);
      Logger.debug(this.TAG, `Evicted cache entry: ${oldestKey}`);
    }
  }

  /**
   * 创建缓存键
   */
  private createKey(pattern: string, flags?: string): string {
    return flags ? `${pattern}___${flags}` : pattern;
  }

  /**
   * 检查是否已缓存
   */
  has(pattern: string, flags?: string): boolean {
    const key = this.createKey(pattern, flags);
    return this.cache.has(key);
  }

  /**
   * 清除缓存
   */
  clear(): void {
    this.cache.clear();
    this.hits = 0;
    this.misses = 0;
    Logger.info(this.TAG, 'Cache cleared');
  }

  /**
   * 获取缓存统计信息
   */
  getStats(): RegexCacheStats {
    const total = this.hits + this.misses;
    return {
      size: this.cache.size,
      maxSize: this.maxSize,
      hits: this.hits,
      misses: this.misses,
      hitRate: total > 0 ? this.hits / total : 0
    };
  }

  /**
   * 设置最大缓存大小
   */
  setMaxSize(size: number): void {
    this.maxSize = Math.max(1, size);
    // 如果当前缓存超过新的大小，移除多余的条目
    while (this.cache.size > this.maxSize) {
      this.evictLRU();
    }
  }

  /**
   * 预编译常用的正则表达式
   */
  precompileCommonPatterns(): void {
    const commonPatterns: PatternEntry[] = [
      // URL 相关
      { pattern: '^(https?:)?//', flags: 'i' },
      { pattern: '^(https?://[^/]+)', flags: 'i' },
      { pattern: '^/[a-zA-Z0-9_/-]+', flags: '' },

      // HTML 相关
      { pattern: '<[^>]*>', flags: 'g' },
      { pattern: '<meta[^>]+charset=["\']?([^"\'>\\s]+)["\']?', flags: 'i' },
      { pattern: 'charset=["\']?([^"\';\\s]+)["\']?', flags: 'i' },

      // 文本处理
      { pattern: '\\s+', flags: 'g' },
      { pattern: '[\\r\\n\\t]+', flags: 'g' },
      { pattern: '&[a-zA-Z]+;', flags: 'g' },
      { pattern: '&#(\\d+);', flags: 'g' },
      { pattern: '&#x([0-9a-fA-F]+);', flags: 'g' },

      // 书源规则相关
      { pattern: '\\{\\{key\\}\\}', flags: 'g' },
      { pattern: '\\{\\{page\\}\\}', flags: 'g' },
      { pattern: '\\$key\\$', flags: 'g' },
      { pattern: '\\$page\\$', flags: 'g' },

      // CSS 选择器相关
      { pattern: '^([.#]?[a-zA-Z_][\\w-]*)', flags: '' },
      { pattern: '\\[([^\\]]+)\\]', flags: 'g' },
      { pattern: ':([a-z-]+)', flags: 'g' },

      // 安全相关
      { pattern: '[.*+?^${}()|[\\]\\\\]', flags: 'g' }
    ];

    let compiled = 0;
    for (let i = 0; i < commonPatterns.length; i++) {
      const entry: PatternEntry = commonPatterns[i];
      const pattern = entry.pattern;
      const flags = entry.flags;
      if (!this.has(pattern, flags)) {
        const regex = this.get(pattern, flags);
        if (regex) {
          compiled++;
        }
      }
    }

    Logger.info(this.TAG, `Precompiled ${compiled} common regex patterns`);
  }
}

/**
 * 便捷方法：使用缓存执行正则匹配
 */
export function cachedMatch(input: string, pattern: string, flags?: string): RegExpMatchArray | null {
  const regex = RegexCache.getInstance().get(pattern, flags);
  if (!regex) return null;
  return input.match(regex);
}

/**
 * 便捷方法：使用缓存执行正则测试
 */
export function cachedTest(input: string, pattern: string, flags?: string): boolean {
  const regex = RegexCache.getInstance().get(pattern, flags);
  if (!regex) return false;
  return regex.test(input);
}

/**
 * 便捷方法：使用缓存执行正则替换
 */
export function cachedReplace(input: string, pattern: string, replacement: string, flags?: string): string {
  const regex = RegexCache.getInstance().get(pattern, flags || 'g');
  if (!regex) return input;
  return input.replace(regex, replacement);
}

/**
 * 便捷方法：使用缓存执行正则分割
 */
export function cachedSplit(input: string, pattern: string, flags?: string, limit?: number): string[] {
  const regex = RegexCache.getInstance().get(pattern, flags);
  if (!regex) return [input];
  return input.split(regex, limit);
}

// 导出单例
export const regexCache = RegexCache.getInstance();
export default RegexCache;
