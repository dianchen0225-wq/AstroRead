import { Result } from "../../../core/Result";

export interface DisguisedRequest {
  url: string;
  headers: Map<string, string>;
  cookie: string;
  proxyHost: string;
  proxyPort: number;
}

export interface ProxyEntry {
  id: string;
  host: string;
  port: number;
  username?: string;
  password?: string;
  protocol: string;
  failCount: number;
  successCount: number;
  lastUsed: number;
  lastFailed: number;
  available: boolean;
}

export enum ProxyStrategy {
  ROUND_ROBIN = 'round_robin',
  RANDOM = 'random',
  LEAST_FAILURES = 'least_failures'
}

export interface AntiCrawlConfig {
  rotateUserAgent: boolean;
  rotateHeaders: boolean;
  manageCookies: boolean;
  defaultRatePerSecond: number;
  minRatePerSecond: number;
  maxRatePerSecond: number;
  rateReductionFactor: number;
  rateRecoveryStep: number;
  successWindowForRecovery: number;
  proxyStrategy: ProxyStrategy;
  proxyFailureThreshold: number;
  proxyRecoveryMs: number;
  jsRenderMaxConcurrency: number;
  jsRenderTimeoutMs: number;
  jsRenderBlockResources: string[];
  fingerprintJitterMs: number;
}

export interface DomainRateState {
  domain: string;
  currentRate: number;
  consecutiveSuccesses: number;
  lastRequestTime: number;
  tokens: number;
  lastRefillTime: number;
}

export interface IHeaderCookieDisguiser {
  disguise(url: string, existingHeaders?: Map<string, string>): DisguisedRequest;
  updateCookies(url: string, setCookieHeader: string): void;
  clearDomainCookies(domain: string): void;
  getDomainCookies(domain: string): string;
}

export interface IDomainFrequencyController {
  waitForPermission(domain: string): Promise<void>;
  reportSuccess(domain: string): void;
  reportThrottled(domain: string): void;
  setDomainRate(domain: string, ratePerSecond: number): void;
  getDomainState(domain: string): DomainRateState | null;
  getMetrics(): FrequencyControlMetrics;
}

export interface FrequencyControlMetrics {
  totalRequests: number;
  throttledRequests: number;
  domainCount: number;
  avgRatePerSecond: number;
}

export interface IProxyRotator {
  getNext(): Result<ProxyEntry>;
  reportSuccess(proxyId: string): void;
  reportFailure(proxyId: string): void;
  updateProxyList(proxies: ProxyEntry[]): void;
  removeProxy(proxyId: string): boolean;
  isAvailable(): boolean;
  getAvailableCount(): number;
}

export interface JSRenderResult {
  html: string;
  renderTimeMs: number;
  success: boolean;
  error?: string;
}

export interface IJSRenderScheduler {
  render(url: string, options?: JSRenderOptions): Promise<Result<JSRenderResult>>;
  isAvailable(): boolean;
  getConcurrency(): number;
  shutdown(): void;
}

export interface JSRenderOptions {
  timeoutMs?: number;
  blockResources?: string[];
  waitForSelector?: string;
  userAgent?: string;
}

export interface IFingerprintRandomizer {
  addJitter(baseMs: number): number;
  shuffleHeaderOrder(headers: Map<string, string>): Map<string, string>;
  randomizeRequestTiming(baseIntervalMs: number): number;
}
