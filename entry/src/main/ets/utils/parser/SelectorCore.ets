/**
 * SelectorCore - CSS 选择器核心解析逻辑
 * 提取公共的选择器解析代码，供同步和异步解析器复用
 */

import { Logger } from "../performance/Logger";
import { HtmlUtils } from "../content/HtmlUtils";
import { StringUtils } from "../content/StringUtils";
import { regexCache, cachedMatch } from "../cache/RegexCache";

/**
 * 选择器解析选项
 */
export interface SelectorParseOptions {
  skipFirst?: number;
  index?: number;
  attribute?: string;
}

/**
 * 选择器解析结果
 */
export interface SelectorParseResult {
  elements: string[];
  success: boolean;
  error?: string;
}

/**
 * 选择器类型
 */
export type SelectorType = 'class' | 'id' | 'tag' | 'xpath' | 'attribute' | 'compound';

/**
 * 预处理选择器结果
 */
export interface PreprocessResult {
  processed: string;
  type: SelectorType;
  skipFirst: number;
  index: number;
}

/**
 * CSS 选择器核心解析器
 * 所有解析逻辑集中在此类中，避免代码重复
 */
export class SelectorCore {
  private static readonly TAG = 'SelectorCore';

  // ========== 前缀处理 ==========

/**
 * 预处理选择器，移除各种前缀
 */
  static preprocessSelector(selector: string): PreprocessResult {
    let processed = selector.trim();
    let type: SelectorType = 'tag';
    let skipFirst = 0;
    let index = -1;

    // 移除 @js: 前缀（暂不支持）
    if (processed.startsWith('@js:') || processed.startsWith('<js>')) {
      Logger.warn(SelectorCore.TAG, 'JavaScript 规则暂不支持');
      return { processed: '', type: 'tag', skipFirst: 0, index: -1 };
    }

    // 移除 @css: 前缀
    if (processed.startsWith('@css:')) {
      processed = processed.substring(5).trim();
    }

    // 处理标准格式前缀
    if (processed.startsWith('class.')) {
      processed = '.' + processed.substring(6);
      type = 'class';
    } else if (processed.startsWith('tag.')) {
      processed = processed.substring(4);
      type = 'tag';
    } else if (processed.startsWith('id.')) {
      processed = '#' + processed.substring(3);
      type = 'id';
    }

    // 检测 XPath
    if (processed.startsWith('//') || processed.startsWith('./')) {
      type = 'xpath';
    }

    // 处理 !N 跳过前 N 个元素
    const skipMatch = processed.match(/!(\d+)$/);
    if (skipMatch) {
      skipFirst = parseInt(skipMatch[1], 10);
      processed = processed.substring(0, processed.lastIndexOf('!'));
    }

    // 处理索引选择器（如 .class.0）
    const indexMatch = processed.match(/\.(\d+)$/);
    if (indexMatch) {
      index = parseInt(indexMatch[1], 10);
      processed = processed.substring(0, processed.lastIndexOf('.'));
    }

    // 检测选择器类型
    if (processed.startsWith('.')) {
      type = 'class';
    } else if (processed.startsWith('#')) {
      type = 'id';
    } else if (processed.startsWith('[')) {
      type = 'attribute';
    }

    return { processed, type, skipFirst, index };
  }

  // ========== 元素选择 ==========

  /**
   * 选择元素 - 核心方法
   */
  static selectElements(html: string, selector: string): string[] {
    if (!html || !selector) {
      return [];
    }

    try {
      // 处理 || 或运算符
      if (selector.includes('||')) {
        return SelectorCore.handleOrOperator(html, selector);
      }

      // 预处理选择器
      const preprocessResult = SelectorCore.preprocessSelector(selector);
      const processed = preprocessResult.processed;
      const type = preprocessResult.type;
      const skipFirst = preprocessResult.skipFirst;
      const index = preprocessResult.index;
      if (!processed) {
        return [];
      }

      // 处理 @ 子选择器
      if (processed.includes('@')) {
        return SelectorCore.handleChildSelector(html, processed, skipFirst, index);
      }

      // 处理后代选择器
      if (processed.includes(' ') && !processed.startsWith('.') && !processed.startsWith('#')) {
        return SelectorCore.handleDescendantSelector(html, processed, index);
      }

      // 根据类型选择元素
      let elements: string[];

      switch (type) {
        case 'xpath':
          elements = SelectorCore.selectByXPath(html, processed);
          break;
        case 'class':
          elements = SelectorCore.selectByClass(html, processed);
          break;
        case 'id':
          elements = SelectorCore.selectById(html, processed);
          break;
        case 'attribute':
          elements = SelectorCore.selectByAttribute(html, processed);
          break;
        default:
          // 尝试复合选择器
          elements = SelectorCore.selectByCompound(html, processed);
      }

      // 应用索引和跳过
      return SelectorCore.applyFilters(elements, skipFirst, index);
    } catch (error) {
      Logger.error(SelectorCore.TAG, `选择元素失败: ${error}`);
      return [];
    }
  }

