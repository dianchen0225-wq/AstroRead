import { Logger } from "../performance/Logger";
import { CrawlerManager } from "./CrawlerManager";
import { RequestThrottler } from "./RequestThrottler";
import { CrawlerMonitor } from "./CrawlerMonitor";
import { DataValidator } from "../validation/DataValidator";

export interface CrawlerRequestOptions {
  url: string;
  method?: 'GET' | 'POST';
  body?: string;
  headers?: Map<string, string>;
  timeout?: number;
  maxRetries?: number;
  validateContent?: boolean;
  cleanContent?: boolean;
  skipRateLimit?: boolean;
  priority?: 'high' | 'normal' | 'low';
}

export interface CrawlerResponseMetadata {
  usedUserAgent?: string;
  usedProxy?: string;
  domain: string;
  contentLength: number;
  validationErrors: string[];
  validationWarnings: string[];
}

export interface CrawlerResponse {
  success: boolean;
  data?: string;
  error?: string;
  statusCode?: number;
  responseTime: number;
  retryCount: number;
  blocked: boolean;
  captcha: boolean;
  validated: boolean;
  cleaned: boolean;
  metadata: CrawlerResponseMetadata;
}

export interface BatchRequestOptions {
  urls: string[];
  concurrent?: number;
  stopOnError?: boolean;
  progressCallback?: (completed: number, total: number, result: CrawlerResponse) => void;
}

export interface BatchResult {
  results: CrawlerResponse[];
  successful: number;
  failed: number;
  blocked: number;
  totalTime: number;
}

type HttpRequestFunction = (url: string, headers?: Map<string, string>, timeout?: number) => Promise<string>;
type HttpPostFunction = (url: string, body: string, headers?: Map<string, string>, timeout?: number) => Promise<string>;

export class CrawlerRequestHandler {
  private static instance: CrawlerRequestHandler | null = null;
  private crawlerManager: CrawlerManager;
  private throttler: RequestThrottler;
  private monitor: CrawlerMonitor;
  private validator: DataValidator;
  private httpGet: HttpRequestFunction | null = null;
  private httpPost: HttpPostFunction | null = null;
  private readonly TAG = 'CrawlerRequestHandler';

  private constructor() {
    this.crawlerManager = CrawlerManager.getInstance();
    this.throttler = RequestThrottler.getInstance();
    this.monitor = CrawlerMonitor.getInstance();
    this.validator = DataValidator.getInstance();
  }

  static getInstance(): CrawlerRequestHandler {
    if (!CrawlerRequestHandler.instance) {
      CrawlerRequestHandler.instance = new CrawlerRequestHandler();
    }
    return CrawlerRequestHandler.instance;
  }

  setHttpFunctions(get: HttpRequestFunction, post: HttpPostFunction): void {
    this.httpGet = get;
    this.httpPost = post;
    Logger.info(this.TAG, 'HTTP函数已配置');
  }

  async fetch(options: CrawlerRequestOptions): Promise<CrawlerResponse> {
    const startTime = Date.now();
    const domain = this.extractDomain(options.url);
    const metadata: CrawlerResponseMetadata = {
      domain,
      contentLength: 0,
      validationErrors: [],
      validationWarnings: []
    };

    const result: CrawlerResponse = {
      success: false,
      responseTime: 0,
      retryCount: 0,
      blocked: false,
      captcha: false,
      validated: false,
      cleaned: false,
      metadata
    };

    if (!options.skipRateLimit) {
      await this.throttler.acquire(options.url);
    }

    const userAgent = this.crawlerManager.getNextUserAgent();
    metadata.usedUserAgent = userAgent;

    const enhancedHeaders = this.buildEnhancedHeaders(options.headers, userAgent, options.url);

    const maxRetries = options.maxRetries ?? this.crawlerManager.getConfig().retryStrategy.maxRetries;
    let lastError: string = '';

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const requestStartTime = Date.now();
        let responseText: string;

        if (options.method === 'POST') {
          if (!this.httpPost) {
            throw new Error('HTTP POST函数未配置');
          }
          responseText = await this.httpPost(options.url, options.body || '', enhancedHeaders, options.timeout);
        } else {
          if (!this.httpGet) {
            throw new Error('HTTP GET函数未配置');
          }
          responseText = await this.httpGet(options.url, enhancedHeaders, options.timeout);
        }

        const responseTime = Date.now() - requestStartTime;
        result.responseTime = Date.now() - startTime;
        result.retryCount = attempt;
        result.statusCode = 200;
        metadata.contentLength = responseText.length;

        if (this.crawlerManager.detectBlocking(responseText)) {
          result.blocked = true;
          this.throttler.recordBlock(options.url);
          this.monitor.logBlock(options.url, '检测到阻止响应');

          if (attempt < maxRetries) {
            const delay = this.crawlerManager.calculateRetryDelay(attempt);
            Logger.warn(this.TAG, `检测到阻止，${delay}ms后重试: ${options.url}`);
            await this.sleep(delay);
            continue;
          }
        }

        if (this.crawlerManager.detectCaptcha(responseText)) {
          result.captcha = true;
          this.monitor.logCaptcha(options.url);
        }

        if (options.validateContent) {
          const validationResult = this.validator.validateContent(responseText);
          result.validated = true;
          metadata.validationErrors = validationResult.errors;
          metadata.validationWarnings = validationResult.warnings;

          if (!validationResult.valid) {
            Logger.warn(this.TAG, `内容验证失败: ${validationResult.errors.join(', ')}`);
          }
        }

        if (options.cleanContent) {
          responseText = this.validator.cleanContent(responseText);
          result.cleaned = true;
        }

        result.success = !result.blocked;
        result.data = responseText;

        this.throttler.recordSuccess(options.url, responseTime);
        this.monitor.logRequest(options.url, 200, responseTime, true, responseText.length);

        this.crawlerManager.recordRequest({
          success: true,
          data: responseText,
          responseTime,
          usedUserAgent: userAgent,
          retryCount: attempt,
          blocked: result.blocked,
          captcha: result.captcha
        });

        return result;

      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);
        result.retryCount = attempt;

