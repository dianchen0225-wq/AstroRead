/**
 * IdempotentRetryHandler - 幂等性重试处理器
 * 仅对幂等操作启用重试，避免非幂等操作重复执行导致副作用
 */

import { RetryConfig, HttpRequestConfig, HttpError, HttpErrorCode } from './interfaces/IHttpClient';
import { Logger } from '../utils/Logger';
import { ErrorUtils } from '../core/errors';
import { RetryConstants } from '../constants';

/**
 * HTTP方法幂等性定义
 */
enum HttpMethodIdempotency {
  /** 幂等方法：多次执行结果相同 */
  IDEMPOTENT = 'IDEMPOTENT',
  /** 安全方法：不修改资源 */
  SAFE = 'SAFE',
  /** 非幂等方法：可能产生副作用 */
  NON_IDEMPOTENT = 'NON_IDEMPOTENT',
}

/**
 * 幂等性配置
 */
interface IdempotencyConfig {
  /** 是否强制启用重试（即使非幂等） */
  forceRetry?: boolean;
  /** 幂等性键生成函数 */
  idempotencyKeyGenerator?: () => string;
  /** 已执行的请求记录（用于防止重复执行） */
  executedRequests?: Set<string>;
}

/**
 * 带幂等性检查的重试配置
 */
interface IdempotentRetryConfig extends RetryConfig {
  /** 幂等性配置 */
  idempotency?: IdempotencyConfig;
}

const DEFAULT_IDEMPOTENT_RETRY_CONFIG: IdempotentRetryConfig = {
  maxRetries: RetryConstants.DEFAULT_RETRY_COUNT,
  retryDelay: RetryConstants.DEFAULT_RETRY_DELAY,
  retryDelayMultiplier: RetryConstants.BACKOFF_BASE,
  maxRetryDelay: 30000,
  retryableStatusCodes: [408, 429, 500, 502, 503, 504],
  retryableErrors: ['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED', 'ENOTFOUND', 'ENETDOWN', 'ENETUNREACH'],
  idempotency: {
    forceRetry: false,
  }
};

/**
 * 幂等性重试处理器
 * 确保只有幂等操作才会被重试
 */
export class IdempotentRetryHandler {
  private static instance: IdempotentRetryHandler | null = null;
  private readonly TAG = 'IdempotentRetryHandler';

  /** 已执行的请求记录（带时间戳，用于自动清理） */
  private executedRequests: Map<string, number> = new Map();
  /** 请求锁（防止并发重复请求） */
  private requestLocks: Map<string, Promise<Object>> = new Map();
  /** 操作锁（确保对共享资源的原子操作） */
  private operationLock: Promise<void> = Promise.resolve();
  /** 最后清理时间 */
  private lastCleanupTime: number = Date.now();
  /** 清理间隔（毫秒） */
  private readonly CLEANUP_INTERVAL: number = 60 * 1000; // 1分钟
  /** 请求记录过期时间（毫秒） */
  private readonly REQUEST_EXPIRY: number = 5 * 60 * 1000; // 5分钟

  private constructor() {}

  static getInstance(): IdempotentRetryHandler {
    if (!IdempotentRetryHandler.instance) {
      IdempotentRetryHandler.instance = new IdempotentRetryHandler();
    }
    return IdempotentRetryHandler.instance;
  }

  /**
   * 原子操作包装器
   * 确保对共享资源的操作是线程安全的
   */
  private async withLock<T>(operation: () => Promise<T>): Promise<T> {
    const currentLock = this.operationLock;
    let releaseLock: () => void;

    const newLock = new Promise<void>((resolve) => {
      releaseLock = resolve;
    });

    this.operationLock = newLock;

    try {
      await currentLock;
      return await operation();
    } finally {
      releaseLock!();
    }
  }

