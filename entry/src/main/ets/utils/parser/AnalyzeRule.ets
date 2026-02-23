import { Logger } from '../performance/Logger';
import { CssSelectorParser } from './CssSelectorParser';
import { EntityDecoder } from '../../core/utils/EntityDecoder';
import { EnhancedJSEngine } from '../scripting/EnhancedJSEngine';
import XPathEngine from './XPathEngine';
import { SafeRegex } from '../security/SafeRegex';
import { RuleAnalyzer } from './RuleAnalyzer';
import { EnhancedParser } from './EnhancedParser';
import { DOMNode } from './DOMNode';
import { RegexMatchResult } from '../security/SafeRegex';

export type RuleMode = 'Default' | 'XPath' | 'Json' | 'Regex' | 'Js';

export interface SourceRule {
  rule: string;
  mode: RuleMode;
  replaceRegex: string;
  replacement: string;
  replaceFirst: boolean;
  putMap: Map<string, string>;
  combinator?: '&&' | '||' | '%%';
}

export interface RuleContext {
  baseUrl: string;
  variables: Map<string, string>;
  book?: object;
  chapter?: object;
  source?: object;
}

export interface ParsedSearchUrl {
  url: string;
  method: 'GET' | 'POST';
  body?: string;
  headers?: Map<string, string>;
}

interface PostConfig {
  body?: string;
  header?: Map<string, string>;
}

interface RuleGroup {
  rules: SourceRule[];
  combinator?: '&&' | '||' | '%%';
}

type JsonValue = string | number | boolean | null | Map<string, JsonValue> | JsonValue[];

const JS_PATTERN = /\{\{([^}]+)\}\}|<js>([\s\S]*?)<\/js>|@js:([\s\S]+)$/i;
const PUT_PATTERN = /@put:\{([^}]+)\}/g;

function createDefaultRuleContext(): RuleContext {
  return {
    baseUrl: '',
    variables: new Map<string, string>()
  };
}

export class AnalyzeRule {
  private static readonly TAG = 'AnalyzeRule';
  private static readonly MAX_REGEX_CACHE_SIZE = 100;
  
  private content: string = '';
  private baseUrl: string = '';
  private isJSON: boolean = false;
  private isRegex: boolean = false;
  
  private ruleContext: RuleContext = createDefaultRuleContext();
  
  private ruleCache: Map<string, SourceRule[]> = new Map();
  private regexCache: Map<string, RegExp> = new Map();
  
  private jsEngine: EnhancedJSEngine | null = null;
  private enhancedParser: EnhancedParser;
  private domRoot: DOMNode | null = null;

  constructor(context?: Partial<RuleContext>) {
    if (context) {
      if (context.baseUrl) this.ruleContext.baseUrl = context.baseUrl;
      if (context.variables) this.ruleContext.variables = context.variables;
      if (context.book) this.ruleContext.book = context.book;
      if (context.chapter) this.ruleContext.chapter = context.chapter;
      if (context.source) this.ruleContext.source = context.source;
    }
    this.jsEngine = EnhancedJSEngine.getInstance();
    this.enhancedParser = EnhancedParser.getInstance();
  }

  setContent(content: string, baseUrl?: string): AnalyzeRule {
    if (!content) {
      throw new Error('内容不能为空');
    }
    this.content = content;
    this.isJSON = this.detectJSON(content);
    this.isRegex = false;

    // 解析 HTML 为 DOM 树（如果不是 JSON）
    if (!this.isJSON) {
      try {
        this.domRoot = this.enhancedParser.parse(content);
      } catch (e) {
        Logger.warn(AnalyzeRule.TAG, `DOM解析失败，将使用备用解析: ${e}`);
        this.domRoot = null;
      }
    } else {
      this.domRoot = null;
    }

    if (baseUrl) {
      this.baseUrl = baseUrl;
      this.ruleContext.baseUrl = baseUrl;
    }
    return this;
  }

