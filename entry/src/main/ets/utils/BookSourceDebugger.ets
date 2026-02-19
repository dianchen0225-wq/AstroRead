/**
 * BookSourceDebugger - 书源调试工具
 * 提供实时测试、日志输出、中间结果查看等功能
 */

import { BookSource, SearchRule, ChapterRule, ContentRule } from '../models/BookSource';
import { BookSourceSearchEngine } from './BookSourceSearchEngine';
import NetworkAdapter from './NetworkAdapter';
import { HTMLParser } from './HTMLParser';
import { EnhancedJSEngine } from './EnhancedJSEngine';
import { Logger } from './Logger';

export interface DebugStep {
  name: string;
  status: 'pending' | 'running' | 'success' | 'error';
  duration?: number;
  input?: string;
  output?: string;
  error?: string;
}

export interface BookInfo {
  name: string;
  author: string;
  cover: string;
  intro: string;
  bookUrl: string;
}

export interface ChapterInfo {
  title: string;
  url: string;
}

export interface DebugResult {
  success: boolean;
  steps: DebugStep[];
  summary: string;
  books?: BookInfo[];
  chapters?: ChapterInfo[];
  content?: string;
}

interface UrlConfig {
  method: 'GET' | 'POST';
  body?: string;
  headers: Record<string, string>;
}

interface SearchUrlResult {
  url: string;
  config: UrlConfig;
}

export class BookSourceDebugger {
  private static instance: BookSourceDebugger | null = null;
  private searchEngine: BookSourceSearchEngine;
  private htmlParser: HTMLParser;
  private jsEngine: EnhancedJSEngine;
  private readonly TAG = 'BookSourceDebugger';

  private constructor() {
    this.searchEngine = BookSourceSearchEngine.getInstance();
    this.htmlParser = HTMLParser.getInstance();
    this.jsEngine = EnhancedJSEngine.getInstance();
  }

  static getInstance(): BookSourceDebugger {
    if (!BookSourceDebugger.instance) {
      BookSourceDebugger.instance = new BookSourceDebugger();
    }
    return BookSourceDebugger.instance;
  }

  /**
   * 测试搜索功能
   */
  async testSearch(
    source: BookSource,
    keyword: string,
    onStep?: (step: DebugStep) => void
  ): Promise<DebugResult> {
    const steps: DebugStep[] = [];
    const startTime = Date.now();

    const addStep = (step: DebugStep) => {
      steps.push(step);
      if (onStep) {
        onStep(step);
      }
    };

    try {
      // 步骤 1: 验证书源配置
      addStep({ name: '验证书源配置', status: 'running' });
      if (!source.searchUrl) {
        throw new Error('搜索 URL 未配置');
      }
      if (!source.searchRule?.bookList) {
        throw new Error('书籍列表规则未配置');
      }
      addStep({
        name: '验证书源配置',
        status: 'success',
        duration: Date.now() - startTime
      });

      // 步骤 2: 构建搜索 URL
      const step2Start = Date.now();
      addStep({ name: '构建搜索 URL', status: 'running', input: `关键词: ${keyword}` });

      const urlConfig = await this.buildSearchUrlWithConfig(source, keyword);
      addStep({
        name: '构建搜索 URL',
        status: 'success',
        duration: Date.now() - step2Start,
        output: `${urlConfig.url} (方法: ${urlConfig.config.method})`
      });

      // 步骤 3: 发送网络请求
      const step3Start = Date.now();
      addStep({ name: '发送网络请求', status: 'running', input: urlConfig.url });

      let html: string;
      if (urlConfig.config.method === 'POST') {
        html = await NetworkAdapter.post(urlConfig.url, urlConfig.config.body || '', urlConfig.config.headers);
      } else {
        html = await NetworkAdapter.get(urlConfig.url, urlConfig.config.headers);
      }

      addStep({
        name: '发送网络请求',
        status: 'success',
        duration: Date.now() - step3Start,
        output: `响应大小: ${html.length} 字符`
      });

      // 步骤 4: 解析书籍列表
      const step4Start = Date.now();
      addStep({ name: '解析书籍列表', status: 'running', input: source.searchRule.bookList });

      const bookList = this.htmlParser.parse(html, source.searchRule.bookList);

      addStep({
        name: '解析书籍列表',
        status: 'success',
        duration: Date.now() - step4Start,
        output: `找到 ${bookList.length} 本书`
      });

      // 步骤 5: 解析书籍详情
      const step5Start = Date.now();
      addStep({ name: '解析书籍详情', status: 'running' });

      const books: BookInfo[] = [];
      for (let i = 0; i < Math.min(bookList.length, 3); i++) {
        const bookHtml = bookList[i];
        const book = await this.parseBookInfo(source, bookHtml);
        books.push(book);
      }

      addStep({
        name: '解析书籍详情',
        status: 'success',
        duration: Date.now() - step5Start,
        output: JSON.stringify(books[0], null, 2)
      });

      return {
        success: true,
        steps,
        summary: `搜索成功，找到 ${bookList.length} 本书`,
        books
      };

    } catch (error) {
      const currentStep = steps[steps.length - 1];
      if (currentStep) {
        currentStep.status = 'error';
        currentStep.error = String(error);
      }

      return {
        success: false,
        steps,
        summary: `搜索失败: ${error}`
      };
    }
  }

