/**
 * BookSourceNetworkService - 书源网络服务
 * 专注于书源相关的业务逻辑，底层网络请求委托给 HttpClient
 */

import { HttpClient } from '../network/HttpClient';
import {
  HttpMethod,
  HttpRequestConfig,
  HttpResponse,
  HttpHeaderMap
} from '../network/interfaces/IHttpClient';
import { BookSource } from '../models/BookSource';
import { ContentParser, ParsedBookItem, ParsedChapterItem } from '../utils/ContentParser';
import { Book } from '../models/Book';
import { Logger } from '../utils/Logger';
import { AsyncChapterParser } from '../utils/AsyncChapterParser';
import { AsyncContentParser } from '../utils/AsyncContentParser';
import astroReadJSRuntime, { SearchContext } from '../utils/AstroReadJSRuntime';

interface UrlConfig {
  method: 'GET' | 'POST';
  body?: string;
  headers: Map<string, string>;
}

interface AntiCrawlingResult {
  detected: boolean;
  indicators: string[];
}

export class BookSourceNetworkService {
  private static instance: BookSourceNetworkService | null = null;
  private httpClient: HttpClient;
  private readonly TAG = 'BookSourceNetworkService';

  private readonly ANTI_CRAWLING_INDICATORS = [
    'probe.js',
    'bot detection',
    'captcha',
    'cloudflare',
    'access denied',
    '请验证',
    '人机验证',
    '安全验证'
  ];

  private constructor() {
    this.httpClient = HttpClient.getInstance();
  }

  static getInstance(): BookSourceNetworkService {
    if (BookSourceNetworkService.instance === null) {
      BookSourceNetworkService.instance = new BookSourceNetworkService();
    }
    return BookSourceNetworkService.instance;
  }

  /**
   * 发送GET请求
   */
  async get(url: string, headers?: Map<string, string>): Promise<string> {
    const config: HttpRequestConfig = {
      url,
      method: HttpMethod.GET,
      headers: headers ? this.mapToHttpHeaders(headers) : undefined,
      responseType: { type: 'text' }
    };

    const response = await this.httpClient.request<string>(config);
    return response.data;
  }

  /**
   * 发送POST请求
   */
  async post(url: string, data: string, headers?: Map<string, string>): Promise<string> {
    const config: HttpRequestConfig = {
      url,
      method: HttpMethod.POST,
      headers: headers ? this.mapToHttpHeaders(headers) : undefined,
      data,
      responseType: { type: 'text' }
    };

    const response = await this.httpClient.request<string>(config);
    return response.data;
  }

