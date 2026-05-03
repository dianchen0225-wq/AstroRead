import { IDynamicAdjuster, ConcurrencyConfig } from "./interfaces/IConcurrency";
import { Logger } from "../performance/Logger";

export interface DynamicAdjusterConfig extends ConcurrencyConfig {
  baseRate?: number;
}

export class DynamicAdjuster implements IDynamicAdjuster {
  private static readonly TAG = 'DynamicAdjuster';

  private currentConcurrency: number;
  private currentRate: number;
  private consecutiveSuccesses: number = 0;
  private totalErrors: number = 0;
  private totalRequests: number = 0;
  private recentLatencies: number[] = [];

  private minConcurrency: number;
  private maxConcurrency: number;
  private baseRate: number;
  private latencyThresholdMs: number;
  private errorRateThreshold: number;
  private successWindowSize: number;
  private reduceStep: number;
  private increaseStep: number;

  private static readonly MAX_LATENCY_WINDOW = 20;

  constructor(config: Partial<DynamicAdjusterConfig>) {
    this.minConcurrency = config.minConcurrency ?? 1;
    this.maxConcurrency = config.maxConcurrency ?? 20;
    this.currentConcurrency = config.defaultConcurrency ?? 10;
    this.baseRate = config.baseRate ?? 10;
    this.currentRate = this.baseRate;
    this.latencyThresholdMs = config.latencyThresholdMs ?? 3000;
    this.errorRateThreshold = config.errorRateThreshold ?? 0.3;
    this.successWindowSize = config.successWindowSize ?? 10;
    this.reduceStep = config.aimdReduceStep ?? 2;
    this.increaseStep = config.aimdIncreaseStep ?? 1;
  }

  onSuccess(responseTimeMs: number): void {
    this.totalRequests++;
    this.consecutiveSuccesses++;
    this.recentLatencies.push(responseTimeMs);

    if (this.recentLatencies.length > DynamicAdjuster.MAX_LATENCY_WINDOW) {
      this.recentLatencies.shift();
    }

    if (this.consecutiveSuccesses >= this.successWindowSize) {
      this.increaseConcurrency();
      this.consecutiveSuccesses = 0;
    }

    Logger.debug(DynamicAdjuster.TAG,
      `Success: latency=${responseTimeMs}ms, consecutive=${this.consecutiveSuccesses}, concurrency=${this.currentConcurrency}`);
  }

  onFailure(): void {
    this.totalRequests++;
    this.totalErrors++;
    this.consecutiveSuccesses = 0;

    const errorRate = this.totalErrors / this.totalRequests;
    const avgLatency = this.getAvgLatency();

    if (avgLatency > this.latencyThresholdMs || errorRate > this.errorRateThreshold) {
      this.reduceConcurrency();
    }

    Logger.debug(DynamicAdjuster.TAG,
      `Failure: errorRate=${(errorRate * 100).toFixed(1)}%, avgLatency=${avgLatency.toFixed(0)}ms, concurrency=${this.currentConcurrency}`);
  }

  getCurrentConcurrency(): number {
    return this.currentConcurrency;
  }

  getCurrentRate(): number {
    return this.currentRate;
  }

  reset(): void {
    this.currentConcurrency = Math.floor((this.minConcurrency + this.maxConcurrency) / 2);
    this.currentRate = this.baseRate;
    this.consecutiveSuccesses = 0;
    this.totalErrors = 0;
    this.totalRequests = 0;
    this.recentLatencies = [];
    Logger.info(DynamicAdjuster.TAG, 'DynamicAdjuster reset');
  }

  private reduceConcurrency(): void {
    const oldConcurrency = this.currentConcurrency;
    this.currentConcurrency = Math.max(
      this.minConcurrency,
      this.currentConcurrency - this.reduceStep
    );
    this.currentRate = this.currentRate * 0.8;

    Logger.info(DynamicAdjuster.TAG,
      `Reducing concurrency: ${oldConcurrency} → ${this.currentConcurrency}, rate → ${this.currentRate.toFixed(1)}/s`);
  }

  private increaseConcurrency(): void {
    const oldConcurrency = this.currentConcurrency;
    this.currentConcurrency = Math.min(
      this.maxConcurrency,
      this.currentConcurrency + this.increaseStep
    );
    this.currentRate = Math.min(
      this.baseRate * 1.5,
      this.currentRate * 1.1
    );

    Logger.info(DynamicAdjuster.TAG,
      `Increasing concurrency: ${oldConcurrency} → ${this.currentConcurrency}, rate → ${this.currentRate.toFixed(1)}/s`);
  }

  private getAvgLatency(): number {
    if (this.recentLatencies.length === 0) return 0;
    const sum = this.recentLatencies.reduce((a: number, b: number) => a + b, 0);
    return sum / this.recentLatencies.length;
  }
}
