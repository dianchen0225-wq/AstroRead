/**
 * SmartSourceSelector - 智能书源选择器
 * 根据书源性能、成功率、响应时间等指标智能选择最佳书源
 * 使用 EnhancedSourceHealthManager 作为数据源
 */

import { BookSource } from '../models/BookSource';
import { Logger } from './Logger';
import { EnhancedSourceHealthManager, EnhancedHealthRecord } from './EnhancedSourceHealthManager';

export enum SourceSelectionStrategy {
  BEST_PERFORMANCE = 'best_performance',
  FASTEST_RESPONSE = 'fastest_response',
  HIGHEST_SUCCESS_RATE = 'highest_success_rate',
  BALANCED = 'balanced',
  ROUND_ROBIN = 'round_robin',
  WEIGHTED_RANDOM = 'weighted_random'
}

export interface SourceSelectionConfig {
  strategy: SourceSelectionStrategy;
  minHealthScore: number;
  blacklistDuration: number;
  enableAutoBlacklist: boolean;
}

export interface SourceMetrics {
  score: number;
  successRate: number;
  avgResponseTime: number;
  isBlacklisted: boolean;
  sourceName: string;
}

export interface SourceMetricsWithId extends SourceMetrics {
  sourceId: string;
}

const DEFAULT_SELECTION_CONFIG: SourceSelectionConfig = {
  strategy: SourceSelectionStrategy.BALANCED,
  minHealthScore: 30,
  blacklistDuration: 300000,
  enableAutoBlacklist: true
};

export class SmartSourceSelector {
  private static instance: SmartSourceSelector | null = null;
  private healthManager: EnhancedSourceHealthManager;
  private config: SourceSelectionConfig;
  private roundRobinIndex: number = 0;
  private blacklistMap: Map<string, number> = new Map();

  private constructor(config: SourceSelectionConfig = DEFAULT_SELECTION_CONFIG) {
    this.config = config;
    this.healthManager = EnhancedSourceHealthManager.getInstance();
  }

  static getInstance(): SmartSourceSelector {
    if (!SmartSourceSelector.instance) {
      SmartSourceSelector.instance = new SmartSourceSelector();
    }
    return SmartSourceSelector.instance;
  }

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

  selectMultipleSources(sources: BookSource[], count: number, strategy?: SourceSelectionStrategy): BookSource[] {
    const useStrategy = strategy || this.config.strategy;
    const availableSources = this.filterAvailableSources(sources);

    if (availableSources.length === 0) {
      return [];
    }

    const sortedSources = this.sortSourcesByStrategy(availableSources, useStrategy);
    return sortedSources.slice(0, Math.min(count, sortedSources.length));
  }

  private filterAvailableSources(sources: BookSource[]): BookSource[] {
    const now = Date.now();
    return sources.filter(source => {
      if (!source.enabled) {
        return false;
      }

      const record = this.healthManager.getRecord(source.id);
      if (!record) {
        return true;
      }

      if (!record.isEnabled || record.isPermanentlyDisabled) {
        return false;
      }

      const blacklistedUntil = this.blacklistMap.get(source.id);
      if (blacklistedUntil && now < blacklistedUntil) {
        return false;
      }

      if (record.score < this.config.minHealthScore) {
        return false;
      }

      return true;
    });
  }

