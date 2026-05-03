import { Result, ErrorCode } from "../../core/Result";
import { ParserResult, ParseOptions } from "../parser/IParser";
import { ICrawlerFacade, BatchCrawlResult, CrawlerMetrics, CrawlerRuntimeConfig } from "./interfaces/ICrawlerFacade";
import { CrawlTask, CrawlResult, ConcurrencyMetrics, TaskPriority } from "./interfaces/IConcurrency";
import { RuleValidationReport } from "../parser/interfaces/IUnifiedParseEngine";
import { CrawlerGlobalConfig } from "./CrawlerGlobalConfig";
import { UnifiedParseEngine } from "../parser/UnifiedParseEngine";
import { ConcurrencyController } from "./ConcurrencyController";
import { ExponentialBackoffRetry } from "./ExponentialBackoffRetry";
import { RuleDegradationManager } from "./RuleDegradationManager";
import { RuleFailureDetector } from "./RuleFailureDetector";
import { ExceptionIsolationGuard } from "./ExceptionIsolationGuard";
import { HeaderCookieDisguiser } from "./HeaderCookieDisguiser";
import { DomainFrequencyController } from "./DomainFrequencyController";
import { ProxyRotator } from "./ProxyRotator";
import { JSRenderScheduler } from "./JSRenderScheduler";
import { FingerprintRandomizer } from "./FingerprintRandomizer";
import { DegradationResult } from "./models/DegradationResult";
import { Logger } from "../performance/Logger";

interface FetchDisguised {
  url: string;
  headers: Map<string, string>;
  cookie: string;
}

export class CrawlerFacade implements ICrawlerFacade {
  private static readonly TAG = 'CrawlerFacade';
  private static instance: CrawlerFacade | null = null;

  private config: CrawlerGlobalConfig;
  private parseEngine!: UnifiedParseEngine;
  private concurrencyController: ConcurrencyController = new ConcurrencyController();
  private retryHandler: ExponentialBackoffRetry = new ExponentialBackoffRetry();
  private degradationManager: RuleDegradationManager = new RuleDegradationManager();
  private failureDetector: RuleFailureDetector = new RuleFailureDetector();
  private isolationGuard: ExceptionIsolationGuard = new ExceptionIsolationGuard();
  private headerDisguiser: HeaderCookieDisguiser = new HeaderCookieDisguiser();
  private frequencyController: DomainFrequencyController = new DomainFrequencyController();
  private proxyRotator: ProxyRotator = new ProxyRotator();
  private jsRenderScheduler: JSRenderScheduler = new JSRenderScheduler();
  private fingerprintRandomizer: FingerprintRandomizer = new FingerprintRandomizer();

  private totalCrawls: number = 0;
  private successCrawls: number = 0;
  private degradedCrawls: number = 0;
  private totalResponseTime: number = 0;
  private initialized: boolean = false;

  private constructor(config?: CrawlerGlobalConfig) {
    this.config = config ?? new CrawlerGlobalConfig();
  }

  static getInstance(config?: CrawlerGlobalConfig): CrawlerFacade {
    if (!CrawlerFacade.instance) {
      CrawlerFacade.instance = new CrawlerFacade(config);
      CrawlerFacade.instance.initialize();
    }
    return CrawlerFacade.instance;
  }

  static resetInstance(): void {
    if (CrawlerFacade.instance) {
      CrawlerFacade.instance.shutdown();
    }
    CrawlerFacade.instance = null;
  }

  async crawl(task: CrawlTask, options?: ParseOptions): Promise<Result<CrawlResult>> {
    const startTime = Date.now();
    this.totalCrawls++;

    try {
      await this.concurrencyController.acquire();

      const domain = this.extractDomain(task.url);
      if (domain) {
        await this.frequencyController.waitForPermission(domain);
      }

      const disguised = this.headerDisguiser.disguise(task.url);

      const proxyResult = this.proxyRotator.getNext();
      let proxyId = '';
      if (proxyResult.isOk()) {
        proxyId = proxyResult.data!.id;
      }

      const content = await this.retryHandler.executeWithRetry(
        async () => {
          return await this.fetchContent(task.url, disguised);
        }
      );

      if (content.isErr()) {
        this.concurrencyController.release();
        this.concurrencyController.recordFailure();
        if (domain) {
          this.failureDetector.recordFailure(task.rule);
        }
        if (proxyId) {
          this.proxyRotator.reportFailure(proxyId);
        }

        const failResult: CrawlResult = {
          taskId: task.id,
          success: false,
          error: content.error?.message ?? 'Request failed',
          degraded: false,
          responseTime: Date.now() - startTime,
          retryCount: task.retryCount,
        };
        return Result.ok(failResult);
      }

      const parseResult = this.parseEngine.parseWithDegradation(
        content.data!,
        task.rule,
        [],
        options
      );

      this.concurrencyController.release();
      const responseTime = Date.now() - startTime;
      this.concurrencyController.recordSuccess(responseTime);
      if (domain) {
        this.frequencyController.reportSuccess(domain);
      }
      if (proxyId) {
        this.proxyRotator.reportSuccess(proxyId);
      }

      if (parseResult.isOk()) {
        const degData = parseResult.data!;
        const degraded = degData instanceof DegradationResult && degData.isDegraded();
        if (degraded) this.degradedCrawls++;
        this.successCrawls++;
        this.totalResponseTime += responseTime;

        const successResult: CrawlResult = {
          taskId: task.id,
          success: true,
          data: degData.result.value,
          data_list: degData.result.values,
          degraded: degraded,
          degradationType: degData.degradationType as string,
          responseTime: responseTime,
          retryCount: task.retryCount,
        };
        return Result.ok(successResult);
      }

      const parseFailResult: CrawlResult = {
        taskId: task.id,
        success: false,
        error: parseResult.error?.message ?? 'Parse failed',
        degraded: false,
        responseTime: responseTime,
        retryCount: task.retryCount,
      };
      return Result.ok(parseFailResult);
    } catch (e) {
      this.concurrencyController.release();
      const message = e instanceof Error ? e.message : String(e);
      return Result.err(ErrorCode.NETWORK_ERROR, message);
    }
  }

