/**
 * MetricsCollector - 指标收集器
 * 负责收集和管理请求指标
 * 增强版：添加URL和请求体脱敏处理
 */

import { RequestMetrics } from './interfaces/IHttpClient';
import { Logger, LogLevel } from '../utils/Logger';
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
 * 敏感URL参数列表
 */
const SENSITIVE_URL_PARAMS: string[] = [
  'token', 'access_token', 'refresh_token', 'auth', 'key',
  'api_key', 'apikey', 'secret', 'session', 'session_id',
  'password', 'passwd', 'pwd', 'private_key', 'signature',
  'sign', 'code', 'authorization_code', 'state',
  'verify_code', 'verification_code', 'reset_token'
];

const MASK = '******';

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
   * 脱敏处理URL
   * 移除敏感查询参数的值
   */
  private sanitizeUrl(url: string): string {
    if (!url) return '';
    
    let sanitized = url;
    
    for (const param of SENSITIVE_URL_PARAMS) {
      // 匹配 ?param=value 或 &param=value 格式
      const patterns = [
        new RegExp(`([?&]${param}=)([^&\\s]+)`, 'gi'),
      ];
      
      for (const pattern of patterns) {
        sanitized = sanitized.replace(pattern, `$1${MASK}`);
      }
    }
    
    return sanitized;
  }

  /**
   * 记录日志
   * 增强版：使用脱敏后的URL
   */
  private logMetrics(metrics: RequestMetrics): void {
    // 脱敏处理URL
    const sanitizedUrl = this.sanitizeUrl(metrics.url || '');
    
    // 构建日志消息，不包含敏感信息
    const logMsg = `[${metrics.method}] ${sanitizedUrl} - ${metrics.success ? 'Success' : 'Failed'} - ${metrics.duration}ms`;
    
    // 错误信息也需要脱敏
    const sanitizedError = metrics.error ? this.sanitizeErrorMessage(metrics.error) : '';
    const fullLogMsg = sanitizedError ? `${logMsg} - Error: ${sanitizedError}` : logMsg;
    
    if (metrics.success) {
      Logger.info(this.tag, fullLogMsg);
    } else {
      Logger.error(this.tag, fullLogMsg);
    }
  }
  
  /**
   * 脱敏处理错误消息
   */
  private sanitizeErrorMessage(error: string): string {
    if (!error) return '';
    
    let sanitized = error;
    
    // 移除可能的敏感信息
    for (const param of SENSITIVE_URL_PARAMS) {
      const patterns = [
        new RegExp(`(${param}[=:]\\s*)[^\\s,;]+`, 'gi'),
        new RegExp(`"${param}"\\s*:\\s*"[^"]*"`, 'gi'),
        new RegExp(`'${param}'\\s*:\\s*'[^']*'`, 'gi'),
      ];
      
      for (const pattern of patterns) {
        sanitized = sanitized.replace(pattern, `$1${MASK}`);
      }
    }
    
    // 移除可能的token/密钥
    sanitized = sanitized.replace(/\beyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/g, '[JWT_TOKEN]');
    sanitized = sanitized.replace(/\b[A-Za-z0-9+/]{40,}={0,2}\b/g, '[BASE64_DATA]');
    
    return sanitized;
  }
}

export default MetricsCollector;
