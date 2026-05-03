import { Result, ErrorCode } from "../../core/Result";
import { IExponentialBackoffRetry, RetryConfig, RetryMetrics } from "./interfaces/IStability";
import { Logger } from "../performance/Logger";

interface ErrorWithStatusCode {
  statusCode: number;
}

export class ExponentialBackoffRetry implements IExponentialBackoffRetry {
  private static readonly TAG = 'ExponentialBackoffRetry';

  private static readonly DEFAULT_CONFIG: RetryConfig = {
    maxRetries: 5,
    baseDelayMs: 1000,
    maxDelayMs: 60000,
    backoffFactor: 2,
    jitterMs: 200,
    retryableStatusCodes: [429, 500, 502, 503, 504],
  };

  private totalAttempts: number = 0;
  private totalRetries: number = 0;
  private exhaustedRetries: number = 0;
  private totalRetryDelay: number = 0;

  async executeWithRetry<T>(
    fn: () => Promise<T>,
    config?: Partial<RetryConfig>
  ): Promise<Result<T>> {
    const fullConfig = this.mergeConfig(config);
    let lastError: Error | null = null;
    let lastStatusCode: number = 0;

    for (let attempt = 0; attempt <= fullConfig.maxRetries; attempt++) {
      this.totalAttempts++;

      try {
        const result = await fn();
        if (attempt > 0) {
          Logger.info(ExponentialBackoffRetry.TAG, `Request succeeded on attempt ${attempt}`);
        }
        return Result.ok(result);
      } catch (e) {
        lastError = e instanceof Error ? e : new Error(String(e));

        const errorObj = e as ErrorWithStatusCode;
        if (errorObj.statusCode !== undefined) {
          lastStatusCode = errorObj.statusCode;
        }

        if (attempt < fullConfig.maxRetries && this.isRetryable(lastStatusCode)) {
          const delay = this.calculateDelay(attempt, fullConfig);
          this.totalRetries++;
          this.totalRetryDelay += delay;

          Logger.info(ExponentialBackoffRetry.TAG,
            `Retry ${attempt + 1}/${fullConfig.maxRetries} after ${delay.toFixed(0)}ms (status=${lastStatusCode})`);

          await this.sleep(delay);
        } else {
          this.exhaustedRetries++;
          Logger.warn(ExponentialBackoffRetry.TAG,
            `Request failed after ${attempt} retries: ${lastError.message}`);
        }
      }
    }

    return Result.err(ErrorCode.NETWORK_ERROR,
      `重试耗尽: ${lastError?.message ?? 'Unknown error'}`);
  }

  calculateDelay(attempt: number, config?: RetryConfig): number {
    const cfg = config ?? ExponentialBackoffRetry.DEFAULT_CONFIG;
    const baseDelay = cfg.baseDelayMs * Math.pow(cfg.backoffFactor, attempt);
    const jitter = (Math.random() * 2 - 1) * cfg.jitterMs;
    const delay = baseDelay + jitter;
    return Math.min(Math.max(0, delay), cfg.maxDelayMs);
  }

  isRetryable(statusCode: number): boolean {
    const config = ExponentialBackoffRetry.DEFAULT_CONFIG;
    if (statusCode === 0) return true;
    if (statusCode >= 400 && statusCode < 500 && statusCode !== 429) return false;
    if (config.retryableStatusCodes.includes(statusCode)) return true;
    if (statusCode >= 500) return true;
    return false;
  }

  getMetrics(): RetryMetrics {
    const metrics: RetryMetrics = {
      totalAttempts: this.totalAttempts,
      totalRetries: this.totalRetries,
      exhaustedRetries: this.exhaustedRetries,
      avgRetryDelay: this.totalRetries > 0
        ? this.totalRetryDelay / this.totalRetries
        : 0,
    };
    return metrics;
  }

  private mergeConfig(config?: Partial<RetryConfig>): RetryConfig {
    const base = ExponentialBackoffRetry.DEFAULT_CONFIG;
    const result: RetryConfig = {
      maxRetries: config?.maxRetries ?? base.maxRetries,
      baseDelayMs: config?.baseDelayMs ?? base.baseDelayMs,
      maxDelayMs: config?.maxDelayMs ?? base.maxDelayMs,
      backoffFactor: config?.backoffFactor ?? base.backoffFactor,
      jitterMs: config?.jitterMs ?? base.jitterMs,
      retryableStatusCodes: config?.retryableStatusCodes ?? base.retryableStatusCodes,
    };
    return result;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => resolve(), ms);
    });
  }
}
