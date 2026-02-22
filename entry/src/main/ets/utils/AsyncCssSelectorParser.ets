/**
 * AsyncCssSelectorParser - 异步 CSS 选择器解析器
 * 使用 TaskPool 将解析任务移至子线程，避免主线程阻塞
 * 当 TaskPool 不可用时，自动降级到同步解析
 */

import taskpool from '@ohos.taskpool';
import { Logger } from './Logger';
import { ParserCore } from './ParserCore';

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

let taskPoolAvailable: boolean = false;
let taskPoolDisabled: boolean = true;

function isTaskPoolAvailable(): boolean {
  return taskPoolAvailable && !taskPoolDisabled;
}

function markTaskPoolUnavailable(): void {
  taskPoolAvailable = false;
  Logger.warn(TAG, 'TaskPool 不可用，已切换到同步解析模式');
}

@Concurrent
function parseInWorker(params: ParseTaskParams): ParseTaskResult {
  try {
    const result: ParseTaskResult = {
      elements: [],
      value: '',
      success: true
    };

    if (params.operation === 'select') {
      result.elements = ParserCore.selectElements(params.html, params.selector);
    } else if (params.operation === 'extract') {
      if (params.attribute) {
        result.value = ParserCore.extractAttribute(params.html, params.selector, params.attribute);
      } else {
        result.value = ParserCore.extractTextWithSelector(params.html, params.selector);
      }
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

export class AsyncCssSelectorParser {
  private static instance: AsyncCssSelectorParser | null = null;

  private constructor() {}

  static getInstance(): AsyncCssSelectorParser {
    if (!AsyncCssSelectorParser.instance) {
      AsyncCssSelectorParser.instance = new AsyncCssSelectorParser();
    }
    return AsyncCssSelectorParser.instance;
  }

  async selectElements(html: string, selector: string): Promise<string[]> {
    if (!html || !selector) {
      return [];
    }

    if (!isTaskPoolAvailable()) {
      return ParserCore.selectElements(html, selector);
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
        return ParserCore.selectElements(html, selector);
      }

      return result.elements;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `TaskPool任务执行失败: ${errorMsg}，降级到同步解析`);
      markTaskPoolUnavailable();
      return ParserCore.selectElements(html, selector);
    }
  }

  async extractValue(html: string, selector: string, attribute?: string): Promise<string> {
    if (!html || !selector) {
      return '';
    }

    if (!isTaskPoolAvailable()) {
      if (attribute) {
        return ParserCore.extractAttribute(html, selector, attribute);
      }
      return ParserCore.extractTextWithSelector(html, selector);
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
        if (attribute) {
          return ParserCore.extractAttribute(html, selector, attribute);
        }
        return ParserCore.extractTextWithSelector(html, selector);
      }

      return result.value;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `TaskPool任务执行失败: ${errorMsg}，降级到同步解析`);
      markTaskPoolUnavailable();
      if (attribute) {
        return ParserCore.extractAttribute(html, selector, attribute);
      }
      return ParserCore.extractTextWithSelector(html, selector);
    }
  }

  async batchSelect(items: string[], selector: string): Promise<string[][]> {
    if (!items.length || !selector) {
      return [];
    }

    if (!isTaskPoolAvailable()) {
      return items.map(item => ParserCore.selectElements(item, selector));
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
      return items.map(item => ParserCore.selectElements(item, selector));
    }
  }
}

export default AsyncCssSelectorParser.getInstance();
