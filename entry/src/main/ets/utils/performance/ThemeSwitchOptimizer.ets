import { Logger } from './Logger';

/**
 * 主题更新项
 */
interface ThemeUpdate {
  componentId: string;
  property: string;
  value: string;
}

/**
 * 主题颜色缓存
 */
export class ThemeColorCache {
  private colorCache: Map<string, string> = new Map();

  /**
   * 预计算主题颜色
   * @param colorMap 颜色映射
   */
  precomputeColors(colorMap: Map<string, string>): void {
    this.colorCache = new Map(colorMap);
    Logger.debug('ThemeColorCache', `预计算主题颜色: ${this.colorCache.size}个`);
  }

  /**
   * 获取颜色
   * @param key 颜色键
   * @returns 颜色值
   */
  getColor(key: string): string | undefined {
    return this.colorCache.get(key);
  }

  /**
   * 批量获取颜色
   * @param keys 颜色键数组
   * @returns 颜色值映射
   */
  getColors(keys: string[]): Map<string, string> {
    const result = new Map<string, string>();
    for (const key of keys) {
      const value = this.colorCache.get(key);
      if (value !== undefined) {
        result.set(key, value);
      }
    }
    return result;
  }

  /**
   * 清空颜色缓存
   */
  clear(): void {
    this.colorCache.clear();
  }

  /**
   * 获取缓存大小
   */
  size(): number {
    return this.colorCache.size;
  }
}

/**
 * 主题切换优化器
 * 优化主题切换性能，支持批量更新和防抖通知
 */
export class ThemeSwitchOptimizer {
  private static instance: ThemeSwitchOptimizer;
  private updateQueue: Array<ThemeUpdate> = [];
  private debounceTimer: number | null = null;
  private colorCache: ThemeColorCache = new ThemeColorCache();
  private listeners: Array<() => void> = [];

  private constructor() {
  }

  public static getInstance(): ThemeSwitchOptimizer {
    if (!ThemeSwitchOptimizer.instance) {
      ThemeSwitchOptimizer.instance = new ThemeSwitchOptimizer();
    }
    return ThemeSwitchOptimizer.instance;
  }

  /**
   * 批量更新主题属性
   * @param updates 主题更新数组
   */
  batchUpdateTheme(updates: ThemeUpdate[]): void {
    Logger.debug('ThemeSwitchOptimizer', `批量更新主题: ${updates.length}个属性`);
    this.updateQueue.push(...updates);
  }

  /**
   * 防抖通知监听器
   * @param delay 延迟时间（毫秒）
   */
  debouncedNotifyListeners(delay: number = 300): void {
    if (this.debounceTimer !== null) {
      clearTimeout(this.debounceTimer);
    }

    this.debounceTimer = setTimeout(() => {
      this.notifyListeners();
      this.debounceTimer = null;
    }, delay);
  }

  /**
   * 预计算主题颜色
   * @param colorMap 颜色映射
   */
  precomputeThemeColors(colorMap: Map<string, string>): void {
    this.colorCache.precomputeColors(colorMap);
  }

  /**
   * 获取主题颜色
   * @param key 颜色键
   * @returns 颜色值
   */
  getThemeColor(key: string): string | undefined {
    return this.colorCache.getColor(key);
  }

  /**
   * 批量获取主题颜色
   * @param keys 颜色键数组
   * @returns 颜色值映射
   */
  getThemeColors(keys: string[]): Map<string, string> {
    return this.colorCache.getColors(keys);
  }

  /**
   * 添加主题监听器
   * @param listener 监听器函数
   */
  addListener(listener: () => void): void {
    this.listeners.push(listener);
  }

  /**
   * 移除主题监听器
   * @param listener 监听器函数
   */
  removeListener(listener: () => void): void {
    const index = this.listeners.indexOf(listener);
    if (index !== -1) {
      this.listeners.splice(index, 1);
    }
  }

  /**
   * 通知所有监听器
   */
  private notifyListeners(): void {
    Logger.debug('ThemeSwitchOptimizer', `通知监听器: ${this.listeners.length}个`);
    for (const listener of this.listeners) {
      try {
        listener();
      } catch (error) {
        Logger.error('ThemeSwitchOptimizer', `监听器执行失败: ${error}`);
      }
    }
  }

  /**
   * 清空更新队列
   */
  clearUpdateQueue(): void {
    this.updateQueue = [];
  }

  /**
   * 清空颜色缓存
   */
  clearColorCache(): void {
    this.colorCache.clear();
  }
}
