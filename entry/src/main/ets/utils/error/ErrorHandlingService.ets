/**
 * ErrorHandlingService - 错误处理和降级服务
 * 提供统一的错误处理、降级策略和恢复机制
 */

import { Logger } from '../performance/Logger';
import { networkConfigManager, DegradationConfig } from '../network/NetworkConfig';
import { smartSourceSelector } from '../search/SmartSourceSelector';

/**
 * 错误类型
 */
export enum ErrorType {
  NETWORK = 'network',
  TIMEOUT = 'timeout',
  PARSE = 'parse',
  AUTH = 'auth',
  NOT_FOUND = 'not_found',
  SERVER = 'server',
  UNKNOWN = 'unknown'
}

/**
 * 错误严重程度
 */
export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

/**
 * 错误信息
 */
export interface ErrorInfo {
  id: string;
  type: ErrorType;
  severity: ErrorSeverity;
  message: string;
  details?: string;
  sourceId?: string;
  sourceName?: string;
  timestamp: number;
  recoverable: boolean;
  retryCount: number;
  maxRetries: number;
}

/**
 * 降级策略
 */
export enum DegradationStrategy {
  RETRY = 'retry',                    // 重试
  FALLBACK_SOURCE = 'fallback_source', // 切换书源
  CACHE = 'cache',                    // 使用缓存
  PARTIAL = 'partial',                // 部分降级
  DISABLE = 'disable',                // 禁用功能
  ABORT = 'abort'                     // 中止操作
}

/**
 * 降级结果
 */
export interface DegradationResult {
  success: boolean;
  strategy: DegradationStrategy;
  message: string;
  data?: string | number | boolean | object | null;
  shouldRetry: boolean;
  retryDelay?: number;
}

/**
 * 错误处理器
 */
export interface ErrorHandler {
  canHandle(error: Error): boolean;
  handle(error: Error, context?: ErrorContext): Promise<DegradationResult>;
}

class NetworkErrorHandler implements ErrorHandler {
  private service: ErrorHandlingService;

  constructor(service: ErrorHandlingService) {
    this.service = service;
  }

  canHandle(error: Error): boolean {
    const msg = error.message.toLowerCase();
    return msg.includes('network') || msg.includes('connection') ||
      msg.includes('econnreset') || msg.includes('econnrefused');
  }

  async handle(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    return this.service.handleNetworkError(error, context);
  }
}

class TimeoutErrorHandler implements ErrorHandler {
  private service: ErrorHandlingService;

  constructor(service: ErrorHandlingService) {
    this.service = service;
  }

  canHandle(error: Error): boolean {
    return error.message.toLowerCase().includes('timeout');
  }

  async handle(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    return this.service.handleTimeoutError(error, context);
  }
}

class ParseErrorHandler implements ErrorHandler {
  private service: ErrorHandlingService;

  constructor(service: ErrorHandlingService) {
    this.service = service;
  }

  canHandle(error: Error): boolean {
    const msg = error.message.toLowerCase();
    return msg.includes('parse') || msg.includes('json') || msg.includes('syntax');
  }

  async handle(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    return this.service.handleParseError(error, context);
  }
}

class ServerErrorHandler implements ErrorHandler {
  private service: ErrorHandlingService;

  constructor(service: ErrorHandlingService) {
    this.service = service;
  }

  canHandle(error: Error): boolean {
    const msg = error.message.toLowerCase();
    return msg.includes('500') || msg.includes('502') || msg.includes('503') || msg.includes('504');
  }

  async handle(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    return this.service.handleServerError(error, context);
  }
}

class NotFoundErrorHandler implements ErrorHandler {
  private service: ErrorHandlingService;

  constructor(service: ErrorHandlingService) {
    this.service = service;
  }

  canHandle(error: Error): boolean {
    return error.message.toLowerCase().includes('404');
  }

  async handle(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    return this.service.handleNotFoundError(error, context);
  }
}

/**
 * 错误上下文
 */
export interface ErrorContext {
  sourceId?: string;
  sourceName?: string;
  operation: string;
  retryCount: number;
  maxRetries: number;
  additionalData?: Map<string, string | number | boolean | object | null>;
}

/**
 * 错误处理服务
 */
export class ErrorHandlingService {
  private static instance: ErrorHandlingService | null = null;
  private errorHistory: ErrorInfo[] = [];
  private handlers: Map<ErrorType, ErrorHandler[]> = new Map();
  private degradationConfig: DegradationConfig;
  private maxErrorHistory: number = 100;

  private constructor() {
    this.degradationConfig = networkConfigManager.getDegradationConfig();
    this.registerDefaultHandlers();
  }

  static getInstance(): ErrorHandlingService {
    if (!ErrorHandlingService.instance) {
      ErrorHandlingService.instance = new ErrorHandlingService();
    }
    return ErrorHandlingService.instance;
  }

  /**
   * 注册默认错误处理器
   */
  private registerDefaultHandlers(): void {
    this.registerHandler(ErrorType.NETWORK, new NetworkErrorHandler(this));
    this.registerHandler(ErrorType.TIMEOUT, new TimeoutErrorHandler(this));
    this.registerHandler(ErrorType.PARSE, new ParseErrorHandler(this));
    this.registerHandler(ErrorType.SERVER, new ServerErrorHandler(this));
    this.registerHandler(ErrorType.NOT_FOUND, new NotFoundErrorHandler(this));
  }

  /**
   * 注册错误处理器
   */
  registerHandler(type: ErrorType, handler: ErrorHandler): void {
    if (!this.handlers.has(type)) {
      this.handlers.set(type, []);
    }
    this.handlers.get(type)!.push(handler);
  }

  /**
   * 处理错误
   */
  async handleError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    const errorInfo = this.createErrorInfo(error, context);
    this.recordError(errorInfo);

    Logger.error('ErrorHandlingService',
      `[${errorInfo.severity.toUpperCase()}] ${errorInfo.type}: ${errorInfo.message}`);

    // 查找合适的处理器
    const handler = this.findHandler(error);
    if (handler) {
      return handler.handle(error, context);
    }

    // 默认处理
    return this.handleDefaultError(error, context);
  }

  /**
   * 创建错误信息
   */
  private createErrorInfo(error: Error, context?: ErrorContext): ErrorInfo {
    const type = this.classifyError(error);
    const severity = this.determineSeverity(error, type);

    return {
      id: `err_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: type,
      severity: severity,
      message: error.message,
      details: error.stack,
      sourceId: context?.sourceId,
      sourceName: context?.sourceName,
      timestamp: Date.now(),
      recoverable: this.isRecoverable(type, severity),
      retryCount: context?.retryCount || 0,
      maxRetries: context?.maxRetries || 3
    };
  }

  /**
   * 分类错误
   */
  private classifyError(error: Error): ErrorType {
    const msg = error.message.toLowerCase();

    if (msg.includes('timeout')) return ErrorType.TIMEOUT;
    if (msg.includes('network') || msg.includes('connection') ||
      msg.includes('econnreset') || msg.includes('econnrefused')) return ErrorType.NETWORK;
    if (msg.includes('parse') || msg.includes('json') || msg.includes('syntax')) return ErrorType.PARSE;
    if (msg.includes('401') || msg.includes('403')) return ErrorType.AUTH;
    if (msg.includes('404')) return ErrorType.NOT_FOUND;
    if (msg.includes('500') || msg.includes('502') || msg.includes('503') || msg.includes('504')) return ErrorType.SERVER;

    return ErrorType.UNKNOWN;
  }

  /**
   * 确定错误严重程度
   */
  private determineSeverity(error: Error, type: ErrorType): ErrorSeverity {
    switch (type) {
      case ErrorType.AUTH:
      case ErrorType.NOT_FOUND:
        return ErrorSeverity.HIGH;

      case ErrorType.SERVER:
        return ErrorSeverity.MEDIUM;

      case ErrorType.NETWORK:
      case ErrorType.TIMEOUT:
        return ErrorSeverity.MEDIUM;

      case ErrorType.PARSE:
        return ErrorSeverity.LOW;

      default:
        return ErrorSeverity.MEDIUM;
    }
  }

  /**
   * 判断是否可恢复
   */
  private isRecoverable(type: ErrorType, severity: ErrorSeverity): boolean {
    if (severity === ErrorSeverity.CRITICAL) return false;

    switch (type) {
      case ErrorType.NETWORK:
      case ErrorType.TIMEOUT:
      case ErrorType.SERVER:
        return true;

      case ErrorType.AUTH:
      case ErrorType.NOT_FOUND:
        return false;

      default:
        return true;
    }
  }

  /**
   * 查找错误处理器
   */
  private findHandler(error: Error): ErrorHandler | null {
    const types = Array.from(this.handlers.keys());
    for (let i = 0; i < types.length; i++) {
      const type = types[i];
      const handlers = this.handlers.get(type);
      if (handlers) {
        for (let j = 0; j < handlers.length; j++) {
          if (handlers[j].canHandle(error)) {
            return handlers[j];
          }
        }
      }
    }
    return null;
  }

  /**
   * 处理网络错误
   */
  async handleNetworkError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    // 记录书源失败
    if (context?.sourceId) {
      smartSourceSelector.recordFailure(context.sourceId, error.message);
    }

    // 检查是否可以重试
    if (context && context.retryCount < context.maxRetries) {
      return {
        success: false,
        strategy: DegradationStrategy.RETRY,
        message: '网络错误，准备重试',
        shouldRetry: true,
        retryDelay: this.calculateRetryDelay(context.retryCount)
      };
    }

    // 切换书源
    return {
      success: false,
      strategy: DegradationStrategy.FALLBACK_SOURCE,
      message: '网络错误，切换书源',
      shouldRetry: false
    };
  }

  /**
   * 处理超时错误
   */
  async handleTimeoutError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    // 记录书源失败
    if (context?.sourceId) {
      smartSourceSelector.recordFailure(context.sourceId, '请求超时');
    }

    // 检查是否可以重试
    if (context && context.retryCount < context.maxRetries) {
      return {
        success: false,
        strategy: DegradationStrategy.RETRY,
        message: '请求超时，准备重试',
        shouldRetry: true,
        retryDelay: this.calculateRetryDelay(context.retryCount)
      };
    }

    // 切换书源
    return {
      success: false,
      strategy: DegradationStrategy.FALLBACK_SOURCE,
      message: '请求超时，切换书源',
      shouldRetry: false
    };
  }

  /**
   * 处理解析错误
   */
  async handleParseError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    // 记录书源失败
    if (context?.sourceId) {
      smartSourceSelector.recordFailure(context.sourceId, '解析错误: ' + error.message);
    }

    // 解析错误通常不可重试，直接切换书源
    return {
      success: false,
      strategy: DegradationStrategy.FALLBACK_SOURCE,
      message: '数据解析失败，切换书源',
      shouldRetry: false
    };
  }

  /**
   * 处理服务器错误
   */
  async handleServerError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    // 记录书源失败
    if (context?.sourceId) {
      smartSourceSelector.recordFailure(context.sourceId, '服务器错误');
    }

    // 检查是否可以重试
    if (context && context.retryCount < context.maxRetries) {
      return {
        success: false,
        strategy: DegradationStrategy.RETRY,
        message: '服务器错误，准备重试',
        shouldRetry: true,
        retryDelay: this.calculateRetryDelay(context.retryCount)
      };
    }

    // 切换书源
    return {
      success: false,
      strategy: DegradationStrategy.FALLBACK_SOURCE,
      message: '服务器错误，切换书源',
      shouldRetry: false
    };
  }

  /**
   * 处理未找到错误
   */
  async handleNotFoundError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    // 404错误通常不可恢复
    return {
      success: false,
      strategy: DegradationStrategy.ABORT,
      message: '资源未找到',
      shouldRetry: false
    };
  }

  /**
   * 默认错误处理
   */
  private async handleDefaultError(error: Error, context?: ErrorContext): Promise<DegradationResult> {
    return {
      success: false,
      strategy: DegradationStrategy.ABORT,
      message: `未知错误: ${error.message}`,
      shouldRetry: false
    };
  }

  /**
   * 计算重试延迟
   */
  private calculateRetryDelay(retryCount: number): number {
    const baseDelay = this.degradationConfig.fastFailThreshold / 10;
    const delay = baseDelay * Math.pow(2, retryCount);
    const jitter = Math.random() * 0.1 * delay;
    return Math.min(delay + jitter, this.degradationConfig.fastFailThreshold);
  }

  /**
   * 记录错误
   */
  private recordError(errorInfo: ErrorInfo): void {
    this.errorHistory.push(errorInfo);

    // 限制历史记录数量
    if (this.errorHistory.length > this.maxErrorHistory) {
      this.errorHistory.shift();
    }
  }

  /**
   * 获取错误历史
   */
  getErrorHistory(): ErrorInfo[] {
    return [...this.errorHistory];
  }

  /**
   * 获取最近的错误
   */
  getRecentErrors(count: number = 10): ErrorInfo[] {
    return this.errorHistory.slice(-count);
  }

  /**
   * 清除错误历史
   */
  clearErrorHistory(): void {
    this.errorHistory = [];
  }

  /**
   * 生成错误报告
   */
  generateErrorReport(): string {
    const errors = this.errorHistory;
    const byType = new Map<ErrorType, number>();
    const bySeverity = new Map<ErrorSeverity, number>();

    errors.forEach(err => {
      byType.set(err.type, (byType.get(err.type) || 0) + 1);
      bySeverity.set(err.severity, (bySeverity.get(err.severity) || 0) + 1);
    });

    let report = '=== 错误处理报告 ===\n\n';
    report += `总错误数: ${errors.length}\n\n`;

    report += '【按类型统计】\n';
    byType.forEach((count, type) => {
      report += `${type}: ${count}\n`;
    });
    report += '\n';

    report += '【按严重程度统计】\n';
    bySeverity.forEach((count, severity) => {
      report += `${severity}: ${count}\n`;
    });
    report += '\n';

    if (errors.length > 0) {
      report += '【最近错误】\n';
      const recent = errors.slice(-5);
      recent.forEach(err => {
        report += `[${err.severity.toUpperCase()}] ${err.type}: ${err.message}\n`;
        if (err.sourceName) {
          report += `  书源: ${err.sourceName}\n`;
        }
        report += `  时间: ${new Date(err.timestamp).toLocaleString()}\n\n`;
      });
    }

    return report;
  }

  /**
   * 更新降级配置
   */
  updateDegradationConfig(config: Partial<DegradationConfig>): void {
    this.degradationConfig = this.mergeDegradationConfig(this.degradationConfig, config);
    Logger.info('ErrorHandlingService', '降级配置已更新');
  }

  private mergeDegradationConfig(base: DegradationConfig, update: Partial<DegradationConfig>): DegradationConfig {
    return {
      fastFailThreshold: update.fastFailThreshold !== undefined ? update.fastFailThreshold : base.fastFailThreshold,
      disableAfterConsecutiveFailures: update.disableAfterConsecutiveFailures !== undefined ? update.disableAfterConsecutiveFailures : base.disableAfterConsecutiveFailures,
      recoveryCheckInterval: update.recoveryCheckInterval !== undefined ? update.recoveryCheckInterval : base.recoveryCheckInterval,
      minHealthyScore: update.minHealthyScore !== undefined ? update.minHealthyScore : base.minHealthyScore
    };
  }
}

export const errorHandlingService = ErrorHandlingService.getInstance();
