/**
 * AsyncCssSelectorParser - 异步 CSS 选择器解析器
 * 使用 TaskPool 将解析任务移至子线程，避免主线程阻塞
 */

import taskpool from '@ohos.taskpool';
import { Logger } from './Logger';

const TAG = 'AsyncCssSelectorParser';

/**
 * 解析任务参数
 */
interface ParseTaskParams {
  html: string;
  selector: string;
  operation: 'select' | 'extract';
  attribute?: string;
}

/**
 * 解析任务结果
 */
interface ParseTaskResult {
  elements: string[];
  value: string;
  success: boolean;
  error?: string;
}

/**
 * 转义正则表达式特殊字符
 */
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
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
        elements.push(...childElements);
      }

      if (skipFirst > 0 && elements.length > skipFirst) {
        return elements.slice(skipFirst);
      }
      if (index >= 0 && index < elements.length) {
        return [elements[index]];
      }
      return elements;
    }

    // 处理类选择器 .className
    if (processedSelector.startsWith('.')) {
      const className = processedSelector.substring(1).split(/[.\s#\[]/)[0];
      const regex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*\\b${escapeRegexLocal(className)}\\b[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`,
        'gi'
      );
      const matches = html.matchAll(regex);
      for (const match of matches) {
        elements.push(match[0]);
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

  // 辅助函数：提取值
  const extractValueSync = (html: string, selector: string, attribute?: string): string => {
    const elements = selectElementsSync(html, selector);

    if (elements.length === 0) {
      return '';
    }

    const element = elements[0];

    if (attribute) {
      // 提取属性值
      const attrRegex = new RegExp(`${escapeRegexLocal(attribute)}=["']([^"']*)["']`, 'i');
      const match = element.match(attrRegex);
      return match ? decodeHtmlEntitiesLocal(match[1]) : '';
    } else {
      // 提取文本内容
      const textMatch = element.match(/>([^<]*)</);
      return textMatch ? decodeHtmlEntitiesLocal(textMatch[1].trim()) : '';
    }
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

  /**
   * 异步选择元素
   * @param html HTML 内容
   * @param selector CSS 选择器
   * @returns 匹配的元素数组
   */
  async selectElements(html: string, selector: string): Promise<string[]> {
    if (!html || !selector) {
      return [];
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
        return [];
      }

      return result.elements;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `任务执行失败: ${errorMsg}`);
      return [];
    }
  }

  /**
   * 异步提取属性值
   * @param html HTML 内容
   * @param selector CSS 选择器
   * @param attribute 要提取的属性名（可选，不提供则提取文本内容）
   * @returns 提取的值
   */
  async extractValue(html: string, selector: string, attribute?: string): Promise<string> {
    if (!html || !selector) {
      return '';
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
        return '';
      }

      return result.value;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `任务执行失败: ${errorMsg}`);
      return '';
    }
  }

  /**
   * 批量异步解析（用于解析多个书籍）
   * @param items 要解析的 HTML 片段数组
   * @param selector CSS 选择器
   * @returns 解析结果数组
   */
  async batchSelect(items: string[], selector: string): Promise<string[][]> {
    if (!items.length || !selector) {
      return [];
    }

    // 创建任务组
    const taskGroup = new taskpool.TaskGroup();
    for (const item of items) {
      const task = new taskpool.Task(parseInWorker, {
        html: item,
        selector,
        operation: 'select'
      } as ParseTaskParams);
      taskGroup.addTask(task);
    }

    try {
      const results = await taskpool.execute(taskGroup) as ParseTaskResult[];
      return results.map(r => r.success ? r.elements : []);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `批量解析失败: ${errorMsg}`);
      return items.map(() => []);
    }
  }
}
