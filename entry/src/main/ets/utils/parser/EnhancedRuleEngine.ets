import { Logger } from '../performance/Logger';
import { CssSelectorParser } from './CssSelectorParser';
import { XPathParser } from './XPathParser';
import { JsonPathParser } from './JsonPathParser';
import { EntityDecoder } from '../../core/utils/EntityDecoder';

export enum RuleMode {
  Default = 'Default',
  XPath = 'XPath',
  Json = 'Json',
  Js = 'Js',
  Regex = 'Regex',
  CSS = 'CSS'
}

export interface RuleContext {
  variables: Map<string, string>;
  baseUrl: string;
  content: string;
  isJson: boolean;
  redirectUrl: string;
}

export interface SourceRuleInterface {
  rule: string;
  mode: RuleMode;
  replaceRegex: string;
  replacement: string;
  replaceFirst: boolean;
  putMap: Map<string, string>;
}

export class SourceRule implements SourceRuleInterface {
  rule: string = '';
  mode: RuleMode = RuleMode.Default;
  replaceRegex: string = '';
  replacement: string = '';
  replaceFirst: boolean = false;
  putMap: Map<string, string> = new Map();

  private ruleParam: string[] = [];
  private ruleType: number[] = [];
  private static readonly GET_RULE_TYPE = -2;
  private static readonly JS_RULE_TYPE = -1;
  private static readonly DEFAULT_RULE_TYPE = 0;

  constructor(ruleStr: string, mode: RuleMode = RuleMode.Default, isJson: boolean = false) {
    this.mode = mode;
    this.parseRule(ruleStr, isJson);
  }

  private parseRule(ruleStr: string, isJson: boolean): void {
    let processedRule = ruleStr;

    if (this.mode === RuleMode.Js || this.mode === RuleMode.Regex) {
      this.rule = processedRule;
      return;
    }

    if (processedRule.toLowerCase().startsWith('@css:')) {
      this.mode = RuleMode.CSS;
      processedRule = processedRule.substring(5);
    } else if (processedRule.startsWith('@@')) {
      this.mode = RuleMode.Default;
      processedRule = processedRule.substring(2);
    } else if (processedRule.toLowerCase().startsWith('@xpath:')) {
      this.mode = RuleMode.XPath;
      processedRule = processedRule.substring(7);
    } else if (processedRule.toLowerCase().startsWith('@json:')) {
      this.mode = RuleMode.Json;
      processedRule = processedRule.substring(6);
    } else if (isJson || processedRule.startsWith('$.') || processedRule.startsWith('$[')) {
      this.mode = RuleMode.Json;
    } else if (processedRule.startsWith('/') || processedRule.startsWith('./')) {
      this.mode = RuleMode.XPath;
    }

    processedRule = this.splitPutRule(processedRule);
    this.parseEvalAndRegex(processedRule);
  }

  private splitPutRule(rule: string): string {
    const putPattern = /@put:\{([^}]+?)\}/gi;
    let result = rule;
    let match: RegExpExecArray | null = null;

