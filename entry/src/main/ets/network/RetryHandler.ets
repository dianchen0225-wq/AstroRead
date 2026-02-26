/**
 * RetryHandler - 请求重试处理器
 * 支持指数退避、自定义重试条件
 */

import { RetryConfig, HttpRequestConfig, HttpError, HttpErrorCode } from './interfaces/IHttpClient';
import { Logger } from '../utils/performance/Logger';

interface ExtendedRetryConfig extends RetryConfig {
  retryableErrorPatterns?: RegExp[];
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 3,
  retryDelay: 1000,
  retryDelayMultiplier: 2,
  maxRetryDelay: 30000,
  retryableStatusCodes: [408, 429, 500, 502, 503, 504],
  retryableErrors: ['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED', 'ENOTFOUND', 'ENETDOWN', 'ENETUNREACH']
};

export class RetryHandler {
  private static instance: RetryHandler | null = null;

  private readonly TAG = 'RetryHandler';

  private constructor() {}

  static getInstance(): RetryHandler {
    if (!RetryHandler.instance) {
      RetryHandler.instance = new RetryHandler();
    }
    return RetryHandler.instance;
  }
  async executeWithRetry<T>(
    requestFn: () => Promise<T>,
    config: HttpRequestConfig,
    retryConfig?: RetryConfig
  ): Promise<T> {
    const mergedConfig = this.mergeRetryConfig(retryConfig);
    let lastError: Error = new Error('Unknown error');
    let attempt = 0;

    while (attempt <= mergedConfig.maxRetries) {
      try {
        const result = await requestFn();
        return result;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        const httpError = error as HttpError;

        if (attempt >= mergedConfig.maxRetries) {
          Logger.warn(this.TAG, `Max retries (${mergedConfig.maxRetries}) exceeded`);
          throw lastError;
        }

        if (!this.shouldRetry(httpError, mergedConfig)) {
          Logger.debug(this.TAG, `Error is not retryable: ${httpError.code ?? 'UNKNOWN'}`);
          throw lastError;
        }

        if (mergedConfig.onRetry) {
          const shouldContinue = await Promise.resolve(mergedConfig.onRetry(attempt + 1, lastError, config));
          if (!shouldContinue) {
            Logger.debug(this.TAG, 'Retry callback returned false, stopping retries');
            throw lastError;
          }
        }

        const delay = this.calculateDelay(attempt, mergedConfig);
        attempt++;

        Logger.info(this.TAG, `Retry ${attempt}/${mergedConfig.maxRetries} after ${delay}ms: ${lastError.message}`);
        await this.sleep(delay);
      }
    }

    throw lastError;
  }

  shouldRetry(error: HttpError, config: RetryConfig): boolean {
    if (error.code === HttpErrorCode.ABORTED || error.code === HttpErrorCode.CANCELLED) {
      return false;
    }

    if (error.status && config.retryableStatusCodes?.includes(error.status)) {
      return true;
    }

    if (error.code === HttpErrorCode.TIMEOUT || error.code === HttpErrorCode.NETWORK_ERROR) {
      return true;
    }

    if (error.code === HttpErrorCode.HTTP_ERROR && error.status) {
      return config.retryableStatusCodes?.includes(error.status) ?? false;
    }

    const errorMessage = error.message.toLowerCase();
    
    if (config.retryableErrors) {
      for (const retryableError of config.retryableErrors) {
        if (errorMessage === retryableError.toLowerCase()) {
          return true;
        }
      }
    }

    if ((config as ExtendedRetryConfig).retryableErrorPatterns) {
      const patterns = (config as ExtendedRetryConfig).retryableErrorPatterns!;
      for (const pattern of patterns) {
        if (pattern.test(errorMessage)) {
          return true;
        }
      }
    }

    return false;
  }

  calculateDelay(attempt: number, config: RetryConfig): number {
    const baseDelay = config.retryDelay ?? 1000;
    const multiplier = config.retryDelayMultiplier ?? 2;
    const maxDelay = config.maxRetryDelay ?? 30000;

    const exponentialDelay = baseDelay * Math.pow(multiplier, attempt);

    const jitter = Math.random() * 0.1 * exponentialDelay;

    return Math.min(exponentialDelay + jitter, maxDelay);
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  getDefaultConfig(): RetryConfig {
    return this.mergeRetryConfig();
  }

  private mergeRetryConfig(retryConfig?: RetryConfig): RetryConfig {
    return {
      maxRetries: retryConfig?.maxRetries ?? DEFAULT_RETRY_CONFIG.maxRetries,
      retryDelay: retryConfig?.retryDelay ?? DEFAULT_RETRY_CONFIG.retryDelay,
      retryDelayMultiplier: retryConfig?.retryDelayMultiplier ?? DEFAULT_RETRY_CONFIG.retryDelayMultiplier,
      maxRetryDelay: retryConfig?.maxRetryDelay ?? DEFAULT_RETRY_CONFIG.maxRetryDelay,
      retryableStatusCodes: retryConfig?.retryableStatusCodes ?? DEFAULT_RETRY_CONFIG.retryableStatusCodes,
      retryableErrors: retryConfig?.retryableErrors ?? DEFAULT_RETRY_CONFIG.retryableErrors,
      onRetry: retryConfig?.onRetry ?? DEFAULT_RETRY_CONFIG.onRetry
    };
  }
}

export default RetryHandler.getInstance();
