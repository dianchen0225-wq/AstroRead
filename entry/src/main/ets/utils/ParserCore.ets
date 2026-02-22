/**
 * 解析核心模块
 * 提供同步和异步解析的统一实现
 * 可以被 TaskPool 的 @Concurrent 函数导入使用
 */

import { EntityDecoder } from '../core/utils/EntityDecoder';
import { StringUtils } from './StringUtils';

export interface ParseResult {
  success: boolean;
  data?: string | ChapterInfo[] | BookInfo | null;
  error?: string;
}

export interface ChapterInfo {
  title: string;
  url: string;
  order: number;
}

export interface BookInfo {
  name: string;
  author: string;
  cover?: string;
  intro?: string;
  bookUrl: string;
}

export interface ReplaceRule {
  pattern: string;
  replacement: string;
}

export class ParserCore {
  static decodeHtmlEntities(text: string): string {
    return EntityDecoder.decode(text);
  }

  static extractText(html: string): string {
    if (!html) return '';
    
    let text = html;
    
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<p[^>]*>/gi, '\n');
    text = text.replace(/<\/p>/gi, '');
    text = text.replace(/<[^>]+>/g, '');
    text = EntityDecoder.decode(text);
    text = text.replace(/\s+/g, ' ').trim();
    
    return text;
  }

  static cleanText(text: string): string {
    if (!text) return '';
    return text
      .replace(/[\n\r\t]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static escapeRegex(text: string): string {
    return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  static resolveUrl(base: string, relative: string): string {
    if (!relative) return '';
    if (relative.startsWith('http')) return relative;
    if (relative.startsWith('//')) return 'https:' + relative;
    
    try {
      const protocolIndex = base.indexOf('://');
      if (protocolIndex === -1) {
        return base.endsWith('/') ? base + relative : base + '/' + relative;
      }
      
      const protocol = base.substring(0, protocolIndex + 3);
      const hostStart = protocolIndex + 3;
      const pathIndex = base.indexOf('/', hostStart);
      
      let host: string;
      let basePath: string;
      
      if (pathIndex === -1) {
        host = base.substring(hostStart);
        basePath = '/';
      } else {
        host = base.substring(hostStart, pathIndex);
        basePath = base.substring(pathIndex);
      }
      
      if (relative.startsWith('/')) {
        return `${protocol}${host}${relative}`;
      }
      
      const baseDir = basePath.split('/').slice(0, -1).join('/') + '/';
      return `${protocol}${host}${baseDir}${relative}`;
    } catch {
      if (base.endsWith('/')) {
        return base + relative;
      }
      return base + '/' + relative;
    }
  }

  static selectElements(html: string, selector: string): string[] {
    if (!html || !selector) return [];
    
    const elements: string[] = [];
    
    const tagMatch = selector.match(/^([a-zA-Z0-9]+)/);
    const idMatch = selector.match(/#([a-zA-Z0-9_-]+)/);
    const classMatch = selector.match(/\.([a-zA-Z0-9_-]+)/);
    
    const tag = tagMatch ? tagMatch[1] : '';
    const id = idMatch ? idMatch[1] : '';
    const className = classMatch ? classMatch[1] : '';
    
    let pattern = '';
    if (tag) {
      pattern += `<${tag}[^>]*`;
    } else {
      pattern += `<[^>]*`;
    }
    
    if (id) {
      pattern += `[^>]*id=["']${ParserCore.escapeRegex(id)}["']`;
    }
    
    if (className) {
      pattern += `[^>]*class=["'][^"']*${ParserCore.escapeRegex(className)}[^"']*["']`;
    }
    
    pattern += '[^>]*>';
    
    const regex = new RegExp(pattern, 'gi');
    let match: RegExpExecArray | null;
    
    while ((match = regex.exec(html)) !== null) {
      const startIndex = match.index;
      const endIndex = ParserCore.findElementEnd(html, startIndex, tag || '');
      if (endIndex > startIndex) {
        elements.push(html.substring(startIndex, endIndex));
      }
    }
    
    return elements;
  }

  private static findElementEnd(html: string, startIndex: number, tag: string): number {
    if (!tag) {
      const nextTag = html.indexOf('<', startIndex + 1);
      return nextTag > 0 ? nextTag : html.length;
    }
    
    const openTag = `<${tag}`;
    const closeTag = `</${tag}>`;
    let depth = 1;
    let pos = startIndex + openTag.length;
    
    while (depth > 0 && pos < html.length) {
      const nextOpen = html.indexOf(openTag, pos);
      const nextClose = html.indexOf(closeTag, pos);
      
      if (nextClose === -1) break;
      
      if (nextOpen !== -1 && nextOpen < nextClose) {
        depth++;
        pos = nextOpen + openTag.length;
      } else {
        depth--;
        if (depth === 0) {
          return nextClose + closeTag.length;
        }
        pos = nextClose + closeTag.length;
      }
    }
    
    return html.length;
  }

  static extractTextWithSelector(html: string, selector?: string): string {
    if (selector) {
      const elements = ParserCore.selectElements(html, selector);
      if (elements.length > 0) {
        return ParserCore.extractText(elements[0]);
      }
      return '';
    }
    return ParserCore.extractText(html);
  }

  static extractAttribute(html: string, selector: string, attribute: string): string {
    const elements = ParserCore.selectElements(html, selector);
    if (elements.length === 0) return '';

    const element = elements[0];
    const attrRegex = new RegExp(`${attribute}=["']([^"']*)["']`, 'i');
    const match = element.match(attrRegex);
    
    if (match) {
      return EntityDecoder.decode(match[1]);
    }
    return '';
  }

  static parseChapterList(
    html: string, 
    listSelector: string, 
    titleSelector: string, 
    urlSelector: string,
    baseUrl: string
  ): ChapterInfo[] {
    const chapters: ChapterInfo[] = [];
    const elements = ParserCore.selectElements(html, listSelector);

    for (let i = 0; i < elements.length; i++) {
      const element = elements[i];
      
      let title = titleSelector 
        ? ParserCore.extractTextWithSelector(element, titleSelector) 
        : ParserCore.extractText(element);
      
      let url = ParserCore.extractAttribute(element, urlSelector || element, 'href');
      
      if (title && url) {
        title = StringUtils.normalizeWhitespace(title);
        url = ParserCore.resolveUrl(baseUrl, url);
        
        chapters.push({
          title,
          url,
          order: i
        });
      }
    }

    return chapters;
  }

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
    const elements = ParserCore.selectElements(html, listSelector);

    for (const element of elements) {
      const name = nameSelector 
        ? ParserCore.extractTextWithSelector(element, nameSelector)
        : '';

      if (!name) continue;

      const author = authorSelector 
        ? ParserCore.extractTextWithSelector(element, authorSelector)
        : '';

      let cover = coverSelector 
        ? ParserCore.extractAttribute(element, coverSelector, 'src')
        : '';
      if (!cover && coverSelector) {
        cover = ParserCore.extractAttribute(element, coverSelector, 'data-src');
      }

      const intro = introSelector 
        ? ParserCore.extractTextWithSelector(element, introSelector)
        : '';

      let bookUrl = urlSelector 
        ? ParserCore.extractAttribute(element, urlSelector, 'href')
        : '';

      if (baseUrl && bookUrl) {
        bookUrl = ParserCore.resolveUrl(baseUrl, bookUrl);
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

  static parseContent(html: string, contentSelector: string): string {
    const content = ParserCore.extractTextWithSelector(html, contentSelector);
    return ParserCore.formatContent(content);
  }

  static formatContent(content: string): string {
    if (!content) return '';

    return content
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  static applyReplaceRules(content: string, rules: ReplaceRule[]): string {
    let result = content;
    for (const rule of rules) {
      try {
        const regex = new RegExp(rule.pattern, 'g');
        result = result.replace(regex, rule.replacement);
      } catch (e) {
      }
    }
    return result;
  }

  static removeAds(content: string, adKeywords: string[]): string {
    let result = content;
    for (const keyword of adKeywords) {
      const regex = new RegExp(`.*${ParserCore.escapeRegex(keyword)}.*`, 'gi');
      result = result.replace(regex, '');
    }
    return result;
  }

  static parseJsonp(jsonp: string, callbackName?: string): Record<string, Object> | null {
    try {
      if (callbackName) {
        const regex = new RegExp(`${callbackName}\\((.*)\\);?$`, 's');
        const match = jsonp.match(regex);
        if (match) {
          return JSON.parse(match[1]) as Record<string, Object>;
        }
      }
      
      const match = jsonp.match(/[^(]*\((.*)\);?$/s);
      if (match) {
        return JSON.parse(match[1]) as Record<string, Object>;
      }
    } catch (e) {
    }
    return null;
  }

  static isValidUrl(url: string): boolean {
    if (!url) return false;
    return /^https?:\/\/.+/i.test(url);
  }

  static extractDomain(url: string): string {
    const match = url.match(/^https?:\/\/([^\/]+)/i);
    return match ? match[1] : '';
  }
}

export function concurrentParseChapterList(
  html: string,
  listSelector: string,
  titleSelector: string,
  urlSelector: string,
  baseUrl: string
): ChapterInfo[] {
  return ParserCore.parseChapterList(html, listSelector, titleSelector, urlSelector, baseUrl);
}

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

export function concurrentParseContent(html: string, contentSelector: string): string {
  return ParserCore.parseContent(html, contentSelector);
}
