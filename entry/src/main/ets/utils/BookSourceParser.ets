/**
 * 书源解析器 - 支持多种格式的书源导入
 * 支持格式：JSON、XML、TXT格式的书源定义
 */

import { BookSource, SearchRule, FindRule, ChapterRule, ContentRule } from '../models/BookSource';
import { Logger } from './Logger';

/**
 * 阅读APP书源规则对象
 */
interface RuleObject {
  bookList?: string;
  name?: string;
  author?: string;
  cover?: string;
  intro?: string;
  bookUrl?: string;
  nextUrl?: string;
  chapterList?: string;
  chapterName?: string;
  chapterUrl?: string;
  content?: string;
  replaceRule?: string;
}

/**
 * AstroRead书源数据结构
 */
interface AstroReadSourceData {
  bookSourceName?: string;
  bookSourceUrl?: string;
  bookSourceGroup?: string;
  bookSourceComment?: string;
  searchUrl?: string;
  exploreUrl?: string;
  enabled?: boolean;
  enabledExplore?: boolean;
  weight?: number;
  customOrder?: number;
  lastUpdateTime?: number;
  respondTime?: number;
  ruleSearch?: RuleObject;
  ruleExplore?: RuleObject;
  ruleBookInfo?: RuleObject;
  ruleToc?: RuleObject;
  ruleContent?: RuleObject;
  header?: string;
  concurrentRate?: string;
  loginUrl?: string;
  loginUi?: string;
  jsLib?: string;
}

class BookSourceParser {

  private TAG: string = 'BookSourceParser';
  
  /**
   * 解析书源内容
   * @param content 书源内容
   * @param format 格式类型：json | xml | txt
   * @returns 解析后的书源数组
   */
  parseSources(content: string, format: string): Array<BookSource> {
    try {
      Logger.debug(this.TAG, `开始解析书源，格式：${format}`);
      
      switch (format.toLowerCase()) {
        case 'json':
          return this.parseJsonSources(content);
        case 'xml':
          return this.parseXmlSources(content);
        case 'txt':
          return this.parseTxtSources(content);
        default:
          Logger.error(this.TAG, `不支持的书源格式：${format}`);
          return [];
      }
    } catch (error) {
      Logger.error(this.TAG, `解析书源失败：${JSON.stringify(error)}`);
      return [];
    }
  }
  
  /**
   * 解析JSON格式书源
   */
  private parseJsonSources(content: string): Array<BookSource> {
    try {
      const sourcesData = JSON.parse(content) as AstroReadSourceData | AstroReadSourceData[];
      const sources: Array<BookSource> = [];
      
      // 处理数组格式
      if (Array.isArray(sourcesData)) {
        for (const sourceData of sourcesData) {
          const source = this.buildBookSourceFromAstroRead(sourceData);
          if (source) {
            sources.push(source);
          }
        }
      } else if (typeof sourcesData === 'object') {
        // 处理单个书源对象
        const source = this.buildBookSourceFromAstroRead(sourcesData);
        if (source) {
          sources.push(source);
        }
      }
      
      Logger.debug(this.TAG, `JSON解析完成，共解析${sources.length}个书源`);
      return sources;
    } catch (error) {
      Logger.error(this.TAG, `JSON解析失败：${JSON.stringify(error)}`);
      return [];
    }
  }
  
