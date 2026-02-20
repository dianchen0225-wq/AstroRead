import { Logger } from './Logger';

export interface ThrottleConfig {
  maxRequestsPerSecond: number;
  maxConcurrentRequests: number;
  minInterval: number;
  maxInterval: number;
  burstSize: number;
  adaptiveMode: boolean;
  backoffOnBlock: boolean;
  maxBackoffMultiplier: number;
}

export interface DomainStats {
  requestCount: number;
  successCount: number;
  failureCount: number;
  blockCount: number;
  lastRequestTime: number;
  avgResponseTime: number;
  currentDelay: number;
  backoffLevel: number;
}

export interface ThrottleResult {
  allowed: boolean;
  waitTime: number;
  reason: string;
}

interface QueueItem {
  domain: string;
  timestamp: number;
  resolve: (value: void) => void;
}

const DEFAULT_THROTTLE_CONFIG: ThrottleConfig = {
  maxRequestsPerSecond: 3,
  maxConcurrentRequests: 5,
  minInterval: 200,
  maxInterval: 10000,
  burstSize: 5,
  adaptiveMode: true,
  backoffOnBlock: true,
  maxBackoffMultiplier: 10
};

export class RequestThrottler {
  private static instance: RequestThrottler | null = null;
  private config: ThrottleConfig;
  private domainStats: Map<string, DomainStats> = new Map();
  private activeRequests: Map<string, number> = new Map();
  private requestTimestamps: Map<string, number[]> = new Map();
  private readonly TAG = 'RequestThrottler';

  private constructor(config?: Partial<ThrottleConfig>) {
    this.config = this.mergeConfig(DEFAULT_THROTTLE_CONFIG, config);
  }

  static getInstance(config?: Partial<ThrottleConfig>): RequestThrottler {
    if (!RequestThrottler.instance) {
      RequestThrottler.instance = new RequestThrottler(config);
    }
    return RequestThrottler.instance;
  }

  private mergeConfig(base: ThrottleConfig, update?: Partial<ThrottleConfig>): ThrottleConfig {
    if (!update) return base;
    return {
      maxRequestsPerSecond: update.maxRequestsPerSecond !== undefined ? update.maxRequestsPerSecond : base.maxRequestsPerSecond,
      maxConcurrentRequests: update.maxConcurrentRequests !== undefined ? update.maxConcurrentRequests : base.maxConcurrentRequests,
      minInterval: update.minInterval !== undefined ? update.minInterval : base.minInterval,
      maxInterval: update.maxInterval !== undefined ? update.maxInterval : base.maxInterval,
      burstSize: update.burstSize !== undefined ? update.burstSize : base.burstSize,
      adaptiveMode: update.adaptiveMode !== undefined ? update.adaptiveMode : base.adaptiveMode,
      backoffOnBlock: update.backoffOnBlock !== undefined ? update.backoffOnBlock : base.backoffOnBlock,
      maxBackoffMultiplier: update.maxBackoffMultiplier !== undefined ? update.maxBackoffMultiplier : base.maxBackoffMultiplier
    };
  }

  private cloneConfig(config: ThrottleConfig): ThrottleConfig {
    return {
      maxRequestsPerSecond: config.maxRequestsPerSecond,
      maxConcurrentRequests: config.maxConcurrentRequests,
      minInterval: config.minInterval,
      maxInterval: config.maxInterval,
      burstSize: config.burstSize,
      adaptiveMode: config.adaptiveMode,
      backoffOnBlock: config.backoffOnBlock,
      maxBackoffMultiplier: config.maxBackoffMultiplier
    };
  }

  updateConfig(config: Partial<ThrottleConfig>): void {
    this.config = this.mergeConfig(this.config, config);
    Logger.info(this.TAG, '限流配置已更新');
  }

  getConfig(): ThrottleConfig {
    return this.cloneConfig(this.config);
  }

  private extractDomain(url: string): string {
    try {
      const match = url.match(/^https?:\/\/([^/:]+)/);
      return match ? match[1].toLowerCase() : url;
    } catch {
      return url;
    }
  }