  setBaseUrl(baseUrl: string): AnalyzeRule {
    this.baseUrl = baseUrl;
    this.ruleContext.baseUrl = baseUrl;
    return this;
  }

  setVariable(key: string, value: string): AnalyzeRule {
    this.ruleContext.variables.set(key, value);
    return this;
  }

  getVariable(key: string): string {
    return this.ruleContext.variables.get(key) || '';
  }

  getString(rule: string, isUrl: boolean = false): Promise<string> {
    if (!rule || !this.content) return Promise.resolve('');
    
    const ruleList = this.splitSourceRule(rule);
    return this.getStringFromRules(ruleList, isUrl);
  }

  getStringList(rule: string, isUrl: boolean = false): Promise<string[]> {
    if (!rule || !this.content) return Promise.resolve([]);
    
    const ruleList = this.splitSourceRule(rule);
    return this.getStringListFromRules(ruleList, isUrl);
  }

  async getElements(rule: string): Promise<string[]> {
    if (!rule || !this.content) return [];
    
    const ruleList = this.splitSourceRule(rule, true);
    return await this.getElementsFromRules(ruleList);
  }

  private splitSourceRule(ruleStr: string, allInOne: boolean = false): SourceRule[] {
    if (!ruleStr) return [];
    
    const cached = this.ruleCache.get(ruleStr);
    if (cached) return cached;
    
    // 使用新的 RuleAnalyzer 处理复杂规则
    const analyzer = new RuleAnalyzer(ruleStr);
    const ruleParts = analyzer.splitRule('&&', '||', '%%');
    const elementsType = analyzer.elementsType;
    
    const ruleList: SourceRule[] = [];
    
    // 处理每个规则部分
    for (let i = 0; i < ruleParts.length; i++) {
      const part = ruleParts[i];
      const isLast = i === ruleParts.length - 1;
      
      // 解析规则部分
      const parsedRules = this.parseRulePart(part, allInOne);
      
      // 如果不是最后一个，添加操作符信息
      if (!isLast && elementsType) {
        for (const rule of parsedRules) {
          rule.combinator = elementsType as '&&' | '||' | '%%';
        }
      }
      
      ruleList.push(...parsedRules);
    }
    
    this.ruleCache.set(ruleStr, ruleList);
    return ruleList;
  }
  
  private parseRulePart(ruleStr: string, allInOne: boolean): SourceRule[] {
    const ruleList: SourceRule[] = [];
    let mode: RuleMode = 'Default';
    let start = 0;
    
    if (allInOne && ruleStr.startsWith(':')) {
      mode = 'Regex';
      this.isRegex = true;
      start = 1;
    } else if (this.isRegex) {
      mode = 'Regex';
    }
    
    const jsMatcher = ruleStr.matchAll(JS_PATTERN);
    const matches = Array.from(jsMatcher);
    
    if (matches.length === 0) {
      const trimmed = ruleStr.substring(start).trim();
      if (trimmed) {
        ruleList.push(this.parseSourceRule(trimmed, mode));
      }
    } else {
      let lastIndex = start;
      for (const match of matches) {
        const matchStart = match.index || 0;
        const matchEnd = matchStart + match[0].length;
        
        if (matchStart > lastIndex) {
          const beforeRule = ruleStr.substring(lastIndex, matchStart).trim();
          if (beforeRule) {
            ruleList.push(this.parseSourceRule(beforeRule, mode));
          }
        }
        
        const jsCode = match[1] || match[2] || match[3];
        ruleList.push(this.createJsRule(jsCode.trim()));
        lastIndex = matchEnd;
      }
      
      if (lastIndex < ruleStr.length) {
        const afterRule = ruleStr.substring(lastIndex).trim();
        if (afterRule) {
          ruleList.push(this.parseSourceRule(afterRule, mode));
        }
      }
    }
    
    return ruleList;
  }

