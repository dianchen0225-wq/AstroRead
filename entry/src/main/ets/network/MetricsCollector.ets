/**
 * MetricsCollector - 指标收集器
 * 负责收集和管理请求指标
 */

import { RequestMetrics } from './interfaces/IHttpClient';
import { Logger } from '../utils/Logger';
import { DEFAULTS } from './HttpClientConfig';

/**
 * 成功统计接口
 */
export interface SuccessStats {
  total: number;
  success: number;
  failed: number;
  successRate: number;
}

/**
 * 指标收集器
 */
export class MetricsCollector {
  private metrics: RequestMetrics[] = [];
  private readonly maxMetrics: number;
  private readonly enableLogging: boolean;
  private readonly enableMetrics: boolean;
  private readonly tag: string;

  constructor(
    tag: string = 'HttpClient',
    enableLogging: boolean = true,
    enableMetrics: boolean = true,
    maxMetrics: number = DEFAULTS.MAX_METRICS
  ) {
    this.tag = tag;
    this.enableLogging = enableLogging;
    this.enableMetrics = enableMetrics;
    this.maxMetrics = maxMetrics;
  }

  /**
   * 记录指标
   */
  record(metrics: RequestMetrics): void {
    if (this.enableMetrics) {
      this.metrics.push(metrics);
      
      // 保持最大数量限制
      if (this.metrics.length > this.maxMetrics) {
        this.metrics.shift();
      }
    }

    if (this.enableLogging) {
      this.logMetrics(metrics);
    }
  }

  /**
   * 获取所有指标
   */
  getMetrics(): RequestMetrics[] {
    return [...this.metrics];
  }

  /**
   * 清空指标
   */
  clear(): void {
    this.metrics = [];
  }

  /**
   * 获取指标数量
   */
  count(): number {
    return this.metrics.length;
  }

  /**
   * 获取成功请求统计
   */
  getSuccessStats(): SuccessStats {
    const total = this.metrics.length;
    const success = this.metrics.filter(m => m.success).length;
    const failed = total - success;
    const successRate = total > 0 ? (success / total) * 100 : 0;

    const stats: SuccessStats = {
      total: total,
      success: success,
      failed: failed,
      successRate: successRate
    };

    return stats;
  }

  /**
   * 获取平均响应时间
   */
  getAverageDuration(): number {
    if (this.metrics.length === 0) {
      return 0;
    }

    const totalDuration = this.metrics.reduce((sum, m) => sum + (m.duration ?? 0), 0);
    return totalDuration / this.metrics.length;
  }

  /**
   * 记录日志
   */
  private logMetrics(metrics: RequestMetrics): void {
    const logMsg = `[${metrics.method}] ${metrics.url} - ${metrics.success ? 'Success' : 'Failed'} - ${metrics.duration}ms`;
    
    if (metrics.success) {
      Logger.info(this.tag, logMsg);
    } else {
      Logger.error(this.tag, logMsg);
    }
  }
}

export default MetricsCollector;