  private getDomainStats(domain: string): DomainStats {
    let stats = this.domainStats.get(domain);
    if (!stats) {
      stats = {
        requestCount: 0,
        successCount: 0,
        failureCount: 0,
        blockCount: 0,
        lastRequestTime: 0,
        avgResponseTime: 0,
        currentDelay: this.config.minInterval,
        backoffLevel: 0
      };
      this.domainStats.set(domain, stats);
    }
    return stats;
  }

  private getRecentRequestCount(domain: string, windowMs: number = 1000): number {
    const timestamps = this.requestTimestamps.get(domain) || [];
    const now = Date.now();
    return timestamps.filter(t => now - t < windowMs).length;
  }

  private cleanupOldTimestamps(domain: string): void {
    const timestamps = this.requestTimestamps.get(domain);
    if (timestamps) {
      const now = Date.now();
      const recent = timestamps.filter(t => now - t < 60000);
      this.requestTimestamps.set(domain, recent);
    }
  }

  checkThrottle(url: string): ThrottleResult {
    const domain = this.extractDomain(url);
    const stats = this.getDomainStats(domain);
    const now = Date.now();

    this.cleanupOldTimestamps(domain);

    const activeCount = this.activeRequests.get(domain) || 0;
    if (activeCount >= this.config.maxConcurrentRequests) {
      return {
        allowed: false,
        waitTime: 100,
        reason: `并发请求数已达上限 (${activeCount}/${this.config.maxConcurrentRequests})`
      };
    }

    const recentRequests = this.getRecentRequestCount(domain);
    if (recentRequests >= this.config.burstSize) {
      const timestamps = this.requestTimestamps.get(domain) || [];
      const firstTimestamp = timestamps.length > 0 ? timestamps[0] : now;
      const waitTime = Math.max(100, 1000 - (now - firstTimestamp));
      return {
        allowed: false,
        waitTime,
        reason: `突发请求已达上限 (${recentRequests}/${this.config.burstSize})`
      };
    }

    const elapsed = now - stats.lastRequestTime;
    const requiredDelay = this.calculateRequiredDelay(domain, stats);

    if (elapsed < requiredDelay) {
      return {
        allowed: false,
        waitTime: requiredDelay - elapsed,
        reason: `请求间隔不足 (需要 ${requiredDelay}ms，已过 ${elapsed}ms)`
      };
    }

    return {
      allowed: true,
      waitTime: 0,
      reason: '允许请求'
    };
  }

  private calculateRequiredDelay(domain: string, stats: DomainStats): number {
    let delay = stats.currentDelay;

    if (this.config.adaptiveMode) {
      const successRate = stats.requestCount > 0
        ? stats.successCount / stats.requestCount
        : 1;

      if (successRate < 0.5) {
        delay = Math.min(delay * 1.5, this.config.maxInterval);
      } else if (successRate > 0.9 && stats.backoffLevel > 0) {
        delay = Math.max(delay / 1.2, this.config.minInterval);
      }

      if (stats.avgResponseTime > 2000) {
        delay = Math.min(delay * 1.2, this.config.maxInterval);
      }
    }

    if (this.config.backoffOnBlock && stats.blockCount > 0) {
      const backoffMultiplier = Math.min(
        Math.pow(2, stats.backoffLevel),
        this.config.maxBackoffMultiplier
      );
      delay = Math.min(delay * backoffMultiplier, this.config.maxInterval);
    }

    return delay;
  }

  async acquire(url: string): Promise<void> {
    const domain = this.extractDomain(url);

    while (true) {
      const result = this.checkThrottle(url);

      if (result.allowed) {
        this.recordRequestStart(domain);
        return;
      }

      Logger.debug(this.TAG, `限流等待: ${domain} - ${result.reason} (等待 ${result.waitTime}ms)`);
      await this.sleep(result.waitTime);
    }
  }

  release(url: string): void {
    const domain = this.extractDomain(url);
    const current = this.activeRequests.get(domain) || 0;
    this.activeRequests.set(domain, Math.max(0, current - 1));
  }

