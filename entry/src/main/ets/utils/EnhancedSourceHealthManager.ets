/**
 * EnhancedSourceHealthManager - 增强版书源健康度管理器
 * 提供更智能的书源健康度评估和自动禁用功能
 */

import { Logger } from './Logger';

export interface EnhancedHealthRecord {
  sourceId: string;
  sourceName: string;
  sourceUrl: string;

  successCount: number;
  failureCount: number;
  lastSuccessTime: number;
  lastFailureTime: number;
  lastErrorType: string;
  lastErrorMessage: string;

  avgResponseTime: number;
  totalResponseTime: number;
  requestCount: number;

  score: number;
  isEnabled: boolean;
  consecutiveFailures: number;

  lastCheckTime: number;
  isPermanentlyDisabled: boolean; // 是否永久禁用
  disabledReason: string; // 禁用原因
}

export interface HealthStatistics {
  total: number;
  enabled: number;
  disabled: number;
  permanentlyDisabled: number;
  avgScore: number;
}

const STORAGE_KEY = 'enhanced_source_health_records';
const MAX_CONSECUTIVE_FAILURES = 3;
const MIN_SCORE = 0;
const MAX_SCORE = 100;
const INITIAL_SCORE = 50;

// 永久性错误类型(不重试,直接禁用)
const PERMANENT_ERROR_TYPES: string[] = ['dns', 'ssl'];
// 临时性错误类型(可重试)
const TEMPORARY_ERROR_TYPES: string[] = ['timeout', 'http', 'network'];

export class EnhancedSourceHealthManager {
  private static instance: EnhancedSourceHealthManager | null = null;
  private healthRecords: Map<string, EnhancedHealthRecord> = new Map();
  private readonly TAG = 'EnhancedSourceHealthManager';

  private constructor() {
    this.loadRecords();
  }

  static getInstance(): EnhancedSourceHealthManager {
    if (!EnhancedSourceHealthManager.instance) {
      EnhancedSourceHealthManager.instance = new EnhancedSourceHealthManager();
    }
    return EnhancedSourceHealthManager.instance;
  }

  private loadRecords(): void {
    Logger.debug(this.TAG, '加载增强版书源健康记录');
  }

  private saveRecords(): void {
    // TODO: 持久化存储
  }

