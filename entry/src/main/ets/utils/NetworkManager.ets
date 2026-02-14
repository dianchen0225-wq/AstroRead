import http from '@ohos.net.http';
import { BookSource } from '../models/BookSource';
import { ContentParser, ParsedBookItem, ParsedChapterItem } from './ContentParser';
import { Book } from '../models/Book';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import astroReadJSRuntime, { SearchContext } from './AstroReadJSRuntime';
import { Logger } from './Logger';
import { BusinessError } from '@kit.BasicServicesKit';

class HttpError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }
}

interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  retryableStatusCodes: number[];
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 3,
  baseDelay: 1000,
  maxDelay: 10000,
  retryableStatusCodes: [408, 429, 500, 502, 503, 504]
};

/**
 * 网络请求管理器
 */
export class NetworkManager {
  private static instance: NetworkManager | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  setContext(context: common.UIAbilityContext): void {
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

  private isRetryableError(error: Error, statusCode?: number, config: RetryConfig = DEFAULT_RETRY_CONFIG): boolean {
    if (statusCode && config.retryableStatusCodes.includes(statusCode)) {
      return true;
    }

    const errorMessage = error.message.toLowerCase();
    return errorMessage.includes('timeout') ||
      errorMessage.includes('network') ||
      errorMessage.includes('connection') ||
      errorMessage.includes('econnreset') ||
      errorMessage.includes('econnrefused');
  }

  async requestWithRetry<T>(
    requestFn: () => Promise<T>,
    config: RetryConfig = DEFAULT_RETRY_CONFIG
  ): Promise<T> {
    let lastError: Error = new Error('Unknown error');

    for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        return await requestFn();
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));

        if (attempt < config.maxRetries && this.isRetryableError(lastError, undefined, config)) {
          const delay = this.calculateBackoffDelay(attempt, config.baseDelay, config.maxDelay);
          Logger.warn('NetworkManager', `请求失败，${delay}ms后重试 (${attempt + 1}/${config.maxRetries}): ${lastError.message}`);
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
   * 发送GET请求
   */
  async get(url: string, headers?: Record<string, string>, maxResponseSize?: number): Promise<string> {
    return this.requestWithRetry(async () => {
      const httpRequest = http.createHttp();

      try {
        const requestHeaders: Record<string, string> = headers || {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
        };

        const requestOptions: http.HttpRequestOptions = {
          method: http.RequestMethod.GET,
          header: requestHeaders,
          connectTimeout: 15000,
          readTimeout: 15000
        };

        const response = await httpRequest.request(url, requestOptions);

        if (response.responseCode === 200) {
          const responseText = response.result.toString();

          if (maxResponseSize && responseText.length > maxResponseSize) {
            throw new Error(`响应大小超过限制: ${responseText.length}字节`);
          }

          return responseText;
        } else if (response.responseCode === 301 || response.responseCode === 302) {
          const headersObj = response.header as Record<string, string>;
          let location: string | undefined;

          if (headersObj) {
            location = headersObj['Location'] || headersObj['location'] || headersObj['LOCATION'];
          }

          if (location) {
            const redirectUrl = this.resolveUrl(url, location);
            Logger.info('NetworkManager', `Redirecting to: ${redirectUrl}`);
            return this.get(redirectUrl, headers, maxResponseSize);
          } else {
            throw new Error(`HTTP ${response.responseCode}: No redirect location`);
          }
        } else {
          throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
        }
      } catch (e) {
        let error: BusinessError = e as BusinessError;
        Logger.error('NetworkManager', `httpRequest.request call failed. code is ${error.code}, message is ${error.message}`);
        throw new Error(error.message);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  /**
   * 发送POST请求
   */
  async post(url: string, data: string, headers?: Record<string, string>, maxResponseSize?: number): Promise<string> {
    return this.requestWithRetry(async () => {
      const httpRequest = http.createHttp();

      try {
        const mergedHeaders: Record<string, string> = {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
        };

        if (headers) {
          const keys = Object.keys(headers);
          for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            mergedHeaders[key] = headers[key];
          }
        }

        const requestOptions: http.HttpRequestOptions = {
          method: http.RequestMethod.POST,
          header: mergedHeaders,
          extraData: data,
          connectTimeout: 15000,
          readTimeout: 15000
        };

        const response = await httpRequest.request(url, requestOptions);

        if (response.responseCode === 200) {
          const responseText = response.result.toString();

          if (maxResponseSize && responseText.length > maxResponseSize) {
            throw new Error(`响应大小超过限制: ${responseText.length}字节`);
          }

          return responseText;
        } else {
          throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
        }
      } catch (e) {
        let error: BusinessError = e as BusinessError;
        Logger.error('NetworkManager', `httpRequest.request call failed. code is ${error.code}, message is ${error.message}`);
        throw new Error(error.message);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  /**
   * 搜索书籍 - 支持JavaScript书源
   */
  async searchBook(bookSource: BookSource, keyword: string, page: number = 1): Promise<Book[]> {
    const TAG = 'NetworkManager';
    try {
      let searchUrl = bookSource.searchUrl;

      // 解析请求头
      let headers: Record<string, string> | undefined = undefined;
      if (bookSource.header) {
        try {
          headers = JSON.parse(bookSource.header) as Record<string, string>;
        } catch (e) {
          Logger.warn(TAG, `Failed to parse headers for ${bookSource.name}`);
        }
      }

      let finalUrl = '';

      // 处理JavaScript书源
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
        // 处理普通模板变量
        finalUrl = searchUrl;

        // 替换 {{key}} 关键词
        if (finalUrl.includes('{{key}}')) {
          finalUrl = finalUrl.replace(/\{\{key\}\}/g, encodeURIComponent(keyword));
        }

        // 替换 {{page}} 页码
        if (finalUrl.includes('{{page}}')) {
          finalUrl = finalUrl.replace(/\{\{page\}\}/g, String(page));
        }

        // 替换 {{(page - 1) * 10}} 等偏移量表达式
        if (finalUrl.includes('{{(page - 1) * 10}}')) {
          finalUrl = finalUrl.replace(/\{\{\(page - 1\) \* 10\}\}/g, String((page - 1) * 10));
        }

        // 处理URL中可能包含的JSON配置
        const commaIndex = finalUrl.indexOf(',{');
        if (commaIndex > 0 && finalUrl.endsWith('}')) {
          try {
            const urlPart = finalUrl.substring(0, commaIndex);
            const configPart = finalUrl.substring(commaIndex + 1);
            const config = JSON.parse(configPart) as Record<string, Record<string, string>>;
            if (config.headers && headers) {
              // 手动合并headers - 不使用spread
              const configHeaderKeys = Object.keys(config.headers);
              for (let i = 0; i < configHeaderKeys.length; i++) {
                const key = configHeaderKeys[i];
                headers[key] = config.headers[key];
              }
            }
            finalUrl = urlPart;
          } catch (e) {
            // 如果解析失败，保持原URL
          }
        }
      }

      // 验证URL
      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        Logger.warn(TAG, `Invalid URL for ${bookSource.name}: ${finalUrl}`);
        return [];
      }

      Logger.info(TAG, `Searching with URL: ${finalUrl}`);
      const html = await this.get(finalUrl, headers);

      // 使用规则解析引擎解析搜索结果
      const results: ParsedBookItem[] = ContentParser.parseSearchResult(html, bookSource);
      Logger.info(TAG, `Found ${results.length} results from ${bookSource.name}`);

      // 转换为Book对象
      return results.map((item: ParsedBookItem) => this.convertToBook(item, bookSource));

    } catch (error) {
      Logger.error(TAG, `Search failed for ${bookSource.name}: ${error}`);
      return [];
    }
  }

  /**
   * 将搜索结果转换为Book对象
   */
  private convertToBook(item: ParsedBookItem, bookSource: BookSource): Book {
    const book: Book = {
      id: `book_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      name: item.name || '',
      author: item.author || '',
      cover: item.cover,
      intro: item.intro,
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookSourceId: bookSource.id,
      bookSourceName: bookSource.name,
      bookUrl: item.bookUrl || '',
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
      const headers: Record<string, string> | undefined = bookSource.header
        ? (JSON.parse(bookSource.header) as Record<string, string>)
        : undefined;

      const fullUrl = this.resolveUrl(bookSource.url, bookUrl);
      Logger.info('NetworkManager', `Getting chapter list from: ${fullUrl}`);

      const html = await this.get(fullUrl, headers);

      const chapters: ParsedChapterItem[] = ContentParser.parseChapterList(html, bookSource);
      Logger.info('NetworkManager', `Found ${chapters.length} chapters`);

      // 处理相对URL并去重
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
    try {
      Logger.info('NetworkManager', `Getting chapter content from: ${chapterUrl}`);

      const headers: Record<string, string> | undefined = bookSource.header
        ? (JSON.parse(bookSource.header) as Record<string, string>)
        : undefined;

      const html = await this.get(chapterUrl, headers);

      const content = ContentParser.parseChapterContent(html, bookSource);

      if (!content || content.trim().length === 0) {
        return '本章内容为空';
      }

      // 限制内容长度
      const maxContentLength = 50000;
      if (content.length > maxContentLength) {
        return content.substring(0, maxContentLength) + '...';
      }

      return content;
    } catch (error) {
      Logger.error('NetworkManager', `Failed to get chapter content: ${error}`);
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
