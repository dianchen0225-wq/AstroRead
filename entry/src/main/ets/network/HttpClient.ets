/**
 * HttpClient - 统一网络请求客户端
 * 提供统一的 HTTP 请求服务
 */

import http from '@ohos.net.http';
import {
  IHttpClient,
  HttpClientConfig,
  HttpRequestConfig,
  HttpResponse,
  HttpMethod,
  RequestMetrics,
  RequestInterceptor,
  ResponseInterceptor,
  CacheStats,
  HttpData
} from './interfaces/IHttpClient';
import { HttpErrorImpl } from './HttpError';
import { InterceptorManager } from './InterceptorManager';
import RequestCache from './RequestCache';
import RetryHandler from './RetryHandler';
import { AbortManager, AbortControllerImpl } from './AbortController';
import { ConfigManager, DEFAULTS } from './HttpClientConfig';
import { CookieManager } from './CookieManager';
import { RequestBuilder } from './RequestBuilder';
import { ResponseParser } from './ResponseParser';
import { MetricsCollector } from './MetricsCollector';

/**
 * HTTP客户端
 */
export class HttpClient implements IHttpClient {
  private static instance: HttpClient | null = null;

  private configManager: ConfigManager;
  private cookieManager: CookieManager;
  private metricsCollector: MetricsCollector;
  private interceptors: InterceptorManager;
  private requestIdCounter: number = 0;

  private readonly TAG = 'HttpClient';

  private constructor(config?: HttpClientConfig) {
    this.configManager = new ConfigManager(config);
    this.cookieManager = new CookieManager();
    this.interceptors = new InterceptorManager();
    this.metricsCollector = new MetricsCollector(
      this.TAG,
      this.configManager.getConfig().enableLogging,
      this.configManager.getConfig().enableMetrics
    );

    this.setupDefaultInterceptors();
  }