  /**
   * 重置指定书源的健康度记录
   */
  resetRecord(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record) {
      record.successCount = 0;
      record.failureCount = 0;
      record.lastSuccessTime = 0;
      record.lastFailureTime = 0;
      record.lastErrorType = '';
      record.lastErrorMessage = '';
      record.avgResponseTime = 0;
      record.totalResponseTime = 0;
      record.requestCount = 0;
      record.score = INITIAL_SCORE;
      record.isEnabled = true;
      record.consecutiveFailures = 0;
      record.isPermanentlyDisabled = false;
      record.disabledReason = '';
      record.lastCheckTime = Date.now();
      
      Logger.info(this.TAG, `已重置书源 ${sourceId} 的健康度记录`);
      this.saveRecords();
    }
  }

  /**
   * 重置所有书源的健康度记录
   */
  resetAllRecords(): void {
    this.healthRecords.clear();
    Logger.info(this.TAG, '已重置所有书源的健康度记录');
    this.saveRecords();
  }

  /**
   * 删除指定书源的健康度记录（用于书源被删除时）
   */
  removeRecord(sourceId: string): void {
    if (this.healthRecords.has(sourceId)) {
      this.healthRecords.delete(sourceId);
      Logger.info(this.TAG, `已删除书源 ${sourceId} 的健康度记录`);
      this.saveRecords();
    }
  }

  /**
   * 批量删除书源的健康度记录
   */
  removeRecords(sourceIds: string[]): void {
    let removedCount = 0;
    for (const id of sourceIds) {
      if (this.healthRecords.has(id)) {
        this.healthRecords.delete(id);
        removedCount++;
      }
    }
    if (removedCount > 0) {
      Logger.info(this.TAG, `已批量删除 ${removedCount} 个书源的健康度记录`);
      this.saveRecords();
    }
  }

  /**
   * 获取健康度记录
   */
  getRecord(sourceId: string): EnhancedHealthRecord | undefined {
    return this.healthRecords.get(sourceId);
  }

  /**
   * 获取所有健康度记录
   */
  getAllRecords(): EnhancedHealthRecord[] {
    return Array.from(this.healthRecords.values());
  }

  /**
   * 启用书源
   */
  enableSource(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record) {
      record.isEnabled = true;
      record.isPermanentlyDisabled = false;
      record.disabledReason = '';
      record.consecutiveFailures = 0;
      Logger.info(this.TAG, `已启用书源 ${sourceId}`);
      this.saveRecords();
    }
  }

  /**
   * 初始化书源记录（如果不存在）
   */
  initializeSourceIfNeeded(sourceId: string, sourceName: string, sourceUrl: string, isEnabled: boolean = true): void {
    let record = this.healthRecords.get(sourceId);

    if (!record) {
      record = this.createRecord(sourceId, sourceName, sourceUrl);
      record.isEnabled = isEnabled;
      this.healthRecords.set(sourceId, record);
      Logger.debug(this.TAG, `初始化书源记录: ${sourceName}, enabled=${isEnabled}`);
    }
  }

  /**
   * 记录成功
   */
  recordSuccess(sourceId: string, sourceName: string, sourceUrl: string, responseTime: number): void {
    let record = this.healthRecords.get(sourceId);

    if (!record) {
      record = this.createRecord(sourceId, sourceName, sourceUrl);
      this.healthRecords.set(sourceId, record);
    }

    record.successCount++;
    record.lastSuccessTime = Date.now();
    record.consecutiveFailures = 0;
    record.isEnabled = true;
    record.isPermanentlyDisabled = false;
    record.disabledReason = '';

    record.totalResponseTime += responseTime;
    record.requestCount++;
    record.avgResponseTime = record.totalResponseTime / record.requestCount;

    this.updateScore(record);
    this.saveRecords();

    Logger.debug(this.TAG, `书源成功: ${sourceName}, 响应时间: ${responseTime}ms, 分数: ${record.score}`);
  }

  /**
   * 记录失败(增强版)
   */
  recordFailure(sourceId: string, sourceName: string, sourceUrl: string, errorType: string, errorMessage: string): void {
    let record = this.healthRecords.get(sourceId);

    if (!record) {
      record = this.createRecord(sourceId, sourceName, sourceUrl);
      this.healthRecords.set(sourceId, record);
    }

    record.failureCount++;
    record.lastFailureTime = Date.now();
    record.lastErrorType = errorType;
    record.lastErrorMessage = errorMessage;
    record.consecutiveFailures++;

    // 根据错误类型决定禁用策略
    if (PERMANENT_ERROR_TYPES.includes(errorType)) {
      // DNS和SSL错误直接永久禁用
      record.isEnabled = false;
      record.isPermanentlyDisabled = true;
      record.disabledReason = `永久性错误: ${errorType} - ${errorMessage}`;
      Logger.warn(this.TAG, `书源已永久禁用: ${sourceName}, 错误类型: ${errorType}, 原因: ${errorMessage}`);
    } else if (TEMPORARY_ERROR_TYPES.includes(errorType)) {
      // 临时性错误,连续失败3次后禁用
      if (record.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
        record.isEnabled = false;
        record.isPermanentlyDisabled = false;
        record.disabledReason = `连续失败${record.consecutiveFailures}次: ${errorType}`;
        Logger.warn(this.TAG, `书源已临时禁用: ${sourceName}, 连续失败次数: ${record.consecutiveFailures}`);
      }
    } else {
      // 未知错误,连续失败3次后禁用
      if (record.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
        record.isEnabled = false;
        record.isPermanentlyDisabled = false;
        record.disabledReason = `连续失败${record.consecutiveFailures}次: ${errorMessage}`;
        Logger.warn(this.TAG, `书源已禁用: ${sourceName}, 连续失败次数: ${record.consecutiveFailures}`);
      }
    }

    this.updateScore(record);
    this.saveRecords();

    Logger.debug(this.TAG, `书源失败: ${sourceName}, 错误: ${errorType}, 分数: ${record.score}`);
  }

  /**
   * 创建健康记录
   */
  private createRecord(sourceId: string, sourceName: string, sourceUrl: string): EnhancedHealthRecord {
    return {
      sourceId,
      sourceName,
      sourceUrl,
      successCount: 0,
      failureCount: 0,
      lastSuccessTime: 0,
      lastFailureTime: 0,
      lastErrorType: '',
      lastErrorMessage: '',
      avgResponseTime: 0,
      totalResponseTime: 0,
      requestCount: 0,
      score: INITIAL_SCORE,
      isEnabled: true,
      consecutiveFailures: 0,
      lastCheckTime: Date.now(),
      isPermanentlyDisabled: false,
      disabledReason: ''
    };
  }

  /**
   * 更新分数(增强版)
   */
  private updateScore(record: EnhancedHealthRecord): void {
    const totalRequests = record.successCount + record.failureCount;

    if (totalRequests === 0) {
      record.score = INITIAL_SCORE;
      return;
    }

    const successRate = record.successCount / totalRequests;
    let score = successRate * 70;

    // 响应时间加分
    if (record.avgResponseTime > 0) {
      if (record.avgResponseTime < 1000) {
        score += 20;
      } else if (record.avgResponseTime < 3000) {
        score += 15;
      } else if (record.avgResponseTime < 5000) {
        score += 10;
      } else if (record.avgResponseTime < 10000) {
        score += 5;
      }
    }

    // 连续失败扣分
    if (record.consecutiveFailures > 0) {
      score -= record.consecutiveFailures * 10;
    }

    // 永久禁用额外扣分
    if (record.isPermanentlyDisabled) {
      score -= 30;
    }

    // 最后成功时间扣分
    const daysSinceLastSuccess = record.lastSuccessTime > 0
      ? (Date.now() - record.lastSuccessTime) / (24 * 60 * 60 * 1000)
      : 30;

    if (daysSinceLastSuccess > 7) {
      score -= 10;
    } else if (daysSinceLastSuccess > 3) {
      score -= 5;
    }

    record.score = Math.max(MIN_SCORE, Math.min(MAX_SCORE, Math.round(score)));
  }

  /**
   * 获取健康记录
   */
  getHealthRecord(sourceId: string): EnhancedHealthRecord | undefined {
    return this.healthRecords.get(sourceId);
  }

  /**
   * 获取所有健康记录
   */
  getAllHealthRecords(): EnhancedHealthRecord[] {
    const records = Array.from(this.healthRecords.values());
    return records.sort((a, b) => b.score - a.score);
  }

  /**
   * 获取启用的书源
   */
  getEnabledSources(): EnhancedHealthRecord[] {
    return this.getAllHealthRecords().filter(r => r.isEnabled);
  }

  /**
   * 获取永久禁用的书源
   */
  getPermanentlyDisabledSources(): EnhancedHealthRecord[] {
    return this.getAllHealthRecords().filter(r => r.isPermanentlyDisabled);
  }

  /**
   * 检查书源是否启用
   */
  isSourceEnabled(sourceId: string): boolean {
    const record = this.healthRecords.get(sourceId);
    return record ? record.isEnabled : true;
  }

  /**
   * 检查书源是否永久禁用
   */
  isSourcePermanentlyDisabled(sourceId: string): boolean {
    const record = this.healthRecords.get(sourceId);
    return record ? record.isPermanentlyDisabled : false;
  }

  /**
   * 获取书源分数
   */
  getSourceScore(sourceId: string): number {
    const record = this.healthRecords.get(sourceId);
    return record ? record.score : INITIAL_SCORE;
  }


  /**
   * 重置书源(仅对非永久禁用的书源有效)
   */
  resetSource(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record && !record.isPermanentlyDisabled) {
      record.successCount = 0;
      record.failureCount = 0;
      record.consecutiveFailures = 0;
      record.score = INITIAL_SCORE;
      record.isEnabled = true;
      record.disabledReason = '';
      this.saveRecords();
    }
  }

  /**
   * 强制重置书源(包括永久禁用的)
   */
  forceResetSource(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record) {
      record.successCount = 0;
      record.failureCount = 0;
      record.consecutiveFailures = 0;
      record.score = INITIAL_SCORE;
      record.isEnabled = true;
      record.isPermanentlyDisabled = false;
      record.disabledReason = '';
      this.saveRecords();
    }
  }

  /**
   * 清空所有记录
   */
  clearAllRecords(): void {
    this.healthRecords.clear();
    this.saveRecords();
    Logger.info(this.TAG, '所有书源健康记录已清空');
  }

  /**
   * 获取统计信息
   */
  getStatistics(): HealthStatistics {
    const records = this.getAllHealthRecords();
    const enabled = records.filter(r => r.isEnabled);
    const permanentlyDisabled = records.filter(r => r.isPermanentlyDisabled);
    const avgScore = records.length > 0
      ? records.reduce((sum, r) => sum + r.score, 0) / records.length
      : 0;

    return {
      total: records.length,
      enabled: enabled.length,
      disabled: records.length - enabled.length,
      permanentlyDisabled: permanentlyDisabled.length,
      avgScore: Math.round(avgScore)
    };
  }

  /**
   * 生成健康报告
   */
  generateHealthReport(): string {
    const stats = this.getStatistics();
    const permanentlyDisabled = this.getPermanentlyDisabledSources();

    const report: string[] = [];
    report.push('=== 书源健康度报告 ===');
    report.push('');
    report.push(`总书源数: ${stats.total}`);
    report.push(`启用书源: ${stats.enabled}`);
    report.push(`禁用书源: ${stats.disabled}`);
    report.push(`永久禁用: ${stats.permanentlyDisabled}`);
    report.push(`平均分数: ${stats.avgScore}`);
    report.push('');

    if (permanentlyDisabled.length > 0) {
      report.push('永久禁用的书源:');
      for (const source of permanentlyDisabled) {
        report.push(`  - ${source.sourceName}: ${source.disabledReason}`);
      }
    }

    return report.join('\n');
  }
}

export const enhancedSourceHealthManager = EnhancedSourceHealthManager.getInstance();