    while ((match = putPattern.exec(rule)) !== null) {
      result = result.replace(match[0], '');
      try {
        const putJsonStr = `{${match[1]}}`;
        const putJson = JSON.parse(putJsonStr) as Record<string, string>;
        const keys = Object.keys(putJson);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          const value = putJson[key];
          this.putMap.set(key, String(value));
        }
      } catch (e) {
        const colonIndex = match[1].indexOf(':');
        if (colonIndex > 0) {
          const varName = match[1].substring(0, colonIndex).trim();
          const varRule = match[1].substring(colonIndex + 1).trim();
          this.putMap.set(varName, varRule);
        }
      }
    }

    return result;
  }

  private parseEvalAndRegex(rule: string): void {
    const evalPattern = /@get:\{[^}]+?\}|\{\{[\w\W]*?\}\}/gi;

    let start = 0;
    let match: RegExpExecArray | null = null;
    const tempRule = rule;

    while ((match = evalPattern.exec(tempRule)) !== null) {
      if (match.index > start) {
        const beforeMatch = tempRule.substring(start, match.index);
        this.splitRegexPattern(beforeMatch);
      }

      const matched = match[0];
      if (matched.startsWith('@get:')) {
        this.ruleType.push(SourceRule.GET_RULE_TYPE);
        this.ruleParam.push(matched.substring(6, matched.length - 1));
      } else if (matched.startsWith('{{')) {
        this.ruleType.push(SourceRule.JS_RULE_TYPE);
        this.ruleParam.push(matched.substring(2, matched.length - 2));
      }

      start = match.index + matched.length;
    }

    if (tempRule.length > start) {
      const remaining = tempRule.substring(start);
      this.splitRegexPattern(remaining);
    }

    this.buildFinalRule();
  }

  private splitRegexPattern(rule: string): void {
    const parts = rule.split('##');
    if (parts.length === 0 || parts[0].length === 0) {
      return;
    }
    const regexPattern = /\$\d{1,2}/g;
    let start = 0;
    let match: RegExpExecArray | null = null;
    const firstPart = parts[0];

    while ((match = regexPattern.exec(firstPart)) !== null) {
      if (match.index > start) {
        this.ruleType.push(SourceRule.DEFAULT_RULE_TYPE);
        this.ruleParam.push(firstPart.substring(start, match.index));
      }

      this.ruleType.push(parseInt(match[0].substring(1)));
      this.ruleParam.push(match[0]);
      start = match.index + match[0].length;
    }

    if (firstPart.length > start) {
      this.ruleType.push(SourceRule.DEFAULT_RULE_TYPE);
      this.ruleParam.push(firstPart.substring(start));
    }
  }

  private buildFinalRule(): void {
    const ruleStrArray = this.ruleParam.length > 0 ? 
      this.ruleParam[this.ruleParam.length - 1].split('##') : [''];
    
    this.rule = ruleStrArray[0]?.trim() || '';
    
    if (ruleStrArray.length > 1) {
      this.replaceRegex = ruleStrArray[1];
    }
    if (ruleStrArray.length > 2) {
      this.replacement = ruleStrArray[2];
    }
    if (ruleStrArray.length > 3) {
      this.replaceFirst = true;
    }
  }

  makeUpRule(result: string | string[], getStringFn: (rule: string) => string, getVariableFn: (key: string) => string): string {
    if (this.ruleParam.length === 0) {
      return this.rule;
    }

    const infoVal: string[] = [];
    
    for (let i = this.ruleParam.length - 1; i >= 0; i--) {
      const regType = this.ruleType[i];
      
      if (regType > SourceRule.DEFAULT_RULE_TYPE) {
        if (Array.isArray(result) && result.length > regType) {
          infoVal.unshift(result[regType] || '');
        } else {
          infoVal.unshift(this.ruleParam[i]);
        }
      } else if (regType === SourceRule.JS_RULE_TYPE) {
        const jsRule = this.ruleParam[i];
        if (this.isRule(jsRule)) {
          infoVal.unshift(getStringFn(jsRule));
        } else {
          infoVal.unshift(jsRule);
        }
      } else if (regType === SourceRule.GET_RULE_TYPE) {
        infoVal.unshift(getVariableFn(this.ruleParam[i]));
      } else {
        infoVal.unshift(this.ruleParam[i]);
      }
    }

    this.rule = infoVal.join('');
    
    const ruleStrS = this.rule.split('##');
    this.rule = ruleStrS[0]?.trim() || '';
    
    if (ruleStrS.length > 1) {
      this.replaceRegex = ruleStrS[1];
    }
    if (ruleStrS.length > 2) {
      this.replacement = ruleStrS[2];
    }
    if (ruleStrS.length > 3) {
      this.replaceFirst = true;
    }

    return this.rule;
  }

  private isRule(ruleStr: string): boolean {
    return ruleStr.startsWith('@') ||
           ruleStr.startsWith('$.') ||
           ruleStr.startsWith('$[') ||
           ruleStr.startsWith('//');
  }

  getParamSize(): number {
    return this.ruleParam.length;
  }
}

