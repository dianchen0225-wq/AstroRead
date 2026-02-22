/**
 * AsyncChapterParser - 异步章节解析器
 * 使用 TaskPool 将章节解析任务移至子线程
 */

import taskpool from '@ohos.taskpool';
import { Logger } from './Logger';
import { ParserCore, ChapterInfo } from './ParserCore';

const TAG = 'AsyncChapterParser';

export interface ParsedChapterItem {
  title: string;
  url: string;
  isVip: boolean;
  order: number;
}

interface ChapterParseParams {
  html: string;
  listRule: string;
  nameRule: string;
  urlRule: string;
  baseUrl: string;
}

interface ChapterParseResult {
  chapters: ParsedChapterItem[];
  success: boolean;
  error?: string;
}

@Concurrent
function parseChaptersInWorker(params: ChapterParseParams): ChapterParseResult {
  try {
    const chapterInfos: ChapterInfo[] = ParserCore.parseChapterList(
      params.html,
      params.listRule,
      params.nameRule,
      params.urlRule,
      params.baseUrl
    );

    const chapters: ParsedChapterItem[] = chapterInfos.map((chapter: ChapterInfo, index: number): ParsedChapterItem => {
      const item: ParsedChapterItem = {
        title: chapter.title,
        url: chapter.url,
        isVip: /vip|收费|会员|付费/i.test(chapter.title),
        order: index
      };
      return item;
    });

    return {
      chapters: chapters,
      success: true
    };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return {
      chapters: [],
      success: false,
      error: errorMsg
    };
  }
}

export class AsyncChapterParser {
  private static instance: AsyncChapterParser | null = null;

  private constructor() {}

  static getInstance(): AsyncChapterParser {
    if (!AsyncChapterParser.instance) {
      AsyncChapterParser.instance = new AsyncChapterParser();
    }
    return AsyncChapterParser.instance;
  }

  async parseChapterList(
    html: string,
    listRule: string,
    nameRule: string,
    urlRule: string,
    baseUrl: string
  ): Promise<ParsedChapterItem[]> {
    if (!html || !listRule) {
      Logger.warn(TAG, '解析参数为空');
      return [];
    }

    const startTime = Date.now();
    Logger.info(TAG, `开始异步解析章节列表, listRule: ${listRule}`);

    try {
      const task = new taskpool.Task(parseChaptersInWorker, {
        html,
        listRule,
        nameRule,
        urlRule,
        baseUrl
      } as ChapterParseParams);

      const result = await taskpool.execute(task) as ChapterParseResult;

      const elapsed = Date.now() - startTime;
      Logger.info(TAG, `异步解析完成, 耗时: ${elapsed}ms, 章节数: ${result.chapters.length}`);

      if (!result.success) {
        Logger.error(TAG, `解析失败: ${result.error}`);
        return [];
      }

      return result.chapters;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      Logger.error(TAG, `任务执行失败: ${errorMsg}`);
      return [];
    }
  }
}

export default AsyncChapterParser.getInstance();
