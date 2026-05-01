import { Logger } from '../performance/Logger';
import { CssSelectorParser } from './CssSelectorParser';
import { EntityDecoder } from '../../core/utils/EntityDecoder';
import { SafeRegex, RegexMatchResult } from '../security/SafeRegex';

export interface RuleContext {
  variables: Map<string, string>;
  baseUrl: string;
  html: string;
}

export interface ParsedUrl {
  url: string;
  method: 'GET' | 'POST';
  body?: string;
  headers?: Record<string, string>;
  charset?: string;
}

export class RuleEngine {
  private static readonly TAG = 'RuleEngine';
  private static context: RuleContext = {
    variables: new Map<string, string>(),
    baseUrl: '',
    html: ''
  };

  // 正则模式缓存 - 避免重复净化
  private static regexCache: Map<string, string> = new Map();
  private static readonly MAX_REGEX_CACHE = 200;

  static setContext(context: Partial<RuleContext>): void {
    if (context.variables !== undefined) {
      RuleEngine.context.variables = context.variables;
    }
    if (context.baseUrl !== undefined) {
      RuleEngine.context.baseUrl = context.baseUrl;
    }
    if (context.html !== undefined) {
      RuleEngine.context.html = context.html;
    }
  }

  static getContext(): RuleContext {
    return RuleEngine.context;
  }

  static clearContext(): void {
    RuleEngine.context.variables.clear();
    RuleEngine.context.baseUrl = '';
    RuleEngine.context.html = '';
  }

  static parseRule(rule: string, html: string): string {
    return RuleEngine.parseRuleWithContext(rule, RuleEngine.context, html);
  }

  /**
   * 不可变版本：接受显式上下文，不修改全局状态
   * 推荐新代码使用此方法以避免并发问题
   */
  static parseRuleWithContext(rule: string, context: RuleContext, html?: string): string {
    if (!rule) {
      return '';
    }

    const actualHtml = html || context.html;
    if (!actualHtml) {
      return '';
    }

    let processedRule = rule.trim();

    if (processedRule.startsWith('@js:') || processedRule.startsWith('<js>')) {
      Logger.warn(RuleEngine.TAG, 'JavaScript规则需要通过JSEngine执行');
      return '';
    }

    if (processedRule.startsWith('@json:') || processedRule.includes('$.')) {
      return RuleEngine.parseJsonRule(actualHtml, processedRule);
    }

    if (processedRule.startsWith('##') || processedRule.startsWith('@regex:')) {
      return RuleEngine.parseRegexRule(actualHtml, processedRule);
    }

    if (processedRule.includes('@put:') || processedRule.includes('@get:')) {
      return RuleEngine.parseVariableRule(actualHtml, processedRule);
    }

    if (RuleEngine.isCombinedRule(processedRule)) {
      return RuleEngine.parseCombinedRule(actualHtml, processedRule);
    }

    return CssSelectorParser.extractValue(actualHtml, processedRule);
  }

  /**
   * 判断是否为组合规则（|| 或 && 分隔），排除 CSS 选择器内部误判
   */
  private static isCombinedRule(rule: string): boolean {
    if (!rule.includes('||') && !rule.includes('&&')) {
      return false;
    }
    // 如果以 // 开头，说明是 XPath，直接认为是组合规则
    if (rule.startsWith('//') || rule.startsWith('./')) {
      return true;
    }
    // CSS 选择器如果包含 || 或 &&，可能是误判（如 .class-1||.class-2 实际是或运算）
    if (rule.includes('||')) {
      return true;
    }
    // 对于 &&，需要排除 CSS 类名中的误判，粗略判断：有空格则为组合规则
    if (rule.includes('&&') && rule.includes(' ')) {
      return true;
    }
    return false;
  }

  static parseRuleList(rule: string, html: string): string[] {
    if (!rule || !html) {
      return [];
    }

    RuleEngine.context.html = html;

    let processedRule = rule.trim();

    if (processedRule.startsWith('@json:') || processedRule.includes('$.')) {
      return RuleEngine.parseJsonRuleList(html, processedRule);
    }

    if (processedRule.startsWith('##') || processedRule.startsWith('@regex:')) {
      return RuleEngine.parseRegexRuleList(html, processedRule);
    }

    return CssSelectorParser.selectElements(html, processedRule);
  }

