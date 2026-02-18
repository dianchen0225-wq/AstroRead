import { ContentFilterConfig, ReplaceRule, FilterRule, AD_KEYWORDS, DEFAULT_FILTER_CONFIG } from '../models/ContentFilter';
import { Logger } from './Logger';

export class ContentFilter {
  private static readonly TAG = 'ContentFilter';
  private config: ContentFilterConfig;

  constructor(config?: ContentFilterConfig) {
    this.config = config || { ...DEFAULT_FILTER_CONFIG };
  }

  setConfig(config: ContentFilterConfig): void {
    this.config = config;
  }

  getConfig(): ContentFilterConfig {
    return this.config;
  }

  filter(content: string): string {
    if (!content) {
      return '';
    }

    let result = content;

    result = this.applyFilterRules(result);
    result = this.applyReplaceRules(result);
    result = this.filterAds(result);
    result = this.cleanWhitespace(result);

    return result;
  }

  private applyFilterRules(content: string): string {
    let result = content;

    for (const rule of this.config.filterRules) {
      if (!rule.enabled) {
        continue;
      }

      try {
        const regex = new RegExp(rule.pattern, 'gis');
        result = result.replace(regex, '');
      } catch (error) {
        Logger.warn(ContentFilter.TAG, `过滤规则执行失败: ${rule.id}, ${error}`);
      }
    }

    return result;
  }

  private applyReplaceRules(content: string): string {
    let result = content;

    for (const rule of this.config.replaceRules) {
      if (!rule.enabled) {
        continue;
      }

      try {
        const regex = new RegExp(rule.pattern, 'gis');
        result = result.replace(regex, rule.replacement);
      } catch (error) {
        Logger.warn(ContentFilter.TAG, `替换规则执行失败: ${rule.id}, ${error}`);
      }
    }

    return result;
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
      } catch (error) {
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

  addReplaceRule(rule: ReplaceRule): void {
    this.config.replaceRules.push(rule);
  }

  removeReplaceRule(ruleId: string): void {
    this.config.replaceRules = this.config.replaceRules.filter(r => r.id !== ruleId);
  }

  updateReplaceRule(rule: ReplaceRule): void {
    const index = this.config.replaceRules.findIndex(r => r.id === rule.id);
    if (index >= 0) {
      this.config.replaceRules[index] = rule;
    }
  }

  addFilterRule(rule: FilterRule): void {
    this.config.filterRules.push(rule);
  }

  removeFilterRule(ruleId: string): void {
    this.config.filterRules = this.config.filterRules.filter(r => r.id !== ruleId);
  }

  updateFilterRule(rule: FilterRule): void {
    const index = this.config.filterRules.findIndex(r => r.id === rule.id);
    if (index >= 0) {
      this.config.filterRules[index] = rule;
    }
  }

  static createDefault(): ContentFilter {
    return new ContentFilter(DEFAULT_FILTER_CONFIG);
  }
}