  /**
   * 从阅读APP格式构建书源对象
   */
  private buildBookSourceFromAstroRead(data: AstroReadSourceData): BookSource | null {
    try {
      const name = data.bookSourceName || '';
      let url = data.bookSourceUrl || '';
      
      if (!name || !url) {
        Logger.warn(this.TAG, '书源缺少必要字段：bookSourceName或bookSourceUrl');
        return null;
      }
      
      if (url.includes('##')) {
        url = url.split('##')[0];
      }
      
      // 构建搜索规则
      const searchRule: SearchRule = this.buildSearchRuleFromAstroRead(data.ruleSearch);
      
      // 构建章节规则
      const chapterRule: ChapterRule = this.buildChapterRuleFromAstroRead(data.ruleToc);
      
      // 构建内容规则
      const contentRule: ContentRule = this.buildContentRuleFromAstroRead(data.ruleContent);
      
      // 构建发现规则
      const findRule: FindRule | undefined = this.buildFindRuleFromAstroRead(data.ruleExplore, data.exploreUrl);
      
      const source: BookSource = {
        id: '',
        name: name,
        url: url,
        enabled: data.enabled !== false,
        header: data.header || undefined,
        searchUrl: data.searchUrl || '',
        searchRule: searchRule,
        findRule: findRule,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: this.detectRuleType(data.ruleSearch, data.ruleToc, data.ruleContent),
        sort: data.customOrder || data.weight || 1,
        lastUpdateTime: data.lastUpdateTime || Date.now(),
        addTime: Date.now()
      };
      
      // 验证书源有效性 - 放宽验证，允许非标准URL
      if (!source.name || source.name.trim().length === 0) {
        return null;
      }
      
      return source;
    } catch (error) {
      Logger.error(this.TAG, `构建书源对象失败：${JSON.stringify(error)}`);
      return null;
    }
  }
  
  /**
   * 从阅读APP规则构建搜索规则
   */
  private buildSearchRuleFromAstroRead(rule?: RuleObject): SearchRule {
    if (!rule) {
      return {
        bookList: '',
        name: '',
        author: '',
        cover: undefined,
        intro: undefined,
        bookUrl: '',
        nextUrl: undefined
      };
    }
    
    return {
      bookList: rule.bookList || '',
      name: rule.name || '',
      author: rule.author || '',
      cover: rule.cover || undefined,
      intro: rule.intro || undefined,
      bookUrl: rule.bookUrl || '',
      nextUrl: rule.nextUrl || undefined
    };
  }
  
  /**
   * 从阅读APP规则构建章节规则
   */
  private buildChapterRuleFromAstroRead(rule?: RuleObject): ChapterRule {
    if (!rule) {
      return {
        chapterList: '',
        chapterName: '',
        chapterUrl: '',
        nextUrl: undefined
      };
    }
    
    return {
      chapterList: rule.chapterList || rule.bookList || '',
      chapterName: rule.chapterName || rule.name || '',
      chapterUrl: rule.chapterUrl || rule.bookUrl || '',
      nextUrl: rule.nextUrl || undefined
    };
  }
  
  /**
   * 从阅读APP规则构建内容规则
   */
  private buildContentRuleFromAstroRead(rule?: RuleObject): ContentRule {
    if (!rule) {
      return {
        content: '',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      };
    }
    
    return {
      content: rule.content || '',
      nextUrl: rule.nextUrl || undefined,
      prevUrl: undefined,
      replaceRule: rule.replaceRule || undefined
    };
  }
  
  /**
   * 从阅读APP规则构建发现规则
   */
  private buildFindRuleFromAstroRead(rule?: RuleObject, exploreUrl?: string): FindRule | undefined {
    if (!rule && !exploreUrl) {
      return undefined;
    }
    
    return {
      url: exploreUrl || '',
      bookList: rule?.bookList || '',
      name: rule?.name || '',
      author: rule?.author || '',
      cover: rule?.cover || undefined,
      intro: rule?.intro || undefined,
      bookUrl: rule?.bookUrl || ''
    };
  }
  
  
  /**
   * 解析XML格式书源
   */
  private parseXmlSources(content: string): Array<BookSource> {
    try {
      // 简化版XML解析，实际项目中可使用DOMParser
      const sources: Array<BookSource> = [];
      
      // 提取书源信息
      const sourceMatches = content.match(/<source[^>]*>([\s\S]*?)<\/source>/g);
      if (sourceMatches) {
        for (const sourceXml of sourceMatches) {
          const sourceData = this.extractXmlData(sourceXml);
          const source = this.buildBookSource(sourceData);
          if (source) {
            sources.push(source);
          }
        }
      }
      
      Logger.debug(this.TAG, `XML解析完成，共解析${sources.length}个书源`);
      return sources;
    } catch (error) {
      Logger.error(this.TAG, `XML解析失败：${JSON.stringify(error)}`);
      return [];
    }
  }
  
