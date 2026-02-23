/**
 * SourceHealthManager - 书源健康度管理器
 * 用于追踪书源的成功率、响应时间，自动调整书源优先级
 */

import { Logger } from "../performance/Logger";

export interface SourceHealthRecord {
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
}

export interface HealthStatistics {
  total: number;
  enabled: number;
  disabled: number;
  avgScore: number;
}

export interface HealthCheckResult {
  sourceId: string;
  isHealthy: boolean;
  score: number;
  errorType?: string;
  errorMessage?: string;
  responseTime?: number;
}

const STORAGE_KEY = 'source_health_records';
const MAX_CONSECUTIVE_FAILURES = 3;
const HEALTH_CHECK_INTERVAL = 24 * 60 * 60 * 1000;
const MIN_SCORE = 0;
const MAX_SCORE = 100;
const INITIAL_SCORE = 50;

export class SourceHealthManager {
  private static instance: SourceHealthManager | null = null;
  private healthRecords: Map<string, SourceHealthRecord> = new Map();
  private readonly TAG = 'SourceHealthManager';

  private constructor() {
    this.loadRecords();
  }

  static getInstance(): SourceHealthManager {
    if (!SourceHealthManager.instance) {
      SourceHealthManager.instance = new SourceHealthManager();
    }
    return SourceHealthManager.instance;
  }

  private loadRecords(): void {
    // TODO: 从持久化存储加载
    Logger.debug(this.TAG, '加载书源健康记录');
  }

  private saveRecords(): void {
    // TODO: 持久化存储
  }

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
    
    record.totalResponseTime += responseTime;
    record.requestCount++;
    record.avgResponseTime = record.totalResponseTime / record.requestCount;
    
    this.updateScore(record);
    this.saveRecords();
    
    Logger.debug(this.TAG, `书源成功: ${sourceName}, 响应时间: ${responseTime}ms, 分数: ${record.score}`);
  }

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
    
    if (record.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
      record.isEnabled = false;
      Logger.warn(this.TAG, `书源已自动禁用: ${sourceName}, 连续失败次数: ${record.consecutiveFailures}`);
    }
    
    this.updateScore(record);
    this.saveRecords();
    
    Logger.debug(this.TAG, `书源失败: ${sourceName}, 错误: ${errorType}, 分数: ${record.score}`);
  }

  private createRecord(sourceId: string, sourceName: string, sourceUrl: string): SourceHealthRecord {
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
      lastCheckTime: Date.now()
    };
  }

  private updateScore(record: SourceHealthRecord): void {
    const totalRequests = record.successCount + record.failureCount;
    
    if (totalRequests === 0) {
      record.score = INITIAL_SCORE;
      return;
    }
    
    const successRate = record.successCount / totalRequests;
    let score = successRate * 70;
    
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
    
    if (record.consecutiveFailures > 0) {
      score -= record.consecutiveFailures * 10;
    }
    
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

  getHealthRecord(sourceId: string): SourceHealthRecord | undefined {
    return this.healthRecords.get(sourceId);
  }

  getAllHealthRecords(): SourceHealthRecord[] {
    const records = Array.from(this.healthRecords.values());
    return records.sort((a: SourceHealthRecord, b: SourceHealthRecord) => b.score - a.score);
  }

  getEnabledSources(): SourceHealthRecord[] {
    return this.getAllHealthRecords().filter((r: SourceHealthRecord) => r.isEnabled);
  }

  getTopSources(count: number = 10): SourceHealthRecord[] {
    return this.getEnabledSources().slice(0, count);
  }

  isSourceEnabled(sourceId: string): boolean {
    const record = this.healthRecords.get(sourceId);
    return record ? record.isEnabled : true;
  }

  getSourceScore(sourceId: string): number {
    const record = this.healthRecords.get(sourceId);
    return record ? record.score : INITIAL_SCORE;
  }

  enableSource(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record) {
      record.isEnabled = true;
      record.consecutiveFailures = 0;
      this.saveRecords();
    }
  }

  disableSource(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record) {
      record.isEnabled = false;
      this.saveRecords();
    }
  }

  resetSource(sourceId: string): void {
    const record = this.healthRecords.get(sourceId);
    if (record) {
      record.successCount = 0;
      record.failureCount = 0;
      record.consecutiveFailures = 0;
      record.score = INITIAL_SCORE;
      record.isEnabled = true;
      record.lastErrorType = '';
      record.lastErrorMessage = '';
      this.saveRecords();
    }
  }

  clearAllRecords(): void {
    this.healthRecords.clear();
    this.saveRecords();
    Logger.info(this.TAG, '所有书源健康记录已清空');
  }

  getStatistics(): HealthStatistics {
    const records = this.getAllHealthRecords();
    const enabled = records.filter((r: SourceHealthRecord) => r.isEnabled);
    const avgScore = records.length > 0
      ? records.reduce((sum: number, r: SourceHealthRecord) => sum + r.score, 0) / records.length
      : 0;
    
    const result: HealthStatistics = {
      total: records.length,
      enabled: enabled.length,
      disabled: records.length - enabled.length,
      avgScore: Math.round(avgScore)
    };
    return result;
  }

  getSourceStats(sourceId: string): SourceHealthRecord | null {
    const record = this.healthRecords.get(sourceId);
    return record !== undefined ? record : null;
  }
}

export const sourceHealthManager = SourceHealthManager.getInstance();
