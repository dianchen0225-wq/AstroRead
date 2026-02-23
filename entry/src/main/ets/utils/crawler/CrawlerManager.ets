import { Logger } from "../performance/Logger";

export interface ProxyConfig {
  host: string;
  port: number;
  username?: string;
  password?: string;
  protocol: 'http' | 'https' | 'socks5';
  enabled: boolean;
  lastUsed: number;
  failCount: number;
  successCount: number;
  avgResponseTime: number;
}

export interface RateLimitConfig {
  requestsPerSecond: number;
  burstSize: number;
  minInterval: number;
  maxInterval: number;
  adaptiveMode: boolean;
}

export interface AntiDetectionConfig {
  rotateUserAgent: boolean;
  rotateReferer: boolean;
  simulateHumanBehavior: boolean;
  randomDelay: boolean;
  cookieHandling: boolean;
  javascriptRendering: boolean;
}

export interface RetryStrategyConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  exponentialBackoff: boolean;
  jitter: boolean;
  retryableStatusCodes: number[];
  retryableErrors: string[];
}

export interface DataValidationConfig {
  requiredFields: string[];
  minContentLength: number;
  maxContentLength: number;
  validateEncoding: boolean;
  stripHtmlTags: boolean;
  normalizeWhitespace: boolean;
}

export interface DataValidationResult {
  valid: boolean;
  errors: string[];
}

export interface CrawlerConfig {
  userAgentPool: string[];
  refererPool: string[];
  proxyPool: ProxyConfig[];
  rateLimit: RateLimitConfig;
  antiDetection: AntiDetectionConfig;
  retryStrategy: RetryStrategyConfig;
  dataValidation: DataValidationConfig;
  timeout: number;
  maxConcurrent: number;
  respectRobotsTxt: boolean;
  debugMode: boolean;
}

export interface CrawlerMetrics {
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  totalBytes: number;
  avgResponseTime: number;
  proxySuccessRate: number;
  blockedRequests: number;
  captchaEncountered: number;
  lastResetTime: number;
}

export interface RequestResult {
  success: boolean;
  data?: string;
  error?: string;
  statusCode?: number;
  responseTime: number;
  usedProxy?: string;
  usedUserAgent?: string;
  retryCount: number;
  blocked: boolean;
  captcha: boolean;
}

const DEFAULT_USER_AGENTS: string[] = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
  'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
];

const DEFAULT_REFERERS: string[] = [
  'https://www.google.com/',
  'https://www.baidu.com/',
  'https://www.bing.com/',
  'https://www.sogou.com/',
  'https://www.so.com/',
  'https://www.google.com.hk/',
  'https://www.douban.com/',
  'https://www.zhihu.com/',
  'https://www.bilibili.com/',
  'https://www.weibo.com/'
];

const DEFAULT_RATE_LIMIT: RateLimitConfig = {
  requestsPerSecond: 2,
  burstSize: 5,
  minInterval: 200,
  maxInterval: 5000,
  adaptiveMode: true
};

const DEFAULT_ANTI_DETECTION: AntiDetectionConfig = {
  rotateUserAgent: true,
  rotateReferer: true,
  simulateHumanBehavior: true,
  randomDelay: true,
  cookieHandling: true,
  javascriptRendering: false
};

const DEFAULT_RETRY_STRATEGY: RetryStrategyConfig = {
  maxRetries: 3,
  baseDelay: 1000,
  maxDelay: 30000,
  exponentialBackoff: true,
  jitter: true,
  retryableStatusCodes: [408, 429, 500, 502, 503, 504],
  retryableErrors: ['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED', 'ENOTFOUND', 'ENETDOWN', 'ENETUNREACH', 'EAI_AGAIN']
};

const DEFAULT_DATA_VALIDATION: DataValidationConfig = {
  requiredFields: [],
  minContentLength: 100,
  maxContentLength: 50 * 1024 * 1024,
  validateEncoding: true,
  stripHtmlTags: false,
  normalizeWhitespace: true
};

const BLOCK_PATTERNS: string[] = [
  'access denied',
  'blocked',
  'captcha',
  'cloudflare',
  '请验证',
  '人机验证',
  '安全验证',
  '访问频率过高',
  '请求过于频繁',
  'ip.*被封',
  'forbidden',
  'rate limit',
  'too many requests'
];

