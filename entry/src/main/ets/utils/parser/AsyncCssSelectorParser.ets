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

    // 处理XPath格式 - 简化为类选择器处理
    if (processedSelector.startsWith('//') || processedSelector.startsWith('./')) {
      const xpathMatch = processedSelector.match(/\/\/([a-zA-Z][a-zA-Z0-9]*)/);
      if (xpathMatch) {
        processedSelector = xpathMatch[1];
      } else {
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

    // 处理类选择器 .className 或 .class1.class2（支持多class）
    if (processedSelector.startsWith('.')) {
      // 提取所有class名（支持多class如 .class1.class2）
      const classNames: string[] = [];
      const classMatches = processedSelector.match(/\.[a-zA-Z0-9_-]+/g);
      if (classMatches) {
        for (const cm of classMatches) {
          classNames.push(cm.substring(1)); // 移除前面的点
        }
      }

      if (classNames.length > 0) {
        // 构建多class匹配正则 - 使用正向前瞻确保所有class都存在
        let pattern = `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*`;
        for (const cn of classNames) {
          pattern += `(?=.*\\b${escapeRegexLocal(cn)}\\b)`;
        }
        pattern += `[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`;

        const regex = new RegExp(pattern, 'gi');
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
    }
    // 处理ID选择器 #id
    else if (processedSelector.startsWith('#')) {
      const id = processedSelector.substring(1).split(/[.\s#\[]/)[0];
      const regex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${escapeRegexLocal(id)}["'][^>]*>([\\s\\S]*?)(?:<\\/\\1>|(?=<[a-zA-Z]|$))`,
        'i'
      );
      const match = regex.exec(html);
      if (match) {
        elements.push(match[0]);
      }
    }
    // 处理标签选择器
    else {
      const tagName = processedSelector.split(/[.\s#\[]/)[0];
      if (tagName) {
        const regex = new RegExp(
          `<${tagName}[^>]*>([\\s\\S]*?)<\\/${tagName}>`,
          'gi'
        );
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
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
    let lastIndex = 0;
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
    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
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

    if (processedSelector.startsWith('//') || processedSelector.startsWith('./')) {
      const xpathMatch = processedSelector.match(/\/\/([a-zA-Z][a-zA-Z0-9]*)/);
      if (xpathMatch) {
        processedSelector = xpathMatch[1];
      } else {
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

    if (processedSelector.startsWith('.')) {
      // 提取所有class名（支持多class如 .class1.class2）
      const classNames: string[] = [];
      const classMatches = processedSelector.match(/\.[a-zA-Z0-9_-]+/g);
      if (classMatches) {
        for (const cm of classMatches) {
          classNames.push(cm.substring(1)); // 移除前面的点
        }
      }

      if (classNames.length > 0) {
        // 构建多class匹配正则 - 使用正向前瞻确保所有class都存在
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
    } else if (processedSelector.startsWith('#')) {
      const id = processedSelector.substring(1).split(/[.\s#\[]/)[0];
      const regex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${escapeRegex(id)}["'][^>]*>([\\s\\S]*?)(?:<\\/\\1>|(?=<[a-zA-Z]|$))`,
        'i'
      );
      const match = regex.exec(html);
      if (match) {
        elements.push(match[0]);
      }
    } else {
      const tagName = processedSelector.split(/[.\s#\[]/)[0];
      if (tagName) {
        const regex = new RegExp(
          `<${tagName}[^>]*>([\\s\\S]*?)<\\/${tagName}>`,
          'gi'
        );
        const matches = html.matchAll(regex);
        for (const match of matches) {
          elements.push(match[0]);
        }
      }
    }

    if (index >= 0 && index < elements.length) {
      return [elements[index]];
    }

    if (skipFirst > 0 && elements.length > skipFirst) {
      return elements.slice(skipFirst);
    }

    return elements;
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
