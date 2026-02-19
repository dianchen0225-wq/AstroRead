/**
 * HTML 解析器 - 纯 TypeScript 实现，替代 jsoup
 * 支持 XPath、CSS Selector、正则等多种解析方式
 */

import { Logger } from './Logger';
import { EntityDecoder } from '../core/utils/EntityDecoder';
import { CssSelectorParser } from './CssSelectorParser';

export interface ParseResult {
  text: string;
  html: string;
  attr?: Record<string, string>;
}

type JsonValue = string | number | boolean | object | null;
type JsonArray = Array<JsonValue>;

export class HTMLParser {
  private static instance: HTMLParser | null = null;
  private readonly TAG = 'HTMLParser';

  static getInstance(): HTMLParser {
    if (!HTMLParser.instance) {
      HTMLParser.instance = new HTMLParser();
    }
    return HTMLParser.instance;
  }

  /**
   * 解析 HTML 并提取元素
   * 支持：xpath、css selector、jsonpath、正则、Legado格式
   */
  parse(html: string, rule: string): string[] {
    if (!html || !rule) {
      Logger.debug(this.TAG, `解析参数为空: html=${html ? '有内容' : '空'}, rule=${rule || '空'}`);
      return [];
    }

    try {
      // 检测规则类型
      if (rule.startsWith('@json:')) {
        Logger.debug(this.TAG, `使用JSON解析: ${rule.substring(6)}`);
        return this.parseJsonPath(html, rule.substring(6));
      }
      if (rule.startsWith('##') || rule.startsWith('@regex:')) {
        const regexRule = rule.startsWith('##') ? rule.substring(2) : rule.substring(7);
        Logger.debug(this.TAG, `使用正则解析: ${regexRule}`);
        return this.parseRegex(html, regexRule);
      }
      if (rule.includes('$.') || rule.startsWith('$[')) {
        Logger.debug(this.TAG, `使用JSONPath解析: ${rule}`);
        return this.parseJsonPath(html, rule);
      }
      if (rule.startsWith('//')) {
        Logger.debug(this.TAG, `使用XPath解析: ${rule}`);
        return this.parseXPath(html, rule);
      }
      
      // Legado格式规则（如 class.bookbox@tag.div 或 @css:.book）
      if (rule.startsWith('class.') || rule.startsWith('tag.') || rule.startsWith('@css:') || rule.includes('@')) {
        Logger.debug(this.TAG, `使用Legado格式解析: ${rule}`);
        const elements = CssSelectorParser.selectElements(html, rule);
        Logger.debug(this.TAG, `Legado格式解析结果: ${elements.length} 个元素`);
        return elements;
      }
      
      // 默认按 CSS Selector 处理
      Logger.debug(this.TAG, `使用CSS选择器解析: ${rule}`);
      return this.parseCSSSelector(html, rule);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(this.TAG, `解析失败: 规则=${rule}, 错误=${errorMsg}`);
      return [];
    }
  }

