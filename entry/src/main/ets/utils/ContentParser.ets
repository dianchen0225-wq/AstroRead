import { BookSource, SearchRule, ChapterRule } from '../models/BookSource';
import { CssSelectorParser } from './CssSelectorParser';
import { Logger } from './Logger';

export interface ParsedBookItem {
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
}

/**
 * 解析后的章节条目
 */
export interface ParsedChapterItem {
  title: string;
  url: string;
  isVip: boolean;
  order: number;
}

/**
 * 替换规则条目
 */
export interface ReplaceRuleItem {
  from: string;
  to: string;
}

/**
 * 替换规则配置
 */
export interface ReplaceRuleConfig {
  removeTags?: string[];
  replace?: ReplaceRuleItem[];
  removeHtmlTags?: boolean;
}

/**
 * 内容解析器 - 用于解析书源规则
 */
export class ContentParser {
  private static readonly TAG = 'ContentParser';

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
      
      switch (bookSource.ruleType) {
        case 'jsonpath':
          return ContentParser.parseByJsonPath(html, rule.bookList, rule);
        case 'xpath':
          return ContentParser.parseByXPath(html, rule.bookList, rule);
        case 'regex':
          return ContentParser.parseByRegex(html, rule.bookList, rule);
        default:
          Logger.error(ContentParser.TAG, `不支持的规则类型: ${bookSource.ruleType}`);
          return [];
      }
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
      
      switch (bookSource.ruleType) {
        case 'jsonpath':
          return ContentParser.parseChaptersByJsonPath(html, rule.chapterList, rule);
        case 'xpath':
          return ContentParser.parseChaptersByXPath(html, rule.chapterList, rule);
        case 'regex':
          return ContentParser.parseChaptersByRegex(html, rule.chapterList, rule);
        default:
          Logger.error(ContentParser.TAG, `不支持的规则类型: ${bookSource.ruleType}`);
          return [];
      }
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
      const rule = bookSource.contentRule;
      let content = '';

      switch (bookSource.ruleType) {
        case 'jsonpath':
          content = ContentParser.extractByJsonPath(html, rule.content);
          break;
        case 'xpath':
          content = ContentParser.extractByXPath(html, rule.content);
          break;
        case 'regex':
          content = ContentParser.extractByRegex(html, rule.content);
          break;
        default:
          content = html;
      }

      const replaceRuleConfig: ReplaceRuleConfig | undefined = rule.replaceRule ? JSON.parse(rule.replaceRule) : undefined;
      content = ContentParser.purifyContent(content, replaceRuleConfig);
      