export class RuleCache {
  private static readonly MAX_CACHE_SIZE = 64;
  private static stringRuleCache: Map<string, SourceRule[]> = new Map();
  private static regexCache: Map<string, RegExp | null> = new Map();
  private static compiledScriptCache: Map<string, string> = new Map();

  static getOrPutStringRule(ruleStr: string, parser: () => SourceRule[]): SourceRule[] {
    let cached = RuleCache.stringRuleCache.get(ruleStr);
    if (cached) {
      return cached;
    }

    if (RuleCache.stringRuleCache.size >= RuleCache.MAX_CACHE_SIZE) {
      const firstKey = RuleCache.stringRuleCache.keys().next().value as string | undefined;
      if (firstKey !== undefined) {
        RuleCache.stringRuleCache.delete(firstKey);
      }
    }

    cached = parser();
    RuleCache.stringRuleCache.set(ruleStr, cached);
    return cached;
  }

  static getOrPutRegex(pattern: string, compiler: () => RegExp | null): RegExp | null {
    let cached = RuleCache.regexCache.get(pattern);
    if (cached !== undefined) {
      return cached;
    }

    if (RuleCache.regexCache.size >= RuleCache.MAX_CACHE_SIZE) {
      const firstKey = RuleCache.regexCache.keys().next().value as string | undefined;
      if (firstKey !== undefined) {
        RuleCache.regexCache.delete(firstKey);
      }
    }

    cached = compiler();
    RuleCache.regexCache.set(pattern, cached);
    return cached;
  }

  static clear(): void {
    RuleCache.stringRuleCache.clear();
    RuleCache.regexCache.clear();
    RuleCache.compiledScriptCache.clear();
  }
}

export class VariableScope {
  private scopes: Map<string, string>[] = [];

  constructor() {
    this.scopes.push(new Map());
  }

  pushScope(): void {
    this.scopes.push(new Map());
  }

  popScope(): void {
    if (this.scopes.length > 1) {
      this.scopes.pop();
    }
  }

  put(key: string, value: string): void {
    this.scopes[this.scopes.length - 1].set(key, value);
  }

  get(key: string): string {
    for (let i = this.scopes.length - 1; i >= 0; i--) {
      const value = this.scopes[i].get(key);
      if (value !== undefined) {
        return value;
      }
    }
    return '';
  }

  has(key: string): boolean {
    for (let i = this.scopes.length - 1; i >= 0; i--) {
      if (this.scopes[i].has(key)) {
        return true;
      }
    }
    return false;
  }

  getAll(): Map<string, string> {
    const result = new Map<string, string>();
    for (const scope of this.scopes) {
      const entries = scope.entries();
      let entry = entries.next();
      while (!entry.done && entry.value) {
        const key = entry.value[0];
        const value = entry.value[1];
        result.set(key, value);
        entry = entries.next();
      }
    }
    return result;
  }

  clear(): void {
    this.scopes = [new Map()];
  }
}

export class EnhancedRuleEngine {
  private static readonly TAG = 'EnhancedRuleEngine';
  
  private context: RuleContext = {
    variables: new Map(),
    baseUrl: '',
    content: '',
    isJson: false,
    redirectUrl: ''
  };

  private variableScope: VariableScope = new VariableScope();
  private xpathParser: XPathParser | null = null;
  private jsonPathParser: JsonPathParser | null = null;

  setContent(content: string, baseUrl: string = ''): EnhancedRuleEngine {
    if (!content) {
      throw new Error('内容不可为空');
    }

    this.context.content = content;
    this.context.baseUrl = baseUrl;
    this.context.isJson = this.detectJson(content);
    this.context.redirectUrl = baseUrl;

    this.xpathParser = null;
    this.jsonPathParser = null;

    return this;
  }

  setBaseUrl(baseUrl: string): EnhancedRuleEngine {
    this.context.baseUrl = baseUrl;
    return this;
  }

  setRedirectUrl(url: string): EnhancedRuleEngine {
    try {
      this.context.redirectUrl = url;
    } catch (e) {
      Logger.warn(EnhancedRuleEngine.TAG, `设置重定向URL失败: ${e}`);
    }
    return this;
  }

