/**
 * ParseCache - 解析结果缓存管理器
 * 继承自 BaseCache，缓存 CSS 选择器解析结果
 */

import { BaseCache, CacheConfig, CacheStats } from '../core/BaseCache';
import { Logger } from './Logger';

/**
 * 解析结果缓存管理器
 */
export class ParseCache extends BaseCache<string[]> {
  private static instance: ParseCache | null = null;
  protected readonly TAG = 'ParseCache';

  private constructor(config?: Partial<CacheConfig>) {
    super({ maxSize: 200, ttl: 5 * 60 * 1000, enableStats: config?.enableStats ?? true });
  }

  static getInstance(): ParseCache {
    if (!ParseCache.instance) {
      ParseCache.instance = new ParseCache();
    }
    return ParseCache.instance;
  }

  /**
   * 生成缓存键
   */
  protected generateKey(html: string, selector: string): string {
    const htmlHash = this.hashString(html);
    return `${selector}:${htmlHash}`;
  }

  /**
   * 获取缓存的解析结果
   */
  getBySelector(html: string, selector: string): string[] | null {
    const key = this.generateKey(html, selector);
    return this.get(key);
  }

  /**
   * 设置缓存
   */
  setBySelector(html: string, selector: string, value: string[]): void {
    const key = this.generateKey(html, selector);
    this.set(key, value);
    Logger.debug(this.TAG, `缓存设置: ${selector}, 当前大小: ${this.size}`);
  }

  /**
   * 估算值大小
   */
  protected estimateValueSize(value: string[]): number {
    return value.reduce((sum, item) => sum + item.length * 2, 0);
  }

  /**
   * 获取缓存统计（兼容旧接口）
   */
  getStats(): CacheStats {
    return super.getStats();
  }

  /**
   * 设置缓存配置（兼容旧接口）
   */
  setConfig(config: Partial<CacheConfig>): void {
    super.setConfig(config);
    Logger.info(this.TAG, `缓存配置更新: maxSize=${this.getConfig().maxSize}, ttl=${this.getConfig().ttl}`);
  }
}

export const parseCache = ParseCache.getInstance();
