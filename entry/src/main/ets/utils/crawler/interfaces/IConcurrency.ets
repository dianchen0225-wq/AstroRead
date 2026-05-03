import { Result } from "../../../core/Result";

export enum TaskPriority {
  HIGH = 0,
  NORMAL = 5,
  LOW = 10
}

export interface CrawlTask {
  id: string;
  url: string;
  rule: string;
  priority: TaskPriority;
  createdAt: number;
  retryCount: number;
  metadata?: Map<string, string>;
}

export interface CrawlResult {
  taskId: string;
  success: boolean;
  data?: string;
  data_list?: string[];
  error?: string;
  degraded: boolean;
  degradationType?: string;
  responseTime: number;
  retryCount: number;
}

export interface ConcurrencyConfig {
  maxConcurrency: number;
  minConcurrency: number;
  defaultConcurrency: number;
  queueCapacity: number;
  ratePerSecond: number;
  enableDynamicAdjustment: boolean;
  latencyThresholdMs: number;
  errorRateThreshold: number;
  successWindowSize: number;
  aimdReduceStep: number;
  aimdIncreaseStep: number;
}

export interface ConcurrencyMetrics {
  activeRequests: number;
  queuedRequests: number;
  completedRequests: number;
  failedRequests: number;
  avgResponseTime: number;
  currentConcurrency: number;
  currentRatePerSecond: number;
}

export interface IConcurrencyController {
  submit(task: CrawlTask): Result<void>;
  acquire(): Promise<void>;
  release(): void;
  getMetrics(): ConcurrencyMetrics;
  updateConfig(config: Partial<ConcurrencyConfig>): void;
  shutdown(): void;
}

export interface IPriorityScheduler {
  enqueue(task: CrawlTask): Result<void>;
  dequeue(): CrawlTask | null;
  peek(): CrawlTask | null;
  size(): number;
  clear(): void;
  isFull(): boolean;
}

export interface IConnectionPoolManager {
  acquire(domain: string): Promise<ConnectionHandle>;
  release(handle: ConnectionHandle): void;
  getMetrics(): ConnectionPoolMetrics;
  cleanup(): number;
  shutdown(): void;
}

export interface ConnectionHandle {
  id: string;
  domain: string;
  createdAt: number;
  lastUsedAt: number;
  isActive: boolean;
}

export interface ConnectionPoolMetrics {
  totalConnections: number;
  activeConnections: number;
  idleConnections: number;
  domainStats: Map<string, DomainConnectionStats>;
  memoryUsageBytes: number;
}

export interface DomainConnectionStats {
  domain: string;
  total: number;
  active: number;
  idle: number;
}

export interface IRateSmoother {
  wait(): Promise<void>;
  updateRate(ratePerSecond: number): void;
  getRate(): number;
  getWaitTimeMs(): number;
}

export interface IDynamicAdjuster {
  onSuccess(responseTimeMs: number): void;
  onFailure(): void;
  getCurrentConcurrency(): number;
  getCurrentRate(): number;
  reset(): void;
}
