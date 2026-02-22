import { BookSource, SearchRule, ChapterRule } from '../models/BookSource';
import { RuleEngine } from './RuleEngine';
import { CssSelectorParser } from './CssSelectorParser';
import { AsyncCssSelectorParser } from './AsyncCssSelectorParser';
import { Logger } from './Logger';
import { EntityDecoder } from '../core/utils/EntityDecoder';

export interface ParsedBookItem {
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

export interface ParsedChapterItem {
  title: string;
  url: string;
  isVip: boolean;
  order: number;
}

export interface ReplaceRuleItem {
  from: string;
  to: string;
}
export interface ReplaceRuleConfig {
  removeTags?: string[];
  replace?: ReplaceRuleItem[];
  removeHtmlTags?: boolean;
}

export type JsonData = Record<string, string | number | boolean | object | null | undefined>;

export type JsonArray = JsonData[];

export type JsonValue = JsonData | JsonArray | string | number | boolean | null | undefined;

export class ContentParser {
  private static readonly TAG = 'ContentParser';
  private static asyncParser = AsyncCssSelectorParser.getInstance();

  static parseSearchResult(html: string, bookSource: BookSource): ParsedBookItem[] {
    if (!html || !bookSource || !bookSource.searchRule) {
      Logger.error(ContentParser.TAG, '解析参数异常：缺少必要的参数');
      return [];
    }

    if (typeof html !== 'string') {
      Logger.error(ContentParser.TAG, '解析异常：HTML内容必须是字符串类型');
      return [];
    }

    try {
      const rule = bookSource.searchRule;

      Logger.info(ContentParser.TAG, `开始解析搜索结果，书源: ${bookSource.name}, 规则类型: ${bookSource.ruleType}`);
      Logger.info(ContentParser.TAG, `规则详情 - bookList: ${rule.bookList}, name: ${rule.name}, author: ${rule.author}, bookUrl: ${rule.bookUrl}`);

      if (!rule.bookList || rule.bookList.trim() === '') {
        Logger.error(ContentParser.TAG, `书源 ${bookSource.name} 缺少bookList规则`);
        return [];
      }

      RuleEngine.setContext({ baseUrl: bookSource.url, html: html });

      let results: ParsedBookItem[];

      switch (bookSource.ruleType) {
        case 'jsonpath':
          results = ContentParser.parseByJsonPath(html, rule.bookList, rule);
          break;
        case 'xpath':
          results = ContentParser.parseByXPath(html, rule.bookList, rule);
          break;
        case 'regex':
          results = ContentParser.parseByRegex(html, rule.bookList, rule);
          break;
        default:
          results = ContentParser.parseByXPath(html, rule.bookList, rule);
      }

      Logger.info(ContentParser.TAG, `解析完成，书源: ${bookSource.name}, 找到 ${results.length} 条结果`);
      return results;
    } catch (error) {
      Logger.error(ContentParser.TAG, `搜索解析异常: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  static parseChapterList(html: string, bookSource: BookSource): ParsedChapterItem[] {
    if (!html || !bookSource || !bookSource.chapterRule) {
      Logger.error(ContentParser.TAG, '解析参数异常：缺少必要的参数');
      return [];
    }

    if (typeof html !== 'string') {
      Logger.error(ContentParser.TAG, '解析异常：HTML内容必须是字符串类型');
      return [];
    }

    try {
      const rule = bookSource.chapterRule;
      
      Logger.info(ContentParser.TAG, `开始解析章节列表 - 书源: ${bookSource.name}, ruleType: ${bookSource.ruleType}`);
      Logger.info(ContentParser.TAG, `章节规则 - chapterList: ${rule.chapterList}, chapterName: ${rule.chapterName}, chapterUrl: ${rule.chapterUrl}`);
      Logger.debug(ContentParser.TAG, `HTML内容长度: ${html.length}, 前500字符: ${html.substring(0, 500)}`);

      RuleEngine.setContext({ baseUrl: bookSource.url, html: html });

      let chapters: ParsedChapterItem[];
      switch (bookSource.ruleType) {
        case 'jsonpath':
          chapters = ContentParser.parseChaptersByJsonPath(html, rule.chapterList, rule);
          break;
        case 'xpath':
          chapters = ContentParser.parseChaptersByXPath(html, rule.chapterList, rule);
          break;
        case 'regex':
          chapters = ContentParser.parseChaptersByRegex(html, rule.chapterList, rule);
          break;
        default:
          chapters = ContentParser.parseChaptersByXPath(html, rule.chapterList, rule);
      }
      
      Logger.info(ContentParser.TAG, `章节解析完成 - 找到 ${chapters.length} 个章节`);
      if (chapters.length > 0) {
        Logger.debug(ContentParser.TAG, `第一个章节: title=${chapters[0].title}, url=${chapters[0].url}`);
      }
      
      return chapters;
    } catch (error) {
      Logger.error(ContentParser.TAG, `章节解析异常: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  static parseChapterContent(html: string, bookSource: BookSource): string {
    if (!html || !bookSource || !bookSource.contentRule) {
      Logger.error(ContentParser.TAG, '解析参数异常：缺少必要的参数');
      return '';
    }

    if (typeof html !== 'string') {
      Logger.error(ContentParser.TAG, '解析异常：HTML内容必须是字符串类型');
      return '';
    }

    try {
      Logger.info(ContentParser.TAG, `========== 开始解析章节内容 ==========`);
      Logger.info(ContentParser.TAG, `书源: ${bookSource.name}, 规则类型: ${bookSource.ruleType}`);
      Logger.info(ContentParser.TAG, `HTML长度: ${html.length} 字符`);

      const rule = bookSource.contentRule;
      Logger.info(ContentParser.TAG, `内容规则: ${rule.content}`);
      if (rule.replaceRule) {
        Logger.debug(ContentParser.TAG, `替换规则: ${rule.replaceRule}`);
      }

      let content = '';

      RuleEngine.setContext({ baseUrl: bookSource.url, html: html });

      Logger.info(ContentParser.TAG, `开始执行规则解析...`);
      switch (bookSource.ruleType) {
        case 'jsonpath':
          Logger.debug(ContentParser.TAG, `使用JSONPath解析`);
          content = RuleEngine.parseRule(rule.content, html);
          break;
        case 'xpath':
          Logger.debug(ContentParser.TAG, `使用XPath/CSS选择器解析`);
          content = RuleEngine.parseRule(rule.content, html);
          break;
        case 'regex':
          Logger.debug(ContentParser.TAG, `使用正则表达式解析`);
          content = RuleEngine.parseRule(rule.content, html);
          break;
        default:
          Logger.debug(ContentParser.TAG, `使用默认(XPath)解析`);
          content = RuleEngine.parseRule(rule.content, html);
      }

      Logger.info(ContentParser.TAG, `规则解析完成，原始内容长度: ${content.length} 字符`);
      if (content.length > 0) {
        Logger.debug(ContentParser.TAG, `解析内容前300字符: ${content.substring(0, 300)}`);
      } else {
        Logger.warn(ContentParser.TAG, `规则解析结果为空！`);
        Logger.debug(ContentParser.TAG, `HTML内容片段(用于调试): ${html.substring(0, 1000)}`);
      }

      const replaceRuleConfig: ReplaceRuleConfig | undefined = rule.replaceRule ? JSON.parse(rule.replaceRule) : undefined;
      content = ContentParser.purifyContent(content, replaceRuleConfig);

      Logger.info(ContentParser.TAG, `净化后内容长度: ${content.length} 字符`);
      Logger.info(ContentParser.TAG, `========== 章节内容解析完成 ==========`);

      return content;
    } catch (error) {
      Logger.error(ContentParser.TAG, `内容解析异常: ${error instanceof Error ? error.message : String(error)}`);
      Logger.error(ContentParser.TAG, `错误堆栈: ${error instanceof Error ? error.stack : '无堆栈信息'}`);
      return '';
    }
  }
  private static parseByJsonPath(html: string, listRule: string, rule: SearchRule): ParsedBookItem[] {
    try {
      Logger.debug(ContentParser.TAG, `JSONPath解析 - listRule: ${listRule}`);
      let jsonData: JsonData | null;
      try {
        const parsedData: JsonData = JSON.parse(html) as JsonData;
        jsonData = typeof parsedData === 'object' && parsedData !== null ? parsedData : null;
      } catch (e) {
        const jsonMatch = html.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          try {
            const parsedData: JsonData = JSON.parse(jsonMatch[0]) as JsonData;
            jsonData = typeof parsedData === 'object' && parsedData !== null ? parsedData : null;
            Logger.debug(ContentParser.TAG, '从HTML中提取JSON成功');
          } catch (parseError) {
            Logger.error(ContentParser.TAG, `JSON解析失败: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
            return [];
          }
        } else {
          Logger.error(ContentParser.TAG, '无法从HTML中提取JSON数据');
          return [];
        }
      }

      if (!jsonData) {
        Logger.error(ContentParser.TAG, 'JSON数据为空或不是对象类型');
        return [];
      }

      const listData = ContentParser.resolveJsonPath(jsonData, listRule);

      if (listData === null || listData === undefined) {
        Logger.error(ContentParser.TAG, `JSONPath路径解析失败: ${listRule}`);
        return [];
      }

      let dataArray: JsonData[] = [];
      
      if (Array.isArray(listData)) {
        for (const item of listData) {
          if (item !== null && typeof item === 'object' && !Array.isArray(item)) {
            dataArray.push(item as JsonData);
          }
        }
      } else if (typeof listData === 'object' && listData !== null && !Array.isArray(listData)) {
        dataArray = [listData as JsonData];
        Logger.debug(ContentParser.TAG, '将单个对象包装为数组');
      } else {
        Logger.error(ContentParser.TAG, `JSONPath解析结果不是有效的对象或数组类型: ${typeof listData}, 值: ${String(listData).substring(0, 100)}`);
        return [];
      }

      Logger.debug(ContentParser.TAG, `JSONPath解析找到 ${dataArray.length} 个元素`);

      const books: ParsedBookItem[] = [];
      for (let i = 0; i < dataArray.length; i++) {
          const item: JsonData = dataArray[i];
        if (item === null || typeof item !== 'object' || Array.isArray(item)) {
          continue;
        }
        const sourceObj: JsonData = item;
        const book: ParsedBookItem = {};

        if (rule.name) {
          book.name = ContentParser.extractJsonValue(sourceObj, rule.name);
        }
        if (rule.author) {
          book.author = ContentParser.extractJsonValue(sourceObj, rule.author);
        }
        if (rule.cover) {
          book.cover = ContentParser.extractJsonValue(sourceObj, rule.cover);
        }
        if (rule.intro) {
          book.intro = ContentParser.extractJsonValue(sourceObj, rule.intro);
        }
        if (rule.bookUrl) {
          book.bookUrl = ContentParser.extractJsonValue(sourceObj, rule.bookUrl);
        }

        if (book.name && book.bookUrl) {
          books.push(book);
          Logger.debug(ContentParser.TAG, `JSONPath解析成功 - 书名: ${book.name}`);
        }
      }

      return books;
    } catch (error) {
      Logger.error(ContentParser.TAG, `JSONPath解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }
  private static resolveJsonPath(data: JsonData, path: string): JsonValue {
    if (!data || !path) {
      return data;
    }
    let processedPath = path.trim();

    if (processedPath.startsWith('$')) {
      processedPath = processedPath.substring(1);
      if (processedPath.startsWith('.')) {
        processedPath = processedPath.substring(1);
      }
    }

    const fromMatch = processedPath.match(/^from\(([^)]+)\)$/);
    if (fromMatch) {
      processedPath = fromMatch[1];
    }

    if (!processedPath || processedPath === '.') {
      return data;
    }
    const parts = processedPath.split(/[.\[\]]+/).filter((p: string) => p.length > 0);
    let current: JsonValue = data;

    for (const part of parts) {
      if (current === null || current === undefined) {
        return undefined;
      }

      if (part === '*') {
        continue;
      }

      const index = parseInt(part, 10);
      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index] as JsonValue;
        } else {
          return undefined;
        }
      } else if (typeof current === 'object' && !Array.isArray(current)) {
        current = (current as JsonData)[part] as JsonValue;
      } else {
        return undefined;
      }
    }

    return current;
  }
  private static extractJsonValue(obj: JsonData, path: string): string {
    if (!obj || !path) {
      return '';
    }

    const value = ContentParser.resolveJsonPath(obj, path);

    if (value === undefined || value === null) {
      return '';
    }
    return String(value).trim();
  }

  private static parseByRegex(html: string, listRule: string, rule: SearchRule): ParsedBookItem[] {
    try {
      const books: ParsedBookItem[] = [];

      const listRegex = new RegExp(listRule.replace(/^\(\?s\)/, ''), listRule.startsWith('(?s)') ? 'gs' : 'g');
      const listMatches = html.matchAll(listRegex);

      for (const match of listMatches) {
        const bookItem: ParsedBookItem = {};
        const matchStr = match[0] || match[1] || '';

        if (rule.name) {
          const nameRegex = new RegExp(rule.name.replace(/^\(\?s\)/, ''), rule.name.startsWith('(?s)') ? 's' : '');
          const nameMatch = matchStr.match(nameRegex);
          if (nameMatch) {
            bookItem.name = ContentParser.cleanText(nameMatch[1] || nameMatch[0]);
          }
        }

        if (rule.author) {
          const authorRegex = new RegExp(rule.author.replace(/^\(\?s\)/, ''), rule.author.startsWith('(?s)') ? 's' : '');
          const authorMatch = matchStr.match(authorRegex);
          if (authorMatch) {
            bookItem.author = ContentParser.cleanText(authorMatch[1] || authorMatch[0]);
          }
        }

        if (rule.cover) {
          const coverRegex = new RegExp(rule.cover.replace(/^\(\?s\)/, ''), rule.cover.startsWith('(?s)') ? 's' : '');
          const coverMatch = matchStr.match(coverRegex);
          if (coverMatch) {
            bookItem.cover = ContentParser.cleanUrl(coverMatch[1] || coverMatch[0]);
          }
        }

        if (rule.intro) {
          const introRegex = new RegExp(rule.intro.replace(/^\(\?s\)/, ''), rule.intro.startsWith('(?s)') ? 's' : '');
          const introMatch = matchStr.match(introRegex);
          if (introMatch) {
            bookItem.intro = ContentParser.cleanText(introMatch[1] || introMatch[0]);
          }
        }

        if (rule.bookUrl) {
          const urlRegex = new RegExp(rule.bookUrl.replace(/^\(\?s\)/, ''), rule.bookUrl.startsWith('(?s)') ? 's' : '');
          const urlMatch = matchStr.match(urlRegex);
          if (urlMatch) {
            bookItem.bookUrl = ContentParser.cleanUrl(urlMatch[1] || urlMatch[0]);
          }
        }

        if (bookItem.name && bookItem.bookUrl) {
          books.push(bookItem);
        }
      }

      return books;
    } catch (error) {
      Logger.error(ContentParser.TAG, `正则表达式解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  private static parseChaptersByRegex(html: string, listRule: string, rule: ChapterRule): ParsedChapterItem[] {
    try {
      const chapters: ParsedChapterItem[] = [];

      const listRegex = new RegExp(listRule.replace(/^\(\?s\)/, ''), listRule.startsWith('(?s)') ? 'gs' : 'g');
      const listMatches = html.matchAll(listRegex);

      let order = 0;
      for (const match of listMatches) {
        const chapterItem: ParsedChapterItem = {
          title: '',
          url: '',
          isVip: false,
          order: 0
        };
        const matchStr = match[0] || match[1] || '';

        if (rule.chapterName) {
          const nameRegex = new RegExp(rule.chapterName.replace(/^\(\?s\)/, ''), rule.chapterName.startsWith('(?s)') ? 's' : '');
          const nameMatch = matchStr.match(nameRegex);
          if (nameMatch) {
            chapterItem.title = ContentParser.cleanText(nameMatch[1] || nameMatch[0]);
          }
        }

        if (rule.chapterUrl) {
          const urlRegex = new RegExp(rule.chapterUrl.replace(/^\(\?s\)/, ''), rule.chapterUrl.startsWith('(?s)') ? 's' : '');
          const urlMatch = matchStr.match(urlRegex);
          if (urlMatch) {
            chapterItem.url = ContentParser.cleanUrl(urlMatch[1] || urlMatch[0]);
          }
        }

        chapterItem.isVip = /vip|收费|会员|付费/i.test(chapterItem.title || '');
        chapterItem.order = order++;

        if (chapterItem.title && chapterItem.url) {
          chapters.push(chapterItem);
        }
      }

      return chapters;
    } catch (error) {
      Logger.error(ContentParser.TAG, `正则表达式章节解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  private static cleanText(text: string): string {
    if (!text) {
      return '';
    }
    return text
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static cleanUrl(url: string): string {
    if (!url) {
      return '';
    }
    if (url.startsWith('//')) {
      return 'https:' + url;
    }
    if (url.startsWith('/')) {
      return url;
    }
    return url.trim();
  }
  private static parseChaptersByJsonPath(html: string, listRule: string, rule: ChapterRule): ParsedChapterItem[] {
    try {
      let jsonData: JsonData | null;
      try {
        const parsedData: JsonData = JSON.parse(html) as JsonData;
        jsonData = typeof parsedData === 'object' && parsedData !== null ? parsedData : null;
      } catch (e) {
        const jsonMatch = html.match(/\{[\s\S]*?\}(?=\s*(?:\{|\}|$))/);
        if (jsonMatch) {
          try {
            const parsedData: JsonData = JSON.parse(jsonMatch[0]) as JsonData;
            jsonData = typeof parsedData === 'object' && parsedData !== null ? parsedData : null;
          } catch (parseError) {
            Logger.error(ContentParser.TAG, `JSON解析失败: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
            return [];
          }
        } else {
          Logger.error(ContentParser.TAG, '无法从HTML中提取JSON数据');
          return [];
        }
      }

      if (!jsonData) {
        Logger.error(ContentParser.TAG, 'JSON数据为空或不是对象类型');
        return [];
      }
        const chapterList = ContentParser.resolveJsonPath(jsonData, listRule);

        if (!Array.isArray(chapterList)) {
        Logger.error(ContentParser.TAG, '章节列表不是数组类型');
        return [];
      }

      const chapters: ParsedChapterItem[] = [];
      let order = 0;

      for (let i = 0; i < chapterList.length; i++) {
          const item: JsonData = chapterList[i] as JsonData;
        if (!item || typeof item !== 'object') {
          continue;
        }

        const chapter: ParsedChapterItem = {
          title: '',
          url: '',
          isVip: false,
          order: 0
        };

        if (rule.chapterName) {
            const title = ContentParser.resolveJsonPath(item, rule.chapterName);
          if (title) {
            chapter.title = String(title).trim();
          }
        }

        if (rule.chapterUrl) {
            const url = ContentParser.resolveJsonPath(item, rule.chapterUrl);
          if (url) {
            chapter.url = String(url).trim();
          }
        }

        chapter.isVip = /vip|收费|会员|付费/i.test(chapter.title || '');
        chapter.order = order++;

        if (chapter.title && chapter.url) {
          chapters.push(chapter);
        }
      }

      return chapters;
    } catch (error) {
      Logger.error(ContentParser.TAG, `JSONPath章节解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  static purifyContent(content: string, replaceRule?: ReplaceRuleConfig): string {
    try {
      let purified = content;

      if (replaceRule?.removeHtmlTags) {
        purified = purified.replace(/<[^>]+>/g, '');
      }

      if (replaceRule?.removeTags) {
        replaceRule.removeTags.forEach((tag: string) => {
          const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'gi');
          purified = purified.replace(regex, '');
        });
      }

      if (replaceRule?.replace) {
        replaceRule.replace.forEach((rule: ReplaceRuleItem) => {
          const regex = new RegExp(rule.from, 'g');
          purified = purified.replace(regex, rule.to);
        });
      }

      purified = EntityDecoder.decode(purified);

      purified = purified.replace(/\s+/g, ' ');
      purified = purified.replace(/[\n\r]+/g, '\n');

      purified = purified.replace(/[！!]+/g, '！');
      purified = purified.replace(/[。.]+/g, '。');
      purified = purified.replace(/[,，]+/g, '，');
      purified = purified.replace(/[;；]+/g, '；');

      purified = purified.trim();

      return purified;
    } catch (error) {
      Logger.error(ContentParser.TAG, `内容净化失败: ${error instanceof Error ? error.message : String(error)}`);
      return content;
    }
  }

  private static parseByXPath(html: string, listRule: string, rule: SearchRule): ParsedBookItem[] {
    try {
      const books: ParsedBookItem[] = [];

      if (listRule.startsWith('<js>') || listRule.startsWith('@js:')) {
        Logger.warn(ContentParser.TAG, 'JavaScript规则暂不支持，使用正则表达式回退');
        return ContentParser.parseByRegex(html, listRule, rule);
      }

      Logger.info(ContentParser.TAG, `XPath解析 - listRule: ${listRule}`);

      // 使用异步解析器（降级到同步）
      const listElements = CssSelectorParser.selectElements(html, listRule);
      Logger.info(ContentParser.TAG, `XPath解析 - 找到 ${listElements.length} 个列表元素`);

      for (const elementHtml of listElements) {
        const bookItem: ParsedBookItem = {};

        if (rule.name) {
          bookItem.name = RuleEngine.parseRule(rule.name, elementHtml);
        }

        if (rule.author) {
          bookItem.author = RuleEngine.parseRule(rule.author, elementHtml);
        }

        if (rule.cover) {
          bookItem.cover = RuleEngine.parseRule(rule.cover, elementHtml);
        }

        if (rule.intro) {
          bookItem.intro = RuleEngine.parseRule(rule.intro, elementHtml);
        }

        if (rule.bookUrl) {
          bookItem.bookUrl = RuleEngine.parseRule(rule.bookUrl, elementHtml);
        }

        if (bookItem.name && bookItem.bookUrl) {
          books.push(bookItem);
          Logger.debug(ContentParser.TAG, `XPath解析成功 - 书名: ${bookItem.name}, 作者: ${bookItem.author || '未知'}`);
        } else {
          Logger.debug(ContentParser.TAG, `XPath解析跳过 - name: ${bookItem.name || '空'}, bookUrl: ${bookItem.bookUrl || '空'}`);
        }
      }

      return books;
    } catch (error) {
      Logger.error(ContentParser.TAG, `XPath/CSS选择器解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  private static parseChaptersByXPath(html: string, listRule: string, rule: ChapterRule): ParsedChapterItem[] {
    try {
      const chapters: ParsedChapterItem[] = [];

      Logger.info(ContentParser.TAG, `XPath章节解析 - listRule: ${listRule}`);

      if (listRule.startsWith('<js>') || listRule.startsWith('@js:')) {
        Logger.warn(ContentParser.TAG, 'JavaScript规则暂不支持，使用正则表达式回退');
        return ContentParser.parseChaptersByRegex(html, listRule, rule);
      }

      const listElements = CssSelectorParser.selectElements(html, listRule);
      Logger.info(ContentParser.TAG, `XPath选择器找到 ${listElements.length} 个元素`);
      
      if (listElements.length > 0) {
        Logger.debug(ContentParser.TAG, `第一个元素内容(前200字符): ${listElements[0].substring(0, 200)}`);
      }
      
      let order = 0;
      let skippedCount = 0;

      for (const elementHtml of listElements) {
        const chapter: ParsedChapterItem = {
          title: '',
          url: '',
          isVip: false,
          order: 0
        };

        if (rule.chapterName) {
          chapter.title = RuleEngine.parseRule(rule.chapterName, elementHtml);
        }

        if (rule.chapterUrl) {
          chapter.url = RuleEngine.parseRule(rule.chapterUrl, elementHtml);
        }

        chapter.isVip = /vip|收费|会员|付费/i.test(chapter.title || '');
        chapter.order = order++;

        if (chapter.title && chapter.url) {
          chapters.push(chapter);
        } else {
          skippedCount++;
          if (skippedCount <= 3) {
            Logger.debug(ContentParser.TAG, `跳过章节 - title: ${chapter.title || '空'}, url: ${chapter.url || '空'}`);
          }
        }
      }
      
      if (skippedCount > 0) {
        Logger.warn(ContentParser.TAG, `共跳过 ${skippedCount} 个无效章节`);
      }

      return chapters;
    } catch (error) {
      Logger.error(ContentParser.TAG, `XPath/CSS选择器章节解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }
}