  private static parseCombinedRule(html: string, rule: string): string {
    const orParts = rule.split('||');

    for (const orPart of orParts) {
      const trimmedOrPart = orPart.trim();

      if (trimmedOrPart.includes('&&')) {
        const andParts = trimmedOrPart.split('&&');
        const results: string[] = [];

        for (const andPart of andParts) {
          const trimmedAndPart = andPart.trim();
          let value = '';

          if (trimmedAndPart.includes('##')) {
            value = RuleEngine.parseRuleWithReplace(html, trimmedAndPart);
          } else if (trimmedAndPart.includes('@put:') || trimmedAndPart.includes('@get:')) {
            value = RuleEngine.parseVariableRule(html, trimmedAndPart);
          } else {
            value = CssSelectorParser.extractValue(html, trimmedAndPart);
          }

          if (value) {
            results.push(value);
          }
        }

        if (results.length > 0) {
          return results.join('\n');
        }
      } else {
        let value = '';

        if (trimmedOrPart.includes('##')) {
          value = RuleEngine.parseRuleWithReplace(html, trimmedOrPart);
        } else if (trimmedOrPart.includes('@put:') || trimmedOrPart.includes('@get:')) {
          value = RuleEngine.parseVariableRule(html, trimmedOrPart);
        } else {
          value = CssSelectorParser.extractValue(html, trimmedOrPart);
        }

        if (value) {
          return value;
        }
      }
    }

    return '';
  }

  private static parseRuleWithReplace(html: string, rule: string): string {
    const parts = rule.split('##');
    const extractRule = parts[0].trim();
    const replacePatterns = parts.slice(1);

    let value = CssSelectorParser.extractValue(html, extractRule);

    // 验证输入安全性
    if (!SafeRegex.isInputSafe(value)) {
      Logger.warn(RuleEngine.TAG, '输入内容未通过安全检查');
      return value.trim();
    }

    for (const pattern of replacePatterns) {
      const trimmedPattern = pattern.trim();

      if (trimmedPattern.includes('##')) {
        const patternParts = trimmedPattern.split('##');
        const searchPattern = patternParts[0];
        const replacement = patternParts[1] || '';
        // 使用安全的替换方法
        value = SafeRegex.safeReplace(value, searchPattern, replacement);
      } else {
        // 使用安全的替换方法
        value = SafeRegex.safeReplace(value, trimmedPattern, '');
      }
    }

    return value.trim();
  }

  private static parseVariableRule(html: string, rule: string): string {
    const putMatch = rule.match(/@put:\{([^}]+)\}/);
    if (putMatch) {
      const variableDef = putMatch[1];
      const colonIndex = variableDef.indexOf(':');

      if (colonIndex > 0) {
        const varName = variableDef.substring(0, colonIndex).trim();
        const varRule = variableDef.substring(colonIndex + 1).trim();

        const extractRule = rule.replace(putMatch[0], '').trim() || varRule;
        const value = CssSelectorParser.extractValue(html, extractRule);

        RuleEngine.context.variables.set(varName, value);
        Logger.debug(RuleEngine.TAG, `存储变量: ${varName} = ${value}`);

        return value;
      }
    }