  /**
   * 执行带重试的请求（自动检查幂等性）
   * @param requestFn 请求函数
   * @param config HTTP请求配置
   * @param retryConfig 重试配置
   * @returns 请求结果
   */
  async executeWithRetry<T>(
    requestFn: () => Promise<T>,
    config: HttpRequestConfig,
    retryConfig?: IdempotentRetryConfig
  ): Promise<T> {
    const mergedConfig = this.mergeRetryConfig(retryConfig);
    const method = config.method?.toUpperCase() ?? 'GET';

    // 检查是否幂等
    const isIdempotent = this.isIdempotentMethod(method);
    const forceRetry = mergedConfig.idempotency?.forceRetry ?? false;

    // 如果不是幂等方法且未强制重试，直接执行不启用重试
    if (!isIdempotent && !forceRetry) {
      Logger.debug(this.TAG, `非幂等方法 ${method} 不启用重试`);
      return requestFn();
    }

    // 生成幂等性键
    const idempotencyKey = this.generateIdempotencyKey(config, mergedConfig);

    // 使用原子操作检查和设置请求锁
    return this.withLock(async () => {
      // 检查是否已有相同请求在执行中（请求去重）
      const existingRequest = this.requestLocks.get(idempotencyKey);
      if (existingRequest) {
        Logger.debug(this.TAG, `检测到重复请求，复用进行中的请求: ${idempotencyKey}`);
        return existingRequest.then((result: Object) => result as T);
      }

      // 创建请求Promise并添加到锁
      const requestPromise = this.executeWithRetryInternal(
        requestFn,
        config,
        mergedConfig,
        idempotencyKey
      );

      // 将 Promise<T> 转换为 Promise<Object> 存储
      const storedPromise = requestPromise.then((result: T): Object => result as Object);
      this.requestLocks.set(idempotencyKey, storedPromise);

      try {
        const result = await requestPromise;
        return result;
      } finally {
        // 清理锁（使用原子操作）
        await this.withLock(async () => {
          this.requestLocks.delete(idempotencyKey);
        });
      }
    });
  }

  /**
   * 内部重试执行逻辑
   */
  private async executeWithRetryInternal<T>(
    requestFn: () => Promise<T>,
    config: HttpRequestConfig,
    retryConfig: IdempotentRetryConfig,
    idempotencyKey: string
  ): Promise<T> {
    let lastError: Error = new Error('Unknown error');
    let attempt = 0;

    while (attempt <= retryConfig.maxRetries!) {
      try {
        // 检查是否已执行过（防止重复执行）- 使用原子操作
        const shouldSkip = await this.withLock(async () => {
          if (attempt > 0 && this.executedRequests.has(idempotencyKey)) {
            return true;
          }
          return false;
        });

        if (shouldSkip) {
          Logger.warn(this.TAG, `请求已执行过，跳过重复执行: ${idempotencyKey}`);
          throw new Error('Duplicate request detected');
        }

        const result = await requestFn();

        // 记录已执行的请求（带时间戳）- 使用原子操作
        if (attempt === 0) {
          await this.withLock(async () => {
            this.executedRequests.set(idempotencyKey, Date.now());
            this.cleanupExecutedRequestsIfNeeded();
          });
        }

        return result;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        const httpError = error as HttpError;

        // 检查是否已达到最大重试次数
        if (attempt >= retryConfig.maxRetries!) {
          Logger.warn(this.TAG, `达到最大重试次数 (${retryConfig.maxRetries})`);
          throw lastError;
        }

        // 检查错误是否可重试
        if (!this.shouldRetry(httpError, retryConfig)) {
          Logger.debug(this.TAG, `错误不可重试: ${httpError.code ?? 'UNKNOWN'}`);
          throw lastError;
        }

        // 检查是否取消
        if (config.signal?.aborted) {
          Logger.debug(this.TAG, '请求已取消，停止重试');
          throw lastError;
        }

        // 执行重试回调
        if (retryConfig.onRetry) {
          const shouldContinue = await Promise.resolve(
            retryConfig.onRetry(attempt + 1, lastError, config)
          );
          if (!shouldContinue) {
            Logger.debug(this.TAG, '重试回调返回false，停止重试');
            throw lastError;
          }
        }

        // 计算延迟时间
        const delay = this.calculateDelay(attempt, retryConfig);
        attempt++;

        Logger.info(this.TAG, `重试 ${attempt}/${retryConfig.maxRetries}，延迟 ${delay}ms: ${lastError.message}`);
        await this.sleep(delay);
      }
    }

    throw lastError;
  }