  /**
   * 解析TXT格式书源
   */
  private parseTxtSources(content: string): Array<BookSource> {
    try {
      const sources: Array<BookSource> = [];
      const lines = content.split('\n');
      
      let currentSource: Record<string, string> = {};
      for (const line of lines) {
        const trimmedLine = line.trim();
        if (!trimmedLine) continue;
        
        if (trimmedLine === '===' || trimmedLine === '---') {
          // 书源分隔符
          if (Object.keys(currentSource).length > 0) {
            const source = this.buildBookSource(currentSource);
            if (source) {
              sources.push(source);
            }
            currentSource = {};
          }
        } else {
          // 解析键值对
          const colonIndex = trimmedLine.indexOf(':');
          if (colonIndex > 0) {
            const key = trimmedLine.substring(0, colonIndex).trim();
            const value = trimmedLine.substring(colonIndex + 1).trim();
            currentSource[key] = value;
          }
        }
      }
      
      // 处理最后一个书源
      if (Object.keys(currentSource).length > 0) {
        const source = this.buildBookSource(currentSource);
        if (source) {
          sources.push(source);
        }
      }
      
      Logger.debug(this.TAG, `TXT解析完成，共解析${sources.length}个书源`);
      return sources;
    } catch (error) {
      Logger.error(this.TAG, `TXT解析失败：${JSON.stringify(error)}`);
      return [];
    }
  }
  