const CAPTCHA_PATTERNS: string[] = [
  'captcha',
  'recaptcha',
  'hcaptcha',
  '验证码',
  '滑动验证',
  '图形验证',
  'geetest',
  '极验'
];

export class CrawlerManager {
  private static instance: CrawlerManager | null = null;
  private config: CrawlerConfig;
  private metrics: CrawlerMetrics;
  private requestHistory: Map<string, number[]> = new Map();
  private domainLastRequest: Map<string, number> = new Map();
  private currentUserAgentIndex: number = 0;
  private currentProxyIndex: number = 0;
  private readonly TAG = 'CrawlerManager';

  private constructor() {
    this.config = this.createDefaultConfig();
    this.metrics = this.createInitialMetrics();
  }

  static getInstance(): CrawlerManager {
    if (!CrawlerManager.instance) {
      CrawlerManager.instance = new CrawlerManager();
    }
    return CrawlerManager.instance;
  }

  private createDefaultConfig(): CrawlerConfig {
    return {
      userAgentPool: DEFAULT_USER_AGENTS,
      refererPool: DEFAULT_REFERERS,
      proxyPool: [],
      rateLimit: DEFAULT_RATE_LIMIT,
      antiDetection: DEFAULT_ANTI_DETECTION,
      retryStrategy: DEFAULT_RETRY_STRATEGY,
      dataValidation: DEFAULT_DATA_VALIDATION,
      timeout: 30000,
      maxConcurrent: 5,
      respectRobotsTxt: true,
      debugMode: false
    };
  }

  private createInitialMetrics(): CrawlerMetrics {
    return {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalBytes: 0,
      avgResponseTime: 0,
      proxySuccessRate: 100,
      blockedRequests: 0,
      captchaEncountered: 0,
      lastResetTime: Date.now()
    };
  }

  updateConfig(newConfig: Partial<CrawlerConfig>): void {
    this.config = this.mergeConfig(this.config, newConfig);
    Logger.info(this.TAG, '爬虫配置已更新');
  }

  private mergeConfig(base: CrawlerConfig, update: Partial<CrawlerConfig>): CrawlerConfig {
    const result: CrawlerConfig = {
      userAgentPool: update.userAgentPool !== undefined ? update.userAgentPool : base.userAgentPool,
      refererPool: update.refererPool !== undefined ? update.refererPool : base.refererPool,
      proxyPool: update.proxyPool !== undefined ? update.proxyPool : base.proxyPool,
      rateLimit: update.rateLimit !== undefined ? update.rateLimit : base.rateLimit,
      antiDetection: update.antiDetection !== undefined ? update.antiDetection : base.antiDetection,
      retryStrategy: update.retryStrategy !== undefined ? update.retryStrategy : base.retryStrategy,
      dataValidation: update.dataValidation !== undefined ? update.dataValidation : base.dataValidation,
      timeout: update.timeout !== undefined ? update.timeout : base.timeout,
      maxConcurrent: update.maxConcurrent !== undefined ? update.maxConcurrent : base.maxConcurrent,
      respectRobotsTxt: update.respectRobotsTxt !== undefined ? update.respectRobotsTxt : base.respectRobotsTxt,
      debugMode: update.debugMode !== undefined ? update.debugMode : base.debugMode
    };
    return result;
  }

  getConfig(): CrawlerConfig {
    return this.cloneConfig(this.config);
  }

  private cloneConfig(config: CrawlerConfig): CrawlerConfig {
    return {
      userAgentPool: config.userAgentPool.slice(),
      refererPool: config.refererPool.slice(),
      proxyPool: config.proxyPool.slice(),
      rateLimit: config.rateLimit,
      antiDetection: config.antiDetection,
      retryStrategy: config.retryStrategy,
      dataValidation: config.dataValidation,
      timeout: config.timeout,
      maxConcurrent: config.maxConcurrent,
      respectRobotsTxt: config.respectRobotsTxt,
      debugMode: config.debugMode
    };
  }

  getMetrics(): CrawlerMetrics {
    return this.cloneMetrics(this.metrics);
  }