  /**
   * 判断HTTP方法是否幂等
   */
  private isIdempotentMethod(method: string): boolean {
    const idempotentMethods = ['GET', 'HEAD', 'OPTIONS', 'TRACE', 'PUT', 'DELETE'];
    return idempotentMethods.includes(method.toUpperCase());
  }

  /**
   * 判断HTTP方法是否安全（不修改资源）
   */
  private isSafeMethod(method: string): boolean {
    const safeMethods = ['GET', 'HEAD', 'OPTIONS', 'TRACE'];
    return safeMethods.includes(method.toUpperCase());
  }

  /**
   * 获取方法的幂等性级别
   */
  getMethodIdempotency(method: string): HttpMethodIdempotency {
    const upperMethod = method.toUpperCase();

    if (this.isSafeMethod(upperMethod)) {
      return HttpMethodIdempotency.SAFE;
    }

    if (this.isIdempotentMethod(upperMethod)) {
      return HttpMethodIdempotency.IDEMPOTENT;
    }

    return HttpMethodIdempotency.NON_IDEMPOTENT;
  }

  /**
   * 生成幂等性键
   */
  private generateIdempotencyKey(
    config: HttpRequestConfig,
    retryConfig: IdempotentRetryConfig
  ): string {
    // 使用自定义生成器
    if (retryConfig.idempotency?.idempotencyKeyGenerator) {
      return retryConfig.idempotency.idempotencyKeyGenerator();
    }

    // 默认生成器：基于URL、方法和关键头部
    const url = config.url ?? '';
    const method = config.method?.toUpperCase() ?? 'GET';
    const body = config.body ? JSON.stringify(config.body) : '';

    // 简单哈希
    const keyData = `${method}:${url}:${body}`;
    return this.simpleHash(keyData);
  }

  /**
   * 简单字符串哈希
   */
  private simpleHash(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return `req_${Math.abs(hash).toString(16)}`;
  }

  /**
   * 判断错误是否可重试
   */
  private shouldRetry(error: HttpError, config: RetryConfig): boolean {
    // 取消和终止的错误不重试
    if (error.code === HttpErrorCode.ABORTED || error.code === HttpErrorCode.CANCELLED) {
      return false;
    }

    // 检查状态码
    if (error.status && config.retryableStatusCodes?.includes(error.status)) {
      return true;
    }

    // 检查超时和网络错误
    if (error.code === HttpErrorCode.TIMEOUT || error.code === HttpErrorCode.NETWORK_ERROR) {
      return true;
    }

    // 检查HTTP错误状态码
    if (error.code === HttpErrorCode.HTTP_ERROR && error.status) {
      return config.retryableStatusCodes?.includes(error.status) ?? false;
    }

    // 检查错误消息模式
    const errorMessage = error.message.toLowerCase();
    if (config.retryableErrors) {
      for (const retryableError of config.retryableErrors) {
        if (errorMessage.includes(retryableError.toLowerCase())) {
          return true;
        }
      }
    }

    // 使用ErrorUtils检查
    return ErrorUtils.isRetryable(error as Error);
  }

  /**
   * 计算重试延迟（指数退避 + 抖动）
   */
  private calculateDelay(attempt: number, config: RetryConfig): number {
    const baseDelay = config.retryDelay ?? RetryConstants.DEFAULT_RETRY_DELAY;
    const multiplier = config.retryDelayMultiplier ?? RetryConstants.BACKOFF_BASE;
    const maxDelay = config.maxRetryDelay ?? 30000;

    // 指数退避
    const exponentialDelay = baseDelay * Math.pow(multiplier, attempt);

    // 添加抖动（0-10%）避免 thundering herd
    const jitter = Math.random() * 0.1 * exponentialDelay;

    return Math.min(exponentialDelay + jitter, maxDelay);
  }