  /**
   * 测试章节列表获取
   */
  async testChapterList(
    source: BookSource,
    bookUrl: string,
    onStep?: (step: DebugStep) => void
  ): Promise<DebugResult> {
    const steps: DebugStep[] = [];

    const addStep = (step: DebugStep) => {
      steps.push(step);
      if (onStep) {
        onStep(step);
      }
    };

    try {
      // 步骤 1: 发送请求
      addStep({ name: '获取书籍页面', status: 'running', input: bookUrl });

      const html = await NetworkAdapter.get(bookUrl);

      addStep({
        name: '获取书籍页面',
        status: 'success',
        output: `响应大小: ${html.length} 字符`
      });

      // 步骤 2: 解析章节列表
      addStep({ name: '解析章节列表', status: 'running' });

      const chapterRule = source.chapterRule;
      if (!chapterRule?.chapterList) {
        throw new Error('章节列表规则未配置');
      }

      const chapterList = this.htmlParser.parse(html, chapterRule.chapterList);

      addStep({
        name: '解析章节列表',
        status: 'success',
        output: `找到 ${chapterList.length} 个章节`
      });

      // 步骤 3: 解析章节详情
      const chapters: ChapterInfo[] = [];
      for (let i = 0; i < Math.min(chapterList.length, 5); i++) {
        const chapterHtml = chapterList[i];
        const chapter = await this.parseChapterInfo(source, chapterHtml);
        chapters.push(chapter);
      }

      return {
        success: true,
        steps,
        summary: `获取章节成功，共 ${chapterList.length} 章`,
        chapters
      };

    } catch (error) {
      return {
        success: false,
        steps,
        summary: `获取章节失败: ${error}`
      };
    }
  }

  /**
   * 测试章节内容获取
   */
  async testContent(
    source: BookSource,
    chapterUrl: string,
    onStep?: (step: DebugStep) => void
  ): Promise<DebugResult> {
    const steps: DebugStep[] = [];

    const addStep = (step: DebugStep) => {
      steps.push(step);
      if (onStep) {
        onStep(step);
      }
    };

    try {
      // 步骤 1: 发送请求
      addStep({ name: '获取章节页面', status: 'running', input: chapterUrl });

      const html = await NetworkAdapter.get(chapterUrl);

      addStep({
        name: '获取章节页面',
        status: 'success',
        output: `响应大小: ${html.length} 字符`
      });

      // 步骤 2: 解析正文
      addStep({ name: '解析正文内容', status: 'running' });

      const contentRule = source.contentRule;
      if (!contentRule?.content) {
        throw new Error('正文规则未配置');
      }

      const content = this.htmlParser.parse(html, contentRule.content);

      addStep({
        name: '解析正文内容',
        status: 'success',
        output: `正文长度: ${content[0]?.length || 0} 字符`
      });

      return {
        success: true,
        steps,
        summary: '获取正文成功',
        content: content[0] || ''
      };

    } catch (error) {
      return {
        success: false,
        steps,
        summary: `获取正文失败: ${error}`
      };
    }
  }

