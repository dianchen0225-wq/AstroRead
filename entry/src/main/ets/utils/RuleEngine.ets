import { Logger } from './Logger';
import { CssSelectorParser } from './CssSelectorParser';
import { EntityDecoder } from '../core/utils/EntityDecoder';

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
    if (!rule || !html) {
      return '';
    }

    RuleEngine.context.html = html;

    let processedRule = rule.trim();

    if (processedRule.startsWith('@js:') || processedRule.startsWith('<js>')) {
      Logger.warn(RuleEngine.TAG, 'JavaScript规则需要通过JSEngine执行');
      return '';
    }

    if (processedRule.startsWith('@json:') || processedRule.includes('$.')) {
      return RuleEngine.parseJsonRule(html, processedRule);
    }

    if (processedRule.startsWith('##') || processedRule.startsWith('@regex:')) {
      return RuleEngine.parseRegexRule(html, processedRule);
    }

    if (processedRule.includes('&&') || processedRule.includes('||')) {
      return RuleEngine.parseCombinedRule(html, processedRule);
    }

    if (processedRule.includes('##')) {
      return RuleEngine.parseRuleWithReplace(html, processedRule);
    }

    if (processedRule.includes('@put:') || processedRule.includes('@get:')) {
      return RuleEngine.parseVariableRule(html, processedRule);
    }

    return CssSelectorParser.extractValue(html, processedRule);
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

    for (const pattern of replacePatterns) {
      const trimmedPattern = pattern.trim();

      if (trimmedPattern.includes('##')) {
        const patternParts = trimmedPattern.split('##');
        const searchPattern = patternParts[0];
        const replacement = patternParts[1] || '';
        try {
          const regex = new RegExp(searchPattern, 'g');
          value = value.replace(regex, replacement);
        } catch (e) {
          value = value.replace(new RegExp(RuleEngine.escapeRegex(searchPattern), 'g'), replacement);
        }
      } else {
        try {
          const regex = new RegExp(trimmedPattern, 'g');
          value = value.replace(regex, '');
        } catch (e) {
          value = value.replace(new RegExp(RuleEngine.escapeRegex(trimmedPattern), 'g'), '');
        }
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

        for (const pattern of replacePatterns) {
          try {
            const regex = new RegExp(pattern.trim(), 'g');
            value = value.replace(regex, '');
          } catch (e) {
            value = value.replace(new RegExp(RuleEngine.escapeRegex(pattern.trim()), 'g'), '');
          }
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

      const regex = new RegExp(pattern, 'gi');
      const match = html.match(regex);

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

      const results: string[] = [];
      const regex = new RegExp(pattern, 'gi');
      let match: RegExpExecArray | null;

      while ((match = regex.exec(html)) !== null) {
        results.push(match[1] || match[0]);
      }

      return results;
    } catch (error) {
      Logger.error(RuleEngine.TAG, `正则规则列表解析失败: ${error}`);
      return [];
    }
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
