import {
  ContentFilterConfig,
  ReplaceRule,
  FilterRule,
  AD_KEYWORDS,
  DEFAULT_FILTER_CONFIG,
  validateReplaceRule,
  matchesScope
} from '../models/ContentFilter';
import { Logger } from './Logger';

function copyContentFilterConfig(source: ContentFilterConfig): ContentFilterConfig {
  return {
    replaceRules: source.replaceRules.slice(),
    filterRules: source.filterRules.slice(),
    enableAdFilter: source.enableAdFilter,
    enableScriptFilter: source.enableScriptFilter,
    enableStyleFilter: source.enableStyleFilter,
    chineseConvertType: source.chineseConvertType
  };
}

function copyReplaceRule(rule: ReplaceRule): ReplaceRule {
  return {
    id: rule.id,
    name: rule.name,
    group: rule.group,
    pattern: rule.pattern,
    replacement: rule.replacement,
    scope: rule.scope,
    scopeTitle: rule.scopeTitle,
    scopeContent: rule.scopeContent,
    excludeScope: rule.excludeScope,
    isEnabled: rule.isEnabled,
    isRegex: rule.isRegex,
    timeoutMillisecond: rule.timeoutMillisecond,
    order: rule.order,
    createTime: rule.createTime,
    updateTime: rule.updateTime
  };
}

export class ContentFilter {
  private static readonly TAG = 'ContentFilter';
  private config: ContentFilterConfig;
  private regexCache: Map<string, RegExp> = new Map();

  constructor(config?: ContentFilterConfig) {
    if (config) {
      this.config = copyContentFilterConfig(config);
    } else {
      this.config = copyContentFilterConfig(DEFAULT_FILTER_CONFIG);
    }
  }

  setConfig(config: ContentFilterConfig): void {
    this.config = config;
    this.regexCache.clear();
  }

  getConfig(): ContentFilterConfig {
    return this.config;
  }

  filter(content: string, bookName?: string, bookOrigin?: string): string {
    if (!content) {
      return '';
    }

    let result = content;

    result = this.applyFilterRules(result);
    result = this.applyReplaceRules(result, bookName, bookOrigin);
    result = this.filterAds(result);
    result = this.cleanWhitespace(result);

    return result;
  }

  filterWithRules(content: string, rules: ReplaceRule[], bookName?: string, bookOrigin?: string): string {
    if (!content) {
      return '';
    }

    let result = content;

    for (const rule of rules) {
      if (!rule.isEnabled) {
        continue;
      }

      if (bookName && bookOrigin && !matchesScope(rule, bookName, bookOrigin)) {
        continue;
      }

      const validation = validateReplaceRule(rule);
      if (!validation.valid) {
        Logger.warn(ContentFilter.TAG, `规则验证失败: ${validation.error}`);
        continue;
      }

      try {
        result = this.applyRule(result, rule);
      } catch (error) {
        Logger.warn(ContentFilter.TAG, `规则执行失败: ${rule.name}, ${error}`);
      }
    }

    return result;
  }

  private applyFilterRules(content: string): string {
    let result = content;

    for (const rule of this.config.filterRules) {
      if (!rule.enabled) {
        continue;
      }

      try {
        const regex = this.getOrCreateRegex(rule.pattern);
        result = result.replace(regex, '');
      } catch (error) {
        Logger.warn(ContentFilter.TAG, `过滤规则执行失败: ${rule.name}, ${error}`);
      }
    }

    return result;
  }

  private applyReplaceRules(content: string, bookName?: string, bookOrigin?: string): string {
    let result = content;

    const sortedRules = [...this.config.replaceRules].sort((a: ReplaceRule, b: ReplaceRule) => a.order - b.order);

    for (const rule of sortedRules) {
      if (!rule.isEnabled) {
        continue;
      }

      if (bookName && bookOrigin && !matchesScope(rule, bookName, bookOrigin)) {
        continue;
      }

      const validation = validateReplaceRule(rule);
      if (!validation.valid) {
        Logger.warn(ContentFilter.TAG, `替换规则验证失败: ${validation.error}`);
        continue;
      }

      try {
        result = this.applyRule(result, rule);
      } catch (error) {
        Logger.warn(ContentFilter.TAG, `替换规则执行失败: ${rule.name}, ${error}`);
      }
    }

    return result;
  }