  recordRequestStart(domain: string): void {
    const stats = this.getDomainStats(domain);
    stats.lastRequestTime = Date.now();
    stats.requestCount++;

    const current = this.activeRequests.get(domain) || 0;
    this.activeRequests.set(domain, current + 1);

    const timestamps = this.requestTimestamps.get(domain) || [];
    timestamps.push(Date.now());
    this.requestTimestamps.set(domain, timestamps);
  }

  recordSuccess(url: string, responseTime: number): void {
    const domain = this.extractDomain(url);
    const stats = this.getDomainStats(domain);

    stats.successCount++;
    stats.avgResponseTime = stats.successCount > 1
      ? (stats.avgResponseTime * (stats.successCount - 1) + responseTime) / stats.successCount
      : responseTime;

    if (stats.backoffLevel > 0) {
      stats.backoffLevel = Math.max(0, stats.backoffLevel - 1);
    }

    stats.currentDelay = Math.max(
      this.config.minInterval,
      stats.currentDelay * 0.9
    );

    Logger.debug(this.TAG, `请求成功: ${domain} - 响应时间 ${responseTime}ms`);
  }

  recordFailure(url: string, error: string): void {
    const domain = this.extractDomain(url);
    const stats = this.getDomainStats(domain);

    stats.failureCount++;

    if (this.config.adaptiveMode) {
      stats.currentDelay = Math.min(
        stats.currentDelay * 1.3,
        this.config.maxInterval
      );
    }

    Logger.warn(this.TAG, `请求失败: ${domain} - ${error}`);
  }

  recordBlock(url: string): void {
    const domain = this.extractDomain(url);
    const stats = this.getDomainStats(domain);

    stats.blockCount++;
    stats.backoffLevel++;

    if (this.config.backoffOnBlock) {
      const backoffMultiplier = Math.min(
        Math.pow(2, stats.backoffLevel),
        this.config.maxBackoffMultiplier
      );
      stats.currentDelay = Math.min(
        this.config.minInterval * backoffMultiplier,
        this.config.maxInterval
      );
    }

    Logger.warn(this.TAG, `检测到阻止: ${domain} - 退避级别 ${stats.backoffLevel}`);
  }

  getDomainStatsForUrl(url: string): DomainStats | null {
    const domain = this.extractDomain(url);
    return this.domainStats.get(domain) || null;
  }

  getAllDomainStats(): Map<string, DomainStats> {
    const result = new Map<string, DomainStats>();
    this.domainStats.forEach((value, key) => {
      result.set(key, Object.assign({}, value));
    });
    return result;
  }

  resetDomainStats(url: string): void {
    const domain = this.extractDomain(url);
    this.domainStats.delete(domain);
    this.requestTimestamps.delete(domain);
    this.activeRequests.delete(domain);
    Logger.info(this.TAG, `已重置域名统计: ${domain}`);
  }

  resetAllStats(): void {
    this.domainStats.clear();
    this.requestTimestamps.clear();
    this.activeRequests.clear();
    Logger.info(this.TAG, '已重置所有限流统计');
  }

  generateReport(): string {
    let report = '请求限流报告\n';
    report += '============\n\n';

    const domains = Array.from(this.domainStats.entries());
    if (domains.length === 0) {
      report += '暂无统计数据\n';
      return report;
    }

    for (let i = 0; i < domains.length; i++) {
      const domain = domains[i][0];
      const stats = domains[i][1];
      const successRate = stats.requestCount > 0
        ? ((stats.successCount / stats.requestCount) * 100).toFixed(1)
        : '0.0';

      report += `域名: ${domain}\n`;
      report += `  总请求: ${stats.requestCount}\n`;
      report += `  成功率: ${successRate}%\n`;
      report += `  被阻止: ${stats.blockCount} 次\n`;
      report += `  平均响应: ${stats.avgResponseTime.toFixed(0)}ms\n`;
      report += `  当前延迟: ${stats.currentDelay.toFixed(0)}ms\n`;
      report += `  退避级别: ${stats.backoffLevel}\n\n`;
    }

    return report;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export default RequestThrottler.getInstance();