  /**
   * CSS Selector 解析
   * 简化版实现，支持常用选择器
   */
  private parseCSSSelector(html: string, selector: string): string[] {
    const results: string[] = [];

    // 处理属性选择器如 .class、#id、tag
    const match = selector.match(/^([a-zA-Z0-9_-]*)?(#[a-zA-Z0-9_-]+)?(\.[a-zA-Z0-9_-]+)?$/);
    if (!match) {
      // 复杂选择器使用通用匹配
      return this.parseGeneric(html, selector);
    }

    const tagName = match[1] || '';
    const id = match[2] ? match[2].substring(1) : '';
    const className = match[3] ? match[3].substring(1) : '';

    // 构建正则表达式
    let pattern: RegExp;
    if (id) {
      pattern = new RegExp(`<([^\\s>]+)[^>]*\\bid=["']?${id}["']?[^>]*>([\\s\\S]*?)<\\/\\1>`, 'gi');
    } else if (className) {
      pattern = new RegExp(`<([^\\s>]+)[^>]*\\bclass=["']?[^"'>]*${className}[^"'>]*["']?[^>]*>([\\s\\S]*?)<\\/\\1>`, 'gi');
    } else if (tagName) {
      pattern = new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)<\\/${tagName}>`, 'gi');
    } else {
      return [];
    }

    let m: RegExpExecArray | null;
    while ((m = pattern.exec(html)) !== null) {
      const content = m[2] || m[1];
      if (content) {
        results.push(this.cleanHtml(content));
      }
    }

    return results.length > 0 ? results : this.parseGeneric(html, selector);
  }

  /**
   * XPath 解析 - 简化实现
   * 支持基本路径如 //div[@class="xxx"]//a/@href
   */
  private parseXPath(html: string, xpath: string): string[] {
    // 提取属性名如 @href、@src
    const attrMatch = xpath.match(/@([a-zA-Z0-9_-]+)$/);
    const attrName = attrMatch ? attrMatch[1] : '';
    let path = attrMatch ? xpath.substring(0, xpath.length - attrMatch[0].length) : xpath;

    // 移除开头的 //
    path = path.replace(/^\/\//, '');

    // 解析条件如 div[@class="xxx"]
    const conditionMatch = path.match(/^([a-zA-Z0-9_-]*)\[@([a-zA-Z0-9_-]+)=["']([^"']+)["']\]/);

    if (conditionMatch) {
      const tag = conditionMatch[1] || '[^\\s>]+';
      const attr = conditionMatch[2];
      const value = conditionMatch[3];
      const remaining = path.substring(conditionMatch[0].length);

      // 构建匹配模式
      const pattern = new RegExp(`<${tag}[^>]*\\b${attr}=["']?${value}["']?[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'gi');
      const matches: string[] = [];
      let m: RegExpExecArray | null;

      while ((m = pattern.exec(html)) !== null) {
        let content = m[1];
        // 继续解析剩余路径
        if (remaining && remaining.startsWith('//')) {
          content = this.extractFromHtml(content, remaining.substring(2), attrName);
        } else if (attrName) {
          content = this.extractAttribute(m[0], attrName) || content;
        }
        matches.push(this.cleanHtml(content));
      }
      return matches;
    }

    // 简单标签选择
    if (path && !path.includes('/')) {
      return this.parseCSSSelector(html, path);
    }

    return this.parseGeneric(html, xpath);
  }

  /**
   * JSON Path 解析
   */
  private parseJsonPath(jsonStr: string, path: string): string[] {
    try {
      const obj = JSON.parse(jsonStr) as Record<string, string | number | boolean | object | null>;
      const results: string[] = [];

      // 简化实现：支持 $.xxx、$[0]、$.*
      const keys = path.match(/\$\.([a-zA-Z0-9_-]+)|\$\[(\d+)\]|\$\.\*/g);
      if (!keys) return [];

      let current: string | number | boolean | object | null | Array<string | number | boolean | object | null> = obj;
      for (const key of keys) {
        if (key === '$.*' && Array.isArray(current)) {
          for (const item of current as Array<string | number | boolean | object | null>) {
            if (typeof item === 'string') {
              results.push(item);
            } else if (typeof item === 'object' && item !== null) {
              // 尝试提取对象中的文本字段
              const itemObj = item as Record<string, string | number | boolean | object | null>;
              const textFields = ['intro', 'description', 'summary', 'content', 'text', 'value', 'name', 'title'];
              let found = false;
              for (const field of textFields) {
                const value = itemObj[field];
                if (value !== undefined && typeof value === 'string') {
                  results.push(value);
                  found = true;
                  break;
                }
              }
              if (!found) {
                results.push('');
              }
            }
          }
          return results;
        }
        const propMatch = key.match(/\$\.([a-zA-Z0-9_-]+)/);
        if (propMatch && typeof current === 'object' && current !== null && !Array.isArray(current)) {
          current = (current as Record<string, string | number | boolean | object | null>)[propMatch[1]];
        }
        const indexMatch = key.match(/\$\[(\d+)\]/);
        if (indexMatch && Array.isArray(current)) {
          current = current[parseInt(indexMatch[1])];
        }
      }

      if (typeof current === 'string') {
        results.push(current);
      } else if (Array.isArray(current)) {
        // 如果是数组，提取其中的字符串值
        const arr = current as Array<string | number | boolean | object | null>;
        for (const item of arr) {
          if (typeof item === 'string') {
            results.push(item);
          }
        }
      } else if (typeof current === 'object' && current !== null) {
        // 如果是对象，尝试提取常见的文本字段
        const obj = current as Record<string, string | number | boolean | object | null>;
        const textFields = ['intro', 'description', 'summary', 'content', 'text', 'value', 'name', 'title'];
        for (const field of textFields) {
          const value = obj[field];
          if (value !== undefined && typeof value === 'string') {
            results.push(value);
            break;
          }
        }
        // 如果没有找到文本字段，返回空字符串
        if (results.length === 0) {
          results.push('');
        }
      }

      return results;
    } catch (error) {
      Logger.error(this.TAG, `JSON解析失败: ${error}`);
      return [];
    }
  }

  /**
   * 正则表达式解析
   */
  private parseRegex(html: string, pattern: string): string[] {
    try {
      const results: string[] = [];
      const regex = new RegExp(pattern, 'gi');
      let match: RegExpExecArray | null;

      while ((match = regex.exec(html)) !== null) {
        const group = match[1] || match[0];
        if (group) {
          results.push(this.cleanHtml(group));
        }
      }

      return results;
    } catch (error) {
      Logger.error(this.TAG, `正则解析失败: ${error}`);
      return [];
    }
  }

  /**
   * 通用解析 - 用于复杂规则
   */
  private parseGeneric(html: string, rule: string): string[] {
    // 尝试按标签名匹配
    const tagMatch = rule.match(/^([a-zA-Z0-9_-]+)$/);
    if (tagMatch) {
      const tag = tagMatch[1];
      const pattern = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'gi');
      const results: string[] = [];
      let m: RegExpExecArray | null;

      while ((m = pattern.exec(html)) !== null) {
        results.push(this.cleanHtml(m[1]));
      }
      return results;
    }

    return [];
  }

  /**
   * 从 HTML 中提取嵌套内容
   */
  private extractFromHtml(html: string, selector: string, attrName: string): string {
    const results = this.parse(html, selector);
    if (attrName && results.length > 0) {
      return this.extractAttribute(results[0], attrName) || results[0];
    }
    return results.join('');
  }

  /**
   * 提取 HTML 属性
   */
  private extractAttribute(html: string, attrName: string): string {
    const pattern = new RegExp(`${attrName}=["']([^"']+)["']`, 'i');
    const match = html.match(pattern);
    return match ? match[1] : '';
  }

  /**
   * 清理 HTML 标签，返回纯文本
   */
  private cleanHtml(html: string): string {
    if (!html) return '';

    return EntityDecoder.cleanHtml(html);
  }

  /**
   * 解析并返回结构化结果
   */
  parseDetailed(html: string, rule: string): ParseResult[] {
    const texts = this.parse(html, rule);
    return texts.map((text: string): ParseResult => ({
      text,
      html: text,
      attr: {}
    }));
  }

  /**
   * 提取纯文本（不包含 HTML 标签）
   */
  extractText(html: string): string {
    return this.cleanHtml(html);
  }

  /**
   * 解析 URL 拼接规则
   * 处理相对路径转绝对路径
   */
  resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (!relativeUrl) return '';
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    try {
      // 简单的 URL 解析
      const protocolEnd = baseUrl.indexOf('://');
      if (protocolEnd === -1) return relativeUrl;

      const protocol = baseUrl.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = baseUrl.indexOf('/', hostStart);
      const host = pathStart === -1 ? baseUrl.substring(hostStart) : baseUrl.substring(hostStart, pathStart);

      if (relativeUrl.startsWith('/')) {
        return `${protocol}${host}${relativeUrl}`;
      }
      if (relativeUrl.startsWith('./')) {
        const path = pathStart === -1 ? '/' : baseUrl.substring(pathStart);
        const lastSlash = path.lastIndexOf('/');
        const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);
        return `${protocol}${host}${basePath}${relativeUrl.substring(2)}`;
      }
      if (relativeUrl.startsWith('../')) {
        const path = pathStart === -1 ? '/' : baseUrl.substring(pathStart);
        const pathParts = path.split('/');
        pathParts.pop();
        pathParts.pop();
        const newPath = pathParts.join('/') + '/';
        return `${protocol}${host}${newPath}${relativeUrl.substring(3)}`;
      }
      const path = pathStart === -1 ? '/' : baseUrl.substring(pathStart);
      const lastSlash = path.lastIndexOf('/');
      const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);
      return `${protocol}${host}${basePath}${relativeUrl}`;
    } catch (error) {
      return relativeUrl;
    }
  }
}

export default HTMLParser.getInstance();
