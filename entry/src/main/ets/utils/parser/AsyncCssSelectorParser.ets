/**
 * AsyncCssSelectorParser - 异步 CSS 选择器解析器
 * 使用 TaskPool 将解析任务移至子线程，避免主线程阻塞
 * 当 TaskPool 不可用时，自动降级到同步解析
 */

import { taskpool } from '@kit.ArkTS';
import { Logger } from '../performance/Logger';

const TAG = 'AsyncCssSelectorParser';

interface ParseTaskParams {
  html: string;
  selector: string;
  operation: 'select' | 'extract';
  attribute?: string;
}

interface ParseTaskResult {
  elements: string[];
  value: string;
  success: boolean;
  error?: string;
}

interface CompoundSelector {
  tag: string;
  classes: string[];
  id: string;
  attributes: AttributePair[];
}

interface AttributePair {
  name: string;
  value: string;
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

let taskPoolAvailable: boolean = true;
let taskPoolDisabled: boolean = false;

function isTaskPoolAvailable(): boolean {
  return taskPoolAvailable && !taskPoolDisabled;
}

function markTaskPoolUnavailable(): void {
  taskPoolAvailable = false;
  Logger.warn(TAG, 'TaskPool 不可用，已切换到同步解析模式');
}

/**
 * 在子线程中执行 CSS 选择器解析
 * 注意：此函数在子线程中运行，不能访问主线程的模块
 * 使用 @Concurrent 装饰器标记
 * 所有辅助函数都内联在此函数中
 */
@Concurrent
function parseInWorker(params: ParseTaskParams): ParseTaskResult {
  // 辅助函数：转义正则
  const escapeRegexLocal = (str: string): string => {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  };

  // 辅助函数：XPath转CSS选择器
  const convertXPathToCssLocal = (xpath: string): string => {
    try {
      let result = xpath;
      if (result.startsWith('//')) {
        result = result.substring(2);
      } else if (result.startsWith('./')) {
        result = result.substring(2);
      }
      const segments = result.split('/');
      const cssParts: string[] = [];
      for (const segment of segments) {
        const trimmed = segment.trim();
        if (!trimmed) continue;
        const attrClassMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)\[@class=["']([^"']+)["']\]$/);
        if (attrClassMatch) { cssParts.push(`${attrClassMatch[1]}.${attrClassMatch[2]}`); continue; }
        const attrIdMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)\[@id=["']([^"']+)["']\]$/);
        if (attrIdMatch) { cssParts.push(`${attrIdMatch[1]}#${attrIdMatch[2]}`); continue; }
        const attrMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)\[@([a-zA-Z][a-zA-Z0-9_-]*)=["']([^"']+)["']\]$/);
        if (attrMatch) { cssParts.push(`${attrMatch[1]}[${attrMatch[2]}="${attrMatch[3]}"]`); continue; }
        const tagMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)$/);
        if (tagMatch) { cssParts.push(tagMatch[1]); continue; }
        const fallbackMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)/);
        if (fallbackMatch) { cssParts.push(fallbackMatch[1]); }
      }
      return cssParts.join(' ');
    } catch {
      const xpathMatch = xpath.match(/\/\/([a-zA-Z][a-zA-Z0-9]*)/);
      return xpathMatch ? xpathMatch[1] : '';
    }
  };

  // 辅助函数：解析复合选择器
  const parseCompoundSelectorLocal = (selector: string): CompoundSelector => {
    const result: CompoundSelector = { tag: '', classes: [], id: '', attributes: [] };
    if (!selector) return result;
    let i = 0;
    const len = selector.length;
    while (i < len && /[a-zA-Z]/.test(selector[i])) { result.tag += selector[i]; i++; }
    while (i < len) {
      if (selector[i] === '.') {
        i++; let cn = '';
        while (i < len && /[a-zA-Z0-9_-]/.test(selector[i])) { cn += selector[i]; i++; }
        if (cn) result.classes.push(cn);
      } else if (selector[i] === '#') {
        i++; let id = '';
        while (i < len && /[a-zA-Z0-9_-]/.test(selector[i])) { id += selector[i]; i++; }
        if (id) result.id = id;
      } else if (selector[i] === '[') {
        i++; let attrName = '';
        while (i < len && selector[i] !== '=' && selector[i] !== ']' && selector[i] !== '"') { attrName += selector[i]; i++; }
        attrName = attrName.trim();
        let attrValue = '';
        if (i < len && selector[i] === '=') {
          i++;
          if (i < len && (selector[i] === '"' || selector[i] === "'")) {
            const q = selector[i]; i++;
            while (i < len && selector[i] !== q) { attrValue += selector[i]; i++; }
            if (i < len) i++;
          } else {
            while (i < len && selector[i] !== ']') { attrValue += selector[i]; i++; }
          }
        }
        if (i < len && selector[i] === ']') i++;
        if (attrName && attrValue) {
          const attrPair: AttributePair = { name: attrName, value: attrValue };
          result.attributes.push(attrPair);
        }
      } else { i++; }
    }
    return result;
  };

  // 辅助函数：分割后代选择器
  const splitDescendantSelectorLocal = (selector: string): string[] => {
    const parts: string[] = [];
    let current = '';
    let inBrackets = 0;
    let inQuote = '';
    for (let i = 0; i < selector.length; i++) {
      const ch = selector[i];
      if (inQuote) { current += ch; if (ch === inQuote) inQuote = ''; continue; }
      if (ch === '"' || ch === "'") { inQuote = ch; current += ch; continue; }
      if (ch === '[') { inBrackets++; current += ch; continue; }
      if (ch === ']') { inBrackets--; current += ch; continue; }
      if (ch === ' ' && inBrackets === 0) { if (current.trim().length > 0) { parts.push(current.trim()); current = ''; } continue; }
      current += ch;
    }
    if (current.trim().length > 0) parts.push(current.trim());
    return parts;
  };

  // 辅助函数：单层选择器匹配
  const selectElementsSingleLevelLocal = (html: string, selector: string): string[] => {
    const elements: string[] = [];
    if (!html || !selector) return elements;
    const compound = parseCompoundSelectorLocal(selector);
    if (compound.id) {
      const regex = new RegExp(`<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${escapeRegexLocal(compound.id)}["'][^>]*>([\\s\\S]*?)(?:<\\/\\1>|(?=<[a-zA-Z]|$))`, 'i');
      const match = regex.exec(html);
      if (match) elements.push(match[0]);
    } else if (compound.classes.length > 0 && !compound.tag) {
      let pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*`;
      for (const cn of compound.classes) { pattern += `(?=.*\\b${escapeRegexLocal(cn)}\\b)`; }
      pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
      const regex = new RegExp(pattern, 'gi');
      for (const match of html.matchAll(regex)) elements.push(match[0]);
    } else if (compound.tag) {
      if (compound.classes.length > 0) {
        let pattern = `<${compound.tag}[^>]*class=["'][^"']*`;
        for (const cn of compound.classes) { pattern += `(?=.*\\b${escapeRegexLocal(cn)}\\b)`; }
        pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/${compound.tag}>`;
        const regex = new RegExp(pattern, 'gi');
        for (const match of html.matchAll(regex)) elements.push(match[0]);
      } else if (compound.attributes.length > 0) {
        const attr = compound.attributes[0];
        const pattern = `<${compound.tag}[^>]*${escapeRegexLocal(attr.name)}\\s*=\\s*["']${escapeRegexLocal(attr.value)}["'][^>]*>([\\s\\S]*?)<\\/${compound.tag}>`;
        const regex = new RegExp(pattern, 'gi');
        for (const match of html.matchAll(regex)) elements.push(match[0]);
      } else {
        const regex = new RegExp(`<${compound.tag}[^>]*>([\\s\\S]*?)<\\/${compound.tag}>`, 'gi');
        for (const match of html.matchAll(regex)) elements.push(match[0]);
      }
    } else if (selector.startsWith('.')) {
      const classNames: string[] = [];
      const classMatches = selector.match(/\.[a-zA-Z0-9_-]+/g);
      if (classMatches) for (const cm of classMatches) classNames.push(cm.substring(1));
      if (classNames.length > 0) {
        let pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*`;
        for (const cn of classNames) { pattern += `(?=.*\\b${escapeRegexLocal(cn)}\\b)`; }
        pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;
        const regex = new RegExp(pattern, 'gi');
        for (const match of html.matchAll(regex)) elements.push(match[0]);
      }
    }
    return elements;
  };

  // 辅助函数：同步选择元素
  const selectElementsSync = (html: string, selector: string): string[] => {
    const elements: string[] = [];

    if (!html || !selector) {
      return elements;
    }

    let processedSelector = selector.trim();

    // 移除@js:前缀
    if (processedSelector.startsWith('@js:') || processedSelector.startsWith('<js>')) {
      return elements;
    }

    // 移除@css:前缀
    if (processedSelector.startsWith('@css:')) {
      processedSelector = processedSelector.substring(5).trim();
    }

    // 处理||或运算符（标准格式：尝试多个选择器，返回第一个成功的结果）
    if (processedSelector.includes('||')) {
      const orSelectors = processedSelector.split('||').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
      
      for (const orSelector of orSelectors) {
        const result = selectElementsSync(html, orSelector);
        if (result.length > 0) {
          return result;
        }
      }
      return elements;
    }

    let skipFirst = 0;

    // 处理@class.前缀
    if (processedSelector.startsWith('class.')) {
      processedSelector = '.' + processedSelector.substring(6);
    }

    // 处理@tag.前缀
    if (processedSelector.startsWith('tag.')) {
      processedSelector = processedSelector.substring(4);
    }

    // 处理id.前缀
    if (processedSelector.startsWith('id.')) {
      processedSelector = '#' + processedSelector.substring(3);
    }

    // 处理XPath格式 - 转换为CSS选择器
    if (processedSelector.startsWith('//') || processedSelector.startsWith('./')) {
      processedSelector = convertXPathToCssLocal(processedSelector);
      if (!processedSelector) {
        return elements;
      }
    }

    // 处理!N跳过前N个元素
    const skipMatch = processedSelector.match(/!(\d+)$/);
    if (skipMatch) {
      skipFirst = parseInt(skipMatch[1], 10);
      processedSelector = processedSelector.substring(0, processedSelector.lastIndexOf('!'));
    }

    // 处理索引选择器
    let index = -1;
    const indexMatch = processedSelector.match(/\.(\d+)$/);
    if (indexMatch) {
      index = parseInt(indexMatch[1], 10);
      processedSelector = processedSelector.substring(0, processedSelector.lastIndexOf('.'));
    }

    // 处理@子选择器（如 .class@tag 或 .class@tag.div）
    if (processedSelector.includes('@')) {
      const atIndex = processedSelector.indexOf('@');
      const parentSelector = processedSelector.substring(0, atIndex).trim();
      const childSelector = processedSelector.substring(atIndex + 1).trim();

      const parentElements = selectElementsSync(html, parentSelector);
      for (const parentHtml of parentElements) {
        const childElements = selectElementsSync(parentHtml, childSelector);
        for (const childElement of childElements) {
          elements.push(childElement);
        }
      }

      if (skipFirst > 0 && elements.length > skipFirst) {
        return elements.slice(skipFirst);
      }
      if (index >= 0 && index < elements.length) {
        return [elements[index]];
      }
      return elements;
    }

    // 后代选择器支持：检测空格分隔的多层选择器
    const descendantParts = splitDescendantSelectorLocal(processedSelector);
    if (descendantParts.length > 1) {
      let currentElements: string[] = [html];
      for (let di = 0; di < descendantParts.length; di++) {
        const partSelector = descendantParts[di];
        const nextElements: string[] = [];
        for (const currentHtml of currentElements) {
          const matched = selectElementsSingleLevelLocal(currentHtml, partSelector);
          for (const m of matched) nextElements.push(m);
        }
        currentElements = nextElements;
        if (currentElements.length === 0) break;
      }
      for (const e of currentElements) elements.push(e);
    } else {
      // 单层选择器（支持复合选择器）
      const singleResults = selectElementsSingleLevelLocal(html, processedSelector);
      for (const r of singleResults) elements.push(r);
    }

    // 应用索引过滤
    if (index >= 0 && index < elements.length) {
      return [elements[index]];
    }

    // 应用跳过
    if (skipFirst > 0 && elements.length > skipFirst) {
      return elements.slice(skipFirst);
    }

    return elements;
  };

  // 辅助函数：提取文本节点内容（保留换行）
  const extractTextNodesLocal = (html: string): string => {
    if (!html) return '';

    let text = html;

    // 将常见块级元素替换为换行
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<\/p>/gi, '\n');
    text = text.replace(/<\/div>/gi, '\n');
    text = text.replace(/<\/li>/gi, '\n');
    text = text.replace(/<\/h[1-6]>/gi, '\n');

    // 移除 script 和 style 标签及其内容
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

    // 移除注释
    text = text.replace(/<!--[\s\S]*?-->/g, '');

    // 移除所有HTML标签
    text = text.replace(/<[^>]+>/g, '');

    // 解码HTML实体
    text = decodeHtmlEntitiesLocal(text);

    // 清理多余空白
    text = text.replace(/\n\s*\n/g, '\n');
    text = text.replace(/[ \t]+/g, ' ');

    return text.trim();
  };

  // 辅助函数：提取值
  const extractValueSync = (html: string, selector: string, attribute?: string): string => {
    const elements = selectElementsSync(html, selector);

    if (elements.length === 0) {
      return '';
    }

    const element = elements[0];

    if (attribute) {
      // 标准化属性名
      const normalizedAttr = attribute.toLowerCase().trim();

      // 处理特殊伪属性
      if (normalizedAttr === 'text' || normalizedAttr === 'text()') {
        // 提取文本内容
        return extractAllTextContent(element, decodeHtmlEntitiesLocal);
      } else if (normalizedAttr === 'html' || normalizedAttr === 'html()') {
        // 返回完整HTML
        return element;
      } else if (normalizedAttr === 'textnodes' || normalizedAttr === 'textnodes()') {
        // 提取所有文本节点（保留换行）
        return extractTextNodesLocal(element);
      } else {
        // 提取其他属性
        const attrRegex = new RegExp(`${escapeRegexLocal(attribute)}=["']([^"']*)["']`, 'i');
        const match = element.match(attrRegex);
        return match ? decodeHtmlEntitiesLocal(match[1]) : '';
      }
    } else {
      // 无属性时默认返回文本
      return extractAllTextContent(element, decodeHtmlEntitiesLocal);
    }
  };

  // 辅助函数：递归提取所有文本内容
  const extractAllTextContent = (html: string, decodeFn: (s: string) => string): string => {
    if (!html) return '';

    // 移除 script 和 style 标签及其内容
    let cleaned = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    cleaned = cleaned.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

    // 提取所有文本节点（标签之间的内容）
    const textParts: string[] = [];
    let depth = 0;
    let textStart = 0;

    for (let i = 0; i < cleaned.length; i++) {
      if (cleaned[i] === '<') {
        if (depth === 0 && i > textStart) {
          const text = cleaned.substring(textStart, i);
          if (text.trim()) {
            textParts.push(decodeFn(text.trim()));
          }
        }
        depth++;
        // 检查是否是自闭合标签
        const remaining = cleaned.substring(i);
        if (remaining.match(/^<[^>]*\/>/)) {
          depth--;
        }
      } else if (cleaned[i] === '>') {
        depth--;
        if (depth < 0) depth = 0;
        textStart = i + 1;
      }
    }

    // 处理末尾的文本
    if (textStart < cleaned.length) {
      const text = cleaned.substring(textStart);
      if (text.trim()) {
        textParts.push(decodeFn(text.trim()));
      }
    }

    // 使用正则表达式作为备选方案（更简单可靠）
    if (textParts.length === 0) {
      const textMatches = cleaned.match(/>([^<]+)</g);
      if (textMatches) {
        for (const match of textMatches) {
          const text = match.substring(1, match.length - 1).trim();
          if (text) {
            textParts.push(decodeFn(text));
          }
        }
      }
    }

    return textParts.join(' ').trim();
  };

  // 辅助函数：解码HTML实体
  const decodeHtmlEntitiesLocal = (text: string): string => {
    if (!text) return '';

    const entities: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
      '&hellip;': '\u2026',
      '&mdash;': '\u2014',
      '&ndash;': '\u2013',
      '&ldquo;': '"',
      '&rdquo;': '"',
      '&lsquo;': '\u2018',
      '&rsquo;': '\u2019',
    };

    let result = text;
    const entityKeys = Object.keys(entities);
    for (const entity of entityKeys) {
      result = result.split(entity).join(entities[entity]);
    }

    // 处理数字实体
    result = result.replace(/&#(\d+);/g, (_match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });

    return result;
  };

  // 主逻辑
  try {
    const result: ParseTaskResult = {
      elements: [],
      value: '',
      success: true
    };

    if (params.operation === 'select') {
      result.elements = selectElementsSync(params.html, params.selector);
    } else if (params.operation === 'extract') {
      result.value = extractValueSync(params.html, params.selector, params.attribute);
    }

    return result;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return {
      elements: [],
      value: '',
      success: false,
      error: errorMsg
    };
  }
}

/**
 * 异步 CSS 选择器解析器
 * 使用 TaskPool 将解析任务移至子线程
 * 当 TaskPool 不可用时，自动降级到同步解析
 */
export class AsyncCssSelectorParser {
  private static instance: AsyncCssSelectorParser | null = null;

  private constructor() {}

  static getInstance(): AsyncCssSelectorParser {
    if (!AsyncCssSelectorParser.instance) {
      AsyncCssSelectorParser.instance = new AsyncCssSelectorParser();
    }
    return AsyncCssSelectorParser.instance;
  }

  private decodeHtmlEntities(text: string): string {
    if (!text) return '';

    const entities: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
      '&hellip;': '\u2026',
      '&mdash;': '\u2014',
      '&ndash;': '\u2013',
      '&ldquo;': '"',
      '&rdquo;': '"',
      '&lsquo;': '\u2018',
      '&rsquo;': '\u2019',
    };

    let result = text;
    const entityKeys = Object.keys(entities);
    for (const entity of entityKeys) {
      result = result.split(entity).join(entities[entity]);
    }

    result = result.replace(/&#(\d+);/g, (_match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });

    return result;
  }

  private selectElementsSync(html: string, selector: string): string[] {
    const elements: string[] = [];

    if (!html || !selector) {
      return elements;
    }

    let processedSelector = selector.trim();

    if (processedSelector.startsWith('@js:') || processedSelector.startsWith('<js>')) {
      return elements;
    }

    if (processedSelector.startsWith('@css:')) {
      processedSelector = processedSelector.substring(5).trim();
    }

    if (processedSelector.includes('||')) {
      const orSelectors = processedSelector.split('||').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
      
      for (const orSelector of orSelectors) {
        const result = this.selectElementsSync(html, orSelector);
        if (result.length > 0) {
          return result;
        }
      }
      return elements;
    }

    let skipFirst = 0;

    if (processedSelector.startsWith('class.')) {
      processedSelector = '.' + processedSelector.substring(6);
    }

    if (processedSelector.startsWith('tag.')) {
      processedSelector = processedSelector.substring(4);
    }

    if (processedSelector.startsWith('id.')) {
      processedSelector = '#' + processedSelector.substring(3);
    }

    // 改进的XPath处理：转换为CSS选择器而非仅提取标签名
    if (processedSelector.startsWith('//') || processedSelector.startsWith('./')) {
      processedSelector = this.convertXPathToCss(processedSelector);
      if (!processedSelector) {
        return elements;
      }
    }

    const skipMatch = processedSelector.match(/!(\d+)$/);
    if (skipMatch) {
      skipFirst = parseInt(skipMatch[1], 10);
      processedSelector = processedSelector.substring(0, processedSelector.lastIndexOf('!'));
    }

    let index = -1;
    const indexMatch = processedSelector.match(/\.(\d+)$/);
    if (indexMatch) {
      index = parseInt(indexMatch[1], 10);
      processedSelector = processedSelector.substring(0, processedSelector.lastIndexOf('.'));
    }

    if (processedSelector.includes('@')) {
      const atIndex = processedSelector.indexOf('@');
      const parentSelector = processedSelector.substring(0, atIndex).trim();
      const childSelector = processedSelector.substring(atIndex + 1).trim();

      const parentElements = this.selectElementsSync(html, parentSelector);
      for (const parentHtml of parentElements) {
        const childElements = this.selectElementsSync(parentHtml, childSelector);
        for (const childElement of childElements) {
          elements.push(childElement);
        }
      }

      if (skipFirst > 0 && elements.length > skipFirst) {
        return elements.slice(skipFirst);
      }
      if (index >= 0 && index < elements.length) {
        return [elements[index]];
      }
      return elements;
    }

    // 后代选择器支持：检测空格分隔的多层选择器（不在引号/方括号内）
    const descendantParts = this.splitDescendantSelector(processedSelector);
    if (descendantParts.length > 1) {
      // 逐层查找后代元素
      let currentElements: string[] = [html]; // 初始为完整HTML
      for (let i = 0; i < descendantParts.length; i++) {
        const partSelector = descendantParts[i];
        const nextElements: string[] = [];
        for (const currentHtml of currentElements) {
          const matched = this.selectElementsSingleLevel(currentHtml, partSelector);
          nextElements.push(...matched);
        }
        currentElements = nextElements;
        if (currentElements.length === 0) {
          break;
        }
      }
      elements.push(...currentElements);
    } else {
      // 单层选择器
      const singleResults = this.selectElementsSingleLevel(html, processedSelector);
      elements.push(...singleResults);
    }

    if (index >= 0 && index < elements.length) {
      return [elements[index]];
    }

    if (skipFirst > 0 && elements.length > skipFirst) {
      return elements.slice(skipFirst);
    }

    return elements;
  }

  /**
   * 分割后代选择器（按空格分割，但忽略引号和方括号内的空格）
   */
  private splitDescendantSelector(selector: string): string[] {
    const parts: string[] = [];
    let current = '';
    let inBrackets = 0;
    let inQuote = '';

    for (let i = 0; i < selector.length; i++) {
      const ch = selector[i];

      if (inQuote) {
        current += ch;
        if (ch === inQuote) {
          inQuote = '';
        }
        continue;
      }

      if (ch === '"' || ch === "'") {
        inQuote = ch;
        current += ch;
        continue;
      }

      if (ch === '[') {
        inBrackets++;
        current += ch;
        continue;
      }

      if (ch === ']') {
        inBrackets--;
        current += ch;
        continue;
      }

      if (ch === ' ' && inBrackets === 0) {
        if (current.trim().length > 0) {
          parts.push(current.trim());
          current = '';
        }
        continue;
      }

      current += ch;
    }

    if (current.trim().length > 0) {
      parts.push(current.trim());
    }

    return parts;
  }

  /**
   * 单层选择器匹配（不含后代选择器）
   */
  private selectElementsSingleLevel(html: string, selector: string): string[] {
    const elements: string[] = [];
    if (!html || !selector) return elements;

    // 解析复合选择器
    const compound = this.parseCompoundSelector(selector);

    if (compound.id) {
      // ID选择器优先
      const regex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${escapeRegex(compound.id)}["'][^>]*>([\\s\\S]*?)(?:<\\/\\1>|(?=<[a-zA-Z]|$))`,
        'i'
      );
      const match = regex.exec(html);
      if (match) {
        elements.push(match[0]);
      }
    } else if (compound.classes.length > 0 && !compound.tag) {
      // 纯类选择器（如 .class1.class2）
      let pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*`;
      for (const cn of compound.classes) {
        pattern += `(?=.*\\b${escapeRegex(cn)}\\b)`;
      }
      pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;

      const regex = new RegExp(pattern, 'gi');
      const matches = html.matchAll(regex);
      for (const match of matches) {
        elements.push(match[0]);
      }
    } else if (compound.tag) {
      // 标签选择器（可能带class约束）
      if (compound.classes.length > 0) {
        // 复合选择器：tag.class1.class2
        let pattern = `<${compound.tag}[^>]*class=["'][^"']*`;
        for (const cn of compound.classes) {
          pattern += `(?=.*\\b${escapeRegex(cn)}\\b)`;
        }
        pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/${compound.tag}>`;

        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      } else if (compound.attributes.length > 0) {
        // 带属性选择器的标签：tag[attr="val"]
        const attr = compound.attributes[0];
        const pattern = `<${compound.tag}[^>]*${escapeRegex(attr.name)}\\s*=\\s*["']${escapeRegex(attr.value)}["'][^>]*>([\\s\\S]*?)<\\/${compound.tag}>`;
        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      } else {
        // 纯标签选择器
        const regex = new RegExp(
          `<${compound.tag}[^>]*>([\\s\\S]*?)<\\/${compound.tag}>`,
          'gi'
        );
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
    } else if (selector.startsWith('.')) {
      // 降级：纯类选择器（parseCompoundSelector未正确解析时）
      const classNames: string[] = [];
      const classMatches = selector.match(/\.[a-zA-Z0-9_-]+/g);
      if (classMatches) {
        for (const cm of classMatches) {
          classNames.push(cm.substring(1));
        }
      }

      if (classNames.length > 0) {
        let pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*`;
        for (const cn of classNames) {
          pattern += `(?=.*\\b${escapeRegex(cn)}\\b)`;
        }
        pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;

        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
    }

    return elements;
  }

  /**
   * 解析复合选择器：提取标签名、类名列表、ID、属性选择器
   * 例如: "div.book#main[href='/list']" → {tag:"div", classes:["book"], id:"main", attributes:[{name:"href",value:"/list"}]}
   */
  private parseCompoundSelector(selector: string): CompoundSelector {
    const result: CompoundSelector = {
      tag: '',
      classes: [],
      id: '',
      attributes: []
    };

    if (!selector) return result;

    let i = 0;
    const len = selector.length;

    // 提取标签名（开头的字母序列）
    while (i < len && /[a-zA-Z]/.test(selector[i])) {
      result.tag += selector[i];
      i++;
    }

    // 提取类名、ID、属性
    while (i < len) {
      if (selector[i] === '.') {
        // 类名
        i++;
        let className = '';
        while (i < len && /[a-zA-Z0-9_-]/.test(selector[i])) {
          className += selector[i];
          i++;
        }
        if (className) {
          result.classes.push(className);
        }
      } else if (selector[i] === '#') {
        // ID
        i++;
        let id = '';
        while (i < len && /[a-zA-Z0-9_-]/.test(selector[i])) {
          id += selector[i];
          i++;
        }
        if (id) {
          result.id = id;
        }
      } else if (selector[i] === '[') {
        // 属性选择器 [attr="value"] 或 [attr='value']
        i++;
        let attrName = '';
        while (i < len && selector[i] !== '=' && selector[i] !== ']' && selector[i] !== '"') {
          attrName += selector[i];
          i++;
        }
        attrName = attrName.trim();

        let attrValue = '';
        if (i < len && selector[i] === '=') {
          i++;
          // 跳过引号
          if (i < len && (selector[i] === '"' || selector[i] === "'")) {
            const quote = selector[i];
            i++;
            while (i < len && selector[i] !== quote) {
              attrValue += selector[i];
              i++;
            }
            if (i < len) i++; // 跳过结束引号
          } else {
            while (i < len && selector[i] !== ']') {
              attrValue += selector[i];
              i++;
            }
          }
        }

        if (i < len && selector[i] === ']') i++;

        if (attrName && attrValue) {
          const attrPair: AttributePair = { name: attrName, value: attrValue };
          result.attributes.push(attrPair);
        }
      } else {
        // 跳过不识别的字符
        i++;
      }
    }

    return result;
  }

  /**
   * 将XPath转换为CSS选择器
   * 支持常见模式：//tag, //tag[@class="x"], //tag[@id="x"], //tag1/tag2
   */
  private convertXPathToCss(xpath: string): string {
    try {
      let result = xpath;

      // 移除开头的 // 或 ./
      if (result.startsWith('//')) {
        result = result.substring(2);
      } else if (result.startsWith('./')) {
        result = result.substring(2);
      }

      // 处理路径中的 / 分隔符（转为空格，即后代选择器）
      const segments = result.split('/');

      const cssParts: string[] = [];
      for (const segment of segments) {
        const trimmed = segment.trim();
        if (!trimmed) continue;

        // 处理属性条件 [@class="xxx"] 或 [@id="xxx"]
        const attrClassMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)\[@class=["']([^"']+)["']\]$/);
        if (attrClassMatch) {
          cssParts.push(`${attrClassMatch[1]}.${attrClassMatch[2]}`);
          continue;
        }

        const attrIdMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)\[@id=["']([^"']+)["']\]$/);
        if (attrIdMatch) {
          cssParts.push(`${attrIdMatch[1]}#${attrIdMatch[2]}`);
          continue;
        }

        // 处理通用属性条件 [@attr="val"]
        const attrMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)\[@([a-zA-Z][a-zA-Z0-9_-]*)=["']([^"']+)["']\]$/);
        if (attrMatch) {
          cssParts.push(`${attrMatch[1]}[${attrMatch[2]}="${attrMatch[3]}"]`);
          continue;
        }

        // 纯标签名
        const tagMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)$/);
        if (tagMatch) {
          cssParts.push(tagMatch[1]);
          continue;
        }

        // 无法转换的部分，尝试提取标签名作为降级
        const fallbackMatch = trimmed.match(/^([a-zA-Z][a-zA-Z0-9]*)/);
        if (fallbackMatch) {
          Logger.warn(TAG, `XPath部分转换降级: "${trimmed}" → "${fallbackMatch[1]}"`);
          cssParts.push(fallbackMatch[1]);
        }
      }

      const cssSelector = cssParts.join(' ');
      if (cssSelector) {
        Logger.debug(TAG, `XPath转CSS: "${xpath}" → "${cssSelector}"`);
      }
      return cssSelector;
    } catch (error) {
      Logger.warn(TAG, `XPath转CSS失败: ${xpath}, ${error}`);
      // 降级：提取第一个标签名
      const xpathMatch = xpath.match(/\/\/([a-zA-Z][a-zA-Z0-9]*)/);
      return xpathMatch ? xpathMatch[1] : '';
    }
  }

  private extractValueSync(html: string, selector: string, attribute?: string): string {
    const elements = this.selectElementsSync(html, selector);

    if (elements.length === 0) {
      return '';
    }

    const element = elements[0];

    if (attribute) {
      // 标准化属性名
      const normalizedAttr = attribute.toLowerCase().trim();
      
      // 处理特殊伪属性
      if (normalizedAttr === 'text' || normalizedAttr === 'text()') {
        // 提取文本内容
        return this.extractAllTextContentSync(element);
      } else if (normalizedAttr === 'html' || normalizedAttr === 'html()') {
        // 返回完整HTML
        return element;
      } else if (normalizedAttr === 'textnodes' || normalizedAttr === 'textnodes()') {
        // 提取所有文本节点（保留换行）
        return this.extractTextNodesSync(element);
      } else {
        // 提取其他属性（使用原始属性名以保持大小写敏感）
        const attrRegex = new RegExp(`${escapeRegex(attribute)}=["']([^"']*)["']`, 'i');
        const match = element.match(attrRegex);
        return match ? this.decodeHtmlEntities(match[1]) : '';
      }
    } else {
      // 无属性时默认返回文本
      return this.extractAllTextContentSync(element);
    }
  }

  /**
   * 提取所有文本节点内容（保留换行）
   */
  private extractTextNodesSync(html: string): string {
    if (!html) return '';

    let text = html;
    
    // 将常见块级元素替换为换行
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<\/p>/gi, '\n');
    text = text.replace(/<\/div>/gi, '\n');
    text = text.replace(/<\/li>/gi, '\n');
    text = text.replace(/<\/h[1-6]>/gi, '\n');
    
    // 移除 script 和 style 标签及其内容
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    
    // 移除注释
    text = text.replace(/<!--[\s\S]*?-->/g, '');
    
    // 移除所有HTML标签
    text = text.replace(/<[^>]+>/g, '');
    
    // 解码HTML实体
    text = this.decodeHtmlEntities(text);
    
    // 清理多余空白
    text = text.replace(/\n\s*\n/g, '\n');
    text = text.replace(/[ \t]+/g, ' ');
    
    return text.trim();
  }

  private extractAllTextContentSync(html: string): string {
    if (!html) return '';

    let cleaned = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    cleaned = cleaned.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

    const textParts: string[] = [];
    const textMatches = cleaned.match(/>([^<]+)</g);
    if (textMatches) {
      for (const match of textMatches) {
        const text = match.substring(1, match.length - 1).trim();
        if (text) {
          textParts.push(this.decodeHtmlEntities(text));
        }
      }
    }

    return textParts.join(' ').trim();
  }

  async selectElements(html: string, selector: string): Promise<string[]> {
    if (!html || !selector) {
      return [];
    }

    if (!isTaskPoolAvailable()) {
      return this.selectElementsSync(html, selector);
    }

    try {
      const task = new taskpool.Task(parseInWorker, {
        html,
        selector,
        operation: 'select'
      } as ParseTaskParams);

      const result = await taskpool.execute(task) as ParseTaskResult;

      if (!result.success) {
        Logger.warn(TAG, `解析失败: ${result.error}`);
        return this.selectElementsSync(html, selector);
      }

      return result.elements;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `TaskPool任务执行失败: ${errorMsg}，降级到同步解析`);
      markTaskPoolUnavailable();
      return this.selectElementsSync(html, selector);
    }
  }

  async extractValue(html: string, selector: string, attribute?: string): Promise<string> {
    if (!html || !selector) {
      return '';
    }

    if (!isTaskPoolAvailable()) {
      return this.extractValueSync(html, selector, attribute);
    }

    try {
      const task = new taskpool.Task(parseInWorker, {
        html,
        selector,
        operation: 'extract',
        attribute
      } as ParseTaskParams);

      const result = await taskpool.execute(task) as ParseTaskResult;

      if (!result.success) {
        Logger.warn(TAG, `提取失败: ${result.error}`);
        return this.extractValueSync(html, selector, attribute);
      }

      return result.value;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `TaskPool任务执行失败: ${errorMsg}，降级到同步解析`);
      markTaskPoolUnavailable();
      return this.extractValueSync(html, selector, attribute);
    }
  }

  async batchSelect(items: string[], selector: string): Promise<string[][]> {
    if (!items.length || !selector) {
      return [];
    }

    if (!isTaskPoolAvailable()) {
      return items.map(item => this.selectElementsSync(item, selector));
    }

    const taskGroup = new taskpool.TaskGroup();
    for (const item of items) {
      const task = new taskpool.Task(parseInWorker, {
        html: item,
        selector,
        operation: 'select'
      } as ParseTaskParams);
      try {
        taskGroup.addTask(task);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        Logger.error(TAG, `添加任务失败: ${errorMsg}`);
      }
    }

    try {
      const results = await taskpool.execute(taskGroup) as ParseTaskResult[];
      return results.map(r => r.success ? r.elements : []);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `TaskPool批量解析失败: ${errorMsg}，降级到同步解析`);
      markTaskPoolUnavailable();
      return items.map(item => this.selectElementsSync(item, selector));
    }
  }
}
