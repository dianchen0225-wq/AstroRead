import { Result } from "../../../core/Result";
import { CrawlTask, CrawlResult, ConcurrencyConfig, ConcurrencyMetrics } from "./IConcurrency";
import { RetryConfig } from "./IStability";
import { AntiCrawlConfig, ProxyEntry } from "./IAntiCrawl";
import { RuleValidationReport } from "../../parser/interfaces/IUnifiedParseEngine";
import { ParserResult, ParseOptions } from "../../parser/IParser";

export interface BatchCrawlResult {
  results: CrawlResult[];
  successCount: number;
  failureCount: number;
  degradedCount: number;
  totalTimeMs: number;
}

export interface CrawlerMetrics {
  concurrency: ConcurrencyMetrics;
  totalCrawls: number;
  successRate: number;
  avgResponseTime: number;
  degradationRate: number;
  proxySuccessRate: number;
  jsRenderUsageRate: number;
}

export interface CrawlerRuntimeConfig {
  concurrency?: Partial<ConcurrencyConfig>;
  retry?: Partial<RetryConfig>;
  antiCrawl?: Partial<AntiCrawlConfig>;
  proxies?: ProxyEntry[];
}

export interface ICrawlerFacade {
  crawl(task: CrawlTask, options?: ParseOptions): Promise<Result<CrawlResult>>;
  crawlBatch(tasks: CrawlTask[], options?: ParseOptions): Promise<Result<BatchCrawlResult>>;
  parseContent(content: string, rule: string, options?: ParseOptions): Result<ParserResult>;
  validateRule(rule: string): RuleValidationReport;
  getMetrics(): CrawlerMetrics;
  updateConfig(config: CrawlerRuntimeConfig): void;
  shutdown(): void;
}
