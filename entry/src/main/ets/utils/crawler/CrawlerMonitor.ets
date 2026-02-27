import { Logger } from "../performance/Logger";

export interface CrawlerLogEntry {
  timestamp: number;
  level: 'debug' | 'info' | 'warn' | 'error';
  category: string;
  message: string;
  url?: string;
  domain?: string;
  duration?: number;
  statusCode?: number;
  error?: string;
  metadata?: Record<string, string | number | boolean>;
}

export interface CrawlerSession {
  sessionId: string;
  startTime: number;
  endTime?: number;
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  blockedRequests: number;
  captchaEncountered: number;
  totalBytes: number;
  avgResponseTime: number;
  sourcesUsed: string[];
  errors: CrawlerLogEntry[];
}

export interface CrawlerStatistics {
  totalSessions: number;
  totalRequests: number;
  successRate: number;
  avgResponseTime: number;
  blockedRate: number;
  captchaRate: number;
  topDomains: Array<{ domain: string; count: number }>;
  errorDistribution: Map<string, number>;
  hourlyDistribution: Map<number, number>;
}

export interface AlertConfig {
  enableAlerts: boolean;
  blockRateThreshold: number;
  errorRateThreshold: number;
  responseTimeThreshold: number;
  consecutiveFailureThreshold: number;
}

type AlertCallback = (alert: CrawlerAlert) => void;

export interface CrawlerAlert {
  type: 'block' | 'error' | 'slow' | 'captcha' | 'failure';
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  domain?: string;
  url?: string;
  timestamp: number;
  metadata?: Record<string, string | number | boolean>;
}

const DEFAULT_ALERT_CONFIG: AlertConfig = {
  enableAlerts: true,
  blockRateThreshold: 0.1,
  errorRateThreshold: 0.3,
  responseTimeThreshold: 10000,
  consecutiveFailureThreshold: 5
};

const MAX_LOG_ENTRIES = 1000;
const MAX_SESSIONS = 100;

export class CrawlerMonitor {
  private static instance: CrawlerMonitor | null = null;
  private logs: CrawlerLogEntry[] = [];
  private sessions: CrawlerSession[] = [];
  private currentSession: CrawlerSession | null = null;
  private alertConfig: AlertConfig;
  private alertCallbacks: AlertCallback[] = [];
  private consecutiveFailures: Map<string, number> = new Map();
  private readonly TAG = 'CrawlerMonitor';

  private constructor() {
    this.alertConfig = DEFAULT_ALERT_CONFIG;
  }

  static getInstance(): CrawlerMonitor {
    if (!CrawlerMonitor.instance) {
      CrawlerMonitor.instance = new CrawlerMonitor();
    }
    return CrawlerMonitor.instance;
  }

  setAlertConfig(config: Partial<AlertConfig>): void {
    this.alertConfig = { ...this.alertConfig, ...config };
  }

  registerAlertCallback(callback: AlertCallback): void {
    this.alertCallbacks.push(callback);
  }

  startSession(): string {
    const sessionId = this.generateSessionId();
    this.currentSession = {
      sessionId,
      startTime: Date.now(),
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      blockedRequests: 0,
      captchaEncountered: 0,
      totalBytes: 0,
      avgResponseTime: 0,
      sourcesUsed: [],
      errors: []
    };
    this.log('info', 'session', `开始爬虫会话: ${sessionId}`);
    return sessionId;
  }

  endSession(): CrawlerSession | null {
    if (!this.currentSession) {
      return null;
    }

    this.currentSession.endTime = Date.now();
    const session = { ...this.currentSession };

    this.sessions.unshift(session);
    if (this.sessions.length > MAX_SESSIONS) {
      this.sessions = this.sessions.slice(0, MAX_SESSIONS);
    }

    this.log('info', 'session', `结束爬虫会话: ${session.sessionId}`, undefined, undefined, session.endTime - session.startTime);
    this.currentSession = null;

    return session;
  }

