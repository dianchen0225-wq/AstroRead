import { taskpool } from '@kit.ArkTS';
import { Logger } from './Logger';

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
  // 本地辅助函数 - escapeRegex
  const escapeRegex = (str: string): string => {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  };

  // 本地辅助函数 - decodeHtmlEntities
  const decodeHtmlEntities = (text: string): string => {
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

    result = result.replace(/&#(\d+);/g, (match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });

    return result;
  };

  // 本地辅助函数 - cleanText
  const cleanText = (text: string): string => {
    if (!text) return '';
    let cleaned = decodeHtmlEntities(text);
    cleaned = cleaned.replace(/<[^>]+>/g, '');
    cleaned = cleaned.replace(/\s+/g, ' ').trim();
    return cleaned;
  };

  // 本地辅助函数 - resolveUrl
  const resolveUrl = (baseUrl: string, relativeUrl: string): string => {
    if (!relativeUrl) return '';
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    try {
      const protocolEnd = baseUrl.indexOf('://');
      if (protocolEnd === -1) return relativeUrl;

      const protocol = baseUrl.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = baseUrl.indexOf('/', hostStart);

      let host: string;
      if (pathStart === -1) {
        host = baseUrl.substring(hostStart);
      } else {
        host = baseUrl.substring(hostStart, pathStart);
      }

      if (relativeUrl.startsWith('//')) {
        return protocol + relativeUrl.substring(2);
      } else if (relativeUrl.startsWith('/')) {
        return protocol + host + relativeUrl;
      } else {
        const lastSlash = baseUrl.lastIndexOf('/');
        const basePath = lastSlash > hostStart + host.length
          ? baseUrl.substring(hostStart + host.length, lastSlash + 1)
          : '/';
        return protocol + host + basePath + relativeUrl;
      }
    } catch {
      return relativeUrl;
    }
  };

  // 本地辅助函数 - selectElements
  const selectElements = (html: string, selector: string): string[] => {
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
        const result = selectElements(html, orSelector);
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

      const parentElements = selectElements(html, parentSelector);
      for (const parentHtml of parentElements) {
        const childElements = selectElements(parentHtml, childSelector);
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

    if (processedSelector.startsWith('.')) {
      const className = processedSelector.substring(1).split(/[.\s#\[]/)[0];
      const regex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*\\b${escapeRegex(className)}\\b[^"']*["'][^>]*>([\\s\\S]*?)<\\/\\1>`,
        'gi'
      );
      const matches = html.matchAll(regex);
      for (const match of matches) {
        elements.push(match[0]);
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
  };

  // 本地辅助函数 - extractValue
  const extractValue = (html: string, rule: string, baseUrl: string): string => {
    if (!html || !rule) return '';

    let processedRule = rule.trim();

    if (processedRule.startsWith('@css:')) {
      processedRule = processedRule.substring(5).trim();
    }

    if (processedRule.includes('||')) {
      const orRules = processedRule.split('||').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
      for (const orRule of orRules) {
        const result = extractValue(html, orRule, baseUrl);
        if (result) return result;
      }
      return '';
    }
    let replacePatterns: string[] = [];
    if (processedRule.includes('##')) {
      const parts = processedRule.split('##');
      processedRule = parts[0];
      if (parts.length > 1) {
        const patternsStr = parts.slice(1).join('##');
        replacePatterns = patternsStr.split('|').map((p: string) => p.trim()).filter((p: string) => p.length > 0);
      }
    }

    let index = -1;
    const indexMatch = processedRule.match(/\.(\d+)$/);
    if (indexMatch) {
      index = parseInt(indexMatch[1], 10);
      processedRule = processedRule.substring(0, processedRule.lastIndexOf('.'));
    }

    if (processedRule.includes('@')) {
      const atIndex = processedRule.lastIndexOf('@');
      const selector = processedRule.substring(0, atIndex).trim();
      const attr = processedRule.substring(atIndex + 1).trim();

      let elements: string[];
      if (selector) {
        elements = selectElements(html, selector);
      } else {
        elements = [html];
      }

      if (elements.length > 0) {
        const elementIndex = index >= 0 && index < elements.length ? index : 0;
        const elementHtml = elements[elementIndex];

        let value = '';
        if (attr === 'text' || attr === 'text()') {
          value = cleanText(elementHtml);
        } else if (attr === 'href') {
          const hrefMatch = elementHtml.match(/href=["']([^"']*)["']/i);
          value = hrefMatch ? hrefMatch[1] : '';
          value = resolveUrl(baseUrl, value);
        } else if (attr === 'src') {
          const srcMatch = elementHtml.match(/src=["']([^"']*)["']/i);
          value = srcMatch ? srcMatch[1] : '';
          value = resolveUrl(baseUrl, value);
        } else {
          const attrRegex = new RegExp(`${escapeRegex(attr)}=["']([^"']*)["']`, 'i');
          const attrMatch = elementHtml.match(attrRegex);
          value = attrMatch ? attrMatch[1] : '';
        }

        for (const pattern of replacePatterns) {
          try {
            const regex = new RegExp(pattern, 'g');
            value = value.replace(regex, '');
          } catch {
            value = value.replace(new RegExp(escapeRegex(pattern), 'g'), '');
          }
        }

        return value.trim();
      }
    }

    let elements = selectElements(html, processedRule);
    if (elements.length > 0) {
      const elementIndex = index >= 0 && index < elements.length ? index : 0;
      let text = cleanText(elements[elementIndex]);

      for (const pattern of replacePatterns) {
        try {
          const regex = new RegExp(pattern, 'g');
          text = text.replace(regex, '');
        } catch {
          text = text.replace(new RegExp(escapeRegex(pattern), 'g'), '');
        }
      }

      return text.trim();
    }

    return '';
  };

  // 主逻辑
  try {
    const chapters: ParsedChapterItem[] = [];

    const listElements = selectElements(params.html, params.listRule);

    let order = 0;
    for (const elementHtml of listElements) {
      const title = extractValue(elementHtml, params.nameRule, params.baseUrl);
      let url = extractValue(elementHtml, params.urlRule, params.baseUrl);

      if (url && !url.startsWith('http')) {
        url = resolveUrl(params.baseUrl, url);
      }

      const isVip = /vip|收费|会员|付费/i.test(title || '');

      if (title && url) {
        chapters.push({
          title: title,
          url: url,
          isVip: isVip,
          order: order++
        });
      }
    }

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
