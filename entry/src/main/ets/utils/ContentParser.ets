import { BookSource, SearchRule, ChapterRule } from '../models/BookSource';

/**
 * 解析后的搜索结果条目
 */
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
  /**
   * 解析搜索结果
   */
  static parseSearchResult(html: string, bookSource: BookSource): ParsedBookItem[] {
    if (!html || !bookSource || !bookSource.searchRule) {
      console.error('解析参数异常：缺少必要的参数');
      return [];
    }
    
    if (typeof html !== 'string') {
      console.error('解析异常：HTML内容必须是字符串类型');
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
          console.error(`不支持的规则类型: ${bookSource.ruleType}`);
          return [];
      }
    } catch (error) {
      console.error('搜索解析异常:', error);
      return [];
    }
  }

  /**
   * 解析章节列表
   */
  static parseChapterList(html: string, bookSource: BookSource): ParsedChapterItem[] {
    if (!html || !bookSource || !bookSource.chapterRule) {
      console.error('解析参数异常：缺少必要的参数');
      return [];
    }
    
    if (typeof html !== 'string') {
      console.error('解析异常：HTML内容必须是字符串类型');
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
          console.error(`不支持的规则类型: ${bookSource.ruleType}`);
          return [];
      }
    } catch (error) {
      console.error('章节解析异常:', error);
      return [];
    }
  }

  /**
   * 解析章节内容
   */
  static parseChapterContent(html: string, bookSource: BookSource): string {
    if (!html || !bookSource || !bookSource.contentRule) {
      console.error('解析参数异常：缺少必要的参数');
      return '';
    }
    
    if (typeof html !== 'string') {
      console.error('解析异常：HTML内容必须是字符串类型');
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

      // 净化内容
      const replaceRuleConfig: ReplaceRuleConfig | undefined = rule.replaceRule ? JSON.parse(rule.replaceRule) : undefined;
      content = ContentParser.purifyContent(content, replaceRuleConfig);
      
      return content;
    } catch (error) {
      console.error('内容解析异常:', error);
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
            console.error('JSON解析失败:', parseError);
            return [];
          }
        } else {
          console.error('无法从HTML中提取JSON数据');
          return [];
        }
      }
      
      // 简单的JSONPath解析（支持简单的路径，如 $.data.list）
      const pathParts = listRule.replace(/^\$\.?/, '').split('.');
      let currentData: object | null | string | number | boolean = jsonData;
      
      for (const part of pathParts) {
        if (currentData !== null && typeof currentData === 'object' && !Array.isArray(currentData)) {
          const currentObj = currentData as Record<string, object | null | string | number | boolean>;
          currentData = currentObj[part];
        } else {
          console.error(`JSONPath路径解析失败: ${part}`);
          return [];
        }
      }
      
      if (!Array.isArray(currentData)) {
        console.error('JSONPath解析结果不是数组类型');
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
      console.error('JSONPath解析失败:', error);
      return [];
    }
  }

  /**
   * 从JSON对象中提取值（支持简单路径）
   */
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
        console.error(`JSON值提取失败: ${part}`);
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
      
      // 使用正则表达式匹配书籍列表（添加DOTALL模式支持）
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
      console.error('正则表达式解析失败:', error);
      return [];
    }
  }

  /**
   * 使用正则表达式解析章节列表
   */
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
      console.error('正则表达式章节解析失败:', error);
      return [];
    }
  }

  /**
   * 使用正则表达式提取内容
   */
  private static extractByRegex(html: string, rule: string): string {
    try {
      const regex = new RegExp(rule.replace(/^\(\?s\)/, ''), rule.startsWith('(?s)') ? 's' : '');
      const match = html.match(regex);
      
      if (match) {
        return ContentParser.cleanText(match[1] || match[0]);
      }
      
      return html;
    } catch (error) {
      console.error('正则表达式提取失败:', error);
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
            console.error('JSON解析失败:', parseError);
            return [];
          }
        } else {
          console.error('无法从HTML中提取JSON数据');
          return [];
        }
      }
      
      // 解析章节列表
      const chapterList = ContentParser.evaluateJsonPath(jsonData, listRule);
      
      if (!Array.isArray(chapterList)) {
        console.error('章节列表不是数组类型');
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
      console.error('JSONPath章节解析失败:', error);
      return [];
    }
  }

  /**
   * 使用JSONPath提取内容
   */
  private static extractByJsonPath(html: string, rule: string): string {
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
            console.error('JSON解析失败:', parseError);
            return html;
          }
        } else {
          console.error('无法从HTML中提取JSON数据');
          return html;
        }
      }
      
      // 使用JSONPath评估规则
      const result = ContentParser.evaluateJsonPath(jsonData, rule);
      
      if (result !== undefined && result !== null) {
        return String(result);
      }
      
      return html;
    } catch (error) {
      console.error('JSONPath提取失败:', error);
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
      console.error('内容净化失败:', error);
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

  // 以下方法需要实现，但当前版本暂时使用正则表达式替代
  private static parseByXPath(_html: string, listRule: string, _rule: SearchRule): ParsedBookItem[] {
    // 简化实现：使用正则表达式替代XPath
    console.warn('XPath解析功能未完全实现，使用正则表达式回退');
    // TODO: 待实现XPath解析功能
    return ContentParser.parseByRegex(_html, listRule, _rule);
  }

  private static parseChaptersByXPath(_html: string, listRule: string, _rule: ChapterRule): ParsedChapterItem[] {
    // 简化实现：使用正则表达式替代XPath
    console.warn('XPath章节解析功能未完全实现，使用正则表达式回退');
    // TODO: 待实现XPath解析功能
    return ContentParser.parseChaptersByRegex(_html, listRule, _rule);
  }

  private static extractByXPath(_html: string, _rule: string): string {
    // 简化实现：使用正则表达式替代XPath
    console.warn('XPath文本提取功能未完全实现');
    // TODO: 待实现XPath解析功能
    return '';
  }

  private static extractElementAttribute(_html: string, _selector: string, _attr: string): string {
    // 简化实现：返回空字符串
    console.warn('XPath属性提取功能未实现');
    // TODO: 待实现XPath属性提取功能
    return '';
  }
}