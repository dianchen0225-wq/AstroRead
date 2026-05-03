import { Result, ErrorCode } from "../../core/Result";
import { IConcurrencyController, CrawlTask, ConcurrencyConfig, ConcurrencyMetrics, IPriorityScheduler, IRateSmoother, IDynamicAdjuster } from "./interfaces/IConcurrency";
import { PriorityScheduler } from "./PriorityScheduler";
import { RateSmoother } from "./RateSmoother";
import { DynamicAdjuster, DynamicAdjusterConfig } from "./DynamicAdjuster";
import { Semaphore, SemaphoreConfig } from "../performance/Semaphore";
import { Logger } from "../performance/Logger";

export class ConcurrencyController implements IConcurrencyController {
  private static readonly TAG = 'ConcurrencyController';

  private semaphore: Semaphore;
  private scheduler: IPriorityScheduler;
  private rateSmoother: IRateSmoother;
  private dynamicAdjuster: IDynamicAdjuster;
  private config: ConcurrencyConfig;

  private completedRequests: number = 0;
  private failedRequests: number = 0;
  private totalResponseTime: number = 0;
  private activeRequests: number = 0;

  constructor(config?: Partial<ConcurrencyConfig>) {
    this.config = this.mergeDefaults(config);
    const semOpts: SemaphoreConfig = {
      permits: this.config.maxConcurrency,
      fair: true,
      name: 'CrawlerConcurrency',
    };
    this.semaphore = new Semaphore(semOpts);
    this.scheduler = new PriorityScheduler(this.config.queueCapacity);
    this.rateSmoother = new RateSmoother(this.config.ratePerSecond);
    const adjusterConfig: Partial<DynamicAdjusterConfig> = {
      maxConcurrency: this.config.maxConcurrency,
      minConcurrency: this.config.minConcurrency,
      defaultConcurrency: this.config.defaultConcurrency,
      queueCapacity: this.config.queueCapacity,
      ratePerSecond: this.config.ratePerSecond,
      enableDynamicAdjustment: this.config.enableDynamicAdjustment,
      latencyThresholdMs: this.config.latencyThresholdMs,
      errorRateThreshold: this.config.errorRateThreshold,
      successWindowSize: this.config.successWindowSize,
      aimdReduceStep: this.config.aimdReduceStep,
      aimdIncreaseStep: this.config.aimdIncreaseStep,
      baseRate: this.config.ratePerSecond,
    };
    this.dynamicAdjuster = new DynamicAdjuster(adjusterConfig);
  }

  submit(task: CrawlTask): Result<void> {
    return this.scheduler.enqueue(task);
  }

  async acquire(): Promise<void> {
    await this.rateSmoother.wait();
    await this.semaphore.acquire();
    this.activeRequests++;
    Logger.debug(ConcurrencyController.TAG, `Permit acquired, active=${this.activeRequests}`);
  }

  release(): void {
    this.activeRequests--;
    this.semaphore.release();
    Logger.debug(ConcurrencyController.TAG, `Permit released, active=${this.activeRequests}`);

    const nextTask = this.scheduler.dequeue();
    if (nextTask) {
      Logger.debug(ConcurrencyController.TAG, `Next task ${nextTask.id} dequeued`);
    }
  }

  getMetrics(): ConcurrencyMetrics {
    const metrics: ConcurrencyMetrics = {
      activeRequests: this.activeRequests,
      queuedRequests: this.scheduler.size(),
      completedRequests: this.completedRequests,
      failedRequests: this.failedRequests,
      avgResponseTime: this.completedRequests > 0
        ? this.totalResponseTime / this.completedRequests
        : 0,
      currentConcurrency: this.dynamicAdjuster.getCurrentConcurrency(),
      currentRatePerSecond: this.dynamicAdjuster.getCurrentRate(),
    };
    return metrics;
  }

  updateConfig(config: Partial<ConcurrencyConfig>): void {
    this.config = this.mergeDefaults(config);

    if (config.maxConcurrency) {
      const diff = config.maxConcurrency - this.semaphore.availablePermits() - this.activeRequests;
      if (diff > 0) {
        this.semaphore.increasePermits(diff);
      } else if (diff < 0) {
        this.semaphore.reducePermits(Math.abs(diff));
      }
    }

    if (config.ratePerSecond) {
      this.rateSmoother.updateRate(config.ratePerSecond);
    }

    Logger.info(ConcurrencyController.TAG, 'Config updated');
  }

  shutdown(): void {
    this.scheduler.clear();
    this.semaphore.clearQueue();
    Logger.info(ConcurrencyController.TAG, 'ConcurrencyController shutdown');
  }

  recordSuccess(responseTimeMs: number): void {
    this.completedRequests++;
    this.totalResponseTime += responseTimeMs;
    this.dynamicAdjuster.onSuccess(responseTimeMs);
  }

  recordFailure(): void {
    this.failedRequests++;
    this.dynamicAdjuster.onFailure();
  }

  private mergeDefaults(config?: Partial<ConcurrencyConfig>): ConcurrencyConfig {
    const result: ConcurrencyConfig = {
      maxConcurrency: config?.maxConcurrency ?? 20,
      minConcurrency: config?.minConcurrency ?? 1,
      defaultConcurrency: config?.defaultConcurrency ?? 10,
      queueCapacity: config?.queueCapacity ?? 10000,
      ratePerSecond: config?.ratePerSecond ?? 10,
      enableDynamicAdjustment: config?.enableDynamicAdjustment ?? true,
      latencyThresholdMs: config?.latencyThresholdMs ?? 3000,
      errorRateThreshold: config?.errorRateThreshold ?? 0.3,
      successWindowSize: config?.successWindowSize ?? 10,
      aimdReduceStep: config?.aimdReduceStep ?? 2,
      aimdIncreaseStep: config?.aimdIncreaseStep ?? 1,
    };
    return result;
  }
}