  private cloneMetrics(metrics: CrawlerMetrics): CrawlerMetrics {
    return {
      totalRequests: metrics.totalRequests,
      successfulRequests: metrics.successfulRequests,
      failedRequests: metrics.failedRequests,
      totalBytes: metrics.totalBytes,
      avgResponseTime: metrics.avgResponseTime,
      proxySuccessRate: metrics.proxySuccessRate,
      blockedRequests: metrics.blockedRequests,
      captchaEncountered: metrics.captchaEncountered,
      lastResetTime: metrics.lastResetTime
    };
  }

  resetMetrics(): void {
    this.metrics = this.createInitialMetrics();
    Logger.info(this.TAG, '爬虫指标已重置');
  }

  getNextUserAgent(): string {
    if (!this.config.antiDetection.rotateUserAgent) {
      return this.config.userAgentPool[0];
    }
    const ua = this.config.userAgentPool[this.currentUserAgentIndex];
    this.currentUserAgentIndex = (this.currentUserAgentIndex + 1) % this.config.userAgentPool.length;
    return ua;
  }

  getNextReferer(baseUrl?: string): string {
    if (baseUrl && !this.config.antiDetection.rotateReferer) {
      return baseUrl;
    }
    const index = Math.floor(Math.random() * this.config.refererPool.length);
    return this.config.refererPool[index];
  }

  addProxy(proxy: ProxyConfig): void {
    this.config.proxyPool.push(proxy);
    Logger.info(this.TAG, `添加代理: ${proxy.host}:${proxy.port}`);
  }

  removeProxy(host: string, port: number): void {
    const index = this.config.proxyPool.findIndex(p => p.host === host && p.port === port);
    if (index !== -1) {
      this.config.proxyPool.splice(index, 1);
      Logger.info(this.TAG, `移除代理: ${host}:${port}`);
    }
  }

  getNextProxy(): ProxyConfig | null {
    const enabledProxies = this.config.proxyPool.filter(p => p.enabled);
    if (enabledProxies.length === 0) {
      return null;
    }

    const sortedProxies = enabledProxies.sort((a, b) => {
      const scoreA = a.successCount / (a.failCount + 1) - a.failCount * 0.5;
      const scoreB = b.successCount / (b.failCount + 1) - b.failCount * 0.5;
      return scoreB - scoreA;
    });

    const proxy = sortedProxies[this.currentProxyIndex % sortedProxies.length];
    this.currentProxyIndex++;
    proxy.lastUsed = Date.now();
    return proxy;
  }

  reportProxyResult(host: string, port: number, success: boolean, responseTime: number): void {
    const proxy = this.config.proxyPool.find(p => p.host === host && p.port === port);
    if (proxy) {
      if (success) {
        proxy.successCount++;
        proxy.avgResponseTime = (proxy.avgResponseTime * (proxy.successCount - 1) + responseTime) / proxy.successCount;
      } else {
        proxy.failCount++;
        if (proxy.failCount >= 5) {
          proxy.enabled = false;
          Logger.warn(this.TAG, `代理 ${host}:${port} 已禁用（连续失败次数过多）`);
        }
      }
    }
  }

  async waitForRateLimit(domain: string): Promise<void> {
    const now = Date.now();
    const lastRequest = this.domainLastRequest.get(domain) || 0;
    const elapsed = now - lastRequest;

    let delay = this.config.rateLimit.minInterval;

    if (this.config.rateLimit.adaptiveMode) {
      const history = this.requestHistory.get(domain) || [];
      const recentRequests = history.filter(t => now - t < 60000);
      const requestRate = recentRequests.length / 60;

      if (requestRate > this.config.rateLimit.requestsPerSecond * 0.8) {
        delay = Math.min(delay * 2, this.config.rateLimit.maxInterval);
      } else if (requestRate < this.config.rateLimit.requestsPerSecond * 0.3) {
        delay = Math.max(delay / 2, this.config.rateLimit.minInterval);
      }
    }

    if (this.config.antiDetection.randomDelay) {
      delay += Math.random() * delay * 0.3;
    }

    if (elapsed < delay) {
      const waitTime = delay - elapsed;
      Logger.debug(this.TAG, `等待 ${waitTime}ms 以遵守速率限制 (${domain})`);
      await this.sleep(waitTime);
    }

    this.domainLastRequest.set(domain, now);
    const history = this.requestHistory.get(domain) || [];
    history.push(now);
    this.requestHistory.set(domain, history);
  }

  calculateRetryDelay(attempt: number): number {
    const strategy = this.config.retryStrategy;
    let delay = strategy.baseDelay;

    if (strategy.exponentialBackoff) {
      delay = strategy.baseDelay * Math.pow(2, attempt);
    }

    if (strategy.jitter) {
      delay += Math.random() * delay * 0.3;
    }

    return Math.min(delay, strategy.maxDelay);
  }

  shouldRetry(error: string, statusCode?: number): boolean {
    const strategy = this.config.retryStrategy;

    if (statusCode && strategy.retryableStatusCodes.includes(statusCode)) {
      return true;
    }

    const lowerError = error.toLowerCase();
    for (const retryableError of strategy.retryableErrors) {
      if (lowerError.includes(retryableError.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  detectBlocking(content: string): boolean {
    const lowerContent = content.toLowerCase();
    for (const pattern of BLOCK_PATTERNS) {
      if (lowerContent.match(new RegExp(pattern, 'i'))) {
        return true;
      }
    }
    return false;
  }

  detectCaptcha(content: string): boolean {
    const lowerContent = content.toLowerCase();
    for (const pattern of CAPTCHA_PATTERNS) {
      if (lowerContent.includes(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  validateData(data: string): DataValidationResult {
    const errors: string[] = [];
    const validation = this.config.dataValidation;

    if (data.length < validation.minContentLength) {
      errors.push(`内容长度 ${data.length} 小于最小值 ${validation.minContentLength}`);
    }

    if (data.length > validation.maxContentLength) {
      errors.push(`内容长度 ${data.length} 超过最大值 ${validation.maxContentLength}`);
    }

    if (validation.validateEncoding) {
      const replacementCount = (data.match(/\uFFFD/g) || []).length;
      if (replacementCount / data.length > 0.05) {
        errors.push('内容包含过多乱码字符，可能编码错误');
      }
    }

    const result: DataValidationResult = {
      valid: errors.length === 0,
      errors
    };
    return result;
  }

  cleanData(data: string): string {
    let result = data;

    if (this.config.dataValidation.stripHtmlTags) {
      result = result.replace(/<[^>]+>/g, '');
    }

    if (this.config.dataValidation.normalizeWhitespace) {
      result = result.replace(/\s+/g, ' ').trim();
    }

    return result;
  }

  recordRequest(result: RequestResult): void {
    this.metrics.totalRequests++;

    if (result.success) {
      this.metrics.successfulRequests++;
      if (result.data) {
        this.metrics.totalBytes += result.data.length;
      }
    } else {
      this.metrics.failedRequests++;
    }

    if (result.blocked) {
      this.metrics.blockedRequests++;
    }

    if (result.captcha) {
      this.metrics.captchaEncountered++;
    }

    const totalResponseTime = this.metrics.avgResponseTime * (this.metrics.totalRequests - 1) + result.responseTime;
    this.metrics.avgResponseTime = totalResponseTime / this.metrics.totalRequests;
  }

  generateReport(): string {
    const successRate = this.metrics.totalRequests > 0
      ? ((this.metrics.successfulRequests / this.metrics.totalRequests) * 100).toFixed(2)
      : '0.00';

    const blockRate = this.metrics.totalRequests > 0
      ? ((this.metrics.blockedRequests / this.metrics.totalRequests) * 100).toFixed(2)
      : '0.00';

    return `
爬虫运行报告
============
总请求数: ${this.metrics.totalRequests}
成功请求: ${this.metrics.successfulRequests} (${successRate}%)
失败请求: ${this.metrics.failedRequests}
被阻止请求: ${this.metrics.blockedRequests} (${blockRate}%)
验证码次数: ${this.metrics.captchaEncountered}
平均响应时间: ${this.metrics.avgResponseTime.toFixed(0)}ms
总传输量: ${(this.metrics.totalBytes / 1024 / 1024).toFixed(2)}MB
代理池大小: ${this.config.proxyPool.length}
User-Agent池大小: ${this.config.userAgentPool.length}
`;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export default CrawlerManager.getInstance();
