/**
 * PerformanceMonitor - 性能监控服务
 * 监控应用性能指标，包括内存、CPU、网络、渲染等
 */

import { Logger } from './Logger';

/**
 * 性能指标类型
 */
export interface PerformanceMetrics {
  timestamp: number;

  // 内存指标
  memoryUsage: number;
  memoryPeak: number;
  gcCount: number;

  // CPU指标
  cpuUsage: number;

  // 网络指标
  networkRequests: number;
  networkSuccessRate: number;
  avgResponseTime: number;
  activeConnections: number;

  // 渲染指标
  fps: number;
  frameTime: number;
  droppedFrames: number;

  // 书源指标
  activeSources: number;
  healthySources: number;
  blacklistedSources: number;

  // 缓存指标
  cacheHitRate: number;
  cacheSize: number;

  // 自定义指标
  customMetrics: Map<string, number>;
}

/**
 * 性能快照
 */
export interface PerformanceSnapshot {
  id: string;
  timestamp: number;
  metrics: PerformanceMetrics;
  label: string;
}

/**
 * 性能警告
 */
export interface PerformanceWarning {
  id: string;
  timestamp: number;
  type: 'memory' | 'cpu' | 'network' | 'render' | 'custom';
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  value: number;
  threshold: number;
}

/**
 * 性能监控配置
 */
export interface PerformanceMonitorConfig {
  enabled: boolean;
  samplingInterval: number;
  maxSnapshots: number;
  enableWarnings: boolean;

  // 阈值配置
  memoryWarningThreshold: number;
  cpuWarningThreshold: number;
  fpsWarningThreshold: number;
  responseTimeWarningThreshold: number;
}

/**
 * 默认配置
 */
const DEFAULT_MONITOR_CONFIG: PerformanceMonitorConfig = {
  enabled: true,
  samplingInterval: 5000, // 5秒
  maxSnapshots: 100,
  enableWarnings: true,
  memoryWarningThreshold: 100 * 1024 * 1024, // 100MB
  cpuWarningThreshold: 80, // 80%
  fpsWarningThreshold: 30, // 30 FPS
  responseTimeWarningThreshold: 5000 // 5秒
};

/**
 * 性能监控服务
 */
export class PerformanceMonitor {
  private static instance: PerformanceMonitor | null = null;
  private config: PerformanceMonitorConfig;
  private snapshots: PerformanceSnapshot[] = [];
  private warnings: PerformanceWarning[] = [];
  private currentMetrics: PerformanceMetrics;
  private isMonitoring: boolean = false;
  private monitorTimer: number = -1;
  private frameCount: number = 0;
  private lastFrameTime: number = 0;
  private fpsHistory: number[] = [];

  private constructor(config: PerformanceMonitorConfig = DEFAULT_MONITOR_CONFIG) {
    this.config = config;
    this.currentMetrics = this.createEmptyMetrics();
  }

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  /**
   * 创建空指标
   */
  private createEmptyMetrics(): PerformanceMetrics {
    return {
      timestamp: Date.now(),
      memoryUsage: 0,
      memoryPeak: 0,
      gcCount: 0,
      cpuUsage: 0,
      networkRequests: 0,
      networkSuccessRate: 0,
      avgResponseTime: 0,
      activeConnections: 0,
      fps: 60,
      frameTime: 16.67,
      droppedFrames: 0,
      activeSources: 0,
      healthySources: 0,
      blacklistedSources: 0,
      cacheHitRate: 0,
      cacheSize: 0,
      customMetrics: new Map()
    };
  }

  /**
   * 开始监控
   */
  startMonitoring(): void {
    if (this.isMonitoring) return;

    this.isMonitoring = true;
    this.lastFrameTime = Date.now();

    // 启动定时采样
    this.monitorTimer = setInterval(() => {
      this.collectMetrics();
    }, this.config.samplingInterval);

    Logger.info('PerformanceMonitor', '性能监控已启动');
  }

  /**
   * 停止监控
   */
  stopMonitoring(): void {
    if (!this.isMonitoring) return;

    this.isMonitoring = false;
    if (this.monitorTimer !== -1) {
      clearInterval(this.monitorTimer);
      this.monitorTimer = -1;
    }

    Logger.info('PerformanceMonitor', '性能监控已停止');
  }

  /**
   * 收集性能指标
   */
  private collectMetrics(): void {
    const now = Date.now();

    // 更新时间戳
    this.currentMetrics.timestamp = now;

    // 计算FPS
    this.calculateFPS();

    // 检查警告
    if (this.config.enableWarnings) {
      this.checkWarnings();
    }

    // 创建快照
    this.createSnapshot('periodic');
  }

  /**
   * 计算FPS
   */
  private calculateFPS(): void {
    const now = Date.now();
    const elapsed = now - this.lastFrameTime;

    if (elapsed > 0) {
      const fps = (this.frameCount / elapsed) * 1000;
      this.fpsHistory.push(fps);

      if (this.fpsHistory.length > 10) {
        this.fpsHistory.shift();
      }

      this.currentMetrics.fps = this.fpsHistory.reduce((a, b) => a + b, 0) / this.fpsHistory.length;
      this.currentMetrics.frameTime = 1000 / this.currentMetrics.fps;
      this.currentMetrics.droppedFrames = Math.max(0, Math.floor((60 - this.currentMetrics.fps) / 60 * elapsed / 16.67));

      this.frameCount = 0;
      this.lastFrameTime = now;
    }
  }

  /**
   * 记录帧
   */
  recordFrame(): void {
    this.frameCount++;
  }

  /**
   * 更新内存指标
   */
  updateMemoryMetrics(usage: number, peak: number, gcCount: number): void {
    this.currentMetrics.memoryUsage = usage;
    this.currentMetrics.memoryPeak = peak;
    this.currentMetrics.gcCount = gcCount;
  }

  /**
   * 更新CPU指标
   */
  updateCPUMetrics(usage: number): void {
    this.currentMetrics.cpuUsage = usage;
  }

  /**
   * 更新网络指标
   */
  updateNetworkMetrics(
    requests: number,
    successRate: number,
    avgResponseTime: number,
    activeConnections: number
  ): void {
    this.currentMetrics.networkRequests = requests;
    this.currentMetrics.networkSuccessRate = successRate;
    this.currentMetrics.avgResponseTime = avgResponseTime;
    this.currentMetrics.activeConnections = activeConnections;
  }

  /**
   * 更新书源指标
   */
  updateSourceMetrics(
    active: number,
    healthy: number,
    blacklisted: number
  ): void {
    this.currentMetrics.activeSources = active;
    this.currentMetrics.healthySources = healthy;
    this.currentMetrics.blacklistedSources = blacklisted;
  }

  /**
   * 更新缓存指标
   */
  updateCacheMetrics(hitRate: number, size: number): void {
    this.currentMetrics.cacheHitRate = hitRate;
    this.currentMetrics.cacheSize = size;
  }

  /**
   * 设置自定义指标
   */
  setCustomMetric(name: string, value: number): void {
    this.currentMetrics.customMetrics.set(name, value);
  }

  /**
   * 检查性能警告
   */
  private checkWarnings(): void {
    const now = Date.now();

    // 内存警告
    if (this.currentMetrics.memoryUsage > this.config.memoryWarningThreshold) {
      this.addWarning({
        id: `mem_${now}`,
        timestamp: now,
        type: 'memory',
        severity: this.currentMetrics.memoryUsage > this.config.memoryWarningThreshold * 1.5 ? 'critical' : 'high',
        message: `内存使用过高: ${(this.currentMetrics.memoryUsage / 1024 / 1024).toFixed(2)}MB`,
        value: this.currentMetrics.memoryUsage,
        threshold: this.config.memoryWarningThreshold
      });
    }

    // CPU警告
    if (this.currentMetrics.cpuUsage > this.config.cpuWarningThreshold) {
      this.addWarning({
        id: `cpu_${now}`,
        timestamp: now,
        type: 'cpu',
        severity: this.currentMetrics.cpuUsage > 90 ? 'critical' : 'high',
        message: `CPU使用率过高: ${this.currentMetrics.cpuUsage.toFixed(1)}%`,
        value: this.currentMetrics.cpuUsage,
        threshold: this.config.cpuWarningThreshold
      });
    }

    // FPS警告
    if (this.currentMetrics.fps < this.config.fpsWarningThreshold) {
      this.addWarning({
        id: `fps_${now}`,
        timestamp: now,
        type: 'render',
        severity: this.currentMetrics.fps < 20 ? 'critical' : 'medium',
        message: `帧率过低: ${this.currentMetrics.fps.toFixed(1)} FPS`,
        value: this.currentMetrics.fps,
        threshold: this.config.fpsWarningThreshold
      });
    }

    // 响应时间警告
    if (this.currentMetrics.avgResponseTime > this.config.responseTimeWarningThreshold) {
      this.addWarning({
        id: `resp_${now}`,
        timestamp: now,
        type: 'network',
        severity: this.currentMetrics.avgResponseTime > 10000 ? 'critical' : 'medium',
        message: `平均响应时间过长: ${this.currentMetrics.avgResponseTime.toFixed(0)}ms`,
        value: this.currentMetrics.avgResponseTime,
        threshold: this.config.responseTimeWarningThreshold
      });
    }
  }

