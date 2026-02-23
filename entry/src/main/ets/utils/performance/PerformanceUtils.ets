/**
 * 性能优化工具类
 * 提供防抖、节流、图片懒加载、内存管理等功能
 * 参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-high-performance-programming
 */

import { themeManager } from "../../common/ThemeManager';
import { Logger } from "./Logger";

export type SimpleCallback = (
  ...args: Array<string | number | boolean | object | null | undefined>
) => void | Promise<void>;

export function debounce(func: SimpleCallback, wait: number): SimpleCallback {
  let timeout: number = -1;

  return (...args: Array<string | number | boolean | object | null | undefined>): void => {
    if (timeout !== -1) {
      clearTimeout(timeout);
    }

    timeout = setTimeout(() => {
      void func(...args);
    }, wait) as number;
  };
}

export function throttle(func: SimpleCallback, limit: number): SimpleCallback {
  let inThrottle: boolean = false;

  return (...args: Array<string | number | boolean | object | null | undefined>): void => {
    if (!inThrottle) {
      void func(...args);
      inThrottle = true;

      setTimeout(() => {
        inThrottle = false;
      }, limit);
    }
  };
}

export interface ImageLoadConfig {
  imageUrl: string;
  placeholderUrl: string;
  maxRetries?: number;
  retryDelay?: number;
}

export interface AnimationConfig {
  duration: number;
  curve: string;
  onFinish?: () => void;
}

export interface RenderStrategy {
  virtualScrollThreshold: number;
  imageCacheSize: number;
  animationFrameRate: number;
}

type PropsObject = Record<string, string | number | boolean | object | null | undefined>;

export interface ComponentUpdateParams {
  prevProps: PropsObject;
  nextProps: PropsObject;
  keysToCheck: string[];
}

export interface CacheStats {
  loaded: number;
  cached: number;
  loading: number;
}

export class ImageLazyLoader {
  private static instance: ImageLazyLoader | null = null;
  private loadedImages: Set<string> = new Set();
  private imageCache: Map<string, string> = new Map();
  private loadingImages: Map<string, Promise<string>> = new Map();
  private readonly maxCacheSize: number = 100;

  static getInstance(): ImageLazyLoader {
    if (ImageLazyLoader.instance === null) {
      ImageLazyLoader.instance = new ImageLazyLoader();
    }
    return ImageLazyLoader.instance;
  }

  isImageLoaded(url: string): boolean {
    return this.loadedImages.has(url);
  }

  markImageLoaded(url: string): void {
    this.loadedImages.add(url);
  }

  getCachedImage(url: string): string {
    return this.imageCache.get(url) || '';
  }

  cacheImage(url: string, data: string): void {
    if (this.imageCache.size >= this.maxCacheSize) {
        const firstKey = this.imageCache.keys().next().value as string;
      if (firstKey) {
        this.imageCache.delete(firstKey);
      }
    }
    this.imageCache.set(url, data);
    this.loadedImages.add(url);
  }

  static getPlaceholderImage(isDarkMode: boolean): string {
    return isDarkMode
      ? 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iIzJhMmEyYSIvPjwvc3ZnPg=='
      : 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iI2YwZWFkNiIvPjwvc3ZnPg==';
  }

  static async loadImageWithFallback(config: ImageLoadConfig): Promise<string> {
    const maxRetries: number = config.maxRetries || 3;
    const retryDelay: number = config.retryDelay || 500;

    for (let i: number = 0; i < maxRetries; i++) {
      try {
        Logger.debug('ImageLoader', `尝试加载图片: ${config.imageUrl} (${i + 1}/${maxRetries})`);
        return config.imageUrl;
      } catch (error) {
        Logger.warn('ImageLoader', `图片加载失败 (尝试 ${i + 1}/${maxRetries}): ${error instanceof Error ? error.message : String(error)}`);
      }

      await new Promise<void>((resolve: Function) => setTimeout(resolve, retryDelay));
    }

    return config.placeholderUrl;
  }

  async loadImageWithCache(url: string): Promise<string> {
    const cached = this.getCachedImage(url);
    if (cached) {
      return cached;
    }

    const loading = this.loadingImages.get(url);
    if (loading) {
      return loading;
    }

    const loadPromise = this.doLoadImage(url);
    this.loadingImages.set(url, loadPromise);

    try {
      const result = await loadPromise;
      this.cacheImage(url, result);
      return result;
    } finally {
      this.loadingImages.delete(url);
    }
  }

  private async doLoadImage(url: string): Promise<string> {
    return url;
  }

  clearCache(): void {
    this.loadedImages.clear();
    this.imageCache.clear();
    this.loadingImages.clear();
  }

  getCacheStats(): CacheStats {
    return {
      loaded: this.loadedImages.size,
      cached: this.imageCache.size,
      loading: this.loadingImages.size
    };
  }
}

export class MemoryManager {
  static cleanupReferences<T>(objects: T[]): void {
    objects.length = 0;
  }

  static async processBatch<T, R>(
    items: T[],
    batchSize: number,
    processor: (batch: T[]) => Promise<R[]>
  ): Promise<R[]> {
    const results: R[] = [];

    for (let i = 0; i < items.length; i += batchSize) {
      const batch: T[] = items.slice(i, i + batchSize);
      const batchResults: R[] = await processor(batch);
      
      for (const result of batchResults) {
        results.push(result);
      }

      await new Promise<void>((resolve: Function) => {
        setTimeout(() => {
          resolve();
        }, 0);
      });
    }

    return results;
  }

  static monitorMemoryUsage(): void {
    Logger.debug('MemoryManager', '内存监控功能需要系统权限支持');
  }
}

export class TaskQueue {
  private queue: Array<() => Promise<void>> = [];
  private running: boolean = false;
  private concurrency: number;

  constructor(concurrency: number = 3) {
    this.concurrency = concurrency;
  }

  async add<T>(task: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve: Function, reject: Function) => {
      this.queue.push(async () => {
        try {
          const result: T = await task();
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });

      if (!this.running) {
        void this.process();
      }
    });
  }

  private async process(): Promise<void> {
    if (this.running) {
      return;
    }

    this.running = true;

    while (this.queue.length > 0) {
      const batch = this.queue.splice(0, this.concurrency);
      await Promise.all(batch.map((task: () => Promise<void>) => task()));
    }

    this.running = false;
  }

  clear(): void {
    this.queue = [];
  }
}

export class ThemeAwareAnimator {
  static getThemeAwareDuration(baseDuration: number): number {
    const isDarkMode: boolean = themeManager.isDarkTheme();
    return isDarkMode ? baseDuration * 1.2 : baseDuration;
  }

  static createThemeTransitionAnimation(): AnimationConfig {
    return {
      duration: 300,
      curve: 'ease-in-out',
      onFinish: (): void => {
        Logger.debug('ThemeAwareAnimator', '主题切换动画完成');
      }
    };
  }
}

export class ResponsivePerformance {
  static getOptimalRenderStrategy(): RenderStrategy {
    return {
      virtualScrollThreshold: 50,
      imageCacheSize: 20,
      animationFrameRate: 60
    };
  }
}

export class ComponentRenderOptimizer {
  static shouldComponentUpdate(params: ComponentUpdateParams): boolean {
    for (let i: number = 0; i < params.keysToCheck.length; i++) {
      const key: string = params.keysToCheck[i];
      if (params.prevProps[key] !== params.nextProps[key]) {
        return true;
      }
    }
    return false;
  }

  static batchStateUpdates(updates: Array<() => void>): void {
    for (let i: number = 0; i < updates.length; i++) {
      updates[i]();
    }
  }

  static createDebouncedStateUpdater(delay: number = 300): (updateFn: () => void) => void {
    let timeoutId: number | null = null;

    return (updateFn: () => void): void => {
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
      }

      timeoutId = setTimeout((): void => {
        updateFn();
        timeoutId = null;
      }, delay) as number;
    };
  }
}