  /**
   * 获取单例实例
   */
  static getInstance(config?: HttpClientConfig): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient(config);
    }
    return HttpClient.instance;
  }

  /**
   * 设置默认拦截器
   */
  private setupDefaultInterceptors(): void {
    // 请求拦截器：添加默认头和Cookie
    this.interceptors.useRequestInterceptor(
      (config: HttpRequestConfig) => this.applyDefaultHeaders(config),
      undefined,
      { priority: 100, id: 'default-headers' }
    );

    // 响应拦截器：处理Set-Cookie
    this.interceptors.useResponseInterceptor(
      (response: HttpResponse<void>) => this.handleResponseCookie(response),
      undefined,
      { priority: 100, id: 'cookie-handler' }
    );
  }

  /**
   * 应用默认请求头
   */
  private applyDefaultHeaders(config: HttpRequestConfig): HttpRequestConfig {
    const headers = this.configManager.mergeHeaders(config.headers);

    // 设置默认User-Agent
    if (headers.UserAgent === undefined) {
      headers.UserAgent = this.configManager.getRandomUserAgent();
    }

    // 设置默认Accept
    if (!headers.Accept) {
      headers.Accept = '*/*';
    }

    // 添加Cookie
    if (config.url) {
      const cookie = this.cookieManager.getCookieForUrl(config.url);
      if (cookie) {
        headers.Cookie = cookie;
      }
    }

    config.headers = headers;
    return config;
  }

  /**
   * 处理响应Cookie
   */
  private handleResponseCookie(response: HttpResponse<void>): HttpResponse<void> {
    const setCookie = ResponseParser.extractSetCookie(response.headers);
    
    if (setCookie && response.config.url) {
      this.cookieManager.saveCookie(response.config.url, setCookie);
    }
    
    return response;
  }

  /**
   * 发送请求
   */
  async request<T = Record<string, string>>(config: HttpRequestConfig): Promise<HttpResponse<T>> {
    const requestId = this.generateRequestId();
    const startTime = Date.now();

    const metrics: RequestMetrics = {
      requestId,
      url: config.url,
      method: config.method ?? HttpMethod.GET,
      startTime,
      success: false,
      cached: false,
      retries: 0
    };

    try {
      // 应用请求拦截器
      let processedConfig = await this.interceptors.applyRequestInterceptors(config);
      
      // 合并配置
      processedConfig = this.configManager.mergeRequestConfig(processedConfig);

      // 验证URL
      if (!processedConfig.url) {
        throw HttpErrorImpl.invalidUrl('URL is required');
      }

      // 创建AbortController
      let abortController: AbortControllerImpl;
      if (processedConfig.abortController instanceof AbortControllerImpl) {
        abortController = processedConfig.abortController;
      } else {
        abortController = AbortManager.getInstance().createController(requestId, processedConfig.timeout ?? DEFAULTS.TIMEOUT);
      }

      // 尝试从缓存获取
      const cachedResponse = await this.tryGetCachedResponse<T>(processedConfig, metrics, startTime);
      if (cachedResponse) {
        return cachedResponse;
      }

      // 执行请求
      const response = await this.executeRequest<T>(processedConfig, abortController, metrics);

      // 记录成功指标
      this.recordSuccessMetrics(metrics, response, startTime);

      // 应用响应拦截器
      return await this.interceptors.applyResponseInterceptors<T>(response);
    } catch (error) {
      // 记录失败指标
      this.recordErrorMetrics(metrics, error as Error, startTime);

      // 应用错误拦截器
      const httpError = error instanceof HttpErrorImpl
        ? error
        : HttpErrorImpl.fromError(error as Error, config);

      try {
        await this.interceptors.applyResponseErrorInterceptors(httpError);
      } catch {
        // 忽略拦截器错误
      }

      throw httpError;
    }
  }

  /**
   * 尝试从缓存获取响应
   */
  private async tryGetCachedResponse<T>(
    config: HttpRequestConfig,
    metrics: RequestMetrics,
    startTime: number
  ): Promise<HttpResponse<T> | null> {
    const cacheConfig = this.configManager.getConfig().cache;
    
    if (!cacheConfig.enabled || config.cache?.forceRefresh) {
      return null;
    }

    const cacheKey = config.cache?.key ??
      RequestCache.generateKey(
        config.url,
        config.method ?? HttpMethod.GET,
        RequestBuilder.paramsToRecord(config.params),
        typeof config.data === 'string' ? config.data : JSON.stringify(config.data)
      );

    const cachedResponse = RequestCache.get(cacheKey);
    
    if (!cachedResponse) {
      return null;
    }

    const response = ResponseParser.createResponse<T>(
      cachedResponse.data as T,
      cachedResponse.status,
      cachedResponse.headers,
      config,
      cachedResponse.duration,
      true,
      cachedResponse.retries
    );

    metrics.cached = true;
    metrics.success = true;
    metrics.endTime = Date.now();
    metrics.duration = metrics.endTime - startTime;
    this.metricsCollector.record(metrics);

    return response;
  }

  /**
   * 执行请求
   */
  private async executeRequest<T>(
    config: HttpRequestConfig,
    abortController: AbortControllerImpl,
    metrics: RequestMetrics
  ): Promise<HttpResponse<T>> {
    const requestFn = async (): Promise<HttpResponse<T>> => {
      const httpRequest = http.createHttp();

      try {
        const url = RequestBuilder.buildUrl(config, this.configManager.getConfig().baseURL);
        const requestOptions = RequestBuilder.buildRequestOptions(config, this.configManager);

        const response = await httpRequest.request(url, requestOptions);

        if (abortController.aborted) {
          throw HttpErrorImpl.aborted('Request was aborted', config);
        }

        const responseHeaders = ResponseParser.parseResponseHeaders(response.header as Record<string, string>);
        const data = ResponseParser.parseResponseData<T>(response.result as string | ArrayBuffer, config);

        const httpResponse = ResponseParser.createResponse<T>(
          data,
          response.responseCode,
          responseHeaders,
          config,
          Date.now() - metrics.startTime,
          false,
          metrics.retries
        );

        this.validateStatus(response.responseCode, httpResponse, config);

        this.cacheResponse(config, httpResponse, response.responseCode);

        return httpResponse;
      } catch (error) {
        if (error instanceof Error) {
          throw error;
        }
        throw new Error(String(error));
      } finally {
        httpRequest.destroy();
      }
    };

    try {
      const retryConfig = config.retry ?? this.configManager.getConfig().retry;
      if (retryConfig) {
        return await RetryHandler.executeWithRetry(requestFn, config, retryConfig);
      }

      return await requestFn();
    } finally {
      AbortManager.getInstance().removeController(metrics.requestId);
    }
  }

  /**
   * 验证状态码
   */
  private validateStatus<T>(
    status: number,
    response: HttpResponse<T>,
    config: HttpRequestConfig
  ): void {
    const validateStatus = config.validateStatus ?? this.configManager.getConfig().validateStatus;
    
    if (!validateStatus(status)) {
      throw HttpErrorImpl.httpError(
        status,
        response.statusText,
        {
          headers: response.headers,
          config,
          response: response as HttpResponse
        }
      );
    }
  }

  /**
   * 缓存响应
   */
  private cacheResponse<T>(config: HttpRequestConfig, response: HttpResponse<T>, status: number): void {
    const cacheConfig = this.configManager.getConfig().cache;
    
    if (!cacheConfig.enabled || !RequestCache.shouldCache(config.method ?? HttpMethod.GET, status)) {
      return;
    }

    const cacheKey = config.cache?.key ??
      RequestCache.generateKey(
        config.url,
        config.method ?? HttpMethod.GET,
        RequestBuilder.paramsToRecord(config.params),
        typeof config.data === 'string' ? config.data : JSON.stringify(config.data)
      );

    RequestCache.set(cacheKey, response as HttpResponse, config.cache?.ttl ?? cacheConfig.ttl);
  }

  /**
   * 记录成功指标
   */
  private recordSuccessMetrics<T>(metrics: RequestMetrics, response: HttpResponse<T>, startTime: number): void {
    metrics.success = true;
    metrics.endTime = Date.now();
    metrics.duration = metrics.endTime - startTime;
    metrics.status = response.status;
    metrics.responseSize = ResponseParser.estimateSize(response.data);
    this.metricsCollector.record(metrics);
  }

  /**
   * 记录错误指标
   */
  private recordErrorMetrics(metrics: RequestMetrics, error: Error, startTime: number): void {
    metrics.success = false;
    metrics.endTime = Date.now();
    metrics.duration = metrics.endTime - startTime;
    metrics.error = error.message;
    this.metricsCollector.record(metrics);
  }

  // ==================== HTTP方法 ====================

  /**
   * GET请求
   */
  async get<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig(HttpMethod.GET, url, undefined, config));
  }

  /**
   * POST请求
   */
  async post<T = Record<string, string>>(url: string, data?: HttpData, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig(HttpMethod.POST, url, data, config));
  }

  /**
   * PUT请求
   */
  async put<T = Record<string, string>>(url: string, data?: HttpData, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig(HttpMethod.PUT, url, data, config));
  }

  /**
   * DELETE请求
   */
  async delete<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig(HttpMethod.DELETE, url, undefined, config));
  }

  /**
   * PATCH请求
   */
  async patch<T = Record<string, string>>(url: string, data?: HttpData, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig('PATCH', url, data, config));
  }

  /**
   * HEAD请求
   */
  async head<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig(HttpMethod.HEAD, url, undefined, config));
  }

  /**
   * OPTIONS请求
   */
  async options<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>> {
    return this.request<T>(RequestBuilder.createRequestConfig(HttpMethod.OPTIONS, url, undefined, config));
  }

  // ==================== 拦截器管理 ====================

  /**
   * 添加请求拦截器
   */
  addRequestInterceptor(interceptor: RequestInterceptor): string {
    return this.interceptors.useRequestInterceptor(
      interceptor.onRequest ?? (() => ({} as HttpRequestConfig)),
      interceptor.onRequestError,
      { priority: interceptor.priority, id: interceptor.id }
    );
  }

  /**
   * 添加响应拦截器
   */
  addResponseInterceptor(interceptor: ResponseInterceptor): string {
    return this.interceptors.useResponseInterceptor(
      interceptor.onResponse ?? ((r: HttpResponse<ESObject>) => r),
      interceptor.onResponseError,
      { priority: interceptor.priority, id: interceptor.id }
    );
  }

  /**
   * 移除请求拦截器
   */
  removeRequestInterceptor(id: string): boolean {
    return this.interceptors.removeRequestInterceptor(id);
  }

  /**
   * 移除响应拦截器
   */
  removeResponseInterceptor(id: string): boolean {
    return this.interceptors.removeResponseInterceptor(id);
  }

  // ==================== 配置管理 ====================

  /**
   * 设置默认请求头
   */
  setDefaultHeader(key: string, value: string): void {
    this.configManager.setDefaultHeader(key, value);
  }

  /**
   * 移除默认请求头
   */
  removeDefaultHeader(key: string): void {
    this.configManager.removeDefaultHeader(key);
  }

  /**
   * 设置基础URL
   */
  setBaseURL(url: string): void {
    this.configManager.setBaseURL(url);
  }

  /**
   * 设置默认配置
   */
  setDefaultConfig(config: Partial<HttpClientConfig>): void {
    this.configManager.updateConfig(config);
  }

  // ==================== 缓存管理 ====================

  /**
   * 清空缓存
   */
  clearCache(): void {
    RequestCache.clear();
  }

  /**
   * 获取缓存统计
   */
  getCacheStats(): CacheStats {
    return RequestCache.getStats();
  }

  // ==================== 指标管理 ====================

  /**
   * 获取指标
   */
  getMetrics(): RequestMetrics[] {
    return this.metricsCollector.getMetrics();
  }

  /**
   * 清空指标
   */
  clearMetrics(): void {
    this.metricsCollector.clear();
  }

  // ==================== 请求控制 ====================

  /**
   * 取消请求
   */
  abort(requestId: string): boolean {
    return AbortManager.getInstance().abort(requestId);
  }

  /**
   * 取消所有请求
   */
  abortAll(): void {
    AbortManager.getInstance().abortAll();
  }

  // ==================== 生命周期 ====================

  /**
   * 销毁客户端
   */
  destroy(): void {
    this.abortAll();
    this.clearCache();
    this.clearMetrics();
    this.interceptors.clear();
    this.cookieManager.clear();
    this.configManager.clearDefaultHeaders();
    HttpClient.instance = null;
  }

  /**
   * 生成请求ID
   */
  private generateRequestId(): string {
    this.requestIdCounter++;
    return `req_${Date.now()}_${this.requestIdCounter}`;
  }
}

// 创建默认实例用于向后兼容
const defaultHttpClient = HttpClient.getInstance();
export default defaultHttpClient;