  /**
   * 添加警告
   */
  private addWarning(warning: PerformanceWarning): void {
    this.warnings.push(warning);

    // 限制警告数量
    if (this.warnings.length > 50) {
      this.warnings.shift();
    }

    Logger.warn('PerformanceMonitor', `[${warning.severity.toUpperCase()}] ${warning.message}`);
  }

  /**
   * 创建快照
   */
  createSnapshot(label: string = 'manual'): PerformanceSnapshot {
    const snapshot: PerformanceSnapshot = {
      id: `snap_${Date.now()}`,
      timestamp: Date.now(),
      metrics: { ...this.currentMetrics, customMetrics: new Map(this.currentMetrics.customMetrics) },
      label: label
    };

    this.snapshots.push(snapshot);

    // 限制快照数量
    if (this.snapshots.length > this.config.maxSnapshots) {
      this.snapshots.shift();
    }

    return snapshot;
  }

  /**
   * 获取当前指标
   */
  getCurrentMetrics(): PerformanceMetrics {
    return { ...this.currentMetrics, customMetrics: new Map(this.currentMetrics.customMetrics) };
  }

  /**
   * 获取所有快照
   */
  getSnapshots(): PerformanceSnapshot[] {
    return [...this.snapshots];
  }

  /**
   * 获取所有警告
   */
  getWarnings(): PerformanceWarning[] {
    return [...this.warnings];
  }

  /**
   * 获取最近的警告
   */
  getRecentWarnings(count: number = 10): PerformanceWarning[] {
    return this.warnings.slice(-count);
  }

  /**
   * 清除警告
   */
  clearWarnings(): void {
    this.warnings = [];
  }

  /**
   * 清除快照
   */
  clearSnapshots(): void {
    this.snapshots = [];
  }

  /**
   * 生成性能报告
   */
  generateReport(): string {
    const metrics = this.currentMetrics;
    const warnings = this.warnings.length;

    let report = '=== 性能监控报告 ===\n\n';

    report += '【系统指标】\n';
    report += `内存使用: ${(metrics.memoryUsage / 1024 / 1024).toFixed(2)}MB (峰值: ${(metrics.memoryPeak / 1024 / 1024).toFixed(2)}MB)\n`;
    report += `GC次数: ${metrics.gcCount}\n`;
    report += `CPU使用率: ${metrics.cpuUsage.toFixed(1)}%\n\n`;

    report += '【渲染指标】\n';
    report += `FPS: ${metrics.fps.toFixed(1)}\n`;
    report += `帧时间: ${metrics.frameTime.toFixed(2)}ms\n`;
    report += `丢帧数: ${metrics.droppedFrames}\n\n`;

    report += '【网络指标】\n';
    report += `总请求数: ${metrics.networkRequests}\n`;
    report += `成功率: ${(metrics.networkSuccessRate * 100).toFixed(1)}%\n`;
    report += `平均响应时间: ${metrics.avgResponseTime.toFixed(0)}ms\n`;
    report += `活跃连接: ${metrics.activeConnections}\n\n`;

    report += '【书源指标】\n';
    report += `活跃书源: ${metrics.activeSources}\n`;
    report += `健康书源: ${metrics.healthySources}\n`;
    report += `黑名单书源: ${metrics.blacklistedSources}\n\n`;

    report += '【缓存指标】\n';
    report += `缓存命中率: ${(metrics.cacheHitRate * 100).toFixed(1)}%\n`;
    report += `缓存大小: ${(metrics.cacheSize / 1024 / 1024).toFixed(2)}MB\n\n`;

    report += '【警告统计】\n';
    report += `总警告数: ${warnings}\n`;
    report += `快照数: ${this.snapshots.length}\n\n`;

    if (metrics.customMetrics.size > 0) {
      report += '【自定义指标】\n';
      metrics.customMetrics.forEach((value, key) => {
        report += `${key}: ${value}\n`;
      });
      report += '\n';
    }

    return report;
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<PerformanceMonitorConfig>): void {
    this.config = { ...this.config, ...config };

    // 如果监控已启动且采样间隔改变，重启监控
    if (this.isMonitoring && config.samplingInterval !== undefined) {
      this.stopMonitoring();
      this.startMonitoring();
    }

    Logger.info('PerformanceMonitor', '配置已更新');
  }

  /**
   * 重置所有指标
   */
  reset(): void {
    this.currentMetrics = this.createEmptyMetrics();
    this.snapshots = [];
    this.warnings = [];
    this.frameCount = 0;
    this.fpsHistory = [];
    Logger.info('PerformanceMonitor', '所有指标已重置');
  }
}

export const performanceMonitor = PerformanceMonitor.getInstance();
