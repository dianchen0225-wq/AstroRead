/**
 * EnhancedJSEngine - 增强版 JavaScript 引擎
 * 使用 ScriptEngine 解释器，支持完整脚本语法
 * 支持 HarmonyOS 安全沙箱环境
 */

import { Logger } from './Logger';
import { HTMLParser } from './HTMLParser';
import { NetworkAdapter } from './NetworkAdapter';
import { ScriptEngine, ScriptContext } from './ScriptEngine';
import { JSSecurityConfig, SecurityValidationResult } from './JSSecurityConfig';

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

export interface CacheStats {
  size: number;
  maxSize: number;
  oldestEntry: number;
}

type CacheValue = Record<string, string | number | boolean | object | null | undefined>;

export class EnhancedJSEngine {
  private static instance: EnhancedJSEngine | null = null;
  private htmlParser: HTMLParser;
  private networkAdapter: NetworkAdapter;
  private scriptEngine: ScriptEngine;
  private securityConfig: JSSecurityConfig;
  private cache: Map<string, CacheValue> = new Map();
  private readonly TAG = 'EnhancedJSEngine';

  private readonly MAX_CACHE_SIZE = 100;
  private readonly CACHE_TTL = 30 * 60 * 1000;
  private cacheTimestamps: Map<string, number> = new Map();
  private accessOrder: string[] = [];

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.networkAdapter = NetworkAdapter.getInstance();
    this.scriptEngine = ScriptEngine.getInstance();
    this.securityConfig = JSSecurityConfig.getInstance();
  }

  static getInstance(): EnhancedJSEngine {
    if (!EnhancedJSEngine.instance) {
      EnhancedJSEngine.instance = new EnhancedJSEngine();
    }
    return EnhancedJSEngine.instance;
  }

  async executeSearchUrl(script: string, context: JSContext): Promise<string> {
    try {
      const jsCode = script.replace(/^@js:\s*/i, '').trim();

      // 安全验证脚本
      const validation = this.securityConfig.validateScript(jsCode);
      if (!validation.valid) {
        Logger.error(this.TAG, `搜索URL脚本安全验证失败: ${validation.error}`);
        return '';
      }

      // 净化上下文输入
      const sanitizedContext: JSContext = {
        key: context.key ? this.securityConfig.sanitizeInput(context.key) : undefined,
        page: context.page,
        baseUrl: context.baseUrl ? this.securityConfig.sanitizeInput(context.baseUrl) : undefined,
        result: context.result ? this.securityConfig.sanitizeInput(context.result) : undefined
      };

      const contextData: ScriptContext = {
        key: sanitizedContext.key,
        page: sanitizedContext.page,
        baseUrl: sanitizedContext.baseUrl,
        result: sanitizedContext.result
      };

      if (this.isSimpleUrlTemplate(jsCode)) {
        return this.processUrlTemplate(jsCode, sanitizedContext);
      }

      return this.scriptEngine.executeAsString(jsCode, contextData);
    } catch (error) {
      Logger.error(this.TAG, `执行搜索 URL 脚本失败: ${error}`);
      return '';
    }
  }

  private isSimpleUrlTemplate(code: string): boolean {
    return code.includes('{{key}}') || code.includes('{{page}}') ||
    code.includes('searchKey') || code.includes('searchPage');
  }

  private processUrlTemplate(template: string, context: JSContext): string {
    let result = template;

    if (context.key !== undefined) {
      result = result.replace(/\{\{key\}\}/g, encodeURIComponent(context.key));
      result = result.replace(/searchKey/g, encodeURIComponent(context.key));
      result = result.replace(/\bkey\b/g, encodeURIComponent(context.key));
    }

    if (context.page !== undefined) {
      result = result.replace(/\{\{page\}\}/g, String(context.page));
      result = result.replace(/searchPage/g, String(context.page));
      result = result.replace(/\bpage\b/g, String(context.page));
    }

    if (context.baseUrl !== undefined) {
      result = result.replace(/\{\{baseUrl\}\}/g, context.baseUrl);
    }

    return result;
  }

  async executeRule(html: string, rule: string, baseUrl: string = ''): Promise<string> {
    try {
      if (!rule) return html;

      // 净化输入
      const sanitizedHtml = this.securityConfig.sanitizeInput(html);
      const sanitizedBaseUrl = this.securityConfig.sanitizeInput(baseUrl);

      if (rule.startsWith('@js:')) {
        const jsCode = rule.substring(4).trim();
        
        // 安全验证
        const validation = this.securityConfig.validateScript(jsCode);
        if (!validation.valid) {
          Logger.error(this.TAG, `规则脚本安全验证失败: ${validation.error}`);
          return '';
        }
        
        return this.evaluateRuleScript(jsCode, sanitizedHtml, sanitizedBaseUrl);
      }

      if (rule.includes('<js>')) {
        const jsMatch = rule.match(/<js>([\s\S]*?)<\/js>/);
        if (jsMatch) {
          const jsCode = jsMatch[1];
          
          // 安全验证
          const validation = this.securityConfig.validateScript(jsCode);
          if (!validation.valid) {
            Logger.error(this.TAG, `规则脚本安全验证失败: ${validation.error}`);
            return '';
          }
          
          return this.evaluateRuleScript(jsCode, sanitizedHtml, sanitizedBaseUrl);
        }
      }

      if (rule.startsWith('@json:')) {
        const jsonPath = rule.substring(6).trim();
        const results = this.htmlParser.parse(html, jsonPath);
        return results.join('');
      }

      if (rule.startsWith('##')) {
        const pattern = rule.substring(2);
        const results = this.htmlParser.parse(html, '##' + pattern);
        return results.join('');
      }

      const results = this.htmlParser.parse(html, rule);
      return results.join('');
    } catch (error) {
      Logger.error(this.TAG, `执行规则失败: ${error}`);
      return '';
    }
  }

  private evaluateRuleScript(jsCode: string, html: string, baseUrl: string): string {
    const contextData: ScriptContext = {
      result: html,
      baseUrl: baseUrl
    };

    return this.scriptEngine.executeAsString(jsCode, contextData);
  }

  async executeRuleList(html: string, rule: string, baseUrl: string = ''): Promise<string[]> {
    try {
      if (!rule) return [html];

      if (rule.startsWith('@js:')) {
        const result = await this.executeRule(html, rule, baseUrl);
        return [result];
      }

      const results = this.htmlParser.parse(html, rule);
      return results;
    } catch (error) {
      Logger.error(this.TAG, `执行规则列表失败: ${error}`);
      return [];
    }
  }

  getCache(key: string): CacheValue | undefined {
    const timestamp = this.cacheTimestamps.get(key);
    if (timestamp && Date.now() - timestamp > this.CACHE_TTL) {
      this.removeCacheEntry(key);
      return undefined;
    }
    return this.cache.get(key);
  }

  setCache(key: string, value: CacheValue): void {
    this.cleanupExpiredCache();

    if (this.cache.size >= this.MAX_CACHE_SIZE && !this.cache.has(key)) {
      this.evictLRU();
    }

    this.cache.set(key, value);
    this.cacheTimestamps.set(key, Date.now());

    const existingIndex = this.accessOrder.indexOf(key);
    if (existingIndex !== -1) {
      this.accessOrder.splice(existingIndex, 1);
    }
    this.accessOrder.push(key);
  }

  private cleanupExpiredCache(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];

    this.cacheTimestamps.forEach((timestamp: number, key: string) => {
      if (now - timestamp > this.CACHE_TTL) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.removeCacheEntry(key);
    }
  }

  private evictLRU(): void {
    if (this.accessOrder.length === 0) return;

    const lruKey = this.accessOrder.shift();
    if (lruKey) {
      this.removeCacheEntry(lruKey);
      Logger.debug(this.TAG, `LRU淘汰缓存: ${lruKey}`);
    }
  }

  private removeCacheEntry(key: string): void {
    this.cache.delete(key);
    this.cacheTimestamps.delete(key);
    const index = this.accessOrder.indexOf(key);
    if (index !== -1) {
      this.accessOrder.splice(index, 1);
    }
  }

  clearCache(): void {
    this.cache.clear();
    this.cacheTimestamps.clear();
    this.accessOrder = [];
  }

  getCacheStats(): CacheStats {
    let oldestTimestamp = Date.now();
    this.cacheTimestamps.forEach((timestamp: number) => {
      if (timestamp < oldestTimestamp) {
        oldestTimestamp = timestamp;
      }
    });

    const stats: CacheStats = {
      size: this.cache.size,
      maxSize: this.MAX_CACHE_SIZE,
      oldestEntry: this.cache.size > 0 ? Date.now() - oldestTimestamp : 0
    };
    return stats;
  }

  destroy(): void {
    this.clearCache();
    EnhancedJSEngine.instance = null;
  }
}

export default EnhancedJSEngine.getInstance();
