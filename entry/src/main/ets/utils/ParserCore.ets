/**
 * 解析核心模块
 * 提供同步和异步解析的统一实现
 * 可以被 TaskPool 的 @Concurrent 函数导入使用
 */

import { HtmlUtils } from './HtmlUtils';
import { StringUtils } from './StringUtils';

/**
 * 解析结果接口
 */
export interface ParseResult {
  success: boolean;
  data?: unknown;
  error?: string;
}

/**
 * 章节信息
 */
export interface ChapterInfo {
  title: string;
  url: string;
  order: number;
}

/**
 * 书籍信息
 */
export interface BookInfo {
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
}

/**
 * 解析核心类
 * 所有方法都是纯函数，不依赖外部状态
 */
export class ParserCore {
  /**
   * 使用CSS选择器提取元素
   */
  static selectElements(html: string, selector: string): string[] {
    return HtmlUtils.selectElements(html, selector);
  }

  /**
   * 从HTML中提取文本内容
   */
  static extractText(html: string, selector?: string): string {
    if (selector) {
      const elements = this.selectElements(html, selector);
      if (elements.length > 0) {
        return HtmlUtils.extractText(elements[0]);
      }
      return '';
    }
    return HtmlUtils.extractText(html);
  }

  /**
   * 提取属性值
   */
  static extractAttribute(html: string, selector: string, attribute: string): string {
    const elements = this.selectElements(html, selector);
    if (elements.length === 0) return '';

    const element = elements[0];
    const attrRegex = new RegExp(`${attribute}=["']([^"']*)["']`, 'i');
    const match = element.match(attrRegex);
    
    if (match) {
      return HtmlUtils.decodeHtmlEntities(match[1]);
    }
    return '';
  }

  /**
   * 解析章节列表
   */
  static parseChapterList(
    html: string, 
    listSelector: string, 
    titleSelector: string, 
    urlSelector: string,
    baseUrl: string
  ): ChapterInfo[] {
    const chapters: ChapterInfo[] = [];
    const elements = this.selectElements(html, listSelector);

    for (let i = 0; i < elements.length; i++) {
      const element = elements[i];
      
      let title = titleSelector 
        ? this.extractText(element, titleSelector) 
        : HtmlUtils.extractText(element);
      
      let url = this.extractAttribute(element, urlSelector || element, 'href');
      
      if (title && url) {
        title = StringUtils.normalizeWhitespace(title);
        url = HtmlUtils.resolveUrl(baseUrl, url);
        
        chapters.push({
          title,
          url,
          order: i
        });
      }
    }

    return chapters;
  }

  /**
   * 解析书籍列表
   */
  static parseBookList(
    html: string,
    listSelector: string,
    nameSelector: string,
    authorSelector?: string,
    coverSelector?: string,
    introSelector?: string,
    urlSelector?: string,
    baseUrl?: string
  ): BookInfo[] {
    const books: BookInfo[] = [];
    const elements = this.selectElements(html, listSelector);

    for (const element of elements) {
      const name = nameSelector 
        ? this.extractText(element, nameSelector)
        : '';

      if (!name) continue;

      const author = authorSelector 
        ? this.extractText(element, authorSelector)
        : '';

      let cover = coverSelector 
        ? this.extractAttribute(element, coverSelector, 'src')
        : '';
      if (!cover && coverSelector) {
        cover = this.extractAttribute(element, coverSelector, 'data-src');
      }

      const intro = introSelector 
        ? this.extractText(element, introSelector)
        : '';

      let bookUrl = urlSelector 
        ? this.extractAttribute(element, urlSelector, 'href')
        : '';

      if (baseUrl && bookUrl) {
        bookUrl = HtmlUtils.resolveUrl(baseUrl, bookUrl);
      }

      books.push({
        name: StringUtils.normalizeWhitespace(name),
        author: StringUtils.normalizeWhitespace(author) || '未知作者',
        cover: cover || undefined,
        intro: intro || undefined,
        bookUrl: bookUrl || ''
      });
    }

    return books;
  }

  /**
   * 解析内容
   */
  static parseContent(html: string, contentSelector: string): string {
    const content = this.extractText(html, contentSelector);
    return this.formatContent(content);
  }

  /**
   * 格式化内容文本
   */
  static formatContent(content: string): string {
    if (!content) return '';

    return content
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  /**
   * 应用替换规则
   */
  static applyReplaceRules(content: string, rules: Array<{ pattern: string; replacement: string }>): string {
    let result = content;
    for (const rule of rules) {
      try {
        const regex = new RegExp(rule.pattern, 'g');
        result = result.replace(regex, rule.replacement);
      } catch (e) {
        // 忽略无效的正则表达式
      }
    }
    return result;
  }

  /**
   * 清理广告文本
   */
  static removeAds(content: string, adKeywords: string[]): string {
    let result = content;
    for (const keyword of adKeywords) {
      const regex = new RegExp(`.*${HtmlUtils.escapeRegex(keyword)}.*`, 'gi');
      result = result.replace(regex, '');
    }
    return result;
  }

  /**
   * 解析JSONP响应
   */
  static parseJsonp(jsonp: string, callbackName?: string): unknown {
    try {
      if (callbackName) {
        const regex = new RegExp(`${callbackName}\\((.*)\\);?$`, 's');
        const match = jsonp.match(regex);
        if (match) {
          return JSON.parse(match[1]);
        }
      }
      
      // 尝试自动提取
      const match = jsonp.match(/[^(]*\((.*)\);?$/s);
      if (match) {
        return JSON.parse(match[1]);
      }
    } catch (e) {
      // 解析失败
    }
    return null;
  }

  /**
   * 验证URL格式
   */
  static isValidUrl(url: string): boolean {
    if (!url) return false;
    return /^https?:\/\/.+/i.test(url);
  }

  /**
   * 提取域名
   */
  static extractDomain(url: string): string {
    try {
      const urlObj = new URL(url);
      return urlObj.hostname;
    } catch {
      const match = url.match(/^https?:\/\/([^\/]+)/i);
      return match ? match[1] : '';
    }
  }

  /**
   * 合并基础URL和相对URL
   */
  static resolveUrl(base: string, relative: string): string {
    return HtmlUtils.resolveUrl(base, relative);
  }
}

/**
 * 并发解析函数 - 用于 TaskPool
 */
export function concurrentParseChapterList(
  html: string,
  listSelector: string,
  titleSelector: string,
  urlSelector: string,
  baseUrl: string
): ChapterInfo[] {
  return ParserCore.parseChapterList(html, listSelector, titleSelector, urlSelector, baseUrl);
}

/**
 * 并发解析书籍列表 - 用于 TaskPool
 */
export function concurrentParseBookList(
  html: string,
  listSelector: string,
  nameSelector: string,
  authorSelector?: string,
  coverSelector?: string,
  introSelector?: string,
  urlSelector?: string,
  baseUrl?: string
): BookInfo[] {
  return ParserCore.parseBookList(
    html, listSelector, nameSelector, authorSelector, 
    coverSelector, introSelector, urlSelector, baseUrl
  );
}

/**
 * 并发解析内容 - 用于 TaskPool
 */
export function concurrentParseContent(html: string, contentSelector: string): string {
  return ParserCore.parseContent(html, contentSelector);
}