  /**
   * 解析书籍信息
   */
  private async parseBookInfo(source: BookSource, html: string): Promise<BookInfo> {
    const searchRule = source.searchRule;

    const extract = async (rule?: string): Promise<string> => {
      if (!rule) return '';
      if (rule.startsWith('@js:')) {
        return this.jsEngine.executeRule(html, rule, source.url);
      }
      const results = this.htmlParser.parse(html, rule);
      return results[0] || '';
    };

    return {
      name: await extract(searchRule.name),
      author: await extract(searchRule.author),
      cover: await extract(searchRule.cover),
      intro: await extract(searchRule.intro),
      bookUrl: await extract(searchRule.bookUrl)
    };
  }

  /**
   * 解析章节信息
   */
  private async parseChapterInfo(source: BookSource, html: string): Promise<ChapterInfo> {
    const chapterRule = source.chapterRule;

    const extract = async (rule?: string): Promise<string> => {
      if (!rule) return '';
      const results = this.htmlParser.parse(html, rule);
      return results[0] || '';
    };

    return {
      title: await extract(chapterRule?.chapterName),
      url: await extract(chapterRule?.chapterUrl)
    };
  }

  /**
   * 构建搜索 URL
   */
  private async buildSearchUrlWithConfig(source: BookSource, key: string): Promise<SearchUrlResult> {
    let searchUrl = source.searchUrl || '';
    const config: UrlConfig = {
      method: 'GET',
      headers: {}
    };

    if (source.header) {
      try {
        config.headers = JSON.parse(source.header);
      } catch {
        // ignore
      }
    }

    if (searchUrl.includes('@js:')) {
      const jsCode = searchUrl.replace(/^@js:/, '');
      const result = await this.jsEngine.executeSearchUrl(jsCode, {
        key,
        page: 1,
        baseUrl: source.url
      });
      return { url: result, config };
    }

    const commaIndex = searchUrl.indexOf(',{');
    if (commaIndex > 0 && searchUrl.endsWith('}')) {
      try {
        const urlPart = searchUrl.substring(0, commaIndex);
        const configPart = searchUrl.substring(commaIndex + 1);
        const parsedConfig = this.parseUrlConfig(configPart, config.headers);
        searchUrl = urlPart;
        config.method = parsedConfig.method;
        config.body = parsedConfig.body;
        config.headers = parsedConfig.headers;
      } catch {
        // ignore
      }
    }

    searchUrl = searchUrl
      .replace(/\{\{key\}\}/g, encodeURIComponent(key))
      .replace(/\{\{page\}\}/g, '1');

    if (config.body) {
      config.body = config.body
        .replace(/\{\{key\}\}/g, encodeURIComponent(key))
        .replace(/\{\{page\}\}/g, '1');
    }

    return { url: searchUrl, config };
  }

  private parseUrlConfig(configStr: string, baseHeaders: Record<string, string>): UrlConfig {
    const config: UrlConfig = {
      method: 'GET',
      headers: this.copyHeaders(baseHeaders)
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
          config.headers[key] = headerObj[key];
        }
      }

      const otherKeys = Object.keys(parsed);
      for (let i = 0; i < otherKeys.length; i++) {
        const key = otherKeys[i];
        if (key !== 'method' && key !== 'body' && key !== 'headers') {
          const value = parsed[key];
          if (typeof value === 'string') {
            config.headers[key] = value;
          }
        }
      }
    } catch (e) {
      Logger.warn(this.TAG, `解析URL配置失败: ${e}`);
    }

    return config;
  }

  private copyHeaders(source: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(source);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      result[key] = source[key];
    }
    return result;
  }

  /**
   * 验证书源规则
   */
  validateSource(source: BookSource): ValidationResult {
    const errors: string[] = [];

    if (!source.name) {
      errors.push('书源名称不能为空');
    }

    if (!source.url) {
      errors.push('书源 URL 不能为空');
    }

    if (!source.searchUrl) {
      errors.push('搜索 URL 未配置（仅支持发现）');
    } else {
      if (!source.searchRule?.bookList) {
        errors.push('搜索规则：书籍列表选择器未配置');
      }
      if (!source.searchRule?.name) {
        errors.push('搜索规则：书名选择器未配置');
      }
    }

    if (!source.chapterRule?.chapterList) {
      errors.push('章节规则：章节列表选择器未配置');
    }

    if (!source.contentRule?.content) {
      errors.push('正文规则：正文选择器未配置');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }
}

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

export default BookSourceDebugger.getInstance();
