import { ExponentialBackoffRetry } from "../ExponentialBackoffRetry";
import { RetryConfig } from "../interfaces/IStability";

export class ExponentialBackoffRetryTest {
  private retry: ExponentialBackoffRetry;
  private passed: number = 0;
  private failed: number = 0;

  constructor() {
    this.retry = new ExponentialBackoffRetry();
  }

  runAll(): void {
    console.log('=== ExponentialBackoffRetry Tests ===');

    this.testDelayCalculation();
    this.testDelayMaxCap();
    this.testRetryableStatusCodes();
    this.testNonRetryableStatusCodes();
    this.testMetrics();

    console.log(`\nResults: ${this.passed} passed, ${this.failed} failed`);
  }

  private testDelayCalculation(): void {
    const config: RetryConfig = {
      maxRetries: 5, baseDelayMs: 1000, maxDelayMs: 60000,
      backoffFactor: 2, jitterMs: 200, retryableStatusCodes: [429, 500, 502, 503, 504],
    };

    const d0 = this.retry.calculateDelay(0, config);
    const d1 = this.retry.calculateDelay(1, config);
    const d2 = this.retry.calculateDelay(2, config);

    this.assert('Delay attempt 0 ~1000ms', d0 > 800 && d0 < 1200, true);
    this.assert('Delay attempt 1 ~2000ms', d1 > 1800 && d1 < 2200, true);
    this.assert('Delay attempt 2 ~4000ms', d2 > 3800 && d2 < 4200, true);
  }

  private testDelayMaxCap(): void {
    const config: RetryConfig = {
      maxRetries: 5, baseDelayMs: 1000, maxDelayMs: 5000,
      backoffFactor: 2, jitterMs: 0, retryableStatusCodes: [],
    };

    const d5 = this.retry.calculateDelay(5, config);
    this.assert('Delay capped at maxDelay', d5 <= 5000, true);
  }

  private testRetryableStatusCodes(): void {
    this.assert('429 is retryable', this.retry.isRetryable(429), true);
    this.assert('500 is retryable', this.retry.isRetryable(500), true);
    this.assert('502 is retryable', this.retry.isRetryable(502), true);
    this.assert('503 is retryable', this.retry.isRetryable(503), true);
    this.assert('Network error (0) is retryable', this.retry.isRetryable(0), true);
  }

  private testNonRetryableStatusCodes(): void {
    this.assert('400 is not retryable', this.retry.isRetryable(400), false);
    this.assert('401 is not retryable', this.retry.isRetryable(401), false);
    this.assert('403 is not retryable', this.retry.isRetryable(403), false);
    this.assert('404 is not retryable', this.retry.isRetryable(404), false);
  }

  private testMetrics(): void {
    const metrics = this.retry.getMetrics();
    this.assert('Metrics has totalAttempts', metrics.totalAttempts >= 0, true);
    this.assert('Metrics has totalRetries', metrics.totalRetries >= 0, true);
  }

  private assert(name: string, actual: boolean | number, expected: boolean | number): void {
    if (actual === expected) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected ${expected}, got ${actual}`);
    }
  }
}
