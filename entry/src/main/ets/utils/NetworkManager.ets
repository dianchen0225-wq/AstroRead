import http from '@ohos.net.http';
import { BookSource } from '../models/BookSource';
import { ContentParser, ParsedBookItem, ParsedChapterItem } from './ContentParser';
import { Book } from '../models/Book';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import util from '@ohos.util';
import common from '@ohos.app.ability.common';

/**
 * 网络请求管理器
 */
export class NetworkManager {
  private static instance: NetworkManager | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  /**
   * 设置上下文（需要在Ability中调用）
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 获取单例实例
   */
  static getInstance(): NetworkManager {
    if (NetworkManager.instance === null) {
      NetworkManager.instance = new NetworkManager();
    }
    return NetworkManager.instance;
  }

  /**
   * 申请存储权限
   */
  async requestStoragePermission(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Permissions[] = ['ohos.permission.READ_MEDIA', 'ohos.permission.WRITE_MEDIA'];
    
    if (!this.context) {
      console.error('Context not set, cannot request permissions');
      return false;
    }
    
    try {
      const result = await atManager.requestPermissionsFromUser(this.context, permissions);
      const authResults = result.authResults || [];
      
      if (authResults.length >= 2 && 
          authResults[0] === 0 &&  // PERMISSION_GRANTED
          authResults[1] === 0) {   // PERMISSION_GRANTED
        console.info('存储权限申请成功，可正常存储书源数据');
        return true;
      } else {
        console.info('存储权限申请失败，无法存储书源数据');
        return false;
      }
    } catch (error) {
      console.error(`申请权限失败: ${error}`);
      return false;
    }
  }

  /**
   * 流式获取数据（处理大量数据）
   */
  async getStream(url: string, headers?: Record<string, string>, maxResponseSize?: number): Promise<string> {
    const httpRequest = http.createHttp();
    const requestHeaders: Record<string, string> = headers || {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
    };
    
    const chunks: Uint8Array[] = [];
    let totalSize = 0;
    
    return new Promise<string>((resolve, reject) => {
      // 监听数据接收事件
      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        if (data) {
          try {
            // 检查响应大小限制
            totalSize += data.byteLength;
            if (maxResponseSize && totalSize > maxResponseSize) {
              httpRequest.off('dataReceive');
              httpRequest.off('dataEnd');
              httpRequest.destroy();
              reject(new Error(`响应大小超过限制: ${totalSize}字节 > ${maxResponseSize}字节`));
              return;
            }
            
            chunks.push(new Uint8Array(data));
          } catch (e) {
            console.error('解析流式数据失败:', e);
          }
        }
      });
      
      // 监听数据结束事件
      httpRequest.on('dataEnd', () => {
        try {
          // 合并所有数据块
          const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
          const mergedArray = new Uint8Array(totalLength);
          let offset = 0;
          
          for (const chunk of chunks) {
            mergedArray.set(chunk, offset);
            offset += chunk.length;
          }
          
          // 使用util模块的TextDecoder（使用新API替代废弃的decode方法）
          const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
          const result = decoder.decodeToString(mergedArray, { stream: false });
          
          // 检查响应大小限制
          if (maxResponseSize && result.length > maxResponseSize) {
            httpRequest.off('dataReceive');
            httpRequest.off('dataEnd');
            httpRequest.destroy();
            reject(new Error(`响应大小超过限制: ${result.length}字节 > ${maxResponseSize}字节`));
            return;
          }
          
          httpRequest.off('dataReceive');
          httpRequest.off('dataEnd');
          httpRequest.destroy();
          resolve(result);
        } catch (e) {
          console.error('合并流式数据失败:', e);
          reject(new Error('Failed to merge stream data'));
        }
      });
      
      // 监听错误事件（使用try-catch处理）
      // httpRequest.on('error', (error: BusinessError) => {
      //   console.error(`流式请求失败: ${error.message}`);
      //   httpRequest.off('dataReceive');
      //   httpRequest.off('dataEnd');
      //   httpRequest.destroy();
      //   reject(new Error(`Network error: ${error.message}`));
      // });

      // 发起流式请求
      try {
        httpRequest.requestInStream(
          url,
          {
            method: http.RequestMethod.GET,
            header: requestHeaders,
            connectTimeout: 30000,
            readTimeout: 30000
          }
        ).then((statusCode: number) => {
          console.log(`流式请求完成，状态码: ${statusCode}`);
        }).catch((error: BusinessError) => {
          console.error('流式请求失败:', error);
          httpRequest.off('dataReceive');
          httpRequest.off('dataEnd');
          httpRequest.destroy();
          reject(new Error(`Request failed: ${error.message}`));
        });
      } catch (error) {
        console.error('发起流式请求失败:', error);
        httpRequest.destroy();
        reject(new Error(`Request failed: ${error instanceof Error ? error.message : 'Unknown error'}`));
      }
    });
  }

  /**
   * 发送GET请求
   */
  async get(url: string, headers?: Record<string, string>, maxResponseSize?: number): Promise<string> {
    const httpRequest = http.createHttp();
    
    try {
      const requestHeaders: Record<string, string> = headers || {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
      };
      
      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: requestHeaders,
        connectTimeout: 15000,
        readTimeout: 15000
      };

      const response = await httpRequest.request(url, requestOptions);
      
      // 处理不同的响应码
      if (response.responseCode === 200) {
        const responseText = response.result.toString();
        
        // 检查响应大小限制
        if (maxResponseSize && responseText.length > maxResponseSize) {
          throw new Error(`响应大小超过限制: ${responseText.length}字节 > ${maxResponseSize}字节`);
        }
        
        return responseText;
      } else if (response.responseCode === 301 || response.responseCode === 302) {
        // 处理重定向
        const headersObj = response.header as Record<string, string>;
        let location: string | undefined;
        
        // 检查不同大小写的Location头
        if (headersObj) {
          location = headersObj['Location'] || headersObj['location'] || headersObj['LOCATION'];
        }
        
        if (location) {
          const redirectUrl = this.resolveUrl(url, location);
          console.log(`Redirecting to: ${redirectUrl}`);
          return this.get(redirectUrl, headers, maxResponseSize);
        } else {
          throw new Error(`HTTP ${response.responseCode}: No redirect location`);
        }
      } else {
        throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
      }
    } catch (error) {
      let errorMessage = 'Unknown error';
      if (error instanceof Error) {
        errorMessage = error.message;
      } else if (typeof error === 'object' && error !== null) {
        errorMessage = JSON.stringify(error);
      } else {
        errorMessage = String(error);
      }
      console.error(`Network error details: ${errorMessage}`);
      throw new Error(`Network error: ${errorMessage}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 发送POST请求
   */
  async post(url: string, data: string, headers?: Record<string, string>, maxResponseSize?: number): Promise<string> {
    const httpRequest = http.createHttp();
    
    try {
      const defaultHeaders: Record<string, string> = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
      };
      
      const mergedHeaders: Record<string, string> = {};
      Object.entries(defaultHeaders).forEach((entry) => {
        const key = entry[0];
        const value = entry[1];
        mergedHeaders[key] = value;
      });
      if (headers) {
        Object.entries(headers).forEach((entry) => {
          const key = entry[0];
          const value = entry[1];
          mergedHeaders[key] = value;
        });
      }

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: mergedHeaders,
        extraData: data,
        connectTimeout: 15000,
        readTimeout: 15000
      };

      const response = await httpRequest.request(url, requestOptions);
      
      // 处理不同的响应码
      if (response.responseCode === 200) {
        const responseText = response.result.toString();
        
        // 检查响应大小限制
        if (maxResponseSize && responseText.length > maxResponseSize) {
          throw new Error(`响应大小超过限制: ${responseText.length}字节 > ${maxResponseSize}字节`);
        }
        
        return responseText;
      } else if (response.responseCode === 301 || response.responseCode === 302) {
        // 处理重定向
        const headersObj = response.header as Record<string, string>;
        let location: string | undefined;
        
        // 检查不同大小写的Location头
        if (headersObj) {
          location = headersObj['Location'] || headersObj['location'] || headersObj['LOCATION'];
        }
        
        if (location) {
          const redirectUrl = this.resolveUrl(url, location);
          console.log(`Redirecting to: ${redirectUrl}`);
          return this.get(redirectUrl, headers, maxResponseSize);
        } else {
          throw new Error(`HTTP ${response.responseCode}: No redirect location`);
        }
      } else {
        throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
      }
    } catch (error) {
      let errorMessage = 'Unknown error';
      if (error instanceof Error) {
        errorMessage = error.message;
      } else if (typeof error === 'object' && error !== null) {
        errorMessage = JSON.stringify(error);
      } else {
        errorMessage = String(error);
      }
      console.error(`Network error details: ${errorMessage}`);
      throw new Error(`Network error: ${errorMessage}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 搜索书籍
   */
  async searchBook(bookSource: BookSource, keyword: string): Promise<Book[]> {
    try {
      let searchUrl = bookSource.searchUrl;
      const headers: Record<string, string> | undefined = bookSource.header
        ? (JSON.parse(bookSource.header) as Record<string, string>)
        : undefined;
      
      // 替换搜索关键词
      if (searchUrl.includes('{{key}}')) {
        searchUrl = searchUrl.replace('{{key}}', encodeURIComponent(keyword));
        console.log(`Searching with URL: ${searchUrl}`);
        const html = await this.get(searchUrl, headers);
        
        // 使用规则解析引擎解析搜索结果
        const results: ParsedBookItem[] = ContentParser.parseSearchResult(html, bookSource);
        console.log(`Found ${results.length} results from ${bookSource.name}`);
        
        // 转换为Book对象
        return results.map((item: ParsedBookItem) => this.convertToBook(item, bookSource));
      } else {
        // POST请求方式
        console.log(`Searching with POST to: ${bookSource.url}`);
        const html = await this.post(bookSource.url, `keyword=${encodeURIComponent(keyword)}`, headers);
        
        // 使用规则解析引擎解析搜索结果
        const results: ParsedBookItem[] = ContentParser.parseSearchResult(html, bookSource);
        console.log(`Found ${results.length} results from ${bookSource.name}`);
        
        // 转换为Book对象
        return results.map((item: ParsedBookItem) => this.convertToBook(item, bookSource));
      }
    } catch (error) {
      console.error(`Search failed for ${bookSource.name}:`, error);
      return [];
    }
  }

  /**
   * 将搜索结果转换为Book对象
   */
  private convertToBook(item: ParsedBookItem, bookSource: BookSource): Book {
    const book: Book = {
      id: `book_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      name: item.name || '',
      author: item.author || '',
      cover: item.cover,
      intro: item.intro,
      kind: undefined,
      wordCount: undefined,
      latestChapter: undefined,
      bookSourceId: bookSource.id,
      bookSourceName: bookSource.name,
      bookUrl: item.bookUrl || '',
      lastUpdateTime: Date.now(),
      addTime: Date.now(),
      readProgress: 0,
      lastReadChapter: undefined
    };
    return book;
  }

  /**
   * 获取章节列表
   */
  async getChapterList(bookSource: BookSource, bookUrl: string): Promise<ParsedChapterItem[]> {
    try {
      const headers: Record<string, string> | undefined = bookSource.header
        ? (JSON.parse(bookSource.header) as Record<string, string>)
        : undefined;
      
      // 处理相对URL
      let fullUrl = this.resolveUrl(bookSource.url, bookUrl);
      console.log(`Getting chapter list from: ${fullUrl}`);
      
      const html = await this.get(fullUrl, headers);
      
      // 使用规则解析引擎解析章节列表
      const chapters: ParsedChapterItem[] = ContentParser.parseChapterList(html, bookSource);
      console.log(`Found ${chapters.length} chapters`);
      
      // 处理相对URL并去重
      const uniqueChapters: ParsedChapterItem[] = [];
      const seenUrls = new Set<string>();
      
      chapters.forEach((chapter: ParsedChapterItem) => {
        if (chapter.url) {
          // 处理相对URL
          if (!chapter.url.startsWith('http')) {
            chapter.url = this.resolveUrl(fullUrl, chapter.url);
          }
          
          // 去重
          if (!seenUrls.has(chapter.url)) {
            seenUrls.add(chapter.url);
            uniqueChapters.push(chapter);
          }
        } else if (chapter.title) {
          // 保留没有URL但有标题的章节
          uniqueChapters.push(chapter);
        }
      });
      
      console.log(`Unique chapters: ${uniqueChapters.length}`);
      return uniqueChapters;
    } catch (error) {
      console.error('Failed to get chapter list:', error);
      return [];
    }
  }

  /**
   * 获取章节内容
   */
  async getChapterContent(bookSource: BookSource, chapterUrl: string): Promise<string> {
    try {
      console.log(`Getting chapter content from: ${chapterUrl}`);
      
      const headers: Record<string, string> | undefined = bookSource.header
        ? (JSON.parse(bookSource.header) as Record<string, string>)
        : undefined;
      
      const html = await this.get(chapterUrl, headers);
      
      // 使用规则解析引擎解析并净化内容
      const content = ContentParser.parseChapterContent(html, bookSource);
      
      // 验证内容
      if (!content || content.trim().length === 0) {
        console.warn('Empty chapter content');
        return '本章内容为空';
      }
      
      // 限制内容长度，防止过大
      const maxContentLength = 50000;
      if (content.length > maxContentLength) {
        console.warn(`Chapter content too long, truncating to ${maxContentLength} characters`);
        return content.substring(0, maxContentLength) + '...';
      }
      
      console.log(`Chapter content length: ${content.length} characters`);
      return content;
    } catch (error) {
      console.error('Failed to get chapter content:', error);
      return `获取章节内容失败: ${error instanceof Error ? error.message : '未知错误'}`;
    }
  }

  /**
   * 简单的 URL 解析与拼接，避免依赖全局 URL 类型
   */
  private resolveUrl(baseUrl: string, relative: string): string {
    if (relative.startsWith('http')) {
      return relative;
    }

    if (relative.startsWith('//')) {
      const protocol = baseUrl.startsWith('https') ? 'https:' : 'http:';
      return protocol + relative;
    }

    const baseMatch = baseUrl.match(/^(https?:\/\/[^/]+)(\/.*)?$/);
    const origin = baseMatch ? baseMatch[1] : '';

    if (relative.startsWith('/')) {
      return origin + relative;
    }

    const lastSlashIndex = baseUrl.lastIndexOf('/');
    const basePath = lastSlashIndex >= 0 ? baseUrl.substring(0, lastSlashIndex + 1) : baseUrl;
    return basePath + relative;
  }
}