  private parseSourceRule(ruleStr: string, defaultMode: RuleMode): SourceRule {
    let rule = ruleStr;
    let mode: RuleMode = defaultMode;
    const putMap = new Map<string, string>();
    
    rule = this.splitPutRule(rule, putMap);
    
    if (rule.startsWith('@CSS:') || rule.startsWith('@css:')) {
      mode = 'Default';
      rule = rule.substring(5);
    } else if (rule.startsWith('@@')) {
      mode = 'Default';
      rule = rule.substring(2);
    } else if (rule.startsWith('@XPath:') || rule.startsWith('@xpath:')) {
      mode = 'XPath';
      rule = rule.substring(7);
    } else if (rule.startsWith('@Json:') || rule.startsWith('@json:')) {
      mode = 'Json';
      rule = rule.substring(6);
    } else if (rule.startsWith('@Regex:') || rule.startsWith('@regex:')) {
      mode = 'Regex';
      rule = rule.substring(7);
    } else if (this.isJSON || rule.startsWith('$.') || rule.startsWith('$[')) {
      mode = 'Json';
    } else if (rule.startsWith('/')) {
      mode = 'XPath';
    }
    
    let replaceRegex = '';
    let replacement = '';
    let replaceFirst = false;
    
    const replaceMatch = rule.match(/##(.+?)##(.*)$/);
    if (replaceMatch) {
      replaceRegex = replaceMatch[1];
      replacement = replaceMatch[2] || '';
      replaceFirst = true;
      rule = rule.substring(0, rule.indexOf('##'));
    } else if (rule.includes('##')) {
      const parts = rule.split('##');
      rule = parts[0].trim();
      if (parts.length > 1) {
        replaceRegex = parts[1].trim();
        if (parts.length > 2) {
          replacement = parts[2].trim();
        }
      }
    }
    
    return {
      rule: rule.trim(),
      mode,
      replaceRegex,
      replacement,
      replaceFirst,
      putMap
    };
  }

  private createJsRule(jsCode: string): SourceRule {
    return {
      rule: jsCode,
      mode: 'Js',
      replaceRegex: '',
      replacement: '',
      replaceFirst: false,
      putMap: new Map()
    };
  }

  private splitPutRule(rule: string, putMap: Map<string, string>): string {
    let result = rule;
    const putMatcher = rule.matchAll(PUT_PATTERN);
    
    for (const match of Array.from(putMatcher)) {
      result = result.replace(match[0], '');
      try {
        const putJson = match[1];
        const colonIndex = putJson.indexOf(':');
        if (colonIndex > 0) {
          const key = putJson.substring(0, colonIndex).trim();
          const value = putJson.substring(colonIndex + 1).trim();
          putMap.set(key, value);
        }
      } catch (e) {
        Logger.warn(AnalyzeRule.TAG, `解析@put规则失败: ${e}`);
      }
    }
    
    return result;
  }

  private async getStringFromRules(rules: SourceRule[], isUrl: boolean): Promise<string> {
    // 按操作符分组处理
    const groups = this.groupRulesByCombinator(rules);
    let finalResult: string | null = null;
    
    for (const group of groups) {
      let groupResult: string | null = null;
      
      if (group.combinator === '%%') {
        // 交叉操作符 - 特殊处理
        groupResult = await this.handleCrossRules(group.rules);
      } else if (group.combinator === '||') {
        // 或操作符 - 取第一个成功的
        for (const rule of group.rules) {
          await this.applyPutMap(rule.putMap);
          groupResult = await this.executeSingleRule(rule, groupResult);
          if (groupResult) break; // 第一个成功的就返回
        }
      } else {
        // 与操作符 && 或无操作符 - 连接所有结果
        const results: string[] = [];
        for (const rule of group.rules) {
          await this.applyPutMap(rule.putMap);
          const singleResult = await this.executeSingleRule(rule, results.length > 0 ? results.join('\n') : null);
          if (singleResult) {
            results.push(singleResult);
          }
        }
        groupResult = results.join('\n');
      }
      
      // 合并组结果
      if (groupResult) {
        if (finalResult) {
          finalResult += '\n' + groupResult;
        } else {
          finalResult = groupResult;
        }
      }
    }
    
    finalResult = finalResult || '';
    
    if (isUrl && finalResult) {
      finalResult = this.resolveUrl(finalResult);
    }
    
    if (finalResult && finalResult.indexOf('&') > -1) {
      finalResult = EntityDecoder.decode(finalResult);
    }
    
    return finalResult;
  }
  
  private async executeSingleRule(rule: SourceRule, previousResult: string | null): Promise<string | null> {
    if (!rule.rule && rule.replaceRegex) {
      if (previousResult) {
        return this.applyReplaceRegex(previousResult, rule);
      }
      return null;
    }
    
    const result = await this.executeRule(rule, previousResult || this.content);
    
    if (rule.replaceRegex && result) {
      return this.applyReplaceRegex(result, rule);
    }
    
    return result;
  }
  
  private groupRulesByCombinator(rules: SourceRule[]): RuleGroup[] {
    const groups: RuleGroup[] = [];
    let currentGroup: SourceRule[] = [];
    let currentCombinator: '&&' | '||' | '%%' | undefined;
    
    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i];
      currentGroup.push(rule);
      
      // 检查下一个规则的操作符
      if (i < rules.length - 1) {
        const nextCombinator = rules[i + 1].combinator;
        if (nextCombinator && nextCombinator !== currentCombinator) {
          // 操作符变化，保存当前组
          const group: RuleGroup = { rules: currentGroup, combinator: currentCombinator };
          groups.push(group);
          currentGroup = [];
          currentCombinator = nextCombinator;
        } else if (!currentCombinator) {
          currentCombinator = nextCombinator;
        }
      }
    }
    
