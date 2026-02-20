/**
 * SmartSourceSelector - 智能书源选择器
 * 根据书源性能、成功率、响应时间等指标智能选择最佳书源
 */

import { BookSource } from '../models/BookSource';
import { Logger } from './Logger';

/**
 * 书源性能指标
 */
export interface SourcePerformanceMetrics {
  sourceId: string;
  sourceName: string;

  // 成功率相关
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  successRate: number;

  // 响应时间相关
  avgResponseTime: number;
  minResponseTime: number;
  maxResponseTime: number;
  recentResponseTimes: number[];

  // 错误相关
  consecutiveFailures: number;
  lastErrorTime: number;
  lastError: string;

  // 时间戳
  lastSuccessTime: number;
  lastUsedTime: number;
  firstUsedTime: number;

  // 权重和评分
  weight: number;
  score: number;
  healthScore: number;

  // 状态
  isEnabled: boolean;
  isHealthy: boolean;
  isBlacklisted: boolean;
  blacklistUntil: number;
}

/**
 * 书源选择策略
 */
export enum SourceSelectionStrategy {
  BEST_PERFORMANCE = 'best_performance',      // 最佳性能
  FASTEST_RESPONSE = 'fastest_response',      // 最快响应
  HIGHEST_SUCCESS_RATE = 'highest_success_rate', // 最高成功率
  BALANCED = 'balanced',                      // 平衡策略
  ROUND_ROBIN = 'round_robin',                // 轮询
  WEIGHTED_RANDOM = 'weighted_random'         // 加权随机
}

/**
 * 书源选择配置
 */
export interface SourceSelectionConfig {
  strategy: SourceSelectionStrategy;
  maxConsecutiveFailures: number;
  blacklistDuration: number;
  healthCheckInterval: number;
  minHealthScore: number;
  maxRecentResponseTimes: number;
  enableAutoBlacklist: boolean;
  enableAutoRecovery: boolean;
}

/**
 * 默认配置
 */
const DEFAULT_SELECTION_CONFIG: SourceSelectionConfig = {
  strategy: SourceSelectionStrategy.BALANCED,
  maxConsecutiveFailures: 3,
  blacklistDuration: 300000, // 5分钟
  healthCheckInterval: 60000, // 1分钟
  minHealthScore: 30,
  maxRecentResponseTimes: 10,
  enableAutoBlacklist: true,
  enableAutoRecovery: true
};

/**
 * 智能书源选择器
 */
export class SmartSourceSelector {
  private static instance: SmartSourceSelector | null = null;
  private metrics: Map<string, SourcePerformanceMetrics> = new Map();
  private config: SourceSelectionConfig;
  private roundRobinIndex: number = 0;

  private constructor(config: SourceSelectionConfig = DEFAULT_SELECTION_CONFIG) {
    this.config = config;
  }

  static getInstance(): SmartSourceSelector {
    if (!SmartSourceSelector.instance) {
      SmartSourceSelector.instance = new SmartSourceSelector();
    }
    return SmartSourceSelector.instance;
  }

  /**
   * 初始化书源指标
   */
  initializeSources(sources: BookSource[]): void {
    sources.forEach(source => {
      if (!this.metrics.has(source.id)) {
        this.metrics.set(source.id, this.createInitialMetrics(source));
      } else {
        // 更新启用状态
        const metrics = this.metrics.get(source.id)!;
        metrics.isEnabled = source.enabled;
      }
    });
    Logger.info('SmartSourceSelector', `初始化了 ${sources.length} 个书源指标`);
  }

  /**
   * 创建初始指标
   */
  private createInitialMetrics(source: BookSource): SourcePerformanceMetrics {
    return {
      sourceId: source.id,
      sourceName: source.name,
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      successRate: 0,
      avgResponseTime: 0,
      minResponseTime: Number.MAX_VALUE,
      maxResponseTime: 0,
      recentResponseTimes: [],
      consecutiveFailures: 0,
      lastErrorTime: 0,
      lastError: '',
      lastSuccessTime: 0,
      lastUsedTime: 0,
      firstUsedTime: Date.now(),
      weight: 1.0,
      score: 50,
      healthScore: 100,
      isEnabled: source.enabled,
      isHealthy: true,
      isBlacklisted: false,
      blacklistUntil: 0
    };
  }