  private detectJson(content: string): boolean {
    const trimmed = content.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
           (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }

  getString(ruleStr: string, isUrl: boolean = false): string {
    if (!ruleStr) {
      return '';
    }

    const ruleList = this.splitSourceRule(ruleStr);
    return this.getStringFromRules(ruleList, isUrl);
  }

  getStringList(ruleStr: string, isUrl: boolean = false): string[] | null {
    if (!ruleStr) {
      return null;
    }

    const ruleList = this.splitSourceRule(ruleStr);
    return this.getStringListFromRules(ruleList, isUrl);
  }

  getElements(ruleStr: string): string[] {
    if (!ruleStr) {
      return [];
    }

    const ruleList = this.splitSourceRule(ruleStr, true);
    let result: string | string[] = this.context.content;

    for (const sourceRule of ruleList) {
      this.putRuleVariables(sourceRule);
      sourceRule.makeUpRule(result, 
        (r) => this.getString(r), 
        (k) => this.variableScope.get(k)
      );

      if (!result) continue;

      const rule = sourceRule.rule;
      if (rule) {
        result = this.getElementsInternal(result, sourceRule);
      }
    }

    return Array.isArray(result) ? result : [];
  }

  private splitSourceRule(ruleStr: string, allInOne: boolean = false): SourceRule[] {
    return RuleCache.getOrPutStringRule(ruleStr, () => {
      const rules: SourceRule[] = [];
      let mode = RuleMode.Default;
      let start = 0;

      if (allInOne && ruleStr.startsWith(':')) {
        mode = RuleMode.Regex;
        start = 1;
      }

      const jsPattern = /\{\{[\s\S]*?\}\}/g;
      let match: RegExpExecArray | null = null;

      while ((match = jsPattern.exec(ruleStr)) !== null) {
        if (match.index > start) {
          const beforeJs = ruleStr.substring(start, match.index).trim();
          if (beforeJs) {
            rules.push(new SourceRule(beforeJs, mode, this.context.isJson));
          }
        }
        const matchContent = match[0];
        const innerContent = matchContent.substring(2, matchContent.length - 2);
        rules.push(new SourceRule(innerContent, RuleMode.Js));
        start = match.index + matchContent.length;
      }

      if (ruleStr.length > start) {
        const remaining = ruleStr.substring(start).trim();
        if (remaining) {
          rules.push(new SourceRule(remaining, mode, this.context.isJson));
        }
      }

      return rules.length > 0 ? rules : [new SourceRule(ruleStr, mode, this.context.isJson)];
    });
  }

  private getStringFromRules(ruleList: SourceRule[], isUrl: boolean): string {
    let result: string | string[] = this.context.content;

    for (const sourceRule of ruleList) {
      this.putRuleVariables(sourceRule);
      sourceRule.makeUpRule(result,
        (r) => this.getString(r),
        (k) => this.variableScope.get(k)
      );

      if (!result) continue;

      const rule = sourceRule.rule;
      if (rule || sourceRule.replaceRegex) {
        result = this.getStringInternal(result, sourceRule, isUrl);
      }

      if (result && sourceRule.replaceRegex) {
        result = this.applyReplaceRegex(String(result), sourceRule);
      }
    }

    if (result === null || result === undefined) {
      return '';
    }

    let resultStr = String(result);

    if (resultStr.indexOf('&') > -1) {
      resultStr = EntityDecoder.decode(resultStr);
    }

    if (isUrl) {
      return this.getAbsoluteUrl(resultStr);
    }

    return resultStr;
  }

  private getStringListFromRules(ruleList: SourceRule[], isUrl: boolean): string[] | null {
    let result: string | string[] = this.context.content;

    for (const sourceRule of ruleList) {
      this.putRuleVariables(sourceRule);
      sourceRule.makeUpRule(result,
        (r) => this.getString(r),
        (k) => this.variableScope.get(k)
      );

      if (!result) continue;

      const rule = sourceRule.rule;
      if (rule) {
        result = this.getStringListInternal(result, sourceRule);
      }

      if (sourceRule.replaceRegex && Array.isArray(result)) {
        result = result.map(item => this.applyReplaceRegex(item, sourceRule));
      } else if (sourceRule.replaceRegex && result) {
        result = [this.applyReplaceRegex(String(result), sourceRule)];
      }
    }

    if (result === null || result === undefined) {
      return null;
    }

    if (typeof result === 'string') {
      result = result.split('\n');
    }

    if (isUrl && Array.isArray(result)) {
      const urlList: string[] = [];
      for (const url of result) {
        const absoluteUrl = this.getAbsoluteUrl(String(url));
        if (absoluteUrl && !urlList.includes(absoluteUrl)) {
          urlList.push(absoluteUrl);
        }
      }
      return urlList;
    }

    return Array.isArray(result) ? result : [String(result)];
  }

  private getStringInternal(content: string | string[], sourceRule: SourceRule, isUrl: boolean): string {
    const rule = sourceRule.rule;

    switch (sourceRule.mode) {
      case RuleMode.Js:
        return this.evalJs(rule, content);

      case RuleMode.Json:
        return this.getJsonPathParser().extractValue(JSON.parse(String(content)) as Record<string, Object>, rule);

      case RuleMode.XPath:
        return this.getXPathParser().selectFirst(String(content), rule);

      case RuleMode.Regex:
        return this.getRegexMatch(String(content), rule);

      case RuleMode.CSS:
      case RuleMode.Default:
      default:
        if (isUrl) {
          return CssSelectorParser.extractValue(String(content), rule);
        }
        return CssSelectorParser.extractValue(String(content), rule);
    }
  }

  private getStringListInternal(content: string | string[], sourceRule: SourceRule): string[] {
    const rule = sourceRule.rule;

    switch (sourceRule.mode) {
      case RuleMode.Js:
        return [this.evalJs(rule, content)];

      case RuleMode.Json:
        const jsonResult = this.getJsonPathParser().resolvePath(JSON.parse(String(content)) as Object, rule);
        if (Array.isArray(jsonResult)) {
          return jsonResult.map((item: Object) => String(item));
        }
        return [String(jsonResult)];

      case RuleMode.XPath:
        return this.getXPathParser().selectElements(String(content), rule);

      case RuleMode.Regex:
        return this.getRegexMatchAll(String(content), rule);

      case RuleMode.CSS:
      case RuleMode.Default:
      default:
        return CssSelectorParser.selectElements(String(content), rule);
    }
  }

  private getElementsInternal(content: string | string[], sourceRule: SourceRule): string[] {
    const rule = sourceRule.rule;

    switch (sourceRule.mode) {
      case RuleMode.Regex:
        return this.getRegexMatchAll(String(content), rule);

      case RuleMode.Js:
        return [this.evalJs(rule, content)];

      case RuleMode.Json:
        const jsonResult = this.getJsonPathParser().resolvePath(JSON.parse(String(content)) as Object, rule);
        if (Array.isArray(jsonResult)) {
          return jsonResult.map((item: Object) => String(item));
        }
        return [String(jsonResult)];

      case RuleMode.XPath:
        return this.getXPathParser().selectElements(String(content), rule);

      case RuleMode.CSS:
      case RuleMode.Default:
      default:
        return CssSelectorParser.selectElements(String(content), rule);
    }
  }

  private putRuleVariables(sourceRule: SourceRule): void {
    sourceRule.putMap.forEach((value, key) => {
      const resolvedValue = this.getString(value);
      this.variableScope.put(key, resolvedValue);
    });
  }

  private applyReplaceRegex(result: string, rule: SourceRule): string {
    if (!rule.replaceRegex) {
      return result;
    }

    const regex = RuleCache.getOrPutRegex(rule.replaceRegex, () => {
      try {
        return new RegExp(rule.replaceRegex, 'g');
      } catch (e) {
        return null;
      }
    });

    if (!regex) {
      return result;
    }

    if (rule.replaceFirst) {
      const match = result.match(regex);
      if (match) {
        return match[0].replace(new RegExp(rule.replaceRegex), rule.replacement);
      }
      return '';
    } else {
      return result.replace(regex, rule.replacement);
    }
  }

  private getRegexMatch(content: string, pattern: string): string {
    try {
      const regex = RuleCache.getOrPutRegex(pattern, () => {
        try {
          return new RegExp(pattern, 'gi');
        } catch (e) {
          return null;
        }
      });

      if (!regex) {
        return '';
      }

      const match = content.match(regex);
      return match ? (match[1] || match[0]) : '';
    } catch (e) {
      Logger.error(EnhancedRuleEngine.TAG, `正则匹配失败: ${e}`);
      return '';
    }
  }

  private getRegexMatchAll(content: string, pattern: string): string[] {
    try {
      const regex = RuleCache.getOrPutRegex(pattern, () => {
        try {
          return new RegExp(pattern, 'gi');
        } catch (e) {
          return null;
        }
      });

      if (!regex) {
        return [];
      }

      const matches: string[] = [];
      let match: RegExpExecArray | null = null;
      const globalRegex = new RegExp(regex.source, 'g');

      while ((match = globalRegex.exec(content)) !== null) {
        const group1 = match[1];
        const matchedValue = group1 !== undefined && group1.length > 0 ? group1 : match[0];
        matches.push(matchedValue);
      }

      return matches;
    } catch (e) {
      Logger.error(EnhancedRuleEngine.TAG, `正则全局匹配失败: ${e}`);
      return [];
    }
  }

  private evalJs(jsCode: string, _result: string | string[]): string {
    Logger.warn(EnhancedRuleEngine.TAG, `JS执行需要通过ScriptEngine: ${jsCode.substring(0, 50)}...`);
    return '';
  }

  private getXPathParser(): XPathParser {
    if (!this.xpathParser) {
      this.xpathParser = new XPathParser();
    }
    return this.xpathParser;
  }

  private getJsonPathParser(): JsonPathParser {
    if (!this.jsonPathParser) {
      this.jsonPathParser = new JsonPathParser();
    }
    return this.jsonPathParser;
  }

  private getAbsoluteUrl(url: string): string {
    if (!url) {
      return this.context.baseUrl;
    }

    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('//')) {
      return url.startsWith('//') ? 'https:' + url : url;
    }

    if (url.startsWith('data:')) {
      return url;
    }

    const base = this.context.redirectUrl || this.context.baseUrl;
    if (!base) {
      return url;
    }

    try {
      if (url.startsWith('/')) {
        const protocolEnd = base.indexOf('://');
        const hostEnd = base.indexOf('/', protocolEnd + 3);
        if (protocolEnd > 0) {
          const protocol = base.substring(0, protocolEnd);
          const host = hostEnd > 0 ? base.substring(protocolEnd + 3, hostEnd) : base.substring(protocolEnd + 3);
          return `${protocol}://${host}${url}`;
        }
        return url;
      } else {
        const lastSlashIndex = base.lastIndexOf('/');
        if (lastSlashIndex > 0) {
          return base.substring(0, lastSlashIndex + 1) + url;
        }
        return base + '/' + url;
      }
    } catch (e) {
      return url;
    }
  }

  putVariable(key: string, value: string): void {
    this.variableScope.put(key, value);
    this.context.variables.set(key, value);
  }

  getVariable(key: string): string {
    return this.variableScope.get(key);
  }

  hasVariable(key: string): boolean {
    return this.variableScope.has(key);
  }

  pushScope(): void {
    this.variableScope.pushScope();
  }

  popScope(): void {
    this.variableScope.popScope();
  }

  clearContext(): void {
    this.context = {
      variables: new Map(),
      baseUrl: '',
      content: '',
      isJson: false,
      redirectUrl: ''
    };
    this.variableScope.clear();
    this.xpathParser = null;
    this.jsonPathParser = null;
  }

  static clearCache(): void {
    RuleCache.clear();
  }
}

export default EnhancedRuleEngine;