  /**
   * 搜索书籍 - 支持JavaScript书源
   */
  async searchBook(bookSource: BookSource, keyword: string, page: number = 1): Promise<Book[]> {
    try {
      Logger.info(this.TAG, `========== 开始搜索 ==========`);
      Logger.info(this.TAG, `书源: ${bookSource.name}, 关键词: ${keyword}, 页码: ${page}`);

      let searchUrl = bookSource.searchUrl;

      if (!searchUrl || searchUrl.trim() === '') {
        Logger.error(this.TAG, `书源 ${bookSource.name} 没有配置搜索URL，跳过此书源`);
        return [];
      }

      searchUrl = searchUrl.trim();
      Logger.info(this.TAG, `原始搜索URL模板: ${searchUrl}`);

      let headers: Map<string, string> = new Map<string, string>();
      if (bookSource.header) {
        try {
          headers = this.parseHeaderString(bookSource.header);
          Logger.debug(this.TAG, `请求头: ${JSON.stringify(Array.from(headers.entries()))}`);
        } catch (e) {
          Logger.warn(this.TAG, `解析请求头失败: ${bookSource.name}`);
        }
      }

      let finalUrl = '';
      let urlConfig: UrlConfig = {
        method: 'GET',
        headers: headers
      };

      if (searchUrl.startsWith('@js:')) {
        Logger.info(this.TAG, `执行JavaScript书源: ${bookSource.name}`);

        const context: SearchContext = {
          key: keyword,
          page: page,
          baseUrl: bookSource.url
        };

        finalUrl = await astroReadJSRuntime.executeSearchUrl(searchUrl, context);

        if (!finalUrl) {
          Logger.warn(this.TAG, `JavaScript执行未返回URL: ${bookSource.name}`);
          return [];
        }

        Logger.info(this.TAG, `JavaScript生成URL: ${finalUrl}`);
      } else {
        finalUrl = searchUrl;

        const commaIndex = finalUrl.indexOf(',{');
        if (commaIndex > 0 && finalUrl.endsWith('}')) {
          try {
            const urlPart = finalUrl.substring(0, commaIndex);
            const configPart = finalUrl.substring(commaIndex + 1);
            urlConfig = this.parseUrlConfig(configPart, headers);
            finalUrl = urlPart;
            Logger.info(this.TAG, `从URL中提取配置，方法: ${urlConfig.method}, 最终URL: ${finalUrl}`);
          } catch (e) {
            Logger.warn(this.TAG, `URL配置解析失败，保持原URL`);
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
          Logger.info(this.TAG, `POST请求体: ${urlConfig.body}`);
        }
      }

      finalUrl = finalUrl.trim();

      if (!finalUrl) {
        Logger.error(this.TAG, `书源 ${bookSource.name} URL为空，跳过`);
        return [];
      }

      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        if (bookSource.url && finalUrl.startsWith('/')) {
          finalUrl = bookSource.url + finalUrl;
          Logger.info(this.TAG, `相对路径转换为绝对路径: ${finalUrl}`);
        } else if (bookSource.url && !finalUrl.startsWith('http')) {
          finalUrl = bookSource.url + '/' + finalUrl;
          Logger.info(this.TAG, `补全URL: ${finalUrl}`);
        } else {
          Logger.error(this.TAG, `URL格式无效: ${finalUrl}，书源URL: ${bookSource.url}`);
          return [];
        }
      }

      Logger.info(this.TAG, `最终搜索URL: ${finalUrl}, 方法: ${urlConfig.method}`);

      let html: string;
      try {
        if (urlConfig.method === 'POST') {
          html = await this.post(finalUrl, urlConfig.body || '', urlConfig.headers);
        } else {
          html = await this.get(finalUrl, urlConfig.headers);
        }
        Logger.info(this.TAG, `获取到HTML内容，长度: ${html.length} 字符`);
      } catch (netError) {
        Logger.error(this.TAG, `网络请求失败: ${netError instanceof Error ? netError.message : String(netError)}`);
        return [];
      }

      if (!html || html.length === 0) {
        Logger.warn(this.TAG, `响应内容为空`);
        return [];
      }

      const antiCrawlingResult = this.detectAntiCrawling(html);
      if (antiCrawlingResult.detected) {
        Logger.warn(this.TAG, `检测到可能的反爬虫响应: ${antiCrawlingResult.indicators.join(', ')}`);
      }

      const results: ParsedBookItem[] = ContentParser.parseSearchResult(html, bookSource);
      Logger.info(this.TAG, `书源 ${bookSource.name} 找到 ${results.length} 条结果`);

      const books = results.map((item: ParsedBookItem) => this.convertToBook(item, bookSource));
      Logger.info(this.TAG, `========== 搜索完成 ==========`);
      return books;

    } catch (error) {
      Logger.error(this.TAG, `搜索失败 - 书源: ${bookSource.name}, 错误: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 获取章节列表
   */
  async getChapterList(bookSource: BookSource, bookUrl: string): Promise<ParsedChapterItem[]> {
    try {
      const headers: Map<string, string> | undefined = bookSource.header
        ? this.parseHeaderString(bookSource.header)
        : undefined;

      const fullUrl = this.resolveUrl(bookSource.url, bookUrl);
      Logger.info(this.TAG, `Getting chapter list from: ${fullUrl}`);

      const html = await this.get(fullUrl, headers);

      const chapterRule = bookSource.chapterRule;
      if (!chapterRule) {
        Logger.error(this.TAG, `书源未配置章节规则: ${bookSource.name}`);
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

      Logger.info(this.TAG, `Found ${chapters.length} chapters`);

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
      Logger.error(this.TAG, `Failed to get chapter list: ${error}`);
      return [];
    }
  }

  /**
   * 获取章节内容
   */
  async getChapterContent(bookSource: BookSource, chapterUrl: string): Promise<string> {
    try {
      Logger.info(this.TAG, `========== 开始获取章节内容 ==========`);
      Logger.info(this.TAG, `章节URL: ${chapterUrl}`);
      Logger.info(this.TAG, `书源: ${bookSource.name}, 规则类型: ${bookSource.ruleType}`);
      Logger.debug(this.TAG, `内容规则: ${bookSource.contentRule?.content || '未配置'}`);

      const headers: Map<string, string> | undefined = bookSource.header
        ? this.parseHeaderString(bookSource.header)
        : undefined;

      if (headers) {
        Logger.debug(this.TAG, `请求头: ${JSON.stringify(Array.from(headers.entries()))}`);
      }

      const html = await this.get(chapterUrl, headers);
      Logger.info(this.TAG, `获取到HTML内容，长度: ${html.length} 字符`);
      Logger.debug(this.TAG, `HTML前500字符: ${html.substring(0, 500)}`);

      const contentRule = bookSource.contentRule;
      if (!contentRule || !contentRule.content) {
        Logger.error(this.TAG, `书源未配置内容规则: ${bookSource.name}`);
        return '本章内容为空';
      }

      const asyncParser = AsyncContentParser.getInstance();
      const content = await asyncParser.parseChapterContent(
        html,
        contentRule.content,
        contentRule.replaceRule
      );

      Logger.info(this.TAG, `解析后内容长度: ${content.length} 字符`);
      Logger.debug(this.TAG, `内容前200字符: ${content.substring(0, 200)}`);

      if (!content || content.trim().length === 0) {
        Logger.warn(this.TAG, `解析结果为空，返回默认提示`);
        return '本章内容为空';
      }

      const maxContentLength = 50000;
      if (content.length > maxContentLength) {
        Logger.info(this.TAG, `内容过长，截断至 ${maxContentLength} 字符`);
        return content.substring(0, maxContentLength) + '...';
      }

      Logger.info(this.TAG, `========== 章节内容获取成功 ==========`);
      return content;
    } catch (error) {
      Logger.error(this.TAG, `========== 章节内容获取失败 ==========`);
      Logger.error(this.TAG, `错误详情: ${error instanceof Error ? error.message : String(error)}`);
      Logger.error(this.TAG, `错误堆栈: ${error instanceof Error ? error.stack : '无堆栈信息'}`);
      return `获取章节内容失败: ${error instanceof Error ? error.message : '未知错误'}`;
    }
  }

  /**
   * 检测反爬虫响应
   */
  private detectAntiCrawling(html: string): AntiCrawlingResult {
    const lowerHtml = html.toLowerCase();
    const indicators: string[] = [];

    for (const indicator of this.ANTI_CRAWLING_INDICATORS) {
      if (lowerHtml.includes(indicator.toLowerCase())) {
        indicators.push(indicator);
      }
    }

    return {
      detected: indicators.length > 0,
      indicators
    };
  }

  /**
   * 解析请求头字符串
   */
  private parseHeaderString(headerStr: string): Map<string, string> {
    const map: Map<string, string> = new Map<string, string>();
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
    } catch {
      // 解析失败，返回空map
    }
    return map;
  }

  /**
   * 解析URL配置
   */
  private parseUrlConfig(configStr: string, baseHeaders: Map<string, string>): UrlConfig {
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
      Logger.warn(this.TAG, `解析URL配置失败: ${e}`);
    }

    return config;
  }

  /**
   * 将搜索结果转换为Book对象
   */
  private convertToBook(item: ParsedBookItem, bookSource: BookSource): Book {
    let bookUrl = item.bookUrl || '';
    if (bookUrl && !bookUrl.startsWith('http')) {
      bookUrl = this.resolveUrl(bookSource.url, bookUrl);
    }

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

  /**
   * 将Map转换为HttpHeaders
   */
  private mapToHttpHeaders(map: Map<string, string>): Record<string, string> {
    const record: Record<string, string> = {};
    map.forEach((value, key) => {
      record[key] = value;
    });
    return record;
  }
}

export default BookSourceNetworkService.getInstance();
