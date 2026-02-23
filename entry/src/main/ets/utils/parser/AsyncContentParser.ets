/**
 * AsyncContentParser - 异步内容解析器
 * 使用 TaskPool 将内容解析任务移至子线程
 */

import { taskpool } from '@kit.ArkTS';
import { Logger } from '../performance/Logger';

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

interface ReplaceRuleItem {
  from: string;
  to: string;
}

interface ReplaceConfig {
  removeTags?: string[];
  replace?: ReplaceRuleItem[];
  removeHtmlTags?: boolean;
}

interface MatchedRange {
  start: number;
  end: number;
}

@Concurrent
function parseContentInWorker(params: ContentParseParams): ContentParseResult {
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

    result = result.replace(/&#(\d+);/g, (_match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });

    return result;
  };

  interface RegexMatchResult {
    index: number;
    match: string;
    groups: string[];
  }

  const convertMatchResult = (match: RegExpExecArray): RegexMatchResult => {
    return {
      index: match.index!,
      match: match[0],
      groups: Array.from(match)
    };
  };

  const convertMatchAllResult = (match: RegExpMatchArray): RegexMatchResult => {
    return {
      index: match.index!,
      match: match[0],
      groups: Array.from(match)
    };
  };

  const extractNestedElement = (html: string, matchResult: RegexMatchResult, tagName: string): string => {
    const startIndex = matchResult.index;
    const tagEndIndex = startIndex + matchResult.match.length;
    let depth = 1;
    let currentIndex = tagEndIndex;
    const openTagRegex = new RegExp(`<${tagName}[^>]*>`, 'gi');
    const closeTagRegex = new RegExp(`<\\/${tagName}>`, 'gi');

    while (currentIndex < html.length && depth > 0) {
      openTagRegex.lastIndex = currentIndex;
      closeTagRegex.lastIndex = currentIndex;
      const nextOpen = openTagRegex.exec(html);
      const nextClose = closeTagRegex.exec(html);
      const nextOpenIndex = nextOpen ? nextOpen.index : -1;
      const nextCloseIndex = nextClose ? nextClose.index : -1;

      if (nextCloseIndex === -1) {
        break;
      }

      if (nextOpenIndex !== -1 && nextOpenIndex < nextCloseIndex) {
        depth++;
        currentIndex = nextOpenIndex + (nextOpen ? nextOpen[0].length : 0);
      } else {
        depth--;
        if (depth === 0) {
          return html.substring(startIndex, nextCloseIndex + (nextClose ? nextClose[0].length : 0));
        }
        currentIndex = nextCloseIndex + (nextClose ? nextClose[0].length : 0);
      }
    }

    return html.substring(startIndex);
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

    const matchedRanges: MatchedRange[] = [];

    const createMatchedRange = (start: number, end: number): MatchedRange => {
      const range: MatchedRange = {
        start: start,
        end: end
      };
      return range;
    };

    const isInsideExistingMatch = (start: number, end: number): boolean => {
      for (const range of matchedRanges) {
        if (start >= range.start && end <= range.end) {
          return true;
        }
      }
      return false;
    };

    if (processedSelector.startsWith('.')) {
      const className = processedSelector.substring(1).split(/[.\s#\[]/)[0];
      const startRegex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*class=["'][^"']*\\b${escapeRegex(className)}\\b[^"']*["'][^>]*>`,
        'gi'
      );
      const matches = Array.from(html.matchAll(startRegex));
      for (const match of matches) {
        const tagName = match[1] ?? '';
        const matchStart = match.index ?? 0;
        const elementHtml = extractNestedElement(html, convertMatchAllResult(match), tagName);
        const matchEnd = matchStart + elementHtml.length;

        if (!isInsideExistingMatch(matchStart, matchEnd)) {
          elements.push(elementHtml);
          matchedRanges.push(createMatchedRange(matchStart, matchEnd));
        }
      }
    } else if (processedSelector.startsWith('#')) {
      const id = processedSelector.substring(1).split(/[.\s#\[]/)[0];
      const startRegex = new RegExp(
        `<([a-zA-Z][a-zA-Z0-9]*)[^>]*\\bid\\s*=\\s*["']${escapeRegex(id)}["'][^>]*>`,
        'i'
      );
      const startMatch = startRegex.exec(html);
      if (startMatch && startMatch[1]) {
        const tagName: string = startMatch[1];
        const elementHtml = extractNestedElement(html, convertMatchResult(startMatch), tagName);
        elements.push(elementHtml);
      }
    } else {
      const tagName = processedSelector.split(/[.\s#\[]/)[0];
      if (tagName) {
        const startRegex = new RegExp(
          `<${tagName}[^>]*>`,
          'gi'
        );
        const matches = Array.from(html.matchAll(startRegex));
        for (const match of matches) {
          const matchStart = match.index ?? 0;
          const elementHtml = extractNestedElement(html, convertMatchAllResult(match), tagName);
          const matchEnd = matchStart + elementHtml.length;

          if (!isInsideExistingMatch(matchStart, matchEnd)) {
            elements.push(elementHtml);
            matchedRanges.push(createMatchedRange(matchStart, matchEnd));
          }
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

  // 本地辅助函数 - extractAllText
  const extractAllText = (html: string): string => {
    if (!html) return '';

    let text = html;

    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<\/p>/gi, '\n');
    text = text.replace(/<\/div>/gi, '\n');
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    text = text.replace(/<!--[\s\S]*?-->/g, '');
    text = text.replace(/<[^>]+>/g, '');

    text = decodeHtmlEntities(text);

    text = text.replace(/\n\s*\n+/g, '\n\n');
    text = text.replace(/[ \t]+/g, ' ');

    return text.trim();
  };

  // 本地辅助函数 - extractInnerHtml
  const extractInnerHtml = (html: string): string => {
    if (!html) return '';

    const match = html.match(/^[^>]*>([\s\S]*)<[^>]*>$/);
    if (match) {
      return decodeHtmlEntities(match[1].trim());
    }

    return decodeHtmlEntities(html);
  };

  // 本地辅助函数 - extractContent
  const extractContent = (html: string, rule: string): string => {
    if (!html || !rule) return '';

    let processedRule = rule.trim();

    if (processedRule.startsWith('@css:')) {
      processedRule = processedRule.substring(5).trim();
    }

    if (processedRule.includes('||')) {
      const orRules = processedRule.split('||').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
      for (const orRule of orRules) {
        const result = extractContent(html, orRule);
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
        if (attr === 'text' || attr === 'text()' || attr === 'textNodes') {
          value = extractAllText(elementHtml);
        } else if (attr === 'html' || attr === 'innerHTML') {
          value = extractInnerHtml(elementHtml);
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
      let text = extractAllText(elements[elementIndex]);

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

  // 本地辅助函数 - purifyContent
  const purifyContent = (content: string, replaceRule?: string): string => {
    if (!content) return '';

    let purified = content;

    purified = purified.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    purified = purified.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    purified = purified.replace(/<!--[\s\S]*?-->/g, '');
    purified = purified.replace(/<[^>]+>/g, '');

    if (replaceRule) {
      try {
        const config: ReplaceConfig = JSON.parse(replaceRule) as ReplaceConfig;

        if (config.removeTags && Array.isArray(config.removeTags)) {
          for (const tag of config.removeTags) {
            const regex = new RegExp(`<${tag}[^>]*>[\\s\\S]*?<\\/${tag}>`, 'gi');
            purified = purified.replace(regex, '');
          }
        }

        if (config.replace && Array.isArray(config.replace)) {
          for (const item of config.replace) {
            if (item.from && item.to !== undefined) {
              try {
                const regex = new RegExp(item.from, 'g');
                purified = purified.replace(regex, item.to);
              } catch {
                purified = purified.replace(new RegExp(escapeRegex(item.from), 'g'), item.to);
              }
            }
          }
        }

        if (config.removeHtmlTags) {
          purified = purified.replace(/<[^>]+>/g, '');
        }
      } catch {
        // ignore
      }
    }

    purified = purified.replace(/&nbsp;/g, ' ');
    purified = purified.replace(/&amp;/g, '&');
    purified = purified.replace(/&lt;/g, '<');
    purified = purified.replace(/&gt;/g, '>');
    purified = purified.replace(/&quot;/g, '"');
    purified = purified.replace(/&#(\d+);/g, (_match: string, dec: string) => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    purified = purified.replace(/\n{3,}/g, '\n\n');
    purified = purified.replace(/[ \t]+/g, ' ');
    purified = purified.trim();

    return purified;
  };

  try {
    let content = extractContent(params.html, params.contentRule);

    content = purifyContent(content, params.replaceRule);

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
