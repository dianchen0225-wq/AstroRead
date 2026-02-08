/**
 * 书源解析器 - 支持多种格式的书源导入
 * 支持格式：JSON、XML、TXT格式的书源定义
 */

import { BookSource, SearchRule, ChapterRule, ContentRule } from '../models/BookSource';
import { Logger } from './Logger';

interface SourceData {
  name?: string;
  url?: string;
  searchUrl?: string;
  search_url?: string;
  bookUrl?: string;
  book_url?: string;
  chapterUrl?: string;
  chapter_url?: string;
  contentUrl?: string;
  content_url?: string;
  enabled?: boolean;
  weight?: number;
  lastUpdateTime?: number;
  description?: string;
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
      const sourcesData = JSON.parse(content) as SourceData | SourceData[];
      const sources: Array<BookSource> = [];
      
      // 处理数组格式
      if (Array.isArray(sourcesData)) {
        for (const sourceData of sourcesData) {
          const source = this.buildBookSource(this.convertToRecord(sourceData));
          if (source) {
            sources.push(source);
          }
        }
      } else if (typeof sourcesData === 'object') {
        // 处理单个书源对象
        const source = this.buildBookSource(this.convertToRecord(sourcesData));
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
   * 安全获取SourceData字段值
   */
  private getSourceDataValue(sourceData: SourceData, key: string): string | undefined {
    switch (key) {
      case 'name': return sourceData.name?.toString();
      case 'url': return sourceData.url?.toString();
      case 'searchUrl': return sourceData.searchUrl?.toString();
      case 'search_url': return sourceData.search_url?.toString();
      case 'bookUrl': return sourceData.bookUrl?.toString();
      case 'book_url': return sourceData.book_url?.toString();
      case 'chapterUrl': return sourceData.chapterUrl?.toString();
      case 'chapter_url': return sourceData.chapter_url?.toString();
      case 'contentUrl': return sourceData.contentUrl?.toString();
      case 'content_url': return sourceData.content_url?.toString();
      case 'enabled': return sourceData.enabled?.toString();
      case 'weight': return sourceData.weight?.toString();
      case 'lastUpdateTime': return sourceData.lastUpdateTime?.toString();
      case 'description': return sourceData.description?.toString();
      default: return undefined;
    }
  }

  /**
   * 将SourceData转换为Record<string, string>
   */
  private convertToRecord(sourceData: SourceData): Record<string, string> {
    const record: Record<string, string> = {};
    
    // 手动映射所有已知字段
    const fields = ['name', 'url', 'searchUrl', 'search_url', 'bookUrl', 'book_url', 
                   'chapterUrl', 'chapter_url', 'contentUrl', 'content_url', 
                   'enabled', 'weight', 'lastUpdateTime', 'description'];
    
    for (const key of fields) {
      const value = this.getSourceDataValue(sourceData, key);
      if (value !== undefined) {
        record[key] = String(value);
      }
    }
    
    return record;
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
      
      const searchRule: SearchRule = {
        bookList: '',
        name: '',
        author: '',
        cover: undefined,
        intro: undefined,
        bookUrl: '',
        nextUrl: undefined
      };
      
      const chapterRule: ChapterRule = {
        chapterList: '',
        chapterName: '',
        chapterUrl: '',
        nextUrl: undefined
      };
      
      const contentRule: ContentRule = {
        content: '',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      };
      
      const source: BookSource = {
        id: '', // 将在ViewModel中生成
        name: name,
        url: url,
        enabled: sourceData['enabled'] !== 'false',
        header: undefined,
        searchUrl: sourceData['searchUrl'] || sourceData['search_url'] || '',
        searchRule: searchRule,
        findRule: undefined,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: 'jsonpath',
        sort: parseInt(sourceData['weight'] || '1'),
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
}

export default new BookSourceParser();