  /**
   * 延迟函数
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 清理已执行请求记录（防止内存泄漏）
   * 使用时间戳进行智能清理，移除过期的记录
   */
  private cleanupExecutedRequestsIfNeeded(): void {
    const now = Date.now();

    // 检查是否需要清理（基于时间间隔）
    if (now - this.lastCleanupTime < this.CLEANUP_INTERVAL) {
      return;
    }

    this.lastCleanupTime = now;

    // 移除过期的请求记录
    const keysToDelete: string[] = [];
    this.executedRequests.forEach((timestamp: number, key: string) => {
      if (now - timestamp > this.REQUEST_EXPIRY) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.executedRequests.delete(key);
    }

    // 如果清理后仍然过大，执行LRU清理
    const MAX_EXECUTED_REQUESTS = 1000;
    if (this.executedRequests.size > MAX_EXECUTED_REQUESTS) {
      // 按时间戳排序，移除最旧的一半
      const entries = Array.from(this.executedRequests.entries())
        .sort((a, b) => a[1] - b[1]);

      const toDelete = entries.slice(0, Math.floor(entries.length / 2));
      for (const [key] of toDelete) {
        this.executedRequests.delete(key);
      }
    }

    if (keysToDelete.length > 0 || this.executedRequests.size > MAX_EXECUTED_REQUESTS / 2) {
      Logger.debug(this.TAG, `清理已执行请求记录，移除${keysToDelete.length}个过期记录，当前数量: ${this.executedRequests.size}`);
    }
  }

  /**
   * 强制清理所有过期的请求记录
   */
  cleanupExpiredRequests(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];

    this.executedRequests.forEach((timestamp: number, key: string) => {
      if (now - timestamp > this.REQUEST_EXPIRY) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.executedRequests.delete(key);
    }

    Logger.debug(this.TAG, `强制清理过期请求记录，移除${keysToDelete.length}个记录`);
  }

  /**
   * 获取默认配置
   */
  getDefaultConfig(): IdempotentRetryConfig {
    const config: IdempotentRetryConfig = {
      maxRetries: DEFAULT_IDEMPOTENT_RETRY_CONFIG.maxRetries ?? 3,
      retryDelay: DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryDelay,
      retryDelayMultiplier: DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryDelayMultiplier,
      maxRetryDelay: DEFAULT_IDEMPOTENT_RETRY_CONFIG.maxRetryDelay,
      retryableStatusCodes: DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryableStatusCodes,
      retryableErrors: DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryableErrors,
      onRetry: DEFAULT_IDEMPOTENT_RETRY_CONFIG.onRetry,
      idempotency: DEFAULT_IDEMPOTENT_RETRY_CONFIG.idempotency
    };
    return config;
  }

  /**
   * 合并重试配置
   */
  private mergeRetryConfig(retryConfig?: IdempotentRetryConfig): IdempotentRetryConfig {
    const mergedIdempotency: IdempotencyConfig = {};
    mergedIdempotency.forceRetry = retryConfig?.idempotency?.forceRetry ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.idempotency?.forceRetry;
    if (retryConfig?.idempotency?.idempotencyKeyGenerator) {
      mergedIdempotency.idempotencyKeyGenerator = retryConfig.idempotency.idempotencyKeyGenerator;
    }

    const mergedConfig: IdempotentRetryConfig = {
      maxRetries: retryConfig?.maxRetries ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.maxRetries ?? 3,
      retryDelay: retryConfig?.retryDelay ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryDelay,
      retryDelayMultiplier: retryConfig?.retryDelayMultiplier ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryDelayMultiplier,
      maxRetryDelay: retryConfig?.maxRetryDelay ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.maxRetryDelay,
      retryableStatusCodes: retryConfig?.retryableStatusCodes ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryableStatusCodes,
      retryableErrors: retryConfig?.retryableErrors ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.retryableErrors,
      onRetry: retryConfig?.onRetry ?? DEFAULT_IDEMPOTENT_RETRY_CONFIG.onRetry,
      idempotency: mergedIdempotency
    };

    return mergedConfig;
  }

  /**
   * 清空已执行请求记录
   */
  clearExecutedRequests(): void {
    this.executedRequests.clear();
    this.lastCleanupTime = Date.now();
    Logger.debug(this.TAG, '已执行请求记录已清空');
  }

  /**
   * 获取统计信息
   */
  getStats(): Record<string, number> {
    const stats: Record<string, number> = {};
    stats['executedRequestsCount'] = this.executedRequests.size;
    stats['pendingRequestsCount'] = this.requestLocks.size;
    stats['lastCleanupTime'] = this.lastCleanupTime;
    return stats;
  }
}

// 导出单例
export const idempotentRetryHandler = IdempotentRetryHandler.getInstance();