  private selectByPerformance(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.BEST_PERFORMANCE)[0];
  }

  private selectByResponseTime(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.FASTEST_RESPONSE)[0];
  }

  private selectBySuccessRate(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.HIGHEST_SUCCESS_RATE)[0];
  }

  private selectByBalanced(sources: BookSource[]): BookSource {
    return this.sortSourcesByStrategy(sources, SourceSelectionStrategy.BALANCED)[0];
  }

  private selectByRoundRobin(sources: BookSource[]): BookSource {
    const source = sources[this.roundRobinIndex % sources.length];
    this.roundRobinIndex++;
    return source;
  }

  private selectByWeightedRandom(sources: BookSource[]): BookSource {
    const weights = sources.map(source => {
      const record = this.healthManager.getRecord(source.id);
      return record ? Math.max(record.score, 1) : 50;
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

  private sortSourcesByStrategy(sources: BookSource[], strategy: SourceSelectionStrategy): BookSource[] {
    return sources.slice().sort((a, b) => {
      const recordA = this.healthManager.getRecord(a.id);
      const recordB = this.healthManager.getRecord(b.id);

      if (!recordA && !recordB) return 0;
      if (!recordA) return 1;
      if (!recordB) return -1;

      switch (strategy) {
        case SourceSelectionStrategy.BEST_PERFORMANCE:
          return recordB.score - recordA.score;

        case SourceSelectionStrategy.FASTEST_RESPONSE:
          return recordA.avgResponseTime - recordB.avgResponseTime;

        case SourceSelectionStrategy.HIGHEST_SUCCESS_RATE: {
          const rateA = recordA.requestCount > 0 ? recordA.successCount / recordA.requestCount : 0;
          const rateB = recordB.requestCount > 0 ? recordB.successCount / recordB.requestCount : 0;
          return rateB - rateA;
        }

        case SourceSelectionStrategy.BALANCED: {
          const scoreA = this.calculateBalancedScore(recordA);
          const scoreB = this.calculateBalancedScore(recordB);
          return scoreB - scoreA;
        }

        default:
          return 0;
      }
    });
  }

  private calculateBalancedScore(record: EnhancedHealthRecord): number {
    const successRate = record.requestCount > 0 ? record.successCount / record.requestCount : 0.5;
    const responseScore = Math.max(0, 100 - record.avgResponseTime / 100);
    return record.score * 0.5 + successRate * 30 + responseScore * 0.2;
  }

  recordSuccess(sourceId: string, responseTime: number): void {
    const record = this.healthManager.getRecord(sourceId);
    if (!record) return;

    this.healthManager.recordSuccess(
      sourceId,
      record.sourceName,
      record.sourceUrl,
      responseTime
    );

    if (this.blacklistMap.has(sourceId)) {
      this.blacklistMap.delete(sourceId);
      Logger.info('SmartSourceSelector', `书源 ${record.sourceName} 已从黑名单中移除`);
    }

    Logger.debug('SmartSourceSelector',
      `书源 ${record.sourceName} 请求成功: 响应时间=${responseTime}ms`);
  }

  recordFailure(sourceId: string, error: string): void {
    const record = this.healthManager.getRecord(sourceId);
    if (!record) return;

    const errorType = this.classifyError(error);
    this.healthManager.recordFailure(
      sourceId,
      record.sourceName,
      record.sourceUrl,
      errorType,
      error
    );

    if (this.config.enableAutoBlacklist && record.consecutiveFailures >= 3) {
      this.blacklistSource(sourceId);
    }

    Logger.warn('SmartSourceSelector',
      `书源 ${record.sourceName} 请求失败: ${error}`);
  }

  private classifyError(error: string): string {
    const msg = error.toLowerCase();
    if (msg.includes('timeout')) return 'timeout';
    if (msg.includes('dns')) return 'dns';
    if (msg.includes('ssl') || msg.includes('certificate')) return 'ssl';
    if (msg.includes('network') || msg.includes('connection')) return 'network';
    if (msg.includes('404')) return 'not_found';
    if (msg.includes('500') || msg.includes('502') || msg.includes('503')) return 'server';
    return 'unknown';
  }

  blacklistSource(sourceId: string, duration?: number): void {
    const record = this.healthManager.getRecord(sourceId);
    if (!record) return;

    const blacklistDuration = duration || this.config.blacklistDuration;
    this.blacklistMap.set(sourceId, Date.now() + blacklistDuration);

    Logger.warn('SmartSourceSelector',
      `书源 ${record.sourceName} 已加入黑名单，持续 ${blacklistDuration / 1000} 秒`);
  }

  unblacklistSource(sourceId: string): void {
    this.blacklistMap.delete(sourceId);
    Logger.info('SmartSourceSelector', `书源已从黑名单中移除`);
  }

  isBlacklisted(sourceId: string): boolean {
    const blacklistedUntil = this.blacklistMap.get(sourceId);
    return blacklistedUntil ? Date.now() < blacklistedUntil : false;
  }

  getHealthManager(): EnhancedSourceHealthManager {
    return this.healthManager;
  }

  getReport(): string {
    const records = this.healthManager.getAllHealthRecords();
    const blacklistedCount = Array.from(this.blacklistMap.entries())
      .filter((entry: [string, number]) => Date.now() < entry[1]).length;

    let report = '=== 智能书源选择器报告 ===\n';
    report += `总书源数: ${records.length}\n`;
    report += `健康书源: ${records.filter(r => r.score >= this.config.minHealthScore).length}\n`;
    report += `黑名单书源: ${blacklistedCount}\n\n`;

    records.forEach(r => {
      const successRate = r.requestCount > 0 ? (r.successCount / r.requestCount * 100).toFixed(1) : '0.0';
      const isBlacklisted = this.isBlacklisted(r.sourceId);
      report += `【${r.sourceName}】\n`;
      report += `  成功率: ${successRate}%\n`;
      report += `  平均响应: ${r.avgResponseTime.toFixed(0)}ms\n`;
      report += `  评分: ${r.score}\n`;
      report += `  状态: ${r.isEnabled ? '启用' : '禁用'} ${isBlacklisted ? '(黑名单)' : ''}\n\n`;
    });

    return report;
  }

  reset(): void {
    this.blacklistMap.clear();
    this.roundRobinIndex = 0;
    Logger.info('SmartSourceSelector', '选择器状态已重置');
  }

  updateConfig(config: Partial<SourceSelectionConfig>): void {
    if (config.strategy !== undefined) this.config.strategy = config.strategy;
    if (config.minHealthScore !== undefined) this.config.minHealthScore = config.minHealthScore;
    if (config.blacklistDuration !== undefined) this.config.blacklistDuration = config.blacklistDuration;
    if (config.enableAutoBlacklist !== undefined) this.config.enableAutoBlacklist = config.enableAutoBlacklist;
    Logger.info('SmartSourceSelector', '配置已更新');
  }

  initializeSources(sources: BookSource[]): void {
    for (const source of sources) {
      this.healthManager.initializeSourceIfNeeded(source.id, source.name, source.url, source.enabled);
    }
    Logger.info('SmartSourceSelector', `已初始化 ${sources.length} 个书源`);
  }

  getMetrics(sourceId: string): SourceMetrics | null {
    const record = this.healthManager.getRecord(sourceId);
    if (!record) return null;
    
    const successRate = record.requestCount > 0 ? record.successCount / record.requestCount : 0;
    const metrics: SourceMetrics = {
      score: record.score,
      successRate: successRate,
      avgResponseTime: record.avgResponseTime,
      isBlacklisted: this.isBlacklisted(sourceId),
      sourceName: record.sourceName
    };
    return metrics;
  }

  getAllMetrics(): SourceMetricsWithId[] {
    const records = this.healthManager.getAllHealthRecords();
    return records.map((record: EnhancedHealthRecord): SourceMetricsWithId => {
      const successRate = record.requestCount > 0 ? record.successCount / record.requestCount : 0;
      const metrics: SourceMetricsWithId = {
        sourceId: record.sourceId,
        sourceName: record.sourceName,
        score: record.score,
        successRate: successRate,
        avgResponseTime: record.avgResponseTime,
        isBlacklisted: this.isBlacklisted(record.sourceId)
      };
      return metrics;
    });
  }

  getHealthySourceCount(): number {
    const records = this.healthManager.getAllHealthRecords();
    return records.filter(r => r.score >= this.config.minHealthScore && r.isEnabled).length;
  }
}

export const smartSourceSelector = SmartSourceSelector.getInstance();
