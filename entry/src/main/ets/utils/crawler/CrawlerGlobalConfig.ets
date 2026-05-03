import { AntiCrawlConfig, ProxyStrategy } from "./interfaces/IAntiCrawl";
import { ConcurrencyConfig } from "./interfaces/IConcurrency";
import { RetryConfig, RuleFailureDetectorConfig, RuleDegradationConfig } from "./interfaces/IStability";

export class CrawlerGlobalConfig {
  concurrency: ConcurrencyConfig;
  retry: RetryConfig;
  antiCrawl: AntiCrawlConfig;
  failureDetector: RuleFailureDetectorConfig;
  degradation: RuleDegradationConfig;

  constructor() {
    this.concurrency = CrawlerGlobalConfig.DEFAULT_CONCURRENCY;
    this.retry = CrawlerGlobalConfig.DEFAULT_RETRY;
    this.antiCrawl = CrawlerGlobalConfig.DEFAULT_ANTI_CRAWL;
    this.failureDetector = CrawlerGlobalConfig.DEFAULT_FAILURE_DETECTOR;
    this.degradation = CrawlerGlobalConfig.DEFAULT_DEGRADATION;
  }

  static readonly DEFAULT_CONCURRENCY: ConcurrencyConfig = {
    maxConcurrency: 20,
    minConcurrency: 1,
    defaultConcurrency: 10,
    queueCapacity: 10000,
    ratePerSecond: 10,
    enableDynamicAdjustment: true,
    latencyThresholdMs: 3000,
    errorRateThreshold: 0.3,
    successWindowSize: 10,
    aimdReduceStep: 2,
    aimdIncreaseStep: 1,
  };

  static readonly DEFAULT_RETRY: RetryConfig = {
    maxRetries: 5,
    baseDelayMs: 1000,
    maxDelayMs: 60000,
    backoffFactor: 2,
    jitterMs: 200,
    retryableStatusCodes: [429, 500, 502, 503, 504],
  };

  static readonly DEFAULT_ANTI_CRAWL: AntiCrawlConfig = {
    rotateUserAgent: true,
    rotateHeaders: true,
    manageCookies: true,
    defaultRatePerSecond: 5,
    minRatePerSecond: 0.5,
    maxRatePerSecond: 20,
    rateReductionFactor: 0.5,
    rateRecoveryStep: 0.1,
    successWindowForRecovery: 10,
    proxyStrategy: ProxyStrategy.ROUND_ROBIN,
    proxyFailureThreshold: 3,
    proxyRecoveryMs: 300000,
    jsRenderMaxConcurrency: 3,
    jsRenderTimeoutMs: 10000,
    jsRenderBlockResources: ['image', 'stylesheet', 'font', 'media'],
    fingerprintJitterMs: 200,
  };

  static readonly DEFAULT_FAILURE_DETECTOR: RuleFailureDetectorConfig = {
    failureThreshold: 10,
    windowMs: 86400000,
    autoRecoveryMs: 3600000,
  };

  static readonly DEFAULT_DEGRADATION: RuleDegradationConfig = {
    maxFallbackRules: 3,
    enableLooseMatch: true,
    failureThreshold: 10,
    failureWindowMs: 86400000,
  };

  merge(overrides: Partial<CrawlerGlobalConfig>): CrawlerGlobalConfig {
    const merged = new CrawlerGlobalConfig();
    if (overrides.concurrency) {
      merged.concurrency = this.mergeObject(this.concurrency, overrides.concurrency) as ConcurrencyConfig;
    }
    if (overrides.retry) {
      merged.retry = this.mergeObject(this.retry, overrides.retry) as RetryConfig;
    }
    if (overrides.antiCrawl) {
      merged.antiCrawl = this.mergeObject(this.antiCrawl, overrides.antiCrawl) as AntiCrawlConfig;
    }
    if (overrides.failureDetector) {
      merged.failureDetector = this.mergeObject(this.failureDetector, overrides.failureDetector) as RuleFailureDetectorConfig;
    }
    if (overrides.degradation) {
      merged.degradation = this.mergeObject(this.degradation, overrides.degradation) as RuleDegradationConfig;
    }
    return merged;
  }

  static fromJSON(json: string): CrawlerGlobalConfig {
    try {
      const obj: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      const config = new CrawlerGlobalConfig();
      if (obj.concurrency) {
        config.concurrency = CrawlerGlobalConfig.mergeStatic(CrawlerGlobalConfig.DEFAULT_CONCURRENCY, obj.concurrency) as ConcurrencyConfig;
      }
      if (obj.retry) {
        config.retry = CrawlerGlobalConfig.mergeStatic(CrawlerGlobalConfig.DEFAULT_RETRY, obj.retry) as RetryConfig;
      }
      if (obj.antiCrawl) {
        config.antiCrawl = CrawlerGlobalConfig.mergeStatic(CrawlerGlobalConfig.DEFAULT_ANTI_CRAWL, obj.antiCrawl) as AntiCrawlConfig;
      }
      return config;
    } catch (_) {
      return new CrawlerGlobalConfig();
    }
  }

  private mergeObject(base: Object, override: Object): Object {
    const result: Record<string, Object> = {};
    const baseMap = base as Record<string, Object>;
    const overrideMap = override as Record<string, Object>;
    const keys = Object.keys(baseMap);
    for (let i = 0; i < keys.length; i++) {
      result[keys[i]] = baseMap[keys[i]];
    }
    const overrideKeys = Object.keys(overrideMap);
    for (let i = 0; i < overrideKeys.length; i++) {
      result[overrideKeys[i]] = overrideMap[overrideKeys[i]];
    }
    return result;
  }

  private static mergeStatic(base: Object, override: Object): Object {
    const result: Record<string, Object> = {};
    const baseMap = base as Record<string, Object>;
    const overrideMap = override as Record<string, Object>;
    const keys = Object.keys(baseMap);
    for (let i = 0; i < keys.length; i++) {
      result[keys[i]] = baseMap[keys[i]];
    }
    const overrideKeys = Object.keys(overrideMap);
    for (let i = 0; i < overrideKeys.length; i++) {
      result[overrideKeys[i]] = overrideMap[overrideKeys[i]];
    }
    return result;
  }
}