  log(
    level: CrawlerLogEntry['level'],
    category: string,
    message: string,
    url?: string,
    metadata?: Record<string, string | number | boolean>,
    duration?: number
  ): void {
    const entry: CrawlerLogEntry = {
      timestamp: Date.now(),
      level,
      category,
      message,
      url,
      domain: url ? this.extractDomain(url) : undefined,
      duration,
      metadata
    };

    this.logs.unshift(entry);
    if (this.logs.length > MAX_LOG_ENTRIES) {
      this.logs = this.logs.slice(0, MAX_LOG_ENTRIES);
    }

    if (this.currentSession && category === 'request') {
      this.currentSession.totalRequests++;
      if (level === 'error') {
        this.currentSession.failedRequests++;
        this.currentSession.errors.push(entry);
      } else if (level === 'info') {
        this.currentSession.successfulRequests++;
      }
      if (duration) {
        const totalTime = this.currentSession.avgResponseTime * (this.currentSession.totalRequests - 1) + duration;
        this.currentSession.avgResponseTime = totalTime / this.currentSession.totalRequests;
      }
    }

    const logMessage = url ? `[${category}] ${message} - ${url}` : `[${category}] ${message}`;
    switch (level) {
      case 'debug':
        Logger.debug(this.TAG, logMessage);
        break;
      case 'info':
        Logger.info(this.TAG, logMessage);
        break;
      case 'warn':
        Logger.warn(this.TAG, logMessage);
        break;
      case 'error':
        Logger.error(this.TAG, logMessage);
        break;
    }
  }

  logRequest(url: string, statusCode: number, duration: number, success: boolean, bytes?: number): void {
    const level = success ? 'info' : 'warn';
    const message = success ? `请求成功 (${statusCode})` : `请求失败 (${statusCode})`;

    this.log(level, 'request', message, url, { statusCode, bytes }, duration);

    if (this.currentSession && bytes) {
      this.currentSession.totalBytes += bytes;
    }

    if (!success) {
      const domain = this.extractDomain(url);
      const failures = (this.consecutiveFailures.get(domain) || 0) + 1;
      this.consecutiveFailures.set(domain, failures);

      if (failures >= this.alertConfig.consecutiveFailureThreshold) {
        this.triggerAlert({
          type: 'failure',
          severity: failures >= this.alertConfig.consecutiveFailureThreshold * 2 ? 'critical' : 'high',
          message: `域名 ${domain} 连续失败 ${failures} 次`,
          domain,
          url,
          timestamp: Date.now()
        });
      }
    } else {
      const domain = this.extractDomain(url);
      this.consecutiveFailures.delete(domain);
    }

    if (duration > this.alertConfig.responseTimeThreshold) {
      this.triggerAlert({
        type: 'slow',
        severity: 'low',
        message: `响应时间过长: ${duration}ms`,
        url,
        timestamp: Date.now(),
        metadata: { duration }
      });
    }
  }

  logBlock(url: string, reason: string): void {
    this.log('warn', 'block', `检测到阻止: ${reason}`, url);

    if (this.currentSession) {
      this.currentSession.blockedRequests++;
    }

    this.triggerAlert({
      type: 'block',
      severity: 'high',
      message: `请求被阻止: ${reason}`,
      url,
      domain: this.extractDomain(url),
      timestamp: Date.now()
    });
  }

  logCaptcha(url: string, type?: string): void {
    this.log('warn', 'captcha', `检测到验证码: ${type || '未知类型'}`, url);

    if (this.currentSession) {
      this.currentSession.captchaEncountered++;
    }

    this.triggerAlert({
      type: 'captcha',
      severity: 'medium',
      message: `遇到验证码: ${type || '未知类型'}`,
      url,
      domain: this.extractDomain(url),
      timestamp: Date.now()
    });
  }

  logError(url: string, error: string, metadata?: Record<string, string | number | boolean>): void {
    this.log('error', 'error', error, url, metadata);

    this.triggerAlert({
      type: 'error',
      severity: 'medium',
      message: error,
      url,
      domain: url ? this.extractDomain(url) : undefined,
      timestamp: Date.now(),
      metadata
    });
  }

  private triggerAlert(alert: CrawlerAlert): void {
    if (!this.alertConfig.enableAlerts) {
      return;
    }

    for (const callback of this.alertCallbacks) {
      try {
        callback(alert);
      } catch (e) {
        Logger.error(this.TAG, `告警回调执行失败: ${e}`);
      }
    }
  }

  getLogs(count: number = 100, level?: CrawlerLogEntry['level'], category?: string): CrawlerLogEntry[] {
    let filtered = this.logs;

    if (level) {
      filtered = filtered.filter(log => log.level === level);
    }

    if (category) {
      filtered = filtered.filter(log => log.category === category);
    }

    return filtered.slice(0, Math.min(count, filtered.length));
  }

  getSession(sessionId: string): CrawlerSession | null {
    return this.sessions.find(s => s.sessionId === sessionId) || null;
  }

  getRecentSessions(count: number = 10): CrawlerSession[] {
    return this.sessions.slice(0, Math.min(count, this.sessions.length));
  }

  getStatistics(hours: number = 24): CrawlerStatistics {
    const cutoff = Date.now() - hours * 60 * 60 * 1000;
    const recentLogs = this.logs.filter(log => log.timestamp >= cutoff);

    const totalRequests = recentLogs.filter(log => log.category === 'request').length;
    const successfulRequests = recentLogs.filter(
      log => log.category === 'request' && log.level === 'info'
    ).length;
    const blockedRequests = recentLogs.filter(log => log.category === 'block').length;
    const captchaCount = recentLogs.filter(log => log.category === 'captcha').length;

    const domainCounts: Map<string, number> = new Map();
    for (const log of recentLogs) {
      if (log.domain) {
        domainCounts.set(log.domain, (domainCounts.get(log.domain) || 0) + 1);
      }
    }
    const topDomains = Array.from(domainCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([domain, count]) => ({ domain, count }));

    const errorDistribution: Map<string, number> = new Map();
    for (const log of recentLogs) {
      if (log.level === 'error' && log.message) {
        const errorType = log.message.substring(0, 50);
        errorDistribution.set(errorType, (errorDistribution.get(errorType) || 0) + 1);
      }
    }

    const hourlyDistribution: Map<number, number> = new Map();
    for (const log of recentLogs) {
      const hour = new Date(log.timestamp).getHours();
      hourlyDistribution.set(hour, (hourlyDistribution.get(hour) || 0) + 1);
    }

    const responseTimes = recentLogs
      .filter(log => log.duration !== undefined)
      .map(log => log.duration!);
    const avgResponseTime = responseTimes.length > 0
      ? responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length
      : 0;

    return {
      totalSessions: this.sessions.filter(s => s.startTime >= cutoff).length,
      totalRequests,
      successRate: totalRequests > 0 ? successfulRequests / totalRequests : 0,
      avgResponseTime,
      blockedRate: totalRequests > 0 ? blockedRequests / totalRequests : 0,
      captchaRate: totalRequests > 0 ? captchaCount / totalRequests : 0,
      topDomains,
      errorDistribution,
      hourlyDistribution
    };
  }

  generateReport(hours: number = 24): string {
    const stats = this.getStatistics(hours);
    const recentSessions = this.getRecentSessions(5);

    let report = `
爬虫监控报告
============
统计周期: 最近 ${hours} 小时

总体统计
--------
总会话数: ${stats.totalSessions}
总请求数: ${stats.totalRequests}
成功率: ${(stats.successRate * 100).toFixed(1)}%
平均响应时间: ${stats.avgResponseTime.toFixed(0)}ms
被阻止率: ${(stats.blockedRate * 100).toFixed(1)}%
验证码率: ${(stats.captchaRate * 100).toFixed(1)}%

热门域名
--------
`;

    for (const { domain, count } of stats.topDomains) {
      report += `  ${domain}: ${count} 次\n`;
    }

    if (stats.errorDistribution.size > 0) {
      report += '\n错误分布\n--------\n';
      const sortedErrors = Array.from(stats.errorDistribution.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);
      for (const entry of sortedErrors) {
        const error = entry[0];
        const count = entry[1];
        report += `  ${error}: ${count} 次\n`;
      }
    }

    if (recentSessions.length > 0) {
      report += '\n最近会话\n--------\n';
      for (const session of recentSessions) {
        const duration = session.endTime ? session.endTime - session.startTime : 0;
        report += `  ${session.sessionId}: ${session.totalRequests} 请求, ${(session.successfulRequests / session.totalRequests * 100).toFixed(0)}% 成功, ${(duration / 1000).toFixed(0)}s\n`;
      }
    }

    return report;
  }

  clearLogs(): void {
    this.logs = [];
    Logger.info(this.TAG, '日志已清空');
  }

  clearSessions(): void {
    this.sessions = [];
    Logger.info(this.TAG, '会话记录已清空');
  }

  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  }

  private extractDomain(url: string): string {
    try {
      const match = url.match(/^https?:\/\/([^/:]+)/);
      return match ? match[1].toLowerCase() : url;
    } catch {
      return url;
    }
  }
}

export default CrawlerMonitor.getInstance();