  async crawlBatch(tasks: CrawlTask[], options?: ParseOptions): Promise<Result<BatchCrawlResult>> {
    const startTime = Date.now();
    const results: CrawlResult[] = [];

    const promises = tasks.map((task: CrawlTask) => this.crawl(task, options));
    const batchResults = await Promise.allSettled(promises);

    for (const r of batchResults) {
      if (r.status === 'fulfilled' && r.value.isOk()) {
        results.push(r.value.data!);
      } else if (r.status === 'fulfilled' && r.value.isErr()) {
        const errResult: CrawlResult = {
          taskId: '',
          success: false,
          error: r.value.error?.message ?? 'Unknown error',
          degraded: false,
          responseTime: 0,
          retryCount: 0,
        };
        results.push(errResult);
      } else {
        const rejectedResult: CrawlResult = {
          taskId: '',
          success: false,
          error: 'Batch task rejected',
          degraded: false,
          responseTime: 0,
          retryCount: 0,
        };
        results.push(rejectedResult);
      }
    }

    const successCount = results.filter((r: CrawlResult) => r.success && !r.degraded).length;
    const degradedCount = results.filter((r: CrawlResult) => r.degraded).length;
    const failureCount = results.filter((r: CrawlResult) => !r.success).length;

    const batchResult: BatchCrawlResult = {
      results: results,
      successCount: successCount,
      failureCount: failureCount,
      degradedCount: degradedCount,
      totalTimeMs: Date.now() - startTime,
    };
    return Result.ok(batchResult);
  }

  parseContent(content: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    return this.parseEngine.parse(content, rule, options);
  }

  validateRule(rule: string): RuleValidationReport {
    return this.parseEngine.validateRule(rule);
  }

  getMetrics(): CrawlerMetrics {
    const concurrencyMetrics = this.concurrencyController.getMetrics();
    const metrics: CrawlerMetrics = {
      concurrency: concurrencyMetrics,
      totalCrawls: this.totalCrawls,
      successRate: this.totalCrawls > 0 ? this.successCrawls / this.totalCrawls : 0,
      avgResponseTime: this.successCrawls > 0 ? this.totalResponseTime / this.successCrawls : 0,
      degradationRate: this.totalCrawls > 0 ? this.degradedCrawls / this.totalCrawls : 0,
      proxySuccessRate: 0,
      jsRenderUsageRate: 0,
    };
    return metrics;
  }

  updateConfig(config: CrawlerRuntimeConfig): void {
    if (config.concurrency) {
      this.concurrencyController.updateConfig(config.concurrency);
    }
    if (config.proxies) {
      this.proxyRotator.updateProxyList(config.proxies);
    }
    Logger.info(CrawlerFacade.TAG, 'Runtime config updated');
  }

  shutdown(): void {
    this.concurrencyController.shutdown();
    this.jsRenderScheduler.shutdown();
    Logger.info(CrawlerFacade.TAG, 'CrawlerFacade shutdown complete');
  }

  private initialize(): void {
    if (this.initialized) {
      return;
    }

    this.failureDetector = new RuleFailureDetector(this.config.failureDetector);
    this.isolationGuard = new ExceptionIsolationGuard();
    this.parseEngine = UnifiedParseEngine.getInstance();
    this.concurrencyController = new ConcurrencyController(this.config.concurrency);
    this.retryHandler = new ExponentialBackoffRetry();
    this.degradationManager = new RuleDegradationManager(
      this.failureDetector, this.isolationGuard, this.parseEngine, this.config.degradation
    );
    this.headerDisguiser = new HeaderCookieDisguiser();
    this.frequencyController = new DomainFrequencyController();
    this.proxyRotator = new ProxyRotator(this.config.antiCrawl.proxyStrategy);
    this.jsRenderScheduler = new JSRenderScheduler(
      this.config.antiCrawl.jsRenderMaxConcurrency,
      this.config.antiCrawl.jsRenderTimeoutMs,
      this.config.antiCrawl.jsRenderBlockResources
    );
    this.fingerprintRandomizer = new FingerprintRandomizer();

    this.initialized = true;
    Logger.info(CrawlerFacade.TAG, 'CrawlerFacade initialized');
  }

  private extractDomain(url: string): string {
    try {
      const urlObj = new URL(url);
      return urlObj.hostname;
    } catch (_) {
      return '';
    }
  }

  private async fetchContent(url: string, disguised: FetchDisguised): Promise<string> {
    return `<!-- fetched content from ${url} -->`;
  }
}
