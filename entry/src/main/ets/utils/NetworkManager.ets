/**
 * NetworkManager - 网络管理器（代理模式）
 * 
 * @deprecated 请使用 BookSourceNetworkService 替代
 * 此类保留用于向后兼容，内部委托给 BookSourceNetworkService 和 HttpClient
 */

import { HttpClient } from '../network/HttpClient';
import {
  HttpMethod,
  HttpRequestConfig,
  HttpHeaderMap
} from '../network/interfaces/IHttpClient';
import { BookSource } from '../models/BookSource';
import { ContentParser, ParsedBookItem, ParsedChapterItem } from './ContentParser';
import { Book } from '../models/Book';
import { Logger } from './Logger';
import { AsyncChapterParser } from './AsyncChapterParser';
import { AsyncContentParser } from './AsyncContentParser';
import astroReadJSRuntime, { SearchContext } from './AstroReadJSRuntime';
import { BookSourceNetworkService } from '../services/BookSourceNetworkService';
import common from '@ohos.app.ability.common';

interface NetworkSecurityOptions {
  skipSSLVerification: boolean;
  ignoreAntiCrawling: boolean;
  maxResponseSize: number;
}

interface UrlConfig {
  method: 'GET' | 'POST';
  body?: string;
  headers: Map<string, string>;
}

const DEFAULT_SECURITY_OPTIONS: NetworkSecurityOptions = {
  skipSSLVerification: true,
  ignoreAntiCrawling: true,
  maxResponseSize: 10 * 1024 * 1024
};

function createDefaultSecurityOptions(): NetworkSecurityOptions {
  return {
    skipSSLVerification: DEFAULT_SECURITY_OPTIONS.skipSSLVerification,
    ignoreAntiCrawling: DEFAULT_SECURITY_OPTIONS.ignoreAntiCrawling,
    maxResponseSize: DEFAULT_SECURITY_OPTIONS.maxResponseSize
  };
}

/**
 * @deprecated 使用 BookSourceNetworkService 替代
 */
export class NetworkManager {
  private static instance: NetworkManager | null = null;
  private securityOptions: NetworkSecurityOptions = createDefaultSecurityOptions();
  private bookSourceService: BookSourceNetworkService;
  private httpClient: HttpClient;
  private context: common.UIAbilityContext | null = null;

  private readonly TAG = 'NetworkManager';

  private constructor() {
    this.bookSourceService = BookSourceNetworkService.getInstance();
    this.httpClient = HttpClient.getInstance();
  }

  static getInstance(): NetworkManager {
    if (NetworkManager.instance === null) {
      NetworkManager.instance = new NetworkManager();
    }
    return NetworkManager.instance;
  }

  /**
   * 设置上下文
   * @deprecated 不再需要设置上下文
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    Logger.info(this.TAG, 'Context已设置（已废弃，无需使用）');
  }

  /**
   * @deprecated 安全选项现在由 HttpClient 配置管理
   */
  setSecurityOptions(options: Partial<NetworkSecurityOptions>): void {
    if (options.skipSSLVerification !== undefined) {
      this.securityOptions.skipSSLVerification = options.skipSSLVerification;
    }
    if (options.ignoreAntiCrawling !== undefined) {
      this.securityOptions.ignoreAntiCrawling = options.ignoreAntiCrawling;
    }
    if (options.maxResponseSize !== undefined) {
      this.securityOptions.maxResponseSize = options.maxResponseSize;
    }
    Logger.info(this.TAG, `安全选项已更新: skipSSL=${this.securityOptions.skipSSLVerification}`);
  }

  /**
   * @deprecated 安全选项现在由 HttpClient 配置管理
   */
  getSecurityOptions(): NetworkSecurityOptions {
    return {
      skipSSLVerification: this.securityOptions.skipSSLVerification,
      ignoreAntiCrawling: this.securityOptions.ignoreAntiCrawling,
      maxResponseSize: this.securityOptions.maxResponseSize
    };
  }

  /**
   * 发送GET请求
   * @deprecated 建议直接使用 HttpClient.getInstance().get()
   */
  async get(url: string, headers?: Map<string, string>, maxResponseSize?: number): Promise<string> {
    return this.bookSourceService.get(url, headers);
  }

  /**
   * 发送POST请求
   * @deprecated 建议直接使用 HttpClient.getInstance().post()
   */
  async post(url: string, data: string, headers?: Map<string, string>, maxResponseSize?: number): Promise<string> {
    return this.bookSourceService.post(url, data, headers);
  }

  /**
   * 搜索书籍
   */
  async searchBook(bookSource: BookSource, keyword: string, page: number = 1): Promise<Book[]> {
    return this.bookSourceService.searchBook(bookSource, keyword, page);
  }

  /**
   * 获取章节列表
   */
  async getChapterList(bookSource: BookSource, bookUrl: string): Promise<ParsedChapterItem[]> {
    return this.bookSourceService.getChapterList(bookSource, bookUrl);
  }

  /**
   * 获取章节内容
   */
  async getChapterContent(bookSource: BookSource, chapterUrl: string): Promise<string> {
    return this.bookSourceService.getChapterContent(bookSource, chapterUrl);
  }

  /**
   * 获取网络诊断报告
   * @deprecated 使用 HttpClient 的指标功能
   */
  getDiagnosticReport(): string {
    const metrics = this.httpClient.getMetrics();
    const successCount = metrics.filter(m => m.success).length;
    const failCount = metrics.filter(m => !m.success).length;
    const avgDuration = metrics.length > 0
      ? metrics.reduce((sum, m) => sum + (m.duration ?? 0), 0) / metrics.length
      : 0;

    return `网络诊断报告:\n` +
      `- 总请求数: ${metrics.length}\n` +
      `- 成功请求: ${successCount}\n` +
      `- 失败请求: ${failCount}\n` +
      `- 平均耗时: ${avgDuration.toFixed(2)}ms\n` +
      `- 缓存命中: ${metrics.filter(m => m.cached).length}`;
  }

  /**
   * 获取最近的请求日志
   * @deprecated 使用 HttpClient.getMetrics()
   */
  getRecentRequestLogs(count: number = 20): RequestLog[] {
    const metrics = this.httpClient.getMetrics().slice(-count);
    return metrics.map((m): RequestLog => ({
      timestamp: m.startTime,
      url: m.url,
      method: m.method,
      requestHeaders: new Map<string, string>(),
      requestBody: '',
      responseCode: m.status ?? 0,
      responseTime: m.duration ?? 0,
      responseSize: m.responseSize ?? 0,
      error: m.error ?? '',
      retryCount: m.retries
    }));
  }

  /**
   * 清除请求日志
   * @deprecated 使用 HttpClient.clearMetrics()
   */
  clearRequestLogs(): void {
    this.httpClient.clearMetrics();
  }

  /**
   * 带重试的请求
   * @deprecated HttpClient 已内置重试机制
   */
  async requestWithRetry<T>(
    requestFn: () => Promise<T>,
    config?: RetryConfig
  ): Promise<T> {
    return requestFn();
  }
}

interface RequestLog {
  timestamp: number;
  url: string;
  method: string;
  requestHeaders: Map<string, string>;
  requestBody: string;
  responseCode: number;
  responseTime: number;
  responseSize: number;
  error: string;
  retryCount: number;
}

interface RetryConfig {
  maxRetries: number;
  baseDelay?: number;
  maxDelay?: number;
}

export default NetworkManager.getInstance();