  private applyRule(content: string, rule: ReplaceRule): string {
    if (!rule.pattern) {
      return content;
    }

    if (rule.isRegex) {
      try {
        const regex = this.getOrCreateRegex(rule.pattern);
        return content.replace(regex, rule.replacement);
      } catch (e) {
        Logger.warn(ContentFilter.TAG, `正则表达式无效: ${rule.pattern}`);
        return content.split(rule.pattern).join(rule.replacement);
      }
    } else {
      return content.split(rule.pattern).join(rule.replacement);
    }
  }

  private filterAds(content: string): string {
    if (!this.config.enableAdFilter) {
      return content;
    }

    let result = content;

    for (const keyword of AD_KEYWORDS) {
      const pattern = `[^。！？\\n]*${this.escapeRegex(keyword)}[^。！？\\n]*[。！？]?`;
      try {
        const regex = new RegExp(pattern, 'gi');
        result = result.replace(regex, '');
      } catch {
        // 忽略无效正则
      }
    }

    return result;
  }

  private cleanWhitespace(content: string): string {
    let result = content;

    result = result.replace(/[\r\n]{3,}/g, '\n\n');
    result = result.replace(/[ \t]{2,}/g, ' ');
    result = result.replace(/^\s+|\s+$/gm, '');
    result = result.trim();

    return result;
  }

  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  private getOrCreateRegex(pattern: string): RegExp {
    let regex = this.regexCache.get(pattern);
    
    if (!regex) {
      regex = new RegExp(pattern, 'gs');
      this.regexCache.set(pattern, regex);
    }
    
    return regex;
  }

  addReplaceRule(rule: ReplaceRule): void {
    const validation = validateReplaceRule(rule);
    if (!validation.valid) {
      Logger.warn(ContentFilter.TAG, `添加规则失败: ${validation.error}`);
      return;
    }
    this.config.replaceRules.push(rule);
    this.regexCache.clear();
  }

  removeReplaceRule(ruleId: string): void {
    this.config.replaceRules = this.config.replaceRules.filter((r: ReplaceRule) => r.id !== ruleId);
    this.regexCache.clear();
  }

  updateReplaceRule(rule: ReplaceRule): void {
    const validation = validateReplaceRule(rule);
    if (!validation.valid) {
      Logger.warn(ContentFilter.TAG, `更新规则失败: ${validation.error}`);
      return;
    }
    
    const index = this.config.replaceRules.findIndex((r: ReplaceRule) => r.id === rule.id);
    if (index >= 0) {
      const updatedRule = copyReplaceRule(rule);
      updatedRule.updateTime = Date.now();
      this.config.replaceRules[index] = updatedRule;
      this.regexCache.clear();
    }
  }

  addFilterRule(rule: FilterRule): void {
    this.config.filterRules.push(rule);
    this.regexCache.clear();
  }

  removeFilterRule(ruleId: string): void {
    this.config.filterRules = this.config.filterRules.filter((r: FilterRule) => r.id !== ruleId);
    this.regexCache.clear();
  }

  updateFilterRule(rule: FilterRule): void {
    const index = this.config.filterRules.findIndex((r: FilterRule) => r.id === rule.id);
    if (index >= 0) {
      this.config.filterRules[index] = rule;
      this.regexCache.clear();
    }
  }

  getTitleReplaceRules(): ReplaceRule[] {
    return this.config.replaceRules.filter((r: ReplaceRule) => r.scopeTitle && r.isEnabled);
  }

  getContentReplaceRules(): ReplaceRule[] {
    return this.config.replaceRules.filter((r: ReplaceRule) => r.scopeContent && r.isEnabled);
  }

  clearCache(): void {
    this.regexCache.clear();
  }

  static createDefault(): ContentFilter {
    return new ContentFilter(DEFAULT_FILTER_CONFIG);
  }
}

export default ContentFilter;
