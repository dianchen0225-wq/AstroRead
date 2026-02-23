import { http } from '@kit.NetworkKit';
import { BookSource } from '../../models/BookSource';
import { ContentParser, ParsedBookItem, ParsedChapterItem } from '../parser/ContentParser';
import { Book } from '../../models/Book';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import astroReadJSRuntime, { SearchContext } from '../scripting/AstroReadJSRuntime';
import { Logger } from '../performance/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { RequestEnhancer, RequestLog } from '../crawler/RequestEnhancer';
import { util } from '@kit.ArkTS';
import { networkConfigManager, RetryConfig, TimeoutConfig } from './NetworkConfig';
import { AsyncChapterParser } from '../parser/AsyncChapterParser';
import { AsyncContentParser } from '../parser/AsyncContentParser';

interface NetworkSecurityOptions {
  skipSSLVerification: boolean;
  ignoreAntiCrawling: boolean;
  maxResponseSize: number;
}

interface UrlConfig {
  method: 'GET' | 'POST';
  body?: string;
  headers: HttpHeaderMap;
}

const DEFAULT_SECURITY_OPTIONS: NetworkSecurityOptions = {
  skipSSLVerification: true,
  ignoreAntiCrawling: true,
  maxResponseSize: 10 * 1024 * 1024
};

const MAX_REDIRECTS = 5;

export type HttpHeaderMap = Map<string, string>;

export class NetworkManager {
  private static instance: NetworkManager | null = null;
  private context: common.UIAbilityContext | null = null;
  private securityOptions: NetworkSecurityOptions = {
    skipSSLVerification: true,
    ignoreAntiCrawling: true,
    maxResponseSize: 10 * 1024 * 1024
  };

  private constructor() {
  }

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
    Logger.info('NetworkManager', `安全选项已更新: skipSSL=${this.securityOptions.skipSSLVerification}, ignoreAntiCrawling=${this.securityOptions.ignoreAntiCrawling}`);
  }

  getSecurityOptions(): NetworkSecurityOptions {
    return {
      skipSSLVerification: this.securityOptions.skipSSLVerification,
      ignoreAntiCrawling: this.securityOptions.ignoreAntiCrawling,
      maxResponseSize: this.securityOptions.maxResponseSize
    };
  }

  setContext(context: common.UIAbilityContext | null): void {
    this.context = context;
  }

  static getInstance(): NetworkManager {
    if (NetworkManager.instance === null) {
      NetworkManager.instance = new NetworkManager();
    }
    return NetworkManager.instance;
  }

  private calculateBackoffDelay(attempt: number, baseDelay: number, maxDelay: number): number {
    const delay = baseDelay * Math.pow(2, attempt);
    const jitter = Math.random() * 0.1 * delay;
    return Math.min(delay + jitter, maxDelay);
  }

  private async sleep(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  private isRetryableError(error: Error, statusCode?: number, config?: RetryConfig): boolean {
    const retryConfig = config ?? networkConfigManager.getRetryConfig();
    const errorType = this.getErrorType(error);

    return networkConfigManager.isRetryableError(errorType, statusCode);
  }

  private getErrorType(error: Error): string {
    const message = error.message.toLowerCase();
    if (message.includes('timeout')) {
      return 'timeout';
    } else if (message.includes('network') || message.includes('connection') ||
      message.includes('econnreset') || message.includes('econnrefused')) {
      return 'network';
    } else if (message.includes('dns') || message.includes('enotfound')) {
      return 'dns';
    }
    return 'unknown';
  }

  async requestWithRetry<T>(
    requestFn: (attempt: number) => Promise<T>,
    config?: RetryConfig
  ): Promise<T> {
    const retryConfig = config ?? networkConfigManager.getRetryConfig();
    let lastError: Error = new Error('Unknown error');

    for (let attempt = 0; attempt <= retryConfig.maxRetries; attempt++) {
      try {
        return await requestFn(attempt);
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));

        if (attempt < retryConfig.maxRetries && this.isRetryableError(lastError, undefined, retryConfig)) {
          const delay = this.calculateBackoffDelay(attempt, retryConfig.baseDelay, retryConfig.maxDelay);
          Logger.warn('NetworkManager', `请求失败，${delay}ms后重试 (${attempt + 1}/${retryConfig.maxRetries}): ${lastError.message}`);
          await this.sleep(delay);
        } else {
          break;
        }
      }
    }

    throw lastError;
  }

  /**
   * 申请存储权限
   */
  async requestStoragePermission(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Permissions[] = ['ohos.permission.READ_MEDIA', 'ohos.permission.WRITE_MEDIA'];

    if (!this.context) {
      Logger.error('NetworkManager', 'Context not set, cannot request permissions');
      return false;
    }

    try {
      const result = await atManager.requestPermissionsFromUser(this.context, permissions);
      const authResults = result.authResults || [];

      if (authResults.length >= 2 &&
        authResults[0] === 0 &&  // PERMISSION_GRANTED
        authResults[1] === 0) {   // PERMISSION_GRANTED
        Logger.info('NetworkManager', '存储权限申请成功');
        return true;
      } else {
        Logger.warn('NetworkManager', '存储权限申请失败');
        return false;
      }
    } catch (error) {
      Logger.error('NetworkManager', `申请权限失败: ${error}`);
      return false;
    }
  }

  /**
   * 发送GET请求 - 增强版
   */
  async get(url: string, headers?: HttpHeaderMap, maxResponseSize?: number, redirectCount: number = 0): Promise<string> {
    if (redirectCount > MAX_REDIRECTS) {
      throw new Error(`重定向次数超过限制 (${MAX_REDIRECTS}次)`);
    }

    const startTime = Date.now();
    const requestLog: RequestLog = {
      timestamp: startTime,
      url: url,
      method: 'GET',
      requestHeaders: new Map<string, string>(),
      requestBody: '',
      responseCode: 0,
      responseTime: 0,
      responseSize: 0,
      error: '',
      retryCount: 0
    };

    return this.requestWithRetry(async (attempt: number) => {
      const httpRequest = http.createHttp();
      const currentRetryCount = attempt + 1;

      try {
        const baseUrl = this.extractBaseUrl(url);
        const inputHeaders: Map<string, string> | null = headers ? headers : null;
        const requestHeaders = RequestEnhancer.buildEnhancedHeaders(inputHeaders, {
          useRandomUA: true,
          useRandomReferer: true,
          baseUrl: baseUrl
        });

        requestLog.requestHeaders = requestHeaders;
        requestLog.retryCount = currentRetryCount;

        const timeoutConfig = networkConfigManager.getTimeoutConfig();

        const requestOptions: http.HttpRequestOptions = {
          method: http.RequestMethod.GET,
          header: this.mapToRecord(requestHeaders),
          connectTimeout: timeoutConfig.connectTimeout,
          readTimeout: timeoutConfig.readTimeout,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        };

        const response = await httpRequest.request(url, requestOptions);
        const responseTime = Date.now() - startTime;

        requestLog.responseCode = response.responseCode;
        requestLog.responseTime = responseTime;

        if (response.responseCode === 200 || response.responseCode === 202) {
          const arrayBuffer = response.result as ArrayBuffer;
          const responseText = this.decodeResponse(arrayBuffer, response.header);
          requestLog.responseSize = responseText.length;

          if (this.isAntiCrawlingResponse(responseText)) {
            Logger.warn('NetworkManager', `检测到可能的反爬虫响应，但仍尝试解析: ${url}`);
          }

          const maxSize = maxResponseSize ?? this.securityOptions.maxResponseSize;
          if (responseText.length > maxSize) {
            Logger.warn('NetworkManager', `响应过大，截断处理: ${responseText.length}字节`);
            return responseText.substring(0, maxSize);
          }

          RequestEnhancer.logRequest(requestLog);
          return responseText;
        } else if (response.responseCode === 301 || response.responseCode === 302) {
          const headersObj = response.header;
          let location: string | undefined;

          if (headersObj) {
            location = this.getHeaderValue(headersObj, 'Location');
            if (!location) {
              location = this.getHeaderValue(headersObj, 'location');
            }
          }

          if (location) {
            const redirectUrl = this.resolveUrl(url, location);
            Logger.info('NetworkManager', `Redirecting to: ${redirectUrl} (重定向次数: ${redirectCount + 1}/${MAX_REDIRECTS})`);
            return this.get(redirectUrl, headers, maxResponseSize, redirectCount + 1);
          } else {
            throw new Error(`HTTP ${response.responseCode}: No redirect location`);
          }
        } else {
          throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
        }
      } catch (e) {
        let error: BusinessError = e as BusinessError;
        const errorCode = error.code || 0;

        requestLog.error = error.message;
        requestLog.responseTime = Date.now() - startTime;

        if (errorCode === 2300060) {
          if (this.securityOptions.skipSSLVerification) {
            Logger.warn('NetworkManager', `SSL证书验证失败，已跳过: ${url}`);
            throw new Error('SSL证书验证失败（已启用跳过）');
          }
          throw new Error('SSL证书验证失败，服务器证书不受信任');
        }

        if (errorCode === 2300023) {
          Logger.warn('NetworkManager', `响应数据写入失败，尝试分块处理: ${url}`);
          throw new Error('响应数据过大，写入失败');
        }

        if (errorCode === 2300999) {
          Logger.warn('NetworkManager', `网络请求内部错误: ${url}`);
          throw new Error('网络请求内部错误');
        }

        Logger.error('NetworkManager', `httpRequest.request call failed. code is ${errorCode}, message is ${error.message}`);
        throw new Error(error.message);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  private isAntiCrawlingResponse(html: string): boolean {
    const antiCrawlingIndicators = [
      'probe.js',
      'bot detection',
      'captcha',
      'cloudflare',
      'access denied',
      '请验证',
      '人机验证',
      '安全验证'
    ];

    const lowerHtml = html.toLowerCase();
    for (const indicator of antiCrawlingIndicators) {
      if (lowerHtml.includes(indicator.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /**
   * 解码响应数据，自动检测编码
   */
  private decodeResponse(arrayBuffer: ArrayBuffer, headers: object): string {
    const uint8Data = new Uint8Array(arrayBuffer);

    const charsetFromHeader = this.detectCharsetFromHeader(headers);
    if (charsetFromHeader) {
      try {
        const decoder = util.TextDecoder.create(charsetFromHeader, { ignoreBOM: true });
        const text = decoder.decodeToString(uint8Data);
        if (this.isValidDecodedContent(text)) {
          Logger.debug('NetworkManager', `使用响应头编码: ${charsetFromHeader}`);
          return text;
        }
      } catch (e) {
        Logger.warn('NetworkManager', `响应头编码 ${charsetFromHeader} 解码失败，尝试其他编码`);
      }
    }

    const charsetFromContent = this.detectCharsetFromContent(uint8Data);
    if (charsetFromContent && charsetFromContent !== charsetFromHeader) {
      try {
        const decoder = util.TextDecoder.create(charsetFromContent, { ignoreBOM: true });
        const text = decoder.decodeToString(uint8Data);
        if (this.isValidDecodedContent(text)) {
          Logger.debug('NetworkManager', `使用内容检测编码: ${charsetFromContent}`);
          return text;
        }
      } catch (e) {
        Logger.warn('NetworkManager', `内容检测编码 ${charsetFromContent} 解码失败`);
      }
    }

    const encodings: string[] = ['utf-8', 'gbk', 'gb2312', 'gb18030', 'big5'];
    for (const encoding of encodings) {
      if (encoding === charsetFromHeader || encoding === charsetFromContent) {
        continue;
      }
      try {
        const decoder = util.TextDecoder.create(encoding, { ignoreBOM: true });
        const text = decoder.decodeToString(uint8Data);
        if (this.isValidDecodedContent(text)) {
          Logger.debug('NetworkManager', `使用自动检测编码: ${encoding}`);
          return text;
        }
      } catch (e) {
        continue;
      }
    }

    try {
      const defaultDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return defaultDecoder.decodeToString(uint8Data);
    } catch (error) {
      Logger.error('NetworkManager', `默认编码解码失败: ${error instanceof Error ? error.message : String(error)}`);
      return '';
    }
  }

  /**
   * 从响应头检测编码
   */
  private detectCharsetFromHeader(headers: object): string | null {
    const contentType = this.getHeaderValue(headers, 'Content-Type');
    if (!contentType) {
      return null;
    }

    const charsetMatch = contentType.match(/charset=["']?([^;"'\s]+)["']?/i);
    if (charsetMatch) {
      let charset = charsetMatch[1].toLowerCase();
      charset = this.normalizeCharset(charset);
      return charset;
    }
    return null;
  }

  /**
   * 从内容检测编码（检查 meta 标签）
   */
  private detectCharsetFromContent(uint8Data: Uint8Array): string | null {
    try {
      const asciiDecoder = util.TextDecoder.create('ascii', { ignoreBOM: true });
      const preview = asciiDecoder.decodeToString(uint8Data.slice(0, 1024));

      const metaCharsetMatch = preview.match(/<meta[^>]+charset=["']?([^"'\s>]+)["']?/i);
      if (metaCharsetMatch) {
        let charset = metaCharsetMatch[1].toLowerCase();
        charset = this.normalizeCharset(charset);
        return charset;
      }

      const contentTypeMatch = preview.match(/<meta[^>]+content=["'][^"']*charset=([^"'\s;]+)/i);
      if (contentTypeMatch) {
        let charset = contentTypeMatch[1].toLowerCase();
        charset = this.normalizeCharset(charset);
        return charset;
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /**
   * 标准化编码名称
   */
  private normalizeCharset(charset: string): string {
    const charsetMap: Record<string, string> = {
      'utf8': 'utf-8',
      'gb2312': 'gbk',
      'gb_2312': 'gbk',
      'gb231280': 'gbk',
      'x-gbk': 'gbk',
      'iso-8859-1': 'latin1',
      'iso8859-1': 'latin1'
    };

    const normalized = charset.toLowerCase().trim();
    return charsetMap[normalized] || normalized;
  }

  /**
   * 检查解码后的内容是否有效（无乱码）
   */
  private isValidDecodedContent(content: string): boolean {
    const replacementChar = '\uFFFD';
    const replacementCount = (content.match(new RegExp(replacementChar, 'g')) || []).length;
    const ratio = replacementCount / content.length;
    return ratio < 0.01;
  }

  private getHeaderValue(headers: object, key: string): string | undefined {
    const headerMap: Map<string, string> = this.objectToMap(headers);
    const keys = Array.from(headerMap.keys());
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() === key.toLowerCase()) {
        return headerMap.get(keys[i]);
      }
    }
    return undefined;
  }

  private objectToMap(obj: object): Map<string, string> {
    const map: Map<string, string> = new Map<string, string>();
    const objStr = JSON.stringify(obj);
    try {
      const parsed = JSON.parse(objStr) as Record<string, string>;
      const keys = Object.keys(parsed);
      for (let i = 0; i < keys.length; i++) {
        const value = parsed[keys[i]];
        if (typeof value === 'string') {
          map.set(keys[i], value);
        }
      }
    } catch (e) {
      // 解析失败，返回空map
    }
    return map;
  }

  private extractBaseUrl(url: string): string {
    try {
      const match = url.match(/^(https?:\/\/[^/]+)/);
      return match ? match[1] : '';
    } catch (e) {
      return '';
    }
  }

  private mapToRecord(map: Map<string, string>): Record<string, string> {
    const record: Record<string, string> = {};
    const keys = Array.from(map.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = map.get(key);
      if (value !== undefined) {
        record[key] = value;
      }
    }
    return record;
  }

  /**
   * 发送POST请求 - 增强版
   */
  async post(url: string, data: string, headers?: HttpHeaderMap, maxResponseSize?: number): Promise<string> {
    const startTime = Date.now();
    const requestLog: RequestLog = {
      timestamp: startTime,
      url: url,
      method: 'POST',
      requestHeaders: new Map<string, string>(),
      requestBody: data,
      responseCode: 0,
      responseTime: 0,
      responseSize: 0,
      error: '',
      retryCount: 0
    };

    return this.requestWithRetry(async (attempt: number) => {
      const httpRequest = http.createHttp();
      const currentRetryCount = attempt + 1;

      try {
        const baseUrl = this.extractBaseUrl(url);
        const inputHeaders: Map<string, string> | null = headers ? headers : null;
        const mergedHeaders = RequestEnhancer.buildEnhancedHeaders(inputHeaders, {
          useRandomUA: true,
          useRandomReferer: true,
          baseUrl: baseUrl
        });

        if (!mergedHeaders.has('Content-Type')) {
          mergedHeaders.set('Content-Type', 'application/x-www-form-urlencoded');
        }

        requestLog.requestHeaders = mergedHeaders;
        requestLog.retryCount = currentRetryCount;

        const timeoutConfig = networkConfigManager.getTimeoutConfig();

        const requestOptions: http.HttpRequestOptions = {
          method: http.RequestMethod.POST,
          header: this.mapToRecord(mergedHeaders),
          extraData: data,
          connectTimeout: timeoutConfig.connectTimeout,
          readTimeout: timeoutConfig.readTimeout,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        };

        const response = await httpRequest.request(url, requestOptions);
        const responseTime = Date.now() - startTime;

        requestLog.responseCode = response.responseCode;
        requestLog.responseTime = responseTime;

        if (response.responseCode === 200) {
          const arrayBuffer = response.result as ArrayBuffer;
          const responseText = this.decodeResponse(arrayBuffer, response.header);
          requestLog.responseSize = responseText.length;

          if (maxResponseSize && responseText.length > maxResponseSize) {
            throw new Error(`响应大小超过限制: ${responseText.length}字节`);
          }

          RequestEnhancer.logRequest(requestLog);
          return responseText;
        } else {
          throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
        }
      } catch (e) {
        let error: BusinessError = e as BusinessError;
        requestLog.error = error.message;
        requestLog.responseTime = Date.now() - startTime;
        RequestEnhancer.logRequest(requestLog);
        Logger.error('NetworkManager', `httpRequest.request call failed. code is ${error.code}, message is ${error.message}`);
        throw new Error(error.message);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  /**
   * 获取网络诊断报告
   */
  getDiagnosticReport(): string {
    return RequestEnhancer.generateDiagnosticReport();
  }

  /**
   * 获取最近的请求日志
   */
  getRecentRequestLogs(count: number = 20): RequestLog[] {
    return RequestEnhancer.getRecentLogs(count);
  }

  /**
   * 清除请求日志
   */
  clearRequestLogs(): void {
    RequestEnhancer.clearLogs();
  }

  /**
   * 搜索书籍 - 支持JavaScript书源
   */
  async searchBook(bookSource: BookSource, keyword: string, page: number = 1): Promise<Book[]> {
    const TAG = 'NetworkManager';
    try {
      Logger.info(TAG, `========== 开始搜索 ==========`);
      Logger.info(TAG, `书源: ${bookSource.name}, 关键词: ${keyword}, 页码: ${page}`);

      let searchUrl = bookSource.legacy.searchUrl;

      if (!searchUrl || searchUrl.trim() === '') {
        Logger.error(TAG, `书源 ${bookSource.name} 没有配置搜索URL，跳过此书源`);
        return [];
      }

      searchUrl = searchUrl.trim();
      Logger.info(TAG, `原始搜索URL模板: ${searchUrl}`);

      let headers: HttpHeaderMap = new Map<string, string>();
      if (bookSource.networkConfig?.header) {
        try {
          headers = this.parseHeaderString(bookSource.networkConfig.header);
          Logger.debug(TAG, `请求头: ${JSON.stringify(Array.from(headers.entries()))}`);
        } catch (e) {
          Logger.warn(TAG, `解析请求头失败: ${bookSource.name}`);
        }
      }

      let finalUrl = '';
      let urlConfig: UrlConfig = {
        method: 'GET',
        headers: headers
      };

      if (searchUrl.startsWith('@js:')) {
        Logger.info(TAG, `执行JavaScript书源: ${bookSource.name}`);

        const context: SearchContext = {
          key: keyword,
          page: page,
          baseUrl: bookSource.url
        };

        finalUrl = await astroReadJSRuntime.executeSearchUrl(searchUrl, context);

        if (!finalUrl) {
          Logger.warn(TAG, `JavaScript执行未返回URL: ${bookSource.name}`);
          return [];
        }

        Logger.info(TAG, `JavaScript生成URL: ${finalUrl}`);
      } else {
        finalUrl = searchUrl;

        const commaIndex = finalUrl.indexOf(',{');
        if (commaIndex > 0 && finalUrl.endsWith('}')) {
          try {
            const urlPart = finalUrl.substring(0, commaIndex);
            const configPart = finalUrl.substring(commaIndex + 1);
            urlConfig = this.parseUrlConfig(configPart, headers);
            finalUrl = urlPart;
            Logger.info(TAG, `从URL中提取配置，方法: ${urlConfig.method}, 最终URL: ${finalUrl}`);
          } catch (e) {
            Logger.warn(TAG, `URL配置解析失败，保持原URL`);
          }
        }

        if (finalUrl.includes('{{key}}')) {
          finalUrl = finalUrl.replace(/\{\{key\}\}/g, encodeURIComponent(keyword));
        }

        if (finalUrl.includes('{{page}}')) {
          finalUrl = finalUrl.replace(/\{\{page\}\}/g, String(page));
        }

        if (finalUrl.includes('{{(page - 1) * 10}}')) {
          finalUrl = finalUrl.replace(/\{\{\(page - 1\) \* 10\}\}/g, String((page - 1) * 10));
        }

        if (urlConfig.body) {
          if (urlConfig.body.includes('{{key}}')) {
            urlConfig.body = urlConfig.body.replace(/\{\{key\}\}/g, encodeURIComponent(keyword));
          }
          if (urlConfig.body.includes('{{page}}')) {
            urlConfig.body = urlConfig.body.replace(/\{\{page\}\}/g, String(page));
          }
          if (urlConfig.body.includes('{{(page - 1) * 10}}')) {
            urlConfig.body = urlConfig.body.replace(/\{\{\(page - 1\) \* 10\}\}/g, String((page - 1) * 10));
          }
          Logger.info(TAG, `POST请求体: ${urlConfig.body}`);
        }
      }

      finalUrl = finalUrl.trim();

      if (!finalUrl) {
        Logger.error(TAG, `书源 ${bookSource.name} URL为空，跳过`);
        return [];
      }

      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        if (bookSource.url && finalUrl.startsWith('/')) {
          finalUrl = bookSource.url + finalUrl;
          Logger.info(TAG, `相对路径转换为绝对路径: ${finalUrl}`);
        } else if (bookSource.url && !finalUrl.startsWith('http')) {
          finalUrl = bookSource.url + '/' + finalUrl;
          Logger.info(TAG, `补全URL: ${finalUrl}`);
        } else {
          Logger.error(TAG, `URL格式无效: ${finalUrl}，书源URL: ${bookSource.url}`);
          return [];
        }
      }

      Logger.info(TAG, `最终搜索URL: ${finalUrl}, 方法: ${urlConfig.method}`);

      let html: string;
      try {
        if (urlConfig.method === 'POST') {
          html = await this.post(finalUrl, urlConfig.body || '', urlConfig.headers);
        } else {
          html = await this.get(finalUrl, urlConfig.headers);
        }
        Logger.info(TAG, `获取到HTML内容，长度: ${html.length} 字符`);
      } catch (netError) {
        Logger.error(TAG, `网络请求失败: ${netError instanceof Error ? netError.message : String(netError)}`);
        return [];
      }

      if (!html || html.length === 0) {
        Logger.warn(TAG, `响应内容为空`);
        return [];
      }

      const results: ParsedBookItem[] = ContentParser.parseSearchResult(html, bookSource);
      Logger.info(TAG, `书源 ${bookSource.name} 找到 ${results.length} 条结果`);

      const books = results.map((item: ParsedBookItem) => this.convertToBook(item, bookSource));
      Logger.info(TAG, `========== 搜索完成 ==========`);
      return books;

    } catch (error) {
      Logger.error(TAG, `搜索失败 - 书源: ${bookSource.name}, 错误: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  private parseHeaderString(headerStr: string): HttpHeaderMap {
    const map: HttpHeaderMap = new Map<string, string>();
    try {
      const parsed = JSON.parse(headerStr) as Record<string, string>;
      const keys = Object.keys(parsed);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const value = parsed[key];
        if (typeof value === 'string') {
          map.set(key, value);
        }
      }
    } catch (e) {
      // 解析失败，返回空map
    }
    return map;
  }

  private parseUrlConfig(configStr: string, baseHeaders: HttpHeaderMap): UrlConfig {
    const config: UrlConfig = {
      method: 'GET',
      headers: new Map<string, string>(baseHeaders)
    };

    try {
      const parsed = JSON.parse(configStr) as Record<string, string | number | boolean | object | null | undefined>;

      if (parsed.method && typeof parsed.method === 'string') {
        const method = parsed.method.toUpperCase();
        if (method === 'POST') {
          config.method = 'POST';
        }
      }

      if (parsed.body && typeof parsed.body === 'string') {
        config.body = parsed.body;
      }

      if (parsed.headers && typeof parsed.headers === 'object') {
        const headerObj = parsed.headers as Record<string, string>;
        const keys = Object.keys(headerObj);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          const value = headerObj[key];
          if (typeof value === 'string') {
            config.headers.set(key, value);
          }
        }
      }

      const otherKeys = Object.keys(parsed);
      for (let i = 0; i < otherKeys.length; i++) {
        const key = otherKeys[i];
        if (key !== 'method' && key !== 'body' && key !== 'headers') {
          const value = parsed[key];
          if (typeof value === 'string') {
            config.headers.set(key, value);
          }
        }
      }
    } catch (e) {
      Logger.warn('NetworkManager', `解析URL配置失败: ${e}`);
    }

    return config;
  }

  /**
   * 将搜索结果转换为Book对象
   */
  private convertToBook(item: ParsedBookItem, bookSource: BookSource): Book {
    // 解析bookUrl，如果是相对路径则转换为绝对路径
    let bookUrl = item.bookUrl || '';
    if (bookUrl && !bookUrl.startsWith('http')) {
      bookUrl = this.resolveUrl(bookSource.url, bookUrl);
    }

    // 解析cover，如果是相对路径则转换为绝对路径
    let cover = item.cover;
    if (cover && !cover.startsWith('http') && !cover.startsWith('data:')) {
      cover = this.resolveUrl(bookSource.url, cover);
    }

    const book: Book = {
      id: `book_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      name: item.name || '',
      author: item.author || '',
      cover: cover,
      intro: item.intro,
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookSourceId: bookSource.id,
      bookSourceName: bookSource.name,
      bookUrl: bookUrl,
      lastUpdateTime: Date.now(),
      addTime: Date.now(),
      readProgress: 0,
      lastReadChapter: undefined,
      lastReadChapterIndex: undefined
    };
    return book;
  }

  /**
   * 获取章节列表
   */
  async getChapterList(bookSource: BookSource, bookUrl: string): Promise<ParsedChapterItem[]> {
    try {
      const headers: HttpHeaderMap | undefined = bookSource.networkConfig?.header
        ? this.parseHeaderString(bookSource.networkConfig.header)
        : undefined;

      const fullUrl = this.resolveUrl(bookSource.url, bookUrl);
      Logger.info('NetworkManager', `Getting chapter list from: ${fullUrl}`);

      const html = await this.get(fullUrl, headers);

      // 使用异步解析器避免主线程阻塞
      const chapterRule = bookSource.rules.tocRule;
      if (!chapterRule) {
        Logger.error('NetworkManager', `书源未配置章节规则: ${bookSource.name}`);
        return [];
      }

      const asyncParser = AsyncChapterParser.getInstance();
      const chapters: ParsedChapterItem[] = await asyncParser.parseChapterList(
        html,
        chapterRule.chapterList,
        chapterRule.chapterName || '',
        chapterRule.chapterUrl || '',
        fullUrl
      );

      Logger.info('NetworkManager', `Found ${chapters.length} chapters`);

      const uniqueChapters: ParsedChapterItem[] = [];
      const seenUrls = new Set<string>();

      for (let i = 0; i < chapters.length; i++) {
        const chapter = chapters[i];
        if (chapter.url) {
          if (!chapter.url.startsWith('http')) {
            chapter.url = this.resolveUrl(fullUrl, chapter.url);
          }

          if (!seenUrls.has(chapter.url)) {
            seenUrls.add(chapter.url);
            uniqueChapters.push(chapter);
          }
        } else if (chapter.title) {
          uniqueChapters.push(chapter);
        }
      }

      return uniqueChapters;
    } catch (error) {
      Logger.error('NetworkManager', `Failed to get chapter list: ${error}`);
      return [];
    }
  }

  /**
   * 获取章节内容
   */
  async getChapterContent(bookSource: BookSource, chapterUrl: string): Promise<string> {
    const TAG = 'NetworkManager';
    try {
      Logger.info(TAG, `========== 开始获取章节内容 ==========`);
      Logger.info(TAG, `章节URL: ${chapterUrl}`);
      Logger.info(TAG, `书源: ${bookSource.name}, 规则类型: ${bookSource.legacy.ruleType}`);
      Logger.debug(TAG, `内容规则: ${bookSource.rules.contentRule?.content || '未配置'}`);

      const headers: HttpHeaderMap | undefined = bookSource.networkConfig?.header
        ? this.parseHeaderString(bookSource.networkConfig.header)
        : undefined;

      if (headers) {
        Logger.debug(TAG, `请求头: ${JSON.stringify(Array.from(headers.entries()))}`);
      }

      const html = await this.get(chapterUrl, headers);
      Logger.info(TAG, `获取到HTML内容，长度: ${html.length} 字符`);
      Logger.debug(TAG, `HTML前500字符: ${html.substring(0, 500)}`);

      // 使用异步解析器避免主线程阻塞
      const contentRule = bookSource.rules.contentRule;
      if (!contentRule || !contentRule.content) {
        Logger.error(TAG, `书源未配置内容规则: ${bookSource.name}`);
        return '本章内容为空';
      }

      const asyncParser = AsyncContentParser.getInstance();
      const content = await asyncParser.parseChapterContent(
        html,
        contentRule.content,
        contentRule.replaceRule
      );
      
      Logger.info(TAG, `解析后内容长度: ${content.length} 字符`);
      Logger.debug(TAG, `内容前200字符: ${content.substring(0, 200)}`);

      if (!content || content.trim().length === 0) {
        Logger.warn(TAG, `解析结果为空，返回默认提示`);
        return '本章内容为空';
      }

      const maxContentLength = 50000;
      if (content.length > maxContentLength) {
        Logger.info(TAG, `内容过长，截断至 ${maxContentLength} 字符`);
        return content.substring(0, maxContentLength) + '...';
      }

      Logger.info(TAG, `========== 章节内容获取成功 ==========`);
      return content;
    } catch (error) {
      Logger.error(TAG, `========== 章节内容获取失败 ==========`);
      Logger.error(TAG, `错误详情: ${error instanceof Error ? error.message : String(error)}`);
      Logger.error(TAG, `错误堆栈: ${error instanceof Error ? error.stack : '无堆栈信息'}`);
      return `获取章节内容失败: ${error instanceof Error ? error.message : '未知错误'}`;
    }
  }

  /**
   * URL解析与拼接
   */
  private resolveUrl(baseUrl: string, relative: string): string {
    if (relative.startsWith('http')) {
      return relative;
    }

    if (relative.startsWith('//')) {
      const protocol = baseUrl.startsWith('https') ? 'https:' : 'http:';
      return protocol + relative;
    }

    const baseMatch = baseUrl.match(/^(https?:\/\/[^/]+)(\/.*)?$/);
    const origin = baseMatch ? baseMatch[1] : '';

    if (relative.startsWith('/')) {
      return origin + relative;
    }

    const lastSlashIndex = baseUrl.lastIndexOf('/');
    const basePath = lastSlashIndex >= 0 ? baseUrl.substring(0, lastSlashIndex + 1) : baseUrl;
    return basePath + relative;
  }
}
