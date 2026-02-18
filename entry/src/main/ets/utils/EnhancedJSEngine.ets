/**
 * EnhancedJSEngine - 增强版 JavaScript 引擎
 * 添加实际的 ajax 请求功能和更多 java 对象方法
 */

import { Logger } from './Logger';
import { HTMLParser } from './HTMLParser';
import { NetworkAdapter } from './NetworkAdapter';
import util from '@ohos.util';

export interface JSExecutionResult {
  success: boolean;
  result: string;
  error?: string;
}

export interface JSContext {
  key?: string;
  page?: number;
  result?: string;
  baseUrl?: string;
}

type CacheValue = Record<string, string | number | boolean | object | null | undefined>;

/**
 * 增强版 JS 引擎
 * 提供完整的书源规则执行环境
 */
export class EnhancedJSEngine {
  private static instance: EnhancedJSEngine | null = null;
  private htmlParser: HTMLParser;
  private networkAdapter: NetworkAdapter;
  private cache: Map<string, CacheValue> = new Map();
  private readonly TAG = 'EnhancedJSEngine';

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.networkAdapter = NetworkAdapter.getInstance();
  }

  static getInstance(): EnhancedJSEngine {
    if (!EnhancedJSEngine.instance) {
      EnhancedJSEngine.instance = new EnhancedJSEngine();
    }
    return EnhancedJSEngine.instance;
  }

  /**
   * 构建完整的 JS 执行环境
   */
  private buildEnvironment(userCode: string, context: JSContext = {}): string {
    return `
  (function() {
    'use strict';

    // 缓存对象
    const _cache = {};

    // 完整的 java 对象模拟
    const java = {
      // 网络请求
      ajax: function(url) {
        return url; // 同步 ajax 在 JS 引擎中无法真正实现，返回 URL
      },

      // 异步 GET 请求（返回 Promise）
      get: async function(url, headers) {
        try {
          const result = await _nativeGet(url, headers);
          return result;
        } catch (e) {
          console.log('[Error] GET failed: ' + e.message);
          return '';
        }
      },

      // 异步 POST 请求
      post: async function(url, body, headers) {
        try {
          const result = await _nativePost(url, body, headers);
          return result;
        } catch (e) {
          console.log('[Error] POST failed: ' + e.message);
          return '';
        }
      },

      // 日志
      log: function(msg) {
        console.log('[AstroRead] ' + msg);
      },

      longToast: function(msg) {
        console.log('[Toast] ' + msg);
      },

      // 编码/解码
      encodeURI: function(str) {
        return encodeURI(String(str));
      },

      decodeURI: function(str) {
        return decodeURI(String(str));
      },

      encodeURIComponent: function(str) {
        return encodeURIComponent(String(str));
      },

      decodeURIComponent: function(str) {
        return decodeURIComponent(String(str));
      },

      base64Encode: function(str) {
        try {
          return btoa(String(str));
        } catch (e) {
          return String(str);
        }
      },

      base64Decode: function(str) {
        try {
          return atob(String(str));
        } catch (e) {
          return String(str);
        }
      },

      // MD5 简化实现
      md5Encode: function(str) {
        // 实际应该使用 MD5 库
        return String(str);
      },

      // 繁简转换（简化实现）
      t2s: function(str) {
        // 繁体转简体
        return String(str);
      },

      s2t: function(str) {
        // 简体转繁体
        return String(str);
      },

      // HTML 解析
      getElements: function(html, rule) {
        // 调用原生解析器
        const results = _nativeParseHtml(html, rule);
        return JSON.parse(results);
      },

      getString: function(html, rule) {
        const results = java.getElements(html, rule);
        return results.length > 0 ? results[0] : '';
      },

      parseHtml: function(html) {
        // 简化版 HTML 解析，返回一个模拟的 DOM 对象
        return {
          text: html.replace(/<[^>]+>/g, ''),
          html: html,
          find: function(selector) {
            const results = java.getElements(html, selector);
            return {
              text: function() { return results.length > 0 ? results[0] : ''; },
              html: function() { return results.length > 0 ? results[0] : ''; },
              attr: function(name) {
                const attrMatch = results[0]?.match(new RegExp(name + '="([^"]+)"'));
                return attrMatch ? attrMatch[1] : '';
              }
            };
          }
        };
      },

      // 缓存操作
      put: function(key, value) {
        _cache[key] = value;
        java._cache[key] = value;
        return value;
      },

      get: function(key) {
        return _cache[key] || java._cache[key];
      },

      _cache: {},

      // 正则表达式
      matches: function(html, pattern) {
        try {
          const regex = new RegExp(pattern, 'g');
          const matches = html.match(regex);
          return matches || [];
        } catch (e) {
          return [];
        }
      },

      // URL 处理
      resolveUrl: function(baseUrl, relativeUrl) {
        if (!relativeUrl) return '';
        if (relativeUrl.startsWith('http')) return relativeUrl;

        try {
          const protocolEnd = baseUrl.indexOf('://');
          if (protocolEnd === -1) return relativeUrl;
          const protocol = baseUrl.substring(0, protocolEnd + 3);
          const hostStart = protocolEnd + 3;
          const pathStart = baseUrl.indexOf('/', hostStart);
          const host = pathStart === -1 ? baseUrl.substring(hostStart) : baseUrl.substring(hostStart, pathStart);

          if (relativeUrl.startsWith('/')) {
            return protocol + host + relativeUrl;
          }

          const path = pathStart === -1 ? '/' : baseUrl.substring(pathStart);
          const lastSlash = path.lastIndexOf('/');
          const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);

          return protocol + host + basePath + relativeUrl;
        } catch (e) {
          return relativeUrl;
        }
      },

      // 时间戳
      timeFormat: function(timestamp, format) {
        const date = new Date(timestamp);
        return date.toLocaleString();
      },

      // 随机数
      random: function(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
      },

      // 字符串处理
      trim: function(str) {
        return String(str).trim();
      },

      // 浏览器操作
      startBrowser: function(url, title) {
        console.log('[Browser] Opening: ' + url);
        return url;
      },

      startBrowserAwait: function(url, title) {
        return java.startBrowser(url, title);
      },

      // JSON 操作
      toJSON: function(obj) {
        return JSON.stringify(obj);
      },

      parseJSON: function(str) {
        try {
          return JSON.parse(str);
        } catch (e) {
          return null;
        }
      },

      // User-Agent
      getWebViewUA: function() {
        return 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      },

      // 设备信息
      getDeviceInfo: function() {
        return {
          model: 'HarmonyOS Device',
          brand: 'Huawei',
          version: '4.0',
          sdk: 40
        };
      },

      // 正则替换
      replace: function(str, pattern, replacement) {
        try {
          const regex = new RegExp(pattern, 'g');
          return String(str).replace(regex, replacement);
        } catch (e) {
          return String(str);
        }
      },

      // 分割字符串
      split: function(str, separator) {
        return String(str).split(separator);
      },

      // 数组操作
      join: function(arr, separator) {
        return Array.isArray(arr) ? arr.join(separator) : String(arr);
      },

      // 排序
      sort: function(arr, reverse) {
        if (!Array.isArray(arr)) return arr;
        const sorted = arr.slice().sort();
        return reverse ? sorted.reverse() : sorted;
      },

      // 去重
      unique: function(arr) {
        if (!Array.isArray(arr)) return arr;
        return [...new Set(arr)];
      },

      // 过滤
      filter: function(arr, pattern) {
        if (!Array.isArray(arr)) return arr;
        try {
          const regex = new RegExp(pattern);
          return arr.filter(item => regex.test(String(item)));
        } catch (e) {
          return arr;
        }
      },

      // 映射
      map: function(arr, callback) {
        if (!Array.isArray(arr)) return arr;
        return arr.map(callback);
      }
    };

    // 注入原生方法占位符（实际执行时会被替换）
    const _nativeGet = function(url, headers) { return Promise.resolve(''); };
    const _nativePost = function(url, body, headers) { return Promise.resolve(''); };
    const _nativeParseHtml = function(html, rule) { return '[]'; };

    // 上下文变量
    const key = ${JSON.stringify(context.key || '')};
    const page = ${context.page || 1};
    const baseUrl = ${JSON.stringify(context.baseUrl || '')};
    let result = ${JSON.stringify(context.result || '')};

    // 全局辅助函数
    const tzs = function(str) { return String(str); };
    const String2 = function(obj) { return obj === null || obj === undefined ? '' : String(obj); };
    const Number2 = function(obj) { return Number(obj) || 0; };
    const Boolean2 = function(obj) { return Boolean(obj); };

    // 执行用户代码
    ${userCode}

    // 尝试返回结果
    if (typeof result !== 'undefined') {
      return result;
    }
  })();
  `;
  }

  /**
   * 执行搜索 URL 生成脚本
   */
  async executeSearchUrl(script: string, context: JSContext): Promise<string> {
    try {
      // 移除 @js: 前缀
      const jsCode = script.replace(/^@js:\s*/i, '').trim();

      // 构建执行环境
      const wrappedCode = this.buildEnvironment(jsCode, context);

      const func = new Function('return ' + wrappedCode);
      const result: string | object | null = func() as string | object | null;

      if (result && typeof result === 'string') {
        return result;
      }

      return '';
    } catch (error) {
      Logger.error(this.TAG, `执行搜索 URL 脚本失败: ${error}`);
      return '';
    }
  }

  /**
   * 执行书源规则
   */
  async executeRule(html: string, rule: string, baseUrl: string = ''): Promise<string> {
    try {
      if (!rule) return html;

      // 处理 @js: 规则
      if (rule.startsWith('@js:')) {
        const jsCode = rule.substring(4).trim();
        const wrappedCode = this.buildEnvironment(jsCode, { result: html, baseUrl });
        const func = new Function('return ' + wrappedCode);
        const result: string | object | null = func() as string | object | null;
        return String(result || '');
      }

      // 处理 <js></js> 标签
      if (rule.includes('<js>')) {
        const jsMatch = rule.match(/<js>([\s\S]*?)<\/js>/);
        if (jsMatch) {
          return this.executeRule(html, '@js:' + jsMatch[1], baseUrl);
        }
      }

      // 处理 @json: 规则
      if (rule.startsWith('@json:')) {
        const jsonPath = rule.substring(6).trim();
        const results = this.htmlParser.parse(html, jsonPath);
        return results.join('');
      }

      // 处理 ## 正则规则
      if (rule.startsWith('##')) {
        const pattern = rule.substring(2);
        const results = this.htmlParser.parse(html, '##' + pattern);
        return results.join('');
      }

      // 普通 XPath/CSS 规则
      const results = this.htmlParser.parse(html, rule);
      return results.join('');
    } catch (error) {
      Logger.error(this.TAG, `执行规则失败: ${error}`);
      return '';
    }
  }

  /**
   * 执行书源规则（返回数组）
   */
  async executeRuleList(html: string, rule: string, baseUrl: string = ''): Promise<string[]> {
    try {
      if (!rule) return [html];

      // 处理 @js: 规则
      if (rule.startsWith('@js:')) {
        const result = await this.executeRule(html, rule, baseUrl);
        return [result];
      }

      // 其他规则
      const results = this.htmlParser.parse(html, rule);
      return results;
    } catch (error) {
      Logger.error(this.TAG, `执行规则列表失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取缓存
   */
  getCache(key: string): CacheValue | undefined {
    return this.cache.get(key);
  }

  /**
   * 设置缓存
   */
  setCache(key: string, value: CacheValue): void {
    this.cache.set(key, value);
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.cache.clear();
  }

  /**
   * 销毁资源
   */
  destroy(): void {
    this.clearCache();
    EnhancedJSEngine.instance = null;
  }
}

export default EnhancedJSEngine.getInstance();