  /**
   * 选择最佳书源
   */
  selectBestSource(sources: BookSource[], strategy?: SourceSelectionStrategy): BookSource | null {
    const useStrategy = strategy || this.config.strategy;
    const availableSources = this.filterAvailableSources(sources);

    if (availableSources.length === 0) {
      Logger.warn('SmartSourceSelector', '没有可用的书源');
      return null;
    }

    let selectedSource: BookSource | null = null;

    switch (useStrategy) {
      case SourceSelectionStrategy.BEST_PERFORMANCE:
        selectedSource = this.selectByPerformance(availableSources);
        break;
      case SourceSelectionStrategy.FASTEST_RESPONSE:
        selectedSource = this.selectByResponseTime(availableSources);
        break;
      case SourceSelectionStrategy.HIGHEST_SUCCESS_RATE:
        selectedSource = this.selectBySuccessRate(availableSources);
        break;
      case SourceSelectionStrategy.BALANCED:
        selectedSource = this.selectByBalanced(availableSources);
        break;
      case SourceSelectionStrategy.ROUND_ROBIN:
        selectedSource = this.selectByRoundRobin(availableSources);
        break;
      case SourceSelectionStrategy.WEIGHTED_RANDOM:
        selectedSource = this.selectByWeightedRandom(availableSources);
        break;
      default:
        selectedSource = availableSources[0];
    }

    if (selectedSource) {
      Logger.info('SmartSourceSelector', `选择书源: ${selectedSource.name} (策略: ${useStrategy})`);
    }

    return selectedSource;
  }

  /**
   * 选择多个书源（按优先级排序）
   */
  selectMultipleSources(sources: BookSource[], count: number, strategy?: SourceSelectionStrategy): BookSource[] {
    const useStrategy = strategy || this.config.strategy;
    const availableSources = this.filterAvailableSources(sources);

    if (availableSources.length === 0) {
      return [];
    }

    // 根据策略排序
    const sortedSources = this.sortSourcesByStrategy(availableSources, useStrategy);

    // 返回前N个
    return sortedSources.slice(0, Math.min(count, sortedSources.length));
  }

  /**
   * 过滤可用书源
   */
  private filterAvailableSources(sources: BookSource[]): BookSource[] {
    const now = Date.now();
    return sources.filter(source => {
      const metrics = this.metrics.get(source.id);
      if (!metrics) {
        return source.enabled;
      }

      // 检查是否启用
      if (!source.enabled || !metrics.isEnabled) {
        return false;
      }

      // 检查是否在黑名单中
      if (metrics.isBlacklisted && now < metrics.blacklistUntil) {
        return false;
      }

      // 检查健康分数
      if (metrics.healthScore < this.config.minHealthScore) {
        return false;
      }

      return true;
    });
  }

  /**
   * 按性能选择
   */
  private selectByPerformance(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.BEST_PERFORMANCE)[0];
  }

  /**
   * 按响应时间选择
   */
  private selectByResponseTime(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.FASTEST_RESPONSE)[0];
  }

  /**
   * 按成功率选择
   */
  private selectBySuccessRate(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.HIGHEST_SUCCESS_RATE)[0];
  }

  /**
   * 平衡策略选择
   */
  private selectByBalanced(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.BALANCED)[0];
  }

  /**
   * 轮询选择
   */
  private selectByRoundRobin(sources: BookSource[]): BookSource {
    const source = sources[this.roundRobinIndex % sources.length];
    this.roundRobinIndex++;
    return source;
  }

  /**
   * 加权随机选择
   */
  private selectByWeightedRandom(sources: BookSource[]): BookSource {
    const weights = sources.map(source => {
      const metrics = this.metrics.get(source.id);
      return metrics ? metrics.weight : 1.0;
    });

    const totalWeight = weights.reduce((sum, w) => sum + w, 0);
    let random = Math.random() * totalWeight;

    for (let i = 0; i < sources.length; i++) {
      random -= weights[i];
      if (random <= 0) {
        return sources[i];
      }
    }

    return sources[0];
  }

  /**
   * 根据策略排序书源
   */
  private sortSourcesByStrategy(sources: BookSource[], strategy: SourceSelectionStrategy): BookSource[] {
    return sources.slice().sort((a, b) => {
      const metricsA = this.metrics.get(a.id);
      const metricsB = this.metrics.get(b.id);

      if (!metricsA && !metricsB) return 0;
      if (!metricsA) return 1;
      if (!metricsB) return -1;

      switch (strategy) {
        case SourceSelectionStrategy.BEST_PERFORMANCE:
          return metricsB.score - metricsA.score;

        case SourceSelectionStrategy.FASTEST_RESPONSE:
          return metricsA.avgResponseTime - metricsB.avgResponseTime;

        case SourceSelectionStrategy.HIGHEST_SUCCESS_RATE:
          return metricsB.successRate - metricsA.successRate;

        case SourceSelectionStrategy.BALANCED:
          return metricsB.healthScore - metricsA.healthScore;

        default:
          return 0;
      }
    });
  }

  /**
   * 记录请求成功
   */
  recordSuccess(sourceId: string, responseTime: number): void {
    const metrics = this.metrics.get(sourceId);
    if (!metrics) return;

    const now = Date.now();

    metrics.totalRequests++;
    metrics.successfulRequests++;
    metrics.consecutiveFailures = 0;
    metrics.lastSuccessTime = now;
    metrics.lastUsedTime = now;

    // 更新响应时间
    this.updateResponseTime(metrics, responseTime);

    // 更新成功率
    this.updateSuccessRate(metrics);

    // 更新评分
    this.updateScore(metrics);

    // 检查是否需要从黑名单中移除
    if (metrics.isBlacklisted && now >= metrics.blacklistUntil) {
      metrics.isBlacklisted = false;
      Logger.info('SmartSourceSelector', `书源 ${metrics.sourceName} 已从黑名单中移除`);
    }

    Logger.debug('SmartSourceSelector',
      `书源 ${metrics.sourceName} 请求成功: 响应时间=${responseTime}ms, 成功率=${(metrics.successRate * 100).toFixed(1)}%`);
  }

  /**
   * 记录请求失败
   */
  recordFailure(sourceId: string, error: string): void {
    const metrics = this.metrics.get(sourceId);
    if (!metrics) return;

    const now = Date.now();

    metrics.totalRequests++;
    metrics.failedRequests++;
    metrics.consecutiveFailures++;
    metrics.lastErrorTime = now;
    metrics.lastError = error;
    metrics.lastUsedTime = now;

    // 更新成功率
    this.updateSuccessRate(metrics);

    // 更新评分
    this.updateScore(metrics);

    // 检查是否需要加入黑名单
    if (this.config.enableAutoBlacklist &&
      metrics.consecutiveFailures >= this.config.maxConsecutiveFailures) {
      this.blacklistSource(sourceId);
    }

    Logger.warn('SmartSourceSelector',
      `书源 ${metrics.sourceName} 请求失败: ${error}, 连续失败=${metrics.consecutiveFailures}`);
  }

  /**
   * 更新响应时间
   */
  private updateResponseTime(metrics: SourcePerformanceMetrics, responseTime: number): void {
    metrics.recentResponseTimes.push(responseTime);

    if (metrics.recentResponseTimes.length > this.config.maxRecentResponseTimes) {
      metrics.recentResponseTimes.shift();
    }

    metrics.minResponseTime = Math.min(metrics.minResponseTime, responseTime);
    metrics.maxResponseTime = Math.max(metrics.maxResponseTime, responseTime);

    const sum = metrics.recentResponseTimes.reduce((a, b) => a + b, 0);
    metrics.avgResponseTime = sum / metrics.recentResponseTimes.length;
  }

  /**
   * 更新成功率
   */
  private updateSuccessRate(metrics: SourcePerformanceMetrics): void {
    if (metrics.totalRequests > 0) {
      metrics.successRate = metrics.successfulRequests / metrics.totalRequests;
    }
  }

  /**
   * 更新评分
   */
  private updateScore(metrics: SourcePerformanceMetrics): void {
    // 成功率权重: 40%
    const successRateScore = metrics.successRate * 40;

    // 响应时间权重: 30% (响应时间越短分数越高)
    const responseTimeScore = Math.max(0, 30 - (metrics.avgResponseTime / 1000));

    // 健康分数权重: 30%
    const healthScoreComponent = metrics.healthScore * 0.3;

    metrics.score = successRateScore + responseTimeScore + healthScoreComponent;

    // 更新健康分数
    this.updateHealthScore(metrics);
  }

  /**
   * 更新健康分数
   */
  private updateHealthScore(metrics: SourcePerformanceMetrics): void {
    let healthScore = 100;

    // 根据连续失败次数扣分
    healthScore -= metrics.consecutiveFailures * 10;

    // 根据成功率调整
    healthScore *= metrics.successRate;

    // 根据响应时间调整
    if (metrics.avgResponseTime > 5000) {
      healthScore *= 0.8;
    } else if (metrics.avgResponseTime > 3000) {
      healthScore *= 0.9;
    }

    metrics.healthScore = Math.max(0, Math.min(100, healthScore));
    metrics.isHealthy = metrics.healthScore >= this.config.minHealthScore;
  }

  /**
   * 将书源加入黑名单
   */
  blacklistSource(sourceId: string, duration?: number): void {
    const metrics = this.metrics.get(sourceId);
    if (!metrics) return;

    const blacklistDuration = duration || this.config.blacklistDuration;
    metrics.isBlacklisted = true;
    metrics.blacklistUntil = Date.now() + blacklistDuration;

    Logger.warn('SmartSourceSelector',
      `书源 ${metrics.sourceName} 已加入黑名单，持续 ${blacklistDuration / 1000} 秒`);
  }

  /**
   * 从黑名单中移除书源
   */
  unblacklistSource(sourceId: string): void {
    const metrics = this.metrics.get(sourceId);
    if (!metrics) return;

    metrics.isBlacklisted = false;
    metrics.blacklistUntil = 0;
    metrics.consecutiveFailures = 0;

    Logger.info('SmartSourceSelector', `书源 ${metrics.sourceName} 已从黑名单中移除`);
  }

  /**
   * 获取书源指标
   */
  getMetrics(sourceId: string): SourcePerformanceMetrics | undefined {
    return this.metrics.get(sourceId);
  }

  /**
   * 获取所有书源指标
   */
  getAllMetrics(): SourcePerformanceMetrics[] {
    return Array.from(this.metrics.values());
  }

  /**
   * 获取健康书源数量
   */
  getHealthySourceCount(): number {
    return Array.from(this.metrics.values()).filter(m => m.isHealthy && m.isEnabled).length;
  }

  /**
   * 获取书源统计报告
   */
  getReport(): string {
    const allMetrics = Array.from(this.metrics.values());
    const healthyCount = allMetrics.filter(m => m.isHealthy).length;
    const blacklistedCount = allMetrics.filter(m => m.isBlacklisted).length;

    let report = '=== 智能书源选择器报告 ===\n';
    report += `总书源数: ${allMetrics.length}\n`;
    report += `健康书源: ${healthyCount}\n`;
    report += `黑名单书源: ${blacklistedCount}\n\n`;

    allMetrics.forEach(m => {
      report += `【${m.sourceName}】\n`;
      report += `  成功率: ${(m.successRate * 100).toFixed(1)}%\n`;
      report += `  平均响应: ${m.avgResponseTime.toFixed(0)}ms\n`;
      report += `  健康分数: ${m.healthScore.toFixed(1)}\n`;
      report += `  评分: ${m.score.toFixed(1)}\n`;
      report += `  状态: ${m.isHealthy ? '健康' : '不健康'} ${m.isBlacklisted ? '(黑名单)' : ''}\n\n`;
    });

    return report;
  }

  /**
   * 重置所有指标
   */
  reset(): void {
    this.metrics.clear();
    this.roundRobinIndex = 0;
    Logger.info('SmartSourceSelector', '所有书源指标已重置');
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<SourceSelectionConfig>): void {
    this.config = this.mergeConfig(this.config, config);
    Logger.info('SmartSourceSelector', '配置已更新');
  }

  private mergeConfig(base: SourceSelectionConfig, update: Partial<SourceSelectionConfig>): SourceSelectionConfig {
    return {
      strategy: update.strategy !== undefined ? update.strategy : base.strategy,
      maxConsecutiveFailures: update.maxConsecutiveFailures !== undefined ? update.maxConsecutiveFailures : base.maxConsecutiveFailures,
      blacklistDuration: update.blacklistDuration !== undefined ? update.blacklistDuration : base.blacklistDuration,
      healthCheckInterval: update.healthCheckInterval !== undefined ? update.healthCheckInterval : base.healthCheckInterval,
      minHealthScore: update.minHealthScore !== undefined ? update.minHealthScore : base.minHealthScore,
      maxRecentResponseTimes: update.maxRecentResponseTimes !== undefined ? update.maxRecentResponseTimes : base.maxRecentResponseTimes,
      enableAutoBlacklist: update.enableAutoBlacklist !== undefined ? update.enableAutoBlacklist : base.enableAutoBlacklist,
      enableAutoRecovery: update.enableAutoRecovery !== undefined ? update.enableAutoRecovery : base.enableAutoRecovery
    };
  }
}

export const smartSourceSelector = SmartSourceSelector.getInstance();