      return content;
    } catch (error) {
      Logger.error(ContentParser.TAG, `内容解析异常: ${error instanceof Error ? error.message : String(error)}`);
      return html;
    }
  }

  /**
   * 使用JSONPath解析搜索结果
   */
  private static parseByJsonPath(html: string, listRule: string, rule: SearchRule): ParsedBookItem[] {
    try {
      // 尝试解析JSON
      let jsonData: object | null | string | number | boolean;
      try {
        jsonData = JSON.parse(html);
      } catch (e) {
        // 如果不是纯JSON，尝试提取JSON部分（更安全的匹配方式）
        const jsonMatch = html.match(/\{[\s\S]*?\}(?=\s*(?:\{|\}|$))/);
        if (jsonMatch) {
          try {
            jsonData = JSON.parse(jsonMatch[0]);
          } catch (parseError) {
            Logger.error(ContentParser.TAG, `JSON解析失败: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
            return [];
          }
        } else {
          Logger.error(ContentParser.TAG, '无法从HTML中提取JSON数据');
          return [];
        }
      }
      
      const pathParts = listRule.replace(/^\$\.?/, '').split('.');
      let currentData: object | null | string | number | boolean = jsonData;
      
      for (const part of pathParts) {
        if (currentData !== null && typeof currentData === 'object' && !Array.isArray(currentData)) {
          const currentObj = currentData as Record<string, object | null | string | number | boolean>;
          currentData = currentObj[part];
        } else {
          Logger.error(ContentParser.TAG, `JSONPath路径解析失败: ${part}`);
          return [];
        }
      }
      
      if (!Array.isArray(currentData)) {
        Logger.error(ContentParser.TAG, 'JSONPath解析结果不是数组类型');
        return [];
      }
      
      // 提取书籍信息
      const books: ParsedBookItem[] = [];
      const dataArray: Array<object | null | string | number | boolean> = currentData;
      for (let i = 0; i < dataArray.length; i++) {
        const item = dataArray[i];
        if (item === null || typeof item !== 'object' || Array.isArray(item)) {
          continue;
        }
        const sourceObj = item as Record<string, object | null | string | number | boolean>;
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
        }
      }
      
      return books;
    } catch (error) {
      Logger.error(ContentParser.TAG, `JSONPath解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  private static extractJsonValue(obj: Record<string, object | null | string | number | boolean>, path: string): string {
    if (!obj || !path) {
      return '';
    }
    
    const cleanPath = path.replace(/^\$\.?/, '');
    const parts = cleanPath.split('.');
    
    let value: object | null | string | number | boolean = obj;
    for (const part of parts) {
      if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        const valueObj = value as Record<string, object | null | string | number | boolean>;
        value = valueObj[part];
      } else {
        Logger.error(ContentParser.TAG, `JSON值提取失败: ${part}`);
        return '';
      }
    }
    
    if (value === undefined || value === null) {
      return '';
    }
    
    return String(value).trim();
  }

  /**
   * 使用正则表达式解析搜索结果
   */
  private static parseByRegex(html: string, listRule: string, rule: SearchRule): ParsedBookItem[] {
    try {
      const books: ParsedBookItem[] = [];
      
      // 使用正则表达式匹配书籍列表（添加单行模式支持）
      const listRegex = new RegExp(listRule.replace(/^\(\?s\)/, ''), listRule.startsWith('(?s)') ? 'gs' : 'g');
      const listMatches = html.matchAll(listRegex);
      
      for (const match of listMatches) {
        const bookItem: ParsedBookItem = {};
        const matchStr = match[0] || match[1] || '';
        
        // 提取书名
        if (rule.name) {
          const nameRegex = new RegExp(rule.name.replace(/^\(\?s\)/, ''), rule.name.startsWith('(?s)') ? 's' : '');
          const nameMatch = matchStr.match(nameRegex);
          if (nameMatch) {
            bookItem.name = ContentParser.cleanText(nameMatch[1] || nameMatch[0]);
          }
        }
        
        // 提取作者
        if (rule.author) {
          const authorRegex = new RegExp(rule.author.replace(/^\(\?s\)/, ''), rule.author.startsWith('(?s)') ? 's' : '');
          const authorMatch = matchStr.match(authorRegex);
          if (authorMatch) {
            bookItem.author = ContentParser.cleanText(authorMatch[1] || authorMatch[0]);
          }
        }
        
        // 提取封面
        if (rule.cover) {
          const coverRegex = new RegExp(rule.cover.replace(/^\(\?s\)/, ''), rule.cover.startsWith('(?s)') ? 's' : '');
          const coverMatch = matchStr.match(coverRegex);
          if (coverMatch) {
            bookItem.cover = ContentParser.cleanUrl(coverMatch[1] || coverMatch[0]);
          }
        }
        
        // 提取简介
        if (rule.intro) {
          const introRegex = new RegExp(rule.intro.replace(/^\(\?s\)/, ''), rule.intro.startsWith('(?s)') ? 's' : '');
          const introMatch = matchStr.match(introRegex);
          if (introMatch) {
            bookItem.intro = ContentParser.cleanText(introMatch[1] || introMatch[0]);
          }
        }
        
        // 提取书籍URL
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
      
      // 使用正则表达式匹配章节列表
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
        
        // 提取章节名
        if (rule.chapterName) {
          const nameRegex = new RegExp(rule.chapterName.replace(/^\(\?s\)/, ''), rule.chapterName.startsWith('(?s)') ? 's' : '');
          const nameMatch = matchStr.match(nameRegex);
          if (nameMatch) {
            chapterItem.title = ContentParser.cleanText(nameMatch[1] || nameMatch[0]);
          }
        }
        
        // 提取章节URL
        if (rule.chapterUrl) {
          const urlRegex = new RegExp(rule.chapterUrl.replace(/^\(\?s\)/, ''), rule.chapterUrl.startsWith('(?s)') ? 's' : '');
          const urlMatch = matchStr.match(urlRegex);
          if (urlMatch) {
            chapterItem.url = ContentParser.cleanUrl(urlMatch[1] || urlMatch[0]);
          }
        }
        
        // 判断是否VIP章节
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

  private static extractByRegex(html: string, rule: string): string {
    try {
      const regex = new RegExp(rule.replace(/^\(\?s\)/, ''), rule.startsWith('(?s)') ? 's' : '');
      const match = html.match(regex);
      
      if (match) {
        return ContentParser.cleanText(match[1] || match[0]);
      }
      
      return html;
    } catch (error) {
      Logger.error(ContentParser.TAG, `正则表达式提取失败: ${error instanceof Error ? error.message : String(error)}`);
      return html;
    }
  }

  /**
   * 清理文本内容
   */
  private static cleanText(text: string): string {
    if (!text) {
      return '';
    }
    return text
      .replace(/<[^>]+>/g, '')  // 移除HTML标签
      .replace(/&nbsp;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 清理URL
   */
  private static cleanUrl(url: string): string {
    if (!url) {
      return '';
    }
    // 处理相对URL
    if (url.startsWith('//')) {
      return 'https:' + url;
    }
    if (url.startsWith('/')) {
      return url; // 保持相对路径，由调用者处理
    }
    return url.trim();
  }

  /**
   * 使用JSONPath解析章节列表
   */
  private static parseChaptersByJsonPath(html: string, listRule: string, rule: ChapterRule): ParsedChapterItem[] {
    try {
      // 尝试解析JSON
      let jsonData: object | Array<object> | string | number | boolean | null;
      try {
        jsonData = JSON.parse(html);
      } catch (e) {
        // 如果不是纯JSON，尝试提取JSON部分（更安全的匹配方式）
        const jsonMatch = html.match(/\{[\s\S]*?\}(?=\s*(?:\{|\}|$))/);
        if (jsonMatch) {
          try {
            jsonData = JSON.parse(jsonMatch[0]);
          } catch (parseError) {
            Logger.error(ContentParser.TAG, `JSON解析失败: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
            return [];
          }
        } else {
          Logger.error(ContentParser.TAG, '无法从HTML中提取JSON数据');
          return [];
        }
      }
      
      const chapterList = ContentParser.evaluateJsonPath(jsonData, listRule);
      
      if (!Array.isArray(chapterList)) {
        Logger.error(ContentParser.TAG, '章节列表不是数组类型');
        return [];
      }
      
      const chapters: ParsedChapterItem[] = [];
      let order = 0;
      
      for (let i = 0; i < chapterList.length; i++) {
        const item = chapterList[i] as object | string | number | boolean | null | undefined;
        if (!item || typeof item !== 'object') {
          continue;
        }
        
        const chapter: ParsedChapterItem = {
          title: '',
          url: '',
          isVip: false,
          order: 0
        };
        
        // 提取章节名
        if (rule.chapterName) {
          const title = ContentParser.evaluateJsonPath(item, rule.chapterName);
          if (title) {
            chapter.title = String(title).trim();
          }
        }
        
        // 提取章节URL
        if (rule.chapterUrl) {
          const url = ContentParser.evaluateJsonPath(item, rule.chapterUrl);
          if (url) {
            chapter.url = String(url).trim();
          }
        }
        
        // 判断是否VIP章节
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

  private static extractByJsonPath(html: string, rule: string): string {
    try {
      let jsonData: object | Array<object> | string | number | boolean | null;
      try {
        jsonData = JSON.parse(html);
      } catch (e) {
        const jsonMatch = html.match(/\{[\s\S]*?\}(?=\s*(?:\{|\}|$))/);
        if (jsonMatch) {
          try {
            jsonData = JSON.parse(jsonMatch[0]);
          } catch (parseError) {
            Logger.error(ContentParser.TAG, `JSON解析失败: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
            return html;
          }
        } else {
          Logger.error(ContentParser.TAG, '无法从HTML中提取JSON数据');
          return html;
        }
      }
      
      const result = ContentParser.evaluateJsonPath(jsonData, rule);
      
      if (result !== undefined && result !== null) {
        return String(result);
      }
      
      return html;
    } catch (error) {
      Logger.error(ContentParser.TAG, `JSONPath提取失败: ${error instanceof Error ? error.message : String(error)}`);
      return html;
    }
  }

  /**
   * 评估JSONPath表达式
   */
  private static evaluateJsonPath(data: object | Array<object> | string | number | boolean | null, path: string): object | Array<object> | string | number | boolean | null | undefined {
    if (!data || !path) {
      return undefined;
    }
    
    // 移除$前缀
    const cleanPath = path.replace(/^\$\.?/, '');
    
    if (!cleanPath) {
      return data;
    }
    
    // 分割路径
    const parts = cleanPath.split('.');
    let current: object | Array<object> | string | number | boolean | null | undefined = data;
    
    for (const part of parts) {
      // 处理数组索引
      if (part.includes('[')) {
        const arrayPart = part.split('[')[0];
        const indexPart = part.split('[')[1].split(']')[0];
        
        if (arrayPart) {
          if (typeof current === 'object' && current !== null && !Array.isArray(current)) {
            current = (current as Record<string, object | string | number | boolean | null>)[arrayPart];
          } else {
            return undefined;
          }
        }
        
        if (Array.isArray(current)) {
          const index = parseInt(indexPart, 10);
          if (!isNaN(index) && index >= 0 && index < current.length) {
            current = current[index];
          } else {
            return undefined;
          }
        } else {
          return undefined;
        }
      } else {
        // 处理对象属性
        if (typeof current === 'object' && current !== null && !Array.isArray(current)) {
          current = (current as Record<string, object | string | number | boolean | null>)[part];
        } else {
          return undefined;
        }
      }
      
      if (current === undefined) {
        return undefined;
      }
    }
    
    return current;
  }

  /**
   * 净化内容
   */
  static purifyContent(content: string, replaceRule?: ReplaceRuleConfig): string {
    try {
      let purified = content;
      
      // 移除HTML标签
      if (replaceRule?.removeHtmlTags) {
        purified = purified.replace(/<[^>]+>/g, '');
      }
      
      // 移除指定的HTML标签
      if (replaceRule?.removeTags) {
        replaceRule.removeTags.forEach((tag: string) => {
          const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'gi');
          purified = purified.replace(regex, '');
        });
      }
      
      // 应用替换规则
      if (replaceRule?.replace) {
        replaceRule.replace.forEach((rule: ReplaceRuleItem) => {
          const regex = new RegExp(rule.from, 'g');
          purified = purified.replace(regex, rule.to);
        });
      }
      
      // 解码HTML实体
      purified = ContentParser.decodeHtmlEntities(purified);
      
      // 清理多余的空白字符
      purified = purified.replace(/\s+/g, ' ');
      purified = purified.replace(/[\n\r]+/g, '\n');
      
      // 清理重复的标点符号
      purified = purified.replace(/[！!]+/g, '！');
      purified = purified.replace(/[。.]+/g, '。');
      purified = purified.replace(/[,，]+/g, '，');
      purified = purified.replace(/[;；]+/g, '；');
      
      // 清理首尾空白
      purified = purified.trim();
      
      return purified;
    } catch (error) {
      Logger.error(ContentParser.TAG, `内容净化失败: ${error instanceof Error ? error.message : String(error)}`);
      return content;
    }
  }

  /**
   * 解码HTML实体
   */
  static decodeHtmlEntities(text: string): string {
    const entities: Record<string, string> = {
      '&nbsp;': ' ',
      '&lt;': '<',
      '&gt;': '>',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'"
    };

    let decoded = text;
    const entries = Object.entries(entities);
    for (let i = 0; i < entries.length; i++) {
      const entity = entries[i][0];
      const char = entries[i][1];
      decoded = decoded.replace(new RegExp(entity, 'g'), char);
    }

    // 解码数字实体（如 &#160;）
    decoded = decoded.replace(/&#(\d+);/g, (_: string, dec: string): string => {
      return String.fromCharCode(parseInt(dec, 10));
    });

    // 解码十六进制实体（如 &#x0a;）
    decoded = decoded.replace(/&#x([0-9a-fA-F]+);/g, (_: string, hex: string): string => {
      return String.fromCharCode(parseInt(hex, 16));
    });

    return decoded;
  }

  /**
   * 使用XPath/CSS选择器解析搜索结果
   * 支持阅读APP的CSS选择器语法
   */
  private static parseByXPath(html: string, listRule: string, rule: SearchRule): ParsedBookItem[] {
    try {
      const books: ParsedBookItem[] = [];
      
      if (listRule.startsWith('<js>') || listRule.startsWith('@js:')) {
        Logger.warn(ContentParser.TAG, 'JavaScript规则暂不支持，使用正则表达式回退');
        return ContentParser.parseByRegex(html, listRule, rule);
      }
      
      // 提取书籍列表元素
      const listElements = CssSelectorParser.selectElements(html, listRule);
      
      for (const elementHtml of listElements) {
        const bookItem: ParsedBookItem = {};
        
        // 提取书名
        if (rule.name) {
          bookItem.name = CssSelectorParser.extractValue(elementHtml, rule.name);
        }
        
        // 提取作者
        if (rule.author) {
          bookItem.author = CssSelectorParser.extractValue(elementHtml, rule.author);
        }
        
        // 提取封面
        if (rule.cover) {
          bookItem.cover = CssSelectorParser.extractValue(elementHtml, rule.cover);
        }
        
        // 提取简介
        if (rule.intro) {
          bookItem.intro = CssSelectorParser.extractValue(elementHtml, rule.intro);
        }
        
        // 提取书籍URL
        if (rule.bookUrl) {
          bookItem.bookUrl = CssSelectorParser.extractValue(elementHtml, rule.bookUrl);
        }
        
        if (bookItem.name && bookItem.bookUrl) {
          books.push(bookItem);
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
      
      // 提取章节列表元素
      const listElements = CssSelectorParser.selectElements(html, listRule);
      
      let order = 0;
      for (const elementHtml of listElements) {
        const chapterItem: ParsedChapterItem = {
          title: '',
          url: '',
          isVip: false,
          order: 0
        };
        
        // 提取章节名
        if (rule.chapterName) {
          chapterItem.title = CssSelectorParser.extractValue(elementHtml, rule.chapterName);
        }
        
        // 提取章节URL
        if (rule.chapterUrl) {
          chapterItem.url = CssSelectorParser.extractValue(elementHtml, rule.chapterUrl);
        }
        
        // 判断是否VIP章节
        chapterItem.isVip = /vip|收费|会员|付费/i.test(chapterItem.title || '');
        chapterItem.order = order++;
        
        if (chapterItem.title && chapterItem.url) {
          chapters.push(chapterItem);
        }
      }
      
      return chapters;
    } catch (error) {
      Logger.error(ContentParser.TAG, `XPath章节解析失败: ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }
  
  private static extractByXPath(html: string, rule: string): string {
    return CssSelectorParser.extractValue(html, rule);
  }
  
}