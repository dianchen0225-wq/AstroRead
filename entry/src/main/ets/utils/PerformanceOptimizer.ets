/**
 * 性能优化工具类
 * 参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-high-performance-programming
 */

/**
 * 通用回调类型（显式枚举常见参数类型，避免 any/unknown）
 */
export type SimpleCallback = (
  ...args: Array<string | number | boolean | object | null | undefined>
) => void | Promise<void>;

/**
 * 防抖函数 - 用于搜索等频繁触发的操作
 */
export function debounce(func: SimpleCallback, wait: number): SimpleCallback {
  let timeout: number = -1;

  return (...args: Array<string | number | boolean | object | null | undefined>): void => {
    if (timeout !== -1) {
      clearTimeout(timeout);
    }

    timeout = setTimeout(() => {
      // 忽略返回值，只关心副作用
      void func(...args);
    }, wait) as number;
  };
}

/**
 * 节流函数 - 用于滚动等连续触发的事件
 */
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

/**
 * 图片懒加载管理器
 */
export class ImageLazyLoader {
  private static instance: ImageLazyLoader | null = null;
  private loadedImages: Set<string> = new Set();
  private imageCache: Map<string, string> = new Map();

  static getInstance(): ImageLazyLoader {
    if (ImageLazyLoader.instance === null) {
      ImageLazyLoader.instance = new ImageLazyLoader();
    }
    return ImageLazyLoader.instance;
  }

  /**
   * 检查图片是否已加载
   */
  isImageLoaded(url: string): boolean {
    return this.loadedImages.has(url);
  }

  /**
   * 标记图片已加载
   */
  markImageLoaded(url: string): void {
    this.loadedImages.add(url);
  }

  /**
   * 清理缓存
   */
  clearCache(): void {
    this.loadedImages.clear();
    this.imageCache.clear();
  }
}

/**
 * 内存管理工具
 */
export class MemoryManager {
  /**
   * 清理不必要的对象引用
   */
  static cleanupReferences<T>(objects: T[]): void {
    objects.length = 0;
  }

  /**
   * 批量处理数据，避免一次性加载过多数据到内存
   */
  static async processBatch<T, R>(
    items: T[],
    batchSize: number,
    processor: (batch: T[]) => Promise<R[]>
  ): Promise<R[]> {
    const results: R[] = [];

    for (let i = 0; i < items.length; i += batchSize) {
      const batch: T[] = items.slice(i, i + batchSize);
      const batchResults: R[] = await processor(batch);
      results.push(...batchResults);

      // 给 UI 线程一些时间
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, 0);
      });
    }

    return results;
  }
}

/**
 * 异步任务队列管理器 - 避免并发过多导致性能问题
 */
export class TaskQueue {
  private queue: Array<() => Promise<void>> = [];
  private running: boolean = false;
  private concurrency: number;

  constructor(concurrency: number = 3) {
    this.concurrency = concurrency;
  }

  /**
   * 添加任务到队列
   */
  async add<T>(task: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
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

  /**
   * 处理队列中的任务
   */
  private async process(): Promise<void> {
    if (this.running) {
      return;
    }

    this.running = true;

    while (this.queue.length > 0) {
      const batch = this.queue.splice(0, this.concurrency);
      await Promise.all(batch.map(task => task()));
    }

    this.running = false;
  }

  /**
   * 清空队列
   */
  clear(): void {
    this.queue = [];
  }
}