    const getMatch = rule.match(/@get:\{([^}]+)\}/);
    if (getMatch) {
      const varName = getMatch[1].trim();
      const value = RuleEngine.context.variables.get(varName) || '';
      Logger.debug(RuleEngine.TAG, `获取变量: ${varName} = ${value}`);
      return value;
    }

    return CssSelectorParser.extractValue(html, rule);
  }

  private static parseJsonRule(html: string, rule: string): string {
    try {
      let processedRule = rule;
      if (processedRule.startsWith('@json:')) {
        processedRule = processedRule.substring(6).trim();
      }

      let jsonData: string | number | boolean | object | null;
      try {
        jsonData = JSON.parse(html);
      } catch (e) {
        const jsonMatch = html.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          jsonData = JSON.parse(jsonMatch[0]);
        } else {
          return '';
        }
      }

      if (processedRule.includes('##')) {
        const parts = processedRule.split('##');
        const jsonPath = parts[0].trim();
        const replacePatterns = parts.slice(1);

        let value = RuleEngine.extractJsonValue(jsonData, jsonPath);

        // 验证输入安全性
        if (!SafeRegex.isInputSafe(value)) {
          Logger.warn(RuleEngine.TAG, '输入内容未通过安全检查');
          return value.trim();
        }

        for (const pattern of replacePatterns) {
          // 使用安全的替换方法
          value = SafeRegex.safeReplace(value, pattern.trim(), '');
        }

        return value.trim();
      }

      if (processedRule.includes('&&')) {
        const parts = processedRule.split('&&');
        const results: string[] = [];

        for (const part of parts) {
          const value = RuleEngine.extractJsonValue(jsonData, part.trim());
          if (value) {
            results.push(value);
          }
        }

        return results.join('\n');
      }

      return RuleEngine.extractJsonValue(jsonData, processedRule);
    } catch (error) {
      Logger.error(RuleEngine.TAG, `JSON规则解析失败: ${error}`);
      return '';
    }
  }

  private static parseJsonRuleList(html: string, rule: string): string[] {
    try {
      let processedRule = rule;
      if (processedRule.startsWith('@json:')) {
        processedRule = processedRule.substring(6).trim();
      }

      let jsonData: string | number | boolean | object | null;
      try {
        jsonData = JSON.parse(html);
      } catch (e) {
        const jsonMatch = html.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          jsonData = JSON.parse(jsonMatch[0]);
        } else {
          return [];
        }
      }

        const result = RuleEngine.extractJsonValuePath(jsonData as Record<string, string | number | boolean | object | null>, processedRule) as string | number | boolean | object | null | Array<string | number | boolean | object | null>;

      if (Array.isArray(result)) {
        const stringResults: string[] = [];
        for (const item of result as Array<string | number | boolean | object | null>) {
          if (typeof item === 'object') {
            stringResults.push(JSON.stringify(item));
          } else {
            stringResults.push(String(item));
          }
        }
        return stringResults;
      }

      return result ? [String(result)] : [];
    } catch (error) {
      Logger.error(RuleEngine.TAG, `JSON规则列表解析失败: ${error}`);
      return [];
    }
  }

  private static extractJsonValue(data: string | number | boolean | object | null | Array<string | number | boolean | object | null>, path: string): string {
    if (!data || !path) {
      return '';
    }

    let processedPath = path.trim();

    if (processedPath.startsWith('$')) {
      processedPath = processedPath.substring(1);
      if (processedPath.startsWith('.')) {
        processedPath = processedPath.substring(1);
      }
    }

    if (!processedPath || processedPath === '.') {
      if (typeof data === 'string') return data;
      if (typeof data === 'number' || typeof data === 'boolean') return String(data);
      return '';
    }

    const parts = processedPath.split(/[.\[\]]+/).filter((p: string) => p.length > 0);
    let current: string | number | boolean | object | null | Array<string | number | boolean | object | null> = data;

    for (const part of parts) {
      if (current === null || current === undefined) {
        return '';
      }

      if (part === '*') {
        continue;
      }

      const index = parseInt(part, 10);
      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index];
        } else {
          return '';
        }
      } else if (typeof current === 'object' && !Array.isArray(current)) {
        current = (current as Record<string, string | number | boolean | object | null>)[part];
      } else {
        return '';
      }
    }

    if (current === null || current === undefined) {
      return '';
    }

    if (typeof current === 'string') {
      return current;
    }

    if (typeof current === 'number' || typeof current === 'boolean') {
      return String(current);
    }

    return '';
  }

  private static extractJsonValuePath(data: string | number | boolean | object | null | Array<string | number | boolean | object | null>, path: string): string | number | boolean | object | null | Array<string | number | boolean | object | null> {
    if (!data || !path) {
      return null;
    }

    let processedPath = path.trim();

    if (processedPath.startsWith('$')) {
      processedPath = processedPath.substring(1);
      if (processedPath.startsWith('.')) {
        processedPath = processedPath.substring(1);
      }
    }

    if (!processedPath || processedPath === '.') {
      return data;
    }

    const parts = processedPath.split(/[.\[\]]+/).filter((p: string) => p.length > 0);
    let current: string | number | boolean | object | null | Array<string | number | boolean | object | null> = data;

    for (const part of parts) {
      if (current === null || current === undefined) {
        return null;
      }

      if (part === '*') {
        continue;
      }

      const index = parseInt(part, 10);
      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index];
        } else {
          return null;
        }
      } else if (typeof current === 'object' && !Array.isArray(current)) {
        current = (current as Record<string, string | number | boolean | object | null>)[part];
      } else {
        return null;
      }
    }

    return current;
  }

  private static parseRegexRule(html: string, rule: string): string {
    try {
      let pattern = rule;
      if (pattern.startsWith('##')) {
        pattern = pattern.substring(2);
      } else if (pattern.startsWith('@regex:')) {
        pattern = pattern.substring(7);
      }

      if (!SafeRegex.isInputSafe(html)) {
        Logger.warn(RuleEngine.TAG, '输入内容未通过安全检查');
        return '';
      }

      // 使用缓存的净化正则
      const sanitizedPattern = RuleEngine.getCachedRegex(pattern);
      if (!sanitizedPattern) {
        Logger.warn(RuleEngine.TAG, '正则表达式模式为空或无效');
        return '';
      }

      const match: RegExpMatchArray | null = SafeRegex.safeMatch(sanitizedPattern, html, 'gi');

      if (match) {
        return match[1] || match[0];
      }

      return '';
    } catch (error) {
      Logger.error(RuleEngine.TAG, `正则规则解析失败: ${error}`);
      return '';
    }
  }

  private static parseRegexRuleList(html: string, rule: string): string[] {
    try {
      let pattern = rule;
      if (pattern.startsWith('##')) {
        pattern = pattern.substring(2);
      } else if (pattern.startsWith('@regex:')) {
        pattern = pattern.substring(7);
      }

      if (!SafeRegex.isInputSafe(html)) {
        Logger.warn(RuleEngine.TAG, '输入内容未通过安全检查');
        return [];
      }

      const sanitizedPattern = RuleEngine.getCachedRegex(pattern);
      if (!sanitizedPattern) {
        Logger.warn(RuleEngine.TAG, '正则表达式模式为空或无效');
        return [];
      }

      const matches: RegexMatchResult[] = SafeRegex.safeMatchAll(sanitizedPattern, html, 'gi');
      const results: string[] = [];

      for (const match of matches) {
        const group1: string | undefined = match.getGroup(1);
        const group0: string | undefined = match.getGroup(0);
        results.push(group1 !== undefined ? group1 : (group0 !== undefined ? group0 : ''));
      }

      return results;
    } catch (error) {
      Logger.error(RuleEngine.TAG, `正则规则列表解析失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取缓存的正则模式 - 避免重复净化
   */
  private static getCachedRegex(pattern: string): string {
    const cached = RuleEngine.regexCache.get(pattern);
    if (cached !== undefined) {
      return cached;
    }

    const sanitized = SafeRegex.sanitizePattern(pattern);
    if (sanitized) {
      if (RuleEngine.regexCache.size >= RuleEngine.MAX_REGEX_CACHE) {
        const keysIter: IterableIterator<string> = RuleEngine.regexCache.keys();
        const firstEntry: IteratorResult<string> = keysIter.next();
        const firstKey: string | undefined = firstEntry.value;
        if (firstKey !== undefined) {
          RuleEngine.regexCache.delete(firstKey);
        }
      }
      RuleEngine.regexCache.set(pattern, sanitized);
    }

    return sanitized || '';
  }

  static parseSearchUrl(searchUrl: string, keyword: string, page: number, baseUrl: string = ''): ParsedUrl {
    RuleEngine.context.baseUrl = baseUrl;

    if (searchUrl.startsWith('@js:') || searchUrl.startsWith('<js>')) {
      Logger.warn(RuleEngine.TAG, 'JavaScript URL需要通过JSEngine执行');
      return { url: '', method: 'GET' };
    }

    const postMatch = searchUrl.match(/^(.+),\s*(\{[\s\S]+\})$/);
    if (postMatch) {
      const urlPart = postMatch[1].trim();
      const configPart = postMatch[2].trim();

      try {
        const config = JSON.parse(configPart) as Record<string, string | number | boolean | object | null>;

        let url = urlPart
          .replace(/\{\{key\}\}/g, encodeURIComponent(keyword))
          .replace(/\{\{page\}\}/g, String(page))
          .replace(/\{\{\(page-1\)\*10\}\}/g, String((page - 1) * 10));

        let body = '';
        if (typeof config.body === 'string') {
          body = (config.body as string)
            .replace(/\{\{key\}\}/g, encodeURIComponent(keyword))
            .replace(/\{\{page\}\}/g, String(page));
        }

        const headers: Record<string, string> = {};
        if (config.header && typeof config.header === 'object') {
          const headerObj = config.header as Record<string, string>;
          for (const key of Object.keys(headerObj)) {
            headers[key] = headerObj[key];
          }
        }

        if (url && !url.startsWith('http')) {
          url = baseUrl + (url.startsWith('/') ? url : '/' + url);
        }

        return {
          url: url,
          method: 'POST',
          body: body,
          headers: headers,
          charset: config.charset as string | undefined
        };
      } catch (e) {
        Logger.error(RuleEngine.TAG, `解析POST配置失败: ${e}`);
      }
    }

    let finalUrl = searchUrl
      .replace(/\{\{key\}\}/g, encodeURIComponent(keyword))
      .replace(/\{\{page\}\}/g, String(page))
      .replace(/\{\{\(page-1\)\*10\}\}/g, String((page - 1) * 10));

    if (finalUrl && !finalUrl.startsWith('http')) {
      finalUrl = baseUrl + (finalUrl.startsWith('/') ? finalUrl : '/' + finalUrl);
    }

    return {
      url: finalUrl,
      method: 'GET'
    };
  }

  static putVariable(key: string, value: string): void {
    RuleEngine.context.variables.set(key, value);
    Logger.debug(RuleEngine.TAG, `存储变量: ${key} = ${value}`);
  }

  static getVariable(key: string): string {
    return RuleEngine.context.variables.get(key) || '';
  }

  static hasVariable(key: string): boolean {
    return RuleEngine.context.variables.has(key);
  }

  static removeVariable(key: string): void {
    RuleEngine.context.variables.delete(key);
  }

  static escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  static cleanText(text: string): string {
    if (!text) return '';

    return EntityDecoder.cleanHtml(text);
  }
}

export default RuleEngine;