  /**
   * 从XML中提取数据
   */
  private extractXmlData(xml: string): Record<string, string> {
    const data: Record<string, string> = {};
    
    // 提取属性
    const attrMatches = xml.match(/\w+="[^"]*"/g);
    if (attrMatches) {
      for (const attr of attrMatches) {
        const keyValue = attr.split('=');
        if (keyValue.length === 2) {
          const key = keyValue[0];
          const value = keyValue[1].replace(/"/g, '');
          data[key] = value;
        }
      }
    }
    
    // 提取元素内容
    const elementMatches = xml.match(/<(\w+)>([^<]*)<\/\1>/g);
    if (elementMatches) {
      for (const element of elementMatches) {
        const match = element.match(/<(\w+)>([^<]*)<\/\1>/);
        if (match) {
          data[match[1]] = match[2];
        }
      }
    }
    
    return data;
  }
  
  /**
   * 构建书源对象
   */
  private buildBookSource(sourceData: Record<string, string>): BookSource | null {
    try {
      const name = sourceData['name'] || sourceData['bookSourceName'] || '';
      const url = sourceData['url'] || sourceData['bookSourceUrl'] || '';
      
      if (!name || !url) {
        Logger.warn(this.TAG, '书源缺少必要字段：name或url');
        return null;
      }
      
      const searchRule: SearchRule = this.buildSearchRule(sourceData);
      const chapterRule: ChapterRule = this.buildChapterRule(sourceData);
      const contentRule: ContentRule = this.buildContentRule(sourceData);
      
      const source: BookSource = {
        id: '', // 将在ViewModel中生成
        name: name,
        url: url,
        enabled: sourceData['enabled'] !== 'false',
        header: sourceData['header'] || sourceData['headers'] || undefined,
        searchUrl: sourceData['searchUrl'] || sourceData['search_url'] || '',
        searchRule: searchRule,
        findRule: this.buildFindRule(sourceData),
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: 'xpath', // 默认使用xpath类型
        sort: parseInt(sourceData['weight'] || sourceData['sort'] || '1'),
        lastUpdateTime: parseInt(sourceData['lastUpdateTime'] || Date.now().toString()),
        addTime: Date.now()
      };
      
      // 验证书源有效性
      if (!this.validateSource(source)) {
        Logger.warn(this.TAG, `书源验证失败：${source.name}`);
        return null;
      }
      
      return source;
    } catch (error) {
      Logger.error(this.TAG, `构建书源对象失败：${JSON.stringify(error)}`);
      return null;
    }
  }
  
  /**
   * 构建搜索规则
   */
  private buildSearchRule(sourceData: Record<string, string>): SearchRule {
    const rule: SearchRule = {
      bookList: sourceData['bookList'] || sourceData['search_bookList'] || '',
      name: sourceData['search_name'] || sourceData['bookName'] || '',
      author: sourceData['search_author'] || sourceData['author'] || '',
      cover: sourceData['search_cover'] || sourceData['cover'] || undefined,
      intro: sourceData['search_intro'] || sourceData['intro'] || undefined,
      bookUrl: sourceData['search_bookUrl'] || sourceData['bookUrl'] || '',
      nextUrl: sourceData['search_nextUrl'] || sourceData['nextUrl'] || undefined
    };
    return rule;
  }
  
  /**
   * 构建发现规则
   */
  private buildFindRule(sourceData: Record<string, string>): FindRule | undefined {
    const url = sourceData['find_url'] || sourceData['findUrl'] || '';
    if (!url) {
      return undefined;
    }
    
    const rule: FindRule = {
      url: url,
      bookList: sourceData['find_bookList'] || sourceData['bookList'] || '',
      name: sourceData['find_name'] || sourceData['bookName'] || '',
      author: sourceData['find_author'] || sourceData['author'] || '',
      cover: sourceData['find_cover'] || sourceData['cover'] || undefined,
      intro: sourceData['find_intro'] || sourceData['intro'] || undefined,
      bookUrl: sourceData['find_bookUrl'] || sourceData['bookUrl'] || ''
    };
    return rule;
  }
  
  /**
   * 构建章节规则
   */
  private buildChapterRule(sourceData: Record<string, string>): ChapterRule {
    const rule: ChapterRule = {
      chapterList: sourceData['chapterList'] || sourceData['toc_chapterList'] || '',
      chapterName: sourceData['chapterName'] || sourceData['toc_chapterName'] || '',
      chapterUrl: sourceData['chapterUrl'] || sourceData['toc_chapterUrl'] || '',
      nextUrl: sourceData['chapter_nextUrl'] || sourceData['toc_nextUrl'] || undefined
    };
    return rule;
  }
  
  /**
   * 构建内容规则
   */
  private buildContentRule(sourceData: Record<string, string>): ContentRule {
    const rule: ContentRule = {
      content: sourceData['content'] || sourceData['content_content'] || '',
      nextUrl: sourceData['content_nextUrl'] || sourceData['nextUrl'] || undefined,
      prevUrl: sourceData['content_prevUrl'] || sourceData['prevUrl'] || undefined,
      replaceRule: sourceData['content_replaceRule'] || sourceData['replaceRule'] || undefined
    };
    return rule;
  }
  
  /**
   * 验证书源有效性
   */
  private validateSource(source: BookSource): boolean {
    // 基本验证
    if (!source.name || source.name.trim().length === 0) {
      return false;
    }
    
    if (!source.url || !this.isValidUrl(source.url)) {
      return false;
    }
    
    // 搜索URL验证
    if (source.searchUrl && !this.isValidUrl(source.searchUrl)) {
      return false;
    }
    
    return true;
  }
  
  /**
   * URL有效性验证
   */
  private isValidUrl(url: string): boolean {
    try {
      // 简单的URL格式验证
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 检测书源格式
   */
  detectFormat(content: string): string {
    if (!content || content.trim().length === 0) {
      return 'unknown';
    }
    
    const trimmedContent = content.trim();
    
    // JSON检测
    if (trimmedContent.startsWith('{') || trimmedContent.startsWith('[')) {
      try {
        JSON.parse(content);
        return 'json';
      } catch (error) {
        // 不是有效的JSON
      }
    }
    
    // XML检测
    if (trimmedContent.startsWith('<?xml') || trimmedContent.includes('<sources>')) {
      return 'xml';
    }
    
    // TXT检测（默认格式）
    return 'txt';
  }
  /**
   * 检测规则类型
   * 根据规则字符串判断是xpath、jsonpath还是regex
   */
  private detectRuleType(searchRule?: RuleObject, chapterRule?: RuleObject, contentRule?: RuleObject): 'xpath' | 'jsonpath' | 'regex' {
    // 检查所有规则中是否包含jsonpath标识
    const rules = [searchRule, chapterRule, contentRule];
    
    for (const rule of rules) {
      if (!rule) continue;
      
      // 检查规则字符串中的标识
        if (rule.bookList && typeof rule.bookList === 'string') {
          if (rule.bookList.includes('$.') || rule.bookList.includes('$[') || rule.bookList.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.bookList.startsWith('##') || rule.bookList.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.name && typeof rule.name === 'string') {
          if (rule.name.includes('$.') || rule.name.includes('$[') || rule.name.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.name.startsWith('##') || rule.name.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.author && typeof rule.author === 'string') {
          if (rule.author.includes('$.') || rule.author.includes('$[') || rule.author.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.author.startsWith('##') || rule.author.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.cover && typeof rule.cover === 'string') {
          if (rule.cover.includes('$.') || rule.cover.includes('$[') || rule.cover.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.cover.startsWith('##') || rule.cover.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.intro && typeof rule.intro === 'string') {
          if (rule.intro.includes('$.') || rule.intro.includes('$[') || rule.intro.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.intro.startsWith('##') || rule.intro.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.bookUrl && typeof rule.bookUrl === 'string') {
          if (rule.bookUrl.includes('$.') || rule.bookUrl.includes('$[') || rule.bookUrl.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.bookUrl.startsWith('##') || rule.bookUrl.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.nextUrl && typeof rule.nextUrl === 'string') {
          if (rule.nextUrl.includes('$.') || rule.nextUrl.includes('$[') || rule.nextUrl.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.nextUrl.startsWith('##') || rule.nextUrl.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.chapterList && typeof rule.chapterList === 'string') {
          if (rule.chapterList.includes('$.') || rule.chapterList.includes('$[') || rule.chapterList.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.chapterList.startsWith('##') || rule.chapterList.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.chapterName && typeof rule.chapterName === 'string') {
          if (rule.chapterName.includes('$.') || rule.chapterName.includes('$[') || rule.chapterName.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.chapterName.startsWith('##') || rule.chapterName.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.chapterUrl && typeof rule.chapterUrl === 'string') {
          if (rule.chapterUrl.includes('$.') || rule.chapterUrl.includes('$[') || rule.chapterUrl.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.chapterUrl.startsWith('##') || rule.chapterUrl.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.content && typeof rule.content === 'string') {
          if (rule.content.includes('$.') || rule.content.includes('$[') || rule.content.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.content.startsWith('##') || rule.content.startsWith('@regex:')) {
            return 'regex';
          }
        }
        if (rule.replaceRule && typeof rule.replaceRule === 'string') {
          if (rule.replaceRule.includes('$.') || rule.replaceRule.includes('$[') || rule.replaceRule.startsWith('@json:')) {
            return 'jsonpath';
          }
          if (rule.replaceRule.startsWith('##') || rule.replaceRule.startsWith('@regex:')) {
            return 'regex';
          }
        }
    }
    
    // 默认返回xpath
    return 'xpath';
  }
  }

export default new BookSourceParser();
export { BookSourceParser };
