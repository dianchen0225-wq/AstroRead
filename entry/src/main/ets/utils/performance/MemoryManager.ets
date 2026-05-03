import { Logger } from './Logger';
import { LRUCache } from './LRUCache';
import { ChapterContent } from '../../models/Book';
import { ResourceMonitor, ResourceLevel } from './ResourceMonitor';
import { PageTurnAnimationOptimizer } from './PageTurnAnimationOptimizer';
import image from '@kit.ArkUI';

/**
 * 内存使用情况
 */
export interface MemoryUsage {
  used: number;
  total: number;
  percentage: number;
  available: number;
}

/**
 * 缓存统计信息
 */
export interface CacheStats {
  chapterCache: object;
  imageCache: object;
}

/**
 * 内存管理器
 * 管理应用内存使用，自动清理缓存
 */
export class MemoryManager {
  private static instance: MemoryManager;
  private chapterCache: LRUCache<string, ChapterContent>;
  private imageCache: LRUCache<string, object>;
  private monitoringTimer: number | null = null;
  private readonly MONITORING_INTERVAL: number = 30000;
  private resourceMonitor: ResourceMonitor = ResourceMonitor.getInstance();
  private animationOptimizer: PageTurnAnimationOptimizer = PageTurnAnimationOptimizer.getInstance();
  private constructor() {
    this.chapterCache = new LRUCache<string, ChapterContent>(5, 30 * 60 * 1000);
    this.imageCache = new LRUCache<string, object>(20, 10 * 60 * 1000);
  }

  public static getInstance(): MemoryManager {
    if (!MemoryManager.instance) {
      MemoryManager.instance = new MemoryManager();
    }
    return MemoryManager.instance;
  }

  /**
   * 启动内存监控
   */
  startMonitoring(): void {
    if (this.monitoringTimer !== null) {
      Logger.warn('MemoryManager', '内存监控已在运行');
      return;
    }

    Logger.info('MemoryManager', '启动内存监控');

    this.resourceMonitor.setOnResourceWarning((level: ResourceLevel, message: string) => {
      this.onMemoryPressure(level);
    });

    this.monitoringTimer = setInterval(() => {
      this.checkMemoryUsage();
      this.chapterCache.cleanExpired();
      this.imageCache.cleanExpired();
    }, this.MONITORING_INTERVAL);
  }

  /**
   * 停止内存监控
   */
  stopMonitoring(): void {
    if (this.monitoringTimer !== null) {
      clearInterval(this.monitoringTimer);
      this.monitoringTimer = null;
      Logger.info('MemoryManager', '停止内存监控');
    }
  }

  /**
   * 获取内存使用情况
   */
  getMemoryUsage(): MemoryUsage {
    // 这里使用模拟数据，实际应用中应使用系统API获取真实内存使用情况
    const used = this.estimateMemoryUsage();
    const total = 1024 * 1024 * 1024; // 1GB
    const available = total - used;
    const percentage = (used / total) * 100;

    return {
      used,
      total,
      percentage,
      available
    };
  }

  /**
   * 清理内存
   */
  cleanupMemory(): void {
    Logger.info('MemoryManager', '开始清理内存');

    // 清理50%的章节缓存
    const chapterCacheSize = this.chapterCache.size();
    if (chapterCacheSize > 0) {
      const toRemove = Math.ceil(chapterCacheSize * 0.5);
      for (let i = 0; i < toRemove; i++) {
        // LRU缓存会自动淘汰最久未使用的条目
        this.chapterCache.set(`dummy_${i}`, {
          chapterId: `dummy_${i}`,
          content: '',
          nextUrl: undefined,
          prevUrl: undefined
        });
        this.chapterCache.delete(`dummy_${i}`);
      }
      Logger.info('MemoryManager', `清理章节缓存: ${toRemove}条`);
    }
    // 清理50%的图片缓存
    const imageCacheSize = this.imageCache.size();
    if (imageCacheSize > 0) {
      const toRemove = Math.ceil(imageCacheSize * 0.5);
      for (let i = 0; i < toRemove; i++) {
        // 使用LRU缓存自身的淘汰机制，无需设置dummy值
        const keys = this.imageCache.keys();
        if (keys.length > 0) {
          this.imageCache.delete(keys[0]);
        }
      }
      Logger.info('MemoryManager', `清理图片缓存: ${toRemove}条`);
    }

    Logger.info('MemoryManager', '内存清理完成');
  }

  /**
   * 获取章节缓存
   */
  getChapterCache(): LRUCache<string, ChapterContent> {
    return this.chapterCache;
  }

  /**
   * 获取图片缓存
   */
  getImageCache(): LRUCache<string, object> {
    return this.imageCache;
  }
  /**
   * 获取缓存统计信息
   */
  getCacheStats(): CacheStats {
    const chapterCacheStats = this.chapterCache.getStats();
    const imageCacheStats = this.imageCache.getStats();

    return {
      chapterCache: chapterCacheStats,
      imageCache: imageCacheStats
    };
  }

  /**
   * 检查内存使用情况
   */
  private checkMemoryUsage(): void {
    const metrics = this.resourceMonitor.getCurrentMetrics();
    const memoryUsagePercent = metrics?.memory.usagePercent ?? this.getMemoryUsage().percentage;
    Logger.debug('MemoryManager', `内存使用: ${memoryUsagePercent.toFixed(2)}%`);

    if (memoryUsagePercent > 80) {
      Logger.warn('MemoryManager', `内存占用过高: ${memoryUsagePercent.toFixed(2)}%，开始清理`);
      this.cleanupMemory();
      const level = memoryUsagePercent > 90 ? ResourceLevel.CRITICAL : ResourceLevel.LOW;
      this.onMemoryPressure(level);
    }
  }

  onMemoryPressure(level: ResourceLevel): void {
    Logger.warn('MemoryManager', `内存压力通知: ${level}`);
    this.animationOptimizer.updateResourceLevel(level);
  }

  /**
   * 估算内存使用量（模拟）
   */
  private estimateMemoryUsage(): number {
    const chapterCacheStats = this.chapterCache.getStats();
    const imageCacheStats = this.imageCache.getStats();

    // 假设每章内容平均50KB
    const chapterMemory = chapterCacheStats.size * 50 * 1024;

    // 假设每张图片平均200KB
    const imageMemory = imageCacheStats.size * 200 * 1024;

    return chapterMemory + imageMemory;
  }

  /**
   * 清空所有缓存
   */
  clearAllCache(): void {
    this.chapterCache.clear();
    this.imageCache.clear();
    Logger.info('MemoryManager', '所有缓存已清空');
  }
}
