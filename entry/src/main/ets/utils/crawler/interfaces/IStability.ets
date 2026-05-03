import { Result } from "../../../core/Result";
import { ParserResult } from "../../parser/IParser";
import { DegradationResult, DegradationType } from "../models/DegradationResult";

export interface RetryConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  backoffFactor: number;
  jitterMs: number;
  retryableStatusCodes: number[];
}

export interface RetryMetrics {
  totalAttempts: number;
  totalRetries: number;
  exhaustedRetries: number;
  avgRetryDelay: number;
}

export interface IExponentialBackoffRetry {
  executeWithRetry<T>(fn: () => Promise<T>, config?: Partial<RetryConfig>): Promise<Result<T>>;
  calculateDelay(attempt: number, config?: RetryConfig): number;
  isRetryable(statusCode: number): boolean;
  getMetrics(): RetryMetrics;
}

export interface RuleDegradationConfig {
  maxFallbackRules: number;
  enableLooseMatch: boolean;
  failureThreshold: number;
  failureWindowMs: number;
}

export interface IRuleDegradationManager {
  tryDegradation(
    content: string,
    mainRule: string,
    fallbackRules: string[],
    options?: Record<string, string>
  ): Promise<Result<DegradationResult>>;
  addFallbackRule(ruleId: string, fallbackRule: string): void;
  removeFallbackRule(ruleId: string, fallbackRule: string): void;
  getConfig(): RuleDegradationConfig;
}

export interface IExceptionIsolationGuard {
  executeSafely<T>(fn: () => T): Result<T>;
  executeIsolated<T>(fns: (() => T)[], index: number): Result<T>[];
}

export interface RuleFailureRecord {
  rule: string;
  failureCount: number;
  lastFailureTime: number;
  firstFailureTime: number;
  suspectedFailed: boolean;
}

export interface IRuleFailureDetector {
  recordFailure(rule: string): void;
  recordSuccess(rule: string): void;
  isRuleSuspectedFailed(rule: string): boolean;
  getFailedRules(): RuleFailureRecord[];
  reset(rule: string): void;
  getConfig(): RuleFailureDetectorConfig;
}

export interface RuleFailureDetectorConfig {
  failureThreshold: number;
  windowMs: number;
  autoRecoveryMs: number;
}