  /**
   * 处理 || 或运算符
   */
  private static handleOrOperator(html: string, selector: string): string[] {
    const orSelectors = selector.split('||')
      .map(s => s.trim())
      .filter(s => s.length > 0);

    for (const orSelector of orSelectors) {
      const result = SelectorCore.selectElements(html, orSelector);
      if (result.length > 0) {
        Logger.debug(SelectorCore.TAG, `|| 匹配成功: ${orSelector}`);
        return result;
      }
    }

    return [];
  }

  /**
   * 处理 @ 子选择器
   */
  private static handleChildSelector(
    html: string,
    selector: string,
    skipFirst: number,
    index: number
  ): string[] {
    const atIndex = selector.indexOf('@');
    const parentSelector = selector.substring(0, atIndex).trim();
    const childSelector = selector.substring(atIndex + 1).trim();

    const parentElements = SelectorCore.selectElements(html, parentSelector);
    const elements: string[] = [];

    for (const parentHtml of parentElements) {
      const childElements = SelectorCore.selectElements(parentHtml, childSelector);
      elements.push(...childElements);
    }

    return SelectorCore.applyFilters(elements, skipFirst, index);
  }

  /**
   * 处理后代选择器
   */
  private static handleDescendantSelector(html: string, selector: string, index: number): string[] {
    const parts = selector.split(/\s+/);
    let currentElements = [html];

    for (const part of parts) {
      const nextElements: string[] = [];
      for (const currentHtml of currentElements) {
        const found = SelectorCore.selectElements(currentHtml, part);
        nextElements.push(...found);
      }
      currentElements = nextElements;
    }

    if (index >= 0 && index < currentElements.length) {
      return [currentElements[index]];
    }

    return currentElements;
  }

  /**
   * 应用过滤条件（跳过和索引）
   */
  private static applyFilters(elements: string[], skipFirst: number, index: number): string[] {
    if (index >= 0 && index < elements.length) {
      return [elements[index]];
    }

    if (skipFirst > 0 && elements.length > skipFirst) {
      return elements.slice(skipFirst);
    }

    return elements;
  }

  // ========== 具体选择器实现 ==========