    // 保存最后一组
    if (currentGroup.length > 0) {
      const group: RuleGroup = { rules: currentGroup, combinator: currentCombinator };
      groups.push(group);
    }
    
    return groups;
  }
  
  private async handleCrossRules(rules: SourceRule[]): Promise<string> {
    // %% 交叉操作符 - 将多个规则的结果交叉组合
    const results: string[][] = [];
    
    for (const rule of rules) {
      await this.applyPutMap(rule.putMap);
      const list = await this.executeRuleList(rule, this.content);
      if (list.length > 0) {
        results.push(list);
      }
    }
    
    if (results.length === 0) return '';
    
    // 交叉组合结果
    const crossed: string[] = [];
    const maxLen = Math.max(...results.map(r => r.length));
    
    for (let i = 0; i < maxLen; i++) {
      for (const result of results) {
        if (i < result.length) {
          crossed.push(result[i]);
        }
      }
    }
    
    return crossed.join('\n');
  }

  private async getStringListFromRules(rules: SourceRule[], isUrl: boolean): Promise<string[]> {
    let result: string[] | null = null;
    
    for (const rule of rules) {
      await this.applyPutMap(rule.putMap);
      
      if (rule.mode === 'Js') {
        const jsResult = await this.evalJS(rule.rule);
        if (Array.isArray(jsResult)) {
          result = this.convertArrayToStringArray(jsResult);
        } else if (typeof jsResult === 'string') {
          result = jsResult.split('\n');
        }
      } else {
        const list: string[] = await this.executeRuleList(rule, result ? result.join('\n') : this.content);
        result = list;
      }
      
      if (rule.replaceRegex && result) {
        result = result.map((s: string) => this.applyReplaceRegex(s, rule));
      }
    }
    
    if (!result) return [];
    
    if (isUrl) {
      result = result.map((url: string) => this.resolveUrl(url));
    }
    
    return result;
  }

  private convertArrayToStringArray(arr: JsonValue[]): string[] {
    const result: string[] = [];
    for (const item of arr) {
      result.push(String(item));
    }
    return result;
  }

  private async getElementsFromRules(rules: SourceRule[]): Promise<string[]> {
    let result: string[] = [];
    let currentDomRoot: DOMNode | null = this.domRoot;

    for (const rule of rules) {
      await this.applyPutMap(rule.putMap);

      switch (rule.mode) {
        case 'Regex':
          result = this.executeRegexElements(rule.rule, result.length > 0 ? result.join('\n') : this.content);
          // 重新解析结果
          if (result.length > 0) {
            try {
              currentDomRoot = this.enhancedParser.parse(result.join('\n'));
            } catch {
              currentDomRoot = null;
            }
          }
          break;
        case 'Js':
          const jsResult = await this.evalJS(rule.rule);
          if (Array.isArray(jsResult)) {
            result = this.convertArrayToStringArray(jsResult);
          }
          break;
        case 'Json':
          result = this.executeJsonElements(rule.rule, result.length > 0 ? result.join('\n') : this.content);
          break;
        case 'XPath':
          result = XPathEngine.selectElements(result.length > 0 ? result.join('\n') : this.content, rule.rule);
          break;
        case 'Default':
        default:
          // 优先使用增强版解析器
          if (currentDomRoot) {
            try {
              const nodes = this.enhancedParser.select(currentDomRoot, this.convertToCssSelector(rule.rule));
              result = nodes.map(n => n.outerHTML);
              // 更新当前 DOM 根为第一个匹配元素（如果有）
              if (nodes.length > 0) {
                currentDomRoot = nodes[0];
              }
            } catch (e) {
              Logger.debug(AnalyzeRule.TAG, `增强解析器getElements失败，回退到旧版: ${e}`);
              result = CssSelectorParser.selectElements(result.length > 0 ? result.join('\n') : this.content, rule.rule);
            }
          } else {
            // 回退到旧版解析器
            result = CssSelectorParser.selectElements(result.length > 0 ? result.join('\n') : this.content, rule.rule);
          }
          break;
      }
    }

    return result;
  }

  private async executeRule(rule: SourceRule, content: string): Promise<string> {
    switch (rule.mode) {
      case 'Js':
        return String(await this.evalJS(rule.rule) || '');
      case 'Json':
        return this.executeJsonRule(rule.rule, content);
      case 'XPath':
        return XPathEngine.selectFirst(content, rule.rule);
      case 'Regex':
        return this.executeRegexRule(rule.rule, content);
      case 'Default':
      default:
        // 优先使用增强版解析器
        if (this.domRoot) {
          try {
            const nodes = this.enhancedParser.select(this.domRoot, this.convertToCssSelector(rule.rule));
            if (nodes.length > 0) {
              return this.extractValueFromNode(nodes[0], rule.rule);
            }
          } catch (e) {
            Logger.debug(AnalyzeRule.TAG, `增强解析器失败，回退到旧版: ${e}`);
          }
        }
        // 回退到旧版解析器
        return CssSelectorParser.extractValue(content, rule.rule);
    }
  }

  /**
   * 将 Legado 规则格式转换为标准 CSS 选择器
   */
  private convertToCssSelector(rule: string): string {
    let selector = rule.trim();

    // 处理 @ 符号（属性提取）
    const atIndex = selector.lastIndexOf('@');
    if (atIndex > 0) {
      selector = selector.substring(0, atIndex).trim();
    }

    // 处理 class. 前缀
    if (selector.startsWith('class.')) {
      selector = '.' + selector.substring(6);
    }

    // 处理 tag. 前缀
    if (selector.startsWith('tag.')) {
      selector = selector.substring(4);
    }

    // 处理 id. 前缀
    if (selector.startsWith('id.')) {
      selector = '#' + selector.substring(3);
    }

    return selector;
  }

  /**
   * 从 DOM 节点提取值
   */
  private extractValueFromNode(node: DOMNode, rule: string): string {
    // 检查是否有 @ 属性提取
    const atIndex = rule.lastIndexOf('@');
    if (atIndex > 0) {
      const attr = rule.substring(atIndex + 1).trim();

      if (attr === 'text' || attr === 'text()') {
        return node.textContent;
      } else if (attr === 'html' || attr === 'html()') {
        return node.innerHTML;
      } else {
        return node.getAttribute(attr) || '';
      }
    }

    // 默认返回文本内容
    return node.textContent;
  }

  private async executeRuleList(rule: SourceRule, content: string): Promise<string[]> {
    switch (rule.mode) {
      case 'Js':
        const jsResult = await this.evalJS(rule.rule);
        if (Array.isArray(jsResult)) {
          return this.convertArrayToStringArray(jsResult);
        }
        return jsResult ? [String(jsResult)] : [];
      case 'Json':
        return this.executeJsonRuleList(rule.rule, content);
      case 'XPath':
        return XPathEngine.selectElements(content, rule.rule);
      case 'Regex':
        return this.executeRegexRuleList(rule.rule, content);
      case 'Default':
      default:
        // 优先使用增强版解析器
        if (this.domRoot) {
          try {
            const nodes = this.enhancedParser.select(this.domRoot, this.convertToCssSelector(rule.rule));
            return nodes.map(node => this.extractValueFromNode(node, rule.rule));
          } catch (e) {
            Logger.debug(AnalyzeRule.TAG, `增强解析器列表失败，回退到旧版: ${e}`);
          }
        }
        // 回退到旧版解析器
        return CssSelectorParser.selectElements(content, rule.rule);
    }
  }

  private executeJsonRule(rule: string, content: string): string {
    try {
      const jsonData = this.parseJsonContent(content);
      if (jsonData === null) return '';
      return this.extractJsonValue(jsonData, rule);
    } catch (e) {
      Logger.error(AnalyzeRule.TAG, `JSON规则解析失败: ${e}`);
      return '';
    }
  }

  private parseJsonContent(content: string): JsonValue | null {
    try {
      return JSON.parse(content) as JsonValue;
    } catch {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[0]) as JsonValue;
        } catch {
          return null;
        }
      }
      return null;
    }
  }

  private executeJsonRuleList(rule: string, content: string): string[] {
    try {
      const jsonData = this.parseJsonContent(content);
      if (jsonData === null) return [];
      
      const result = this.extractJsonValuePath(jsonData, rule);
      if (Array.isArray(result)) {
        return this.convertJsonArrayToStringArray(result);
      }
      return result ? [String(result)] : [];
    } catch (e) {
      Logger.error(AnalyzeRule.TAG, `JSON规则列表解析失败: ${e}`);
      return [];
    }
  }

  private convertJsonArrayToStringArray(arr: JsonValue[]): string[] {
    const result: string[] = [];
    for (const item of arr) {
      if (typeof item === 'object' && item !== null) {
        result.push(JSON.stringify(item));
      } else {
        result.push(String(item));
      }
    }
    return result;
  }

  private executeJsonElements(rule: string, content: string): string[] {
    return this.executeJsonRuleList(rule, content);
  }

  private executeRegexRule(rule: string, content: string): string {
    try {
      const match: RegExpMatchArray | null = SafeRegex.safeMatch(rule, content);
      if (match) {
        return match[1] || match[0];
      }
      return '';
    } catch (e) {
      Logger.error(AnalyzeRule.TAG, `正则规则解析失败: ${e}`);
      return '';
    }
  }

  private executeRegexRuleList(rule: string, content: string): string[] {
    try {
      const matches: RegexMatchResult[] = SafeRegex.safeMatchAll(rule, content);
      const results: string[] = [];
      
      for (const match of matches) {
        results.push(match.getGroup(1) || match.getMatch());
      }
      
      return results;
    } catch (e) {
      Logger.error(AnalyzeRule.TAG, `正则规则列表解析失败: ${e}`);
      return [];
    }
  }

  private executeRegexElements(rule: string, content: string): string[] {
    return this.executeRegexRuleList(rule, content);
  }

  private extractJsonValue(data: JsonValue | null, path: string): string {
    const value = this.extractJsonValuePath(data, path);
    if (value === null || value === undefined) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value);
    }
    return '';
  }

  private extractJsonValuePath(data: JsonValue | null, path: string): JsonValue | undefined {
    if (!data || !path) {
      return data;
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
    let current: JsonValue | undefined = data;
    
    for (const part of parts) {
      if (current === null || current === undefined) {
        return undefined;
      }
      
      if (part === '*') {
        continue;
      }
      
      const index = parseInt(part, 10);
      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index];
        } else {
          return undefined;
        }
      } else if (typeof current === 'object' && !Array.isArray(current) && current !== null) {
        const objMap = current as Map<string, JsonValue>;
        current = objMap.get(part);
      } else {
        return undefined;
      }
    }
    
    return current;
  }

  private async evalJS(jsCode: string): Promise<JsonValue> {
    try {
      if (!this.jsEngine) {
        this.jsEngine = EnhancedJSEngine.getInstance();
      }
      
      const jsResult: string = await this.jsEngine.executeRule(this.content, `@js:${jsCode}`, this.baseUrl);
      if (typeof jsResult === 'string') {
        return jsResult;
      }
      return '';
    } catch (e) {
      Logger.error(AnalyzeRule.TAG, `JS执行失败: ${e}`);
      return '';
    }
  }

  private async applyPutMap(putMap: Map<string, string>): Promise<void> {
    const entries = Array.from(putMap.entries());
    for (const entry of entries) {
      const key = entry[0];
      const rule = entry[1];
      const value = await this.getString(rule);
      this.ruleContext.variables.set(key, value);
    }
  }

  private applyReplaceRegex(content: string, rule: SourceRule): string {
    if (!rule.replaceRegex) return content;
    
    try {
      if (rule.replaceFirst) {
        const match: RegExpMatchArray | null = SafeRegex.safeMatch(rule.replaceRegex, content);
        if (match) {
          return SafeRegex.safeReplace(match[0], rule.replaceRegex, rule.replacement);
        }
        return '';
      } else {
        return SafeRegex.safeReplace(content, rule.replaceRegex, rule.replacement);
      }
    } catch (e) {
      Logger.warn(AnalyzeRule.TAG, `替换正则执行失败: ${e}`);
      return content;
    }
  }

  private getOrCreateRegex(pattern: string, flags: string = 'gi'): RegExp {
    const cacheKey = `${pattern}_${flags}`;
    let regex = this.regexCache.get(cacheKey);
    
    if (!regex) {
      if (this.regexCache.size >= AnalyzeRule.MAX_REGEX_CACHE_SIZE) {
        const keys = Array.from(this.regexCache.keys());
        for (let i = 0; i < Math.floor(keys.length / 2); i++) {
          this.regexCache.delete(keys[i]);
        }
      }
      regex = new RegExp(pattern, flags);
      this.regexCache.set(cacheKey, regex);
    }
    
    return regex;
  }

  private resolveUrl(url: string): string {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:' + url;
    }
    if (!this.baseUrl) return url;
    
    try {
      const protocolEnd = this.baseUrl.indexOf('://');
      if (protocolEnd === -1) return url;
      
      const protocol = this.baseUrl.substring(0, protocolEnd + 3);
      const hostStart = protocolEnd + 3;
      const pathStart = this.baseUrl.indexOf('/', hostStart);
      const host = pathStart === -1 ? this.baseUrl.substring(hostStart) : this.baseUrl.substring(hostStart, pathStart);
      
      if (url.startsWith('/')) {
        return `${protocol}${host}${url}`;
      }
      
      const path = pathStart === -1 ? '/' : this.baseUrl.substring(pathStart);
      const lastSlash = path.lastIndexOf('/');
      const basePath = lastSlash === -1 ? '/' : path.substring(0, lastSlash + 1);
      
      return `${protocol}${host}${basePath}${url}`;
    } catch {
      return url;
    }
  }

  private detectJSON(content: string): boolean {
    const trimmed = content.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
           (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }

  static parseSearchUrl(
    searchUrl: string,
    keyword: string,
    page: number,
    baseUrl: string = ''
  ): ParsedSearchUrl {
    if (!searchUrl) {
      return { url: '', method: 'GET' };
    }
    
    if (searchUrl.startsWith('@js:') || searchUrl.startsWith('<js>')) {
      Logger.warn(AnalyzeRule.TAG, 'JavaScript URL需要通过JSEngine执行');
      return { url: '', method: 'GET' };
    }
    
    const postMatch = searchUrl.match(/^(.+),\s*(\{[\s\S]+\})$/);
    if (postMatch) {
      const urlPart = postMatch[1].trim();
      const configPart = postMatch[2].trim();
      
      try {
        const config = AnalyzeRule.parsePostConfig(configPart);
        
        let url = AnalyzeRule.replaceUrlParams(urlPart, keyword, page);
        let body = '';
        if (config.body) {
          body = AnalyzeRule.replaceUrlParams(config.body, keyword, page);
        }
        
        const headers = config.header || new Map<string, string>();
        
        if (url && !url.startsWith('http')) {
          url = baseUrl + (url.startsWith('/') ? url : '/' + url);
        }
        
        const result: ParsedSearchUrl = {
          url: url,
          method: 'POST',
          body: body,
          headers: headers
        };
        return result;
      } catch (e) {
        Logger.error(AnalyzeRule.TAG, `解析POST配置失败: ${e}`);
      }
    }
    
    let finalUrl = AnalyzeRule.replaceUrlParams(searchUrl, keyword, page);
    
    if (finalUrl && !finalUrl.startsWith('http')) {
      finalUrl = baseUrl + (finalUrl.startsWith('/') ? finalUrl : '/' + finalUrl);
    }
    
    return {
      url: finalUrl,
      method: 'GET'
    };
  }

  private static parsePostConfig(configJson: string): PostConfig {
    const config: PostConfig = {
      body: '',
      header: new Map<string, string>()
    };
    
    const bodyMatch = configJson.match(/"body"\s*:\s*"([^"]*)"/);
    if (bodyMatch) {
      config.body = bodyMatch[1];
    }
    
    const headerMatch = configJson.match(/"header"\s*:\s*\{([^}]*)\}/);
    if (headerMatch) {
      const headerStr = headerMatch[1];
      const pairs = headerStr.matchAll(/"([^"]+)"\s*:\s*"([^"]*)"/g);
      for (const pair of Array.from(pairs)) {
        if (config.header) {
          config.header.set(pair[1], pair[2]);
        }
      }
    }
    
    return config;
  }

  private static replaceUrlParams(url: string, keyword: string, page: number): string {
    let result = url;
    result = result.replace(/\{\{key\}\}/g, encodeURIComponent(keyword));
    result = result.replace(/\{\{page\}\}/g, String(page));
    result = result.replace(/\{key\}/g, encodeURIComponent(keyword));
    result = result.replace(/\{page\}/g, String(page));
    result = result.replace(/searchKey/g, encodeURIComponent(keyword));
    result = result.replace(/searchPage/g, String(page));
    result = result.replace(/<key>/g, encodeURIComponent(keyword));
    result = result.replace(/<page>/g, String(page));
    result = result.replace(/\$key\$/g, encodeURIComponent(keyword));
    result = result.replace(/\$page\$/g, String(page));
    return result;
  }

  clearCache(): void {
    this.ruleCache.clear();
    this.regexCache.clear();
  }
}

export default AnalyzeRule;
