/**
 * EnhancedJSEngine - 增强版 JavaScript 引擎
 * 使用安全表达式解析器，不依赖 eval 或 new Function()
 * 支持 HarmonyOS 安全沙箱环境
 */

import { Logger } from './Logger';
import { HTMLParser } from './HTMLParser';
import { NetworkAdapter } from './NetworkAdapter';
import { SafeExpressionEngine, ExpressionContext } from './SafeExpressionEngine';

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

interface AssignmentResult {
  name: string;
  value: string;
}

export class EnhancedJSEngine {
  private static instance: EnhancedJSEngine | null = null;
  private htmlParser: HTMLParser;
  private networkAdapter: NetworkAdapter;
  private expressionEngine: SafeExpressionEngine;
  private cache: Map<string, CacheValue> = new Map();
  private readonly TAG = 'EnhancedJSEngine';

  private readonly MAX_CACHE_SIZE = 100;
  private readonly CACHE_TTL = 30 * 60 * 1000;
  private cacheTimestamps: Map<string, number> = new Map();
  private accessOrder: string[] = [];

  private constructor() {
    this.htmlParser = HTMLParser.getInstance();
    this.networkAdapter = NetworkAdapter.getInstance();
    this.expressionEngine = SafeExpressionEngine.getInstance();
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

      const contextData: ExpressionContext = {
        key: context.key,
        page: context.page,
        baseUrl: context.baseUrl,
        result: context.result
      };

      if (this.isSimpleUrlTemplate(jsCode)) {
        return this.processUrlTemplate(jsCode, context);
      }

      if (this.isTemplateString(jsCode)) {
        return this.expressionEngine.evaluateAsString(jsCode, contextData);
      }

      if (this.isSimpleExpression(jsCode)) {
        return this.expressionEngine.evaluateAsString(jsCode, contextData);
      }

      return this.evaluateComplexScript(jsCode, context);
    } catch (error) {
      Logger.error(this.TAG, `执行搜索 URL 脚本失败: ${error}`);
      return '';
    }
  }

  private isSimpleUrlTemplate(code: string): boolean {
    return code.includes('{{key}}') || code.includes('{{page}}') ||
    code.includes('searchKey') || code.includes('searchPage');
  }

  private isTemplateString(code: string): boolean {
    return code.includes('{{') && code.includes('}}');
  }

  private isSimpleExpression(code: string): boolean {
    const simplePatterns = [
      /^[a-zA-Z_$][a-zA-Z0-9_$]*$/,
      /^[a-zA-Z_$][a-zA-Z0-9_$]*\s*[+\-*/]\s*('[^']*'|"[^"]*"|\d+|[a-zA-Z_$][a-zA-Z0-9_$]*)$/,
      /^[a-zA-Z_$][a-zA-Z0-9_$]*\([^)]*\)$/,
      /^encodeURI(Component)?\([^)]*\)$/,
      /^decodeURI(Component)?\([^)]*\)$/,
      /^String2?\([^)]*\)$/,
      /^base64(Encode|Decode)\([^)]*\)$/,
      /^replace\([^)]+\)$/,
      /^match\([^)]+\)$/
    ];

    for (const pattern of simplePatterns) {
      if (pattern.test(code.trim())) {
        return true;
      }
    }
    return false;
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

  private evaluateComplexScript(code: string, context: JSContext): string {
    const contextData: ExpressionContext = {
      key: context.key,
      page: context.page,
      baseUrl: context.baseUrl,
      result: context.result
    };

    const lines = code.split(/[;\n]/);
    let lastResult = '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      if (trimmed.startsWith('//')) continue;

      if (trimmed.startsWith('let ') || trimmed.startsWith('const ') || trimmed.startsWith('var ')) {
        const assignment = this.parseAssignment(trimmed);
        if (assignment) {
          const value = this.expressionEngine.evaluate(assignment.value, contextData);
          this.setCacheValue(assignment.name, value);
        }
        continue;
      }

      if (trimmed.includes('=') && !trimmed.includes('==') && !trimmed.includes('===')) {
        const assignment = this.parseAssignment(trimmed);
        if (assignment) {
          const value = this.expressionEngine.evaluate(assignment.value, contextData);
          this.setCacheValue(assignment.name, value);
          lastResult = String(value ?? '');
        }
        continue;
      }

      if (trimmed.startsWith('return ')) {
        const returnExpr = trimmed.substring(7).trim();
        return this.expressionEngine.evaluateAsString(returnExpr, contextData);
      }

      lastResult = this.expressionEngine.evaluateAsString(trimmed, contextData);
    }

    return lastResult;
  }

  private parseAssignment(line: string): AssignmentResult | null {
    const match = line.match(/^(?:let|const|var)?\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/);
    if (match) {
      const result: AssignmentResult = {
        name: match[1],
        value: match[2].trim()
      };
      return result;
    }
    return null;
  }

  private setCacheValue(name: string, value: string | number | boolean | object | null): void {
    const cacheKey = `var_${name}`;

    this.cleanupExpiredCache();

    if (this.cache.size >= this.MAX_CACHE_SIZE && !this.cache.has(cacheKey)) {
      this.evictLRU();
    }

    const cacheData: CacheValue = {};
    cacheData['value'] = value;
    this.cache.set(cacheKey, cacheData);
    this.cacheTimestamps.set(cacheKey, Date.now());

    const existingIndex = this.accessOrder.indexOf(cacheKey);
    if (existingIndex !== -1) {
      this.accessOrder.splice(existingIndex, 1);
    }
    this.accessOrder.push(cacheKey);
  }

  private getCacheValue(name: string): string | number | boolean | object | null {
    const cacheKey = `var_${name}`;

    const timestamp = this.cacheTimestamps.get(cacheKey);
    if (timestamp && Date.now() - timestamp > this.CACHE_TTL) {
      this.removeCacheEntry(cacheKey);
      return null;
    }

    const cached = this.cache.get(cacheKey);
    if (cached) {
      const existingIndex = this.accessOrder.indexOf(cacheKey);
      if (existingIndex !== -1) {
        this.accessOrder.splice(existingIndex, 1);
        this.accessOrder.push(cacheKey);
      }
    }
    return cached?.value ?? null;
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

  async executeRule(html: string, rule: string, baseUrl: string = ''): Promise<string> {
    try {
      if (!rule) return html;

      if (rule.startsWith('@js:')) {
        const jsCode = rule.substring(4).trim();
        return this.evaluateRuleScript(jsCode, html, baseUrl);
      }

      if (rule.includes('<js>')) {
        const jsMatch = rule.match(/<js>([\s\S]*?)<\/js>/);
        if (jsMatch) {
          return this.evaluateRuleScript(jsMatch[1], html, baseUrl);
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
    const contextData: ExpressionContext = {
      result: html,
      baseUrl: baseUrl
    };

    if (this.isSimpleExpression(jsCode)) {
      return this.expressionEngine.evaluateAsString(jsCode, contextData);
    }

    return this.evaluateComplexScript(jsCode, { result: html, baseUrl });
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

  clearCache(): void {
    this.cache.clear();
    this.cacheTimestamps.clear();
    this.accessOrder = [];
  }

  getCacheStats(): { size: number; maxSize: number; oldestEntry: number } {
    let oldestTimestamp = Date.now();
    this.cacheTimestamps.forEach((timestamp: number) => {
      if (timestamp < oldestTimestamp) {
        oldestTimestamp = timestamp;
      }
    });

    return {
      size: this.cache.size,
      maxSize: this.MAX_CACHE_SIZE,
      oldestEntry: this.cache.size > 0 ? Date.now() - oldestTimestamp : 0
    };
  }

  destroy(): void {
    this.clearCache();
    EnhancedJSEngine.instance = null;
  }
}

export default EnhancedJSEngine.getInstance();