  /**
   * 按类名选择
   */
  static selectByClass(html: string, selector: string): string[] {
    const className = selector.substring(1).split(/[.\s#\[]/)[0];
    const pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*\\b${StringUtils.escapeRegex(className)}\\b[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;

    const regex: RegExp | null = regexCache.get(pattern, 'gi');
    if (!regex) return [];

    const elements: string[] = [];
    let match: RegExpExecArray | null = null;
    const clonedRegex = new RegExp(regex.source, regex.flags);

    while ((match = clonedRegex.exec(html)) !== null) {
      elements.push(match[0]);
    }

    return elements;
  }

  /**
   * 按 ID 选择
   */
  static selectById(html: string, selector: string): string[] {
    const id = selector.substring(1).split(/[.\s#\[]/)[0];
    const pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${StringUtils.escapeRegex(id)}["'][^>]*>([\\s\\S]*?)(?:<\\/\\1>|(?=<[a-zA-Z]|$))`;

    const regex: RegExp | null = regexCache.get(pattern, 'gi');
    if (!regex) return [];

    const elements: string[] = [];
    let match: RegExpExecArray | null = null;
    const clonedRegex = new RegExp(regex.source, regex.flags);

    while ((match = clonedRegex.exec(html)) !== null) {
      elements.push(match[0]);
    }

    return elements;
  }

  /**
   * 按属性选择
   */
  static selectByAttribute(html: string, selector: string): string[] {
    const attrMatch = selector.match(/^\[([a-zA-Z-]+)=(["'])([^"']*)\2\]$/);
    if (!attrMatch) return [];

    const attrName = attrMatch[1];
    const attrValue = attrMatch[3];
    const pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${StringUtils.escapeRegex(attrName)}=["']${StringUtils.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/\\1>`;

    const regex: RegExp | null = regexCache.get(pattern, 'gi');
    if (!regex) return [];

    const elements: string[] = [];
    let match: RegExpExecArray | null = null;
    const clonedRegex = new RegExp(regex.source, regex.flags);

    while ((match = clonedRegex.exec(html)) !== null) {
      elements.push(match[0]);
    }

    return elements;
  }

  /**
   * 按复合选择器选择（如 div.book 或 a#link）
   */
  static selectByCompound(html: string, selector: string): string[] {
    const compoundMatch = selector.match(/^([a-zA-Z][a-zA-Z0-9]*)?(\.([a-zA-Z0-9_-]+))?(#([a-zA-Z0-9_-]+))?$/);
    if (!compoundMatch) {
      // 尝试简单标签选择
      return SelectorCore.selectByTag(html, selector);
    }

    const tagName = compoundMatch[1] || '';
    const className = compoundMatch[3] || '';
    const id = compoundMatch[5] || '';

    let pattern = '<';
    if (tagName) {
      pattern += StringUtils.escapeRegex(tagName);
    } else {
      pattern += '([a-zA-Z][a-zA-Z0-9]*)';
    }
    pattern += '[^>]*';

    if (id) {
      pattern += `id=["']${StringUtils.escapeRegex(id)}["'][^>]*`;
    }

    if (className) {
      pattern += `class=["'][^"']*\\b${StringUtils.escapeRegex(className)}\\b[^"']*["'][^>]*`;
    }

    pattern += '>([\\s\\S]*?)<\\/';
    if (tagName) {
      pattern += StringUtils.escapeRegex(tagName);
    } else {
      pattern += '\\1';
    }
    pattern += '>';

    const regex: RegExp | null = regexCache.get(pattern, 'gi');
    if (!regex) return [];

    const elements: string[] = [];
    let match: RegExpExecArray | null = null;
    const clonedRegex = new RegExp(regex.source, regex.flags);

    while ((match = clonedRegex.exec(html)) !== null) {
      elements.push(match[0]);
    }

    return elements;
  }

  /**
   * 按标签名选择
   */
  static selectByTag(html: string, tagName: string): string[] {
    if (!tagName) return [];

    const tag = tagName.split(/[.\s#\[@]/)[0];
    if (!tag) return [];

    const pattern = `<${StringUtils.escapeRegex(tag)}[^>]*>([\\s\\S]*?)<\\/${StringUtils.escapeRegex(tag)}>`;
    const regex: RegExp | null = regexCache.get(pattern, 'gi');
    if (!regex) return [];

    const elements: string[] = [];
    let match: RegExpExecArray | null = null;
    const clonedRegex = new RegExp(regex.source, regex.flags);

    while ((match = clonedRegex.exec(html)) !== null) {
      elements.push(match[0]);
    }

    return elements;
  }

  /**
   * XPath 选择（简化实现）
   */
  static selectByXPath(html: string, xpath: string): string[] {
    let processedXpath = xpath;
    let skipFirst = 0;

    // 移除前缀
    if (processedXpath.startsWith('//')) {
      processedXpath = processedXpath.substring(2);
    } else if (processedXpath.startsWith('./')) {
      processedXpath = processedXpath.substring(2);
    }

    // 处理 position()>N
    const posMatch = processedXpath.match(/\[position\(\)>(\d+)\]/);
    if (posMatch) {
      skipFirst = parseInt(posMatch[1], 10);
      processedXpath = processedXpath.replace(/\[position\(\)>\d+\]/, '');
    }

    // 处理路径分隔符
    if (processedXpath.includes('/') && !processedXpath.startsWith('[')) {
      const parts = processedXpath.split('/').filter(p => p.length > 0);
      let currentElements = [html];

      for (const part of parts) {
        const nextElements: string[] = [];
        for (const currentHtml of currentElements) {
          const found = SelectorCore.selectByXPathSimple(currentHtml, part);
          nextElements.push(...found);
        }
        currentElements = nextElements;

        if (currentElements.length === 0) break;
      }

      if (skipFirst > 0 && currentElements.length > skipFirst) {
        return currentElements.slice(skipFirst);
      }
      return currentElements;
    }

    const result = SelectorCore.selectByXPathSimple(html, processedXpath);
    if (skipFirst > 0 && result.length > skipFirst) {
      return result.slice(skipFirst);
    }
    return result;
  }

  /**
   * 简单 XPath 选择
   */
  private static selectByXPathSimple(html: string, xpathPart: string): string[] {
    let tagName = '';
    let attrCondition = '';
    let index = -1;

    const complexMatch = xpathPart.match(/^([a-zA-Z*]+)(?:\[([^\]]+)\])?$/);

    if (complexMatch) {
      tagName = complexMatch[1] === '*' ? '' : complexMatch[1];
      const condition = complexMatch[2] || '';

      if (condition) {
        const indexMatch = condition.match(/^(\d+)$/);
        if (indexMatch) {
          index = parseInt(indexMatch[1], 10) - 1;
        } else {
          attrCondition = condition;
        }
      }
    } else {
      tagName = xpathPart;
    }

    let pattern: string;

    if (attrCondition) {
      const attrMatch = attrCondition.match(/@([a-zA-Z-]+)=["']([^"']*)["']/);
      const containsMatch = attrCondition.match(/contains\s*\(\s*@([a-zA-Z-]+)\s*,\s*["']([^"']*)["']\s*\)/);

      if (attrMatch) {
        const attrName = attrMatch[1];
        const attrValue = attrMatch[2];
        if (tagName) {
          pattern = `<${StringUtils.escapeRegex(tagName)}[^>]*${StringUtils.escapeRegex(attrName)}=["']${StringUtils.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/${StringUtils.escapeRegex(tagName)}>`;
        } else {
          pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${StringUtils.escapeRegex(attrName)}=["']${StringUtils.escapeRegex(attrValue)}["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
        }
      } else if (containsMatch) {
        const attrName = containsMatch[1];
        const attrValue = containsMatch[2];
        if (tagName) {
          pattern = `<${StringUtils.escapeRegex(tagName)}[^>]*${StringUtils.escapeRegex(attrName)}=["'][^"']*${StringUtils.escapeRegex(attrValue)}[^"']*["'][^>]*>([\\s\\S]*?)<\\/${StringUtils.escapeRegex(tagName)}>`;
        } else {
          pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*${StringUtils.escapeRegex(attrName)}=["'][^"']*${StringUtils.escapeRegex(attrValue)}[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
        }
      } else {
        if (tagName) {
          pattern = `<${StringUtils.escapeRegex(tagName)}[^>]*>([\\s\\S]*?)<\\/${StringUtils.escapeRegex(tagName)}>`;
        } else {
          pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*>([\\s\\S]*?)<\\/\\1>`;
        }
      }
    } else {
      if (tagName) {
        pattern = `<${StringUtils.escapeRegex(tagName)}[^>]*>([\\s\\S]*?)<\\/${StringUtils.escapeRegex(tagName)}>`;
      } else {
        pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*>([\\s\\S]*?)<\\/\\1>`;
      }
    }

    const regex: RegExp | null = regexCache.get(pattern, 'gi');
    if (!regex) return [];

    const elements: string[] = [];
    let match: RegExpExecArray | null = null;
    const clonedRegex = new RegExp(regex.source, regex.flags);

    while ((match = clonedRegex.exec(html)) !== null) {
      elements.push(match[0]);
    }

    if (index >= 0 && index < elements.length) {
      return [elements[index]];
    }

    return elements;
  }

  // ========== 值提取 ==========

  /**
   * 提取值
   */
  static extractValue(html: string, rule: string): string {
    if (!html || !rule) {
      return '';
    }

    try {
      let processedRule = rule.trim();

      // 移除前缀
      if (processedRule.startsWith('@css:')) {
        processedRule = processedRule.substring(5).trim();
      }
      if (processedRule.startsWith('class.')) {
        processedRule = '.' + processedRule.substring(6);
      }
      if (processedRule.startsWith('tag.')) {
        processedRule = processedRule.substring(4);
      }
      if (processedRule.startsWith('id.')) {
        processedRule = '#' + processedRule.substring(3);
      }

      // 处理 XPath
      if (processedRule.startsWith('//') || processedRule.startsWith('./')) {
        const elements = SelectorCore.selectByXPath(html, processedRule);
        if (elements.length > 0) {
          return SelectorCore.extractTextContent(elements[0]);
        }
        return '';
      }

      // 处理 ## 替换规则
      let replacePatterns: string[] = [];
      if (processedRule.includes('##')) {
        const parts = processedRule.split('##');
        processedRule = parts[0];
        if (parts.length > 1) {
          replacePatterns = parts.slice(1).join('##').split('|').map(p => p.trim()).filter(p => p.length > 0);
        }
      }

      // 处理 {{}} 模板
      if (processedRule.includes('{{')) {
        return SelectorCore.processTemplate(html, processedRule);
      }

      // 处理 @ 属性选择器
      if (processedRule.includes('@')) {
        return SelectorCore.extractAttribute(html, processedRule, replacePatterns);
      }

      // 纯选择器
      const elements = SelectorCore.selectElements(html, processedRule);
      if (elements.length > 0) {
        let text = SelectorCore.extractTextContent(elements[0]);
        text = SelectorCore.applyReplacePatterns(text, replacePatterns);
        return text.trim();
      }

      return '';
    } catch (error) {
      Logger.error(SelectorCore.TAG, `提取值失败: ${error}`);
      return '';
    }
  }

  /**
   * 提取属性值
   */
  private static extractAttribute(html: string, rule: string, replacePatterns: string[]): string {
    const atIndex = rule.lastIndexOf('@');
    const selector = rule.substring(0, atIndex).trim();
    const attr = rule.substring(atIndex + 1).trim();

    const elements = selector ? SelectorCore.selectElements(html, selector) : [html];
    if (elements.length === 0) return '';

    const elementHtml = elements[0];
    let value = '';

    switch (attr) {
      case 'text':
      case 'text()':
        value = SelectorCore.extractTextContent(elementHtml);
        break;
      case 'textNodes':
        value = SelectorCore.extractTextNodes(elementHtml);
        break;
      case 'href':
        const hrefMatch = elementHtml.match(/href=["']([^"']*)["']/i);
        value = hrefMatch ? hrefMatch[1] : '';
        break;
      case 'src':
        const srcMatch = elementHtml.match(/src=["']([^"']*)["']/i);
        value = srcMatch ? srcMatch[1] : '';
        break;
      default:
        const attrRegex = new RegExp(`${StringUtils.escapeRegex(attr)}=["']([^"']*)["']`, 'i');
        const attrMatch = elementHtml.match(attrRegex);
        value = attrMatch ? attrMatch[1] : '';
    }

    return SelectorCore.applyReplacePatterns(value, replacePatterns).trim();
  }

  /**
   * 提取文本内容
   */
  static extractTextContent(html: string): string {
    if (!html) return '';
    return HtmlUtils.extractText(html);
  }

  /**
   * 提取所有文本节点
   */
  static extractTextNodes(html: string): string {
    if (!html) return '';

    let text = html;
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<\/p>/gi, '\n');
    text = text.replace(/<\/div>/gi, '\n');
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    text = text.replace(/<!--[\s\S]*?-->/g, '');
    text = text.replace(/<[^>]+>/g, '');
    text = HtmlUtils.decodeHtmlEntities(text);
    text = text.replace(/\n\s*\n/g, '\n');
    text = text.replace(/[ \t]+/g, ' ');

    return text;
  }

  /**
   * 处理模板
   */
  private static processTemplate(html: string, template: string): string {
    let result = template;
    const templateMatches = template.matchAll(/\{\{([^}]+)\}\}/g);

    for (const match of templateMatches) {
      const placeholder = match[0];
      const innerRule = match[1].trim();
      const value = SelectorCore.extractValue(html, innerRule);
      result = result.replace(placeholder, value);
    }

    return result;
  }

  /**
   * 应用替换规则
   */
  static applyReplacePatterns(text: string, patterns: string[]): string {
    if (!text || patterns.length === 0) {
      return text;
    }

    let result = text;
    for (const pattern of patterns) {
      if (!pattern) continue;

      try {
        const regex = new RegExp(pattern, 'g');
        result = result.replace(regex, '');
      } catch {
        result = result.replace(new RegExp(StringUtils.escapeRegex(pattern), 'g'), '');
      }
    }

    return result;
  }
}

export default SelectorCore;