        this.throttler.recordFailure(options.url, lastError);

        if (this.crawlerManager.shouldRetry(lastError)) {
          if (attempt < maxRetries) {
            const delay = this.crawlerManager.calculateRetryDelay(attempt);
            Logger.warn(this.TAG, `请求失败，${delay}ms后重试 (${attempt + 1}/${maxRetries}): ${lastError}`);
            await this.sleep(delay);
            continue;
          }
        }

        break;
      }
    }

    result.success = false;
    result.error = lastError;
    result.responseTime = Date.now() - startTime;

    this.monitor.logError(options.url, lastError);
    this.crawlerManager.recordRequest({
      success: false,
      error: lastError,
      responseTime: result.responseTime,
      usedUserAgent: userAgent,
      retryCount: result.retryCount,
      blocked: false,
      captcha: false
    });

    return result;
  }

  async fetchBatch(options: BatchRequestOptions): Promise<BatchResult> {
    const startTime = Date.now();
    const results: CrawlerResponse[] = [];
    let successful = 0;
    let failed = 0;
    let blocked = 0;
    const concurrent = options.concurrent ?? this.crawlerManager.getConfig().maxConcurrent;

    this.monitor.startSession();

    const chunks: string[][] = [];
    for (let i = 0; i < options.urls.length; i += concurrent) {
      chunks.push(options.urls.slice(i, i + concurrent));
    }

    for (const chunk of chunks) {
      const promises = chunk.map(url => this.fetch({ url }));

      const chunkResults = await Promise.all(promises);

      for (const result of chunkResults) {
        results.push(result);

        if (result.success) {
          successful++;
        } else {
          failed++;
        }
        if (result.blocked) {
          blocked++;
        }

        if (options.progressCallback) {
          options.progressCallback(results.length, options.urls.length, result);
        }

        if (options.stopOnError && !result.success) {
          this.monitor.endSession();
          return {
            results,
            successful,
            failed,
            blocked,
            totalTime: Date.now() - startTime
          };
        }
      }
    }

    this.monitor.endSession();

    return {
      results,
      successful,
      failed,
      blocked,
      totalTime: Date.now() - startTime
    };
  }

  async fetchWithFallback(primaryUrl: string, fallbackUrls: string[], options?: Partial<CrawlerRequestOptions>): Promise<CrawlerResponse> {
    const allUrls: string[] = [primaryUrl];
    for (let i = 0; i < fallbackUrls.length; i++) {
      allUrls.push(fallbackUrls[i]);
    }

    for (const url of allUrls) {
      const requestOptions: CrawlerRequestOptions = {
        url: url,
        method: options?.method,
        body: options?.body,
        headers: options?.headers,
        timeout: options?.timeout,
        maxRetries: options?.maxRetries,
        validateContent: options?.validateContent,
        cleanContent: options?.cleanContent,
        skipRateLimit: options?.skipRateLimit,
        priority: options?.priority
      };
      const result = await this.fetch(requestOptions);

      if (result.success && !result.blocked) {
        return result;
      }

      Logger.warn(this.TAG, `URL失败，尝试下一个: ${url}`);
    }

    const failureMetadata: CrawlerResponseMetadata = {
      domain: this.extractDomain(primaryUrl),
      contentLength: 0,
      validationErrors: ['所有URL均失败'],
      validationWarnings: []
    };
    const failureResponse: CrawlerResponse = {
      success: false,
      error: '所有URL均失败',
      responseTime: 0,
      retryCount: 0,
      blocked: false,
      captcha: false,
      validated: false,
      cleaned: false,
      metadata: failureMetadata
    };
    return failureResponse;
  }

  private buildEnhancedHeaders(customHeaders?: Map<string, string>, userAgent?: string, url?: string): Map<string, string> {
    const headers = new Map<string, string>();

    headers.set('User-Agent', userAgent || this.crawlerManager.getNextUserAgent());
    headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    headers.set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
    headers.set('Accept-Encoding', 'gzip, deflate');
    headers.set('Connection', 'keep-alive');
    headers.set('Cache-Control', 'max-age=0');

    if (url) {
      headers.set('Referer', this.crawlerManager.getNextReferer(url));
    }

    if (customHeaders) {
      customHeaders.forEach((value, key) => {
        headers.set(key, value);
      });
    }

    return headers;
  }

  getStatistics(): string {
    return `
爬虫请求处理器统计
==================
${this.crawlerManager.generateReport()}

${this.throttler.generateReport()}

${this.monitor.generateReport()}
`;
  }

  reset(): void {
    this.crawlerManager.resetMetrics();
    this.throttler.resetAllStats();
    this.monitor.clearLogs();
    this.monitor.clearSessions();
    Logger.info(this.TAG, '爬虫请求处理器已重置');
  }

  private extractDomain(url: string): string {
    try {
      const match = url.match(/^https?:\/\/([^/:]+)/);
      return match ? match[1].toLowerCase() : url;
    } catch {
      return url;
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export default CrawlerRequestHandler.getInstance();
