/**
  * AsyncContentParser - 异步内容解析器
  * 使用 TaskPool 将内容解析任务移至子线程
  */

import { taskpool } from '@kit.ArkTS';
import { Logger } from './Logger';
import { ParserCore } from './ParserCore';
import { purifyContent } from './ContentPurifier';

const TAG = 'AsyncContentParser';

interface ContentParseParams {
  html: string;
  contentRule: string;
  baseUrl: string;
  replaceRule?: string;
}

interface ContentParseResult {
  content: string;
  success: boolean;
  error?: string;
}

@Concurrent
function parseContentInWorker(params: ContentParseParams): ContentParseResult {
  try {
    let content = ParserCore.parseContent(params.html, params.contentRule);

    if (params.replaceRule) {
      content = purifyContent(content, params.replaceRule);
    }

    return {
      content: content,
      success: true
    };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return {
      content: '',
      success: false,
      error: errorMsg
    };
  }
}

export class AsyncContentParser {
  private static instance: AsyncContentParser | null = null;

  private constructor() {}

  static getInstance(): AsyncContentParser {
    if (!AsyncContentParser.instance) {
      AsyncContentParser.instance = new AsyncContentParser();
    }
    return AsyncContentParser.instance;
  }

  async parseChapterContent(
    html: string,
    contentRule: string,
    replaceRule?: string
  ): Promise<string> {
    if (!html || !contentRule) {
      Logger.warn(TAG, '解析参数为空');
      return '';
    }

    const startTime = Date.now();
    Logger.info(TAG, `开始异步解析章节内容, contentRule: ${contentRule}`);

    try {
      const task = new taskpool.Task(parseContentInWorker, {
        html,
        contentRule,
        baseUrl: '',
        replaceRule
      } as ContentParseParams);

      const result = await taskpool.execute(task) as ContentParseResult;

      const elapsed = Date.now() - startTime;
      Logger.info(TAG, `异步内容解析完成, 耗时: ${elapsed}ms, 内容长度: ${result.content.length}`);

      if (!result.success) {
        Logger.error(TAG, `解析失败: ${result.error}`);
        return '';
      }

      return result.content;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `任务执行失败: ${errorMsg}`);
      return '';
    }
  }
}

export default AsyncContentParser.getInstance();
