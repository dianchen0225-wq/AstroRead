import { Logger } from '../performance/Logger';
import { EntityDecoder } from '../../core/utils/EntityDecoder';
import { ReplaceRule } from '../../models/ContentFilter';

export { ReplaceRule };

export interface ContentProcessorConfig {
  removeDuplicateTitle: boolean;
  reSegment: boolean;
  chineseConvertType: 0 | 1 | 2;
  paragraphIndent: string;
  useReplaceRule: boolean;
}

export interface ProcessedContent {
  content: string[];
  sameTitleRemoved: boolean;
  appliedRules: ReplaceRule[];
}

export interface ProcessOptions {
  includeTitle?: boolean;
  useReplace?: boolean;
  chineseConvert?: boolean;
  reSegment?: boolean;
}

export interface RemoveTitleResult {
  content: string;
  removed: boolean;
}

export interface ReplaceResult {
  content: string;
  appliedRules: ReplaceRule[];
}

export const DEFAULT_PROCESSOR_CONFIG: ContentProcessorConfig = {
  removeDuplicateTitle: true,
  reSegment: true,
  chineseConvertType: 0,
  paragraphIndent: '　　',
  useReplaceRule: true
};

const SPACE_REGEX = /\s+/g;
const PUNCTUATION_REGEX = /^[\s\p{P}]+|[\s\p{P}]+$/gu;

function createConfigWithDefaults(base: ContentProcessorConfig, override?: Partial<ContentProcessorConfig>): ContentProcessorConfig {
  if (!override) return base;
  
  return {
    removeDuplicateTitle: override.removeDuplicateTitle !== undefined ? override.removeDuplicateTitle : base.removeDuplicateTitle,
    reSegment: override.reSegment !== undefined ? override.reSegment : base.reSegment,
    chineseConvertType: override.chineseConvertType !== undefined ? override.chineseConvertType : base.chineseConvertType,
    paragraphIndent: override.paragraphIndent !== undefined ? override.paragraphIndent : base.paragraphIndent,
    useReplaceRule: override.useReplaceRule !== undefined ? override.useReplaceRule : base.useReplaceRule
  };
}

function createDefaultProcessOptions(): ProcessOptions {
  return {
    includeTitle: true,
    useReplace: true,
    chineseConvert: true,
    reSegment: true
  };
}

function mergeProcessOptions(base: ProcessOptions, override?: ProcessOptions): ProcessOptions {
  if (!override) return base;
  
  return {
    includeTitle: override.includeTitle !== undefined ? override.includeTitle : base.includeTitle,
    useReplace: override.useReplace !== undefined ? override.useReplace : base.useReplace,
    chineseConvert: override.chineseConvert !== undefined ? override.chineseConvert : base.chineseConvert,
    reSegment: override.reSegment !== undefined ? override.reSegment : base.reSegment
  };
}

export class ContentProcessor {
  private static readonly TAG = 'ContentProcessor';
  private static instances: Map<string, ContentProcessor> = new Map();
  
  private bookName: string;
  private titleReplaceRules: ReplaceRule[] = [];
  private contentReplaceRules: ReplaceRule[] = [];
  private config: ContentProcessorConfig;
  
  private regexCache: Map<string, RegExp> = new Map();

  private constructor(bookName: string, config?: Partial<ContentProcessorConfig>) {
    this.bookName = bookName;
    this.config = createConfigWithDefaults(DEFAULT_PROCESSOR_CONFIG, config);
  }

  static getInstance(bookName: string, bookOrigin: string, config?: Partial<ContentProcessorConfig>): ContentProcessor {
    const key = `${bookName}_${bookOrigin}`;
    let instance = ContentProcessor.instances.get(key);
    
    if (!instance) {
      instance = new ContentProcessor(bookName, config);
      ContentProcessor.instances.set(key, instance);
    }
    
    return instance;
  }

  static clearInstance(bookName: string, bookOrigin: string): void {
    const key = `${bookName}_${bookOrigin}`;
    ContentProcessor.instances.delete(key);
  }

  static clearAllInstances(): void {
    ContentProcessor.instances.clear();
  }

  setReplaceRules(rules: ReplaceRule[]): void {
    this.titleReplaceRules = rules.filter((r: ReplaceRule) => r.scopeTitle && r.isEnabled);
    this.contentReplaceRules = rules.filter((r: ReplaceRule) => r.scopeContent && r.isEnabled);
    
    this.titleReplaceRules.sort((a: ReplaceRule, b: ReplaceRule) => a.order - b.order);
    this.contentReplaceRules.sort((a: ReplaceRule, b: ReplaceRule) => a.order - b.order);
    
    this.regexCache.clear();
  }

  setConfig(config: Partial<ContentProcessorConfig>): void {
    this.config = createConfigWithDefaults(this.config, config);
  }

  processContent(
    content: string,
    chapterTitle: string,
    options?: ProcessOptions
  ): ProcessedContent {
    const mergedOptions = mergeProcessOptions(createDefaultProcessOptions(), options);
    const includeTitle = mergedOptions.includeTitle || true;
    const useReplace = mergedOptions.useReplace || true;
    const chineseConvert = mergedOptions.chineseConvert || true;
    const reSegment = mergedOptions.reSegment || true;
    
    let processedContent = content;
    let sameTitleRemoved = false;
    const appliedRules: ReplaceRule[] = [];
    
    if (processedContent === 'null' || !processedContent) {
      processedContent = '';
    } else {
      if (this.config.removeDuplicateTitle) {
        const result = this.removeDuplicateTitle(processedContent, chapterTitle);
        processedContent = result.content;
        sameTitleRemoved = result.removed;
      }
      
      if (reSegment && this.config.reSegment) {
        processedContent = this.reSegment(processedContent);
      }
      
      if (chineseConvert && this.config.chineseConvertType !== 0) {
        processedContent = this.convertChinese(processedContent);
      }
      
      if (useReplace && this.config.useReplaceRule) {
        const replaceResult = this.applyReplaceRules(processedContent);
        processedContent = replaceResult.content;
        appliedRules.push(...replaceResult.appliedRules);
      }
    }
    
    if (includeTitle) {
      const displayTitle = this.getDisplayTitle(chapterTitle, useReplace && this.config.useReplaceRule);
      processedContent = displayTitle + '\n' + processedContent;
    }
    
    const contentLines = this.formatContent(processedContent, includeTitle);
    
    const result: ProcessedContent = {
      content: contentLines,
      sameTitleRemoved: sameTitleRemoved,
      appliedRules: appliedRules
    };
    return result;
  }

  processTitle(title: string, useReplace: boolean = true): string {
    let processedTitle = this.cleanText(title);
    
    if (useReplace && this.config.useReplaceRule) {
      for (const rule of this.titleReplaceRules) {
        if (!rule.pattern) continue;
        
        try {
          const before = processedTitle;
          processedTitle = this.applyReplace(processedTitle, rule);
          
          if (before !== processedTitle) {
            Logger.debug(ContentProcessor.TAG, `标题规则 "${rule.name}" 已应用`);
          }
        } catch (e) {
          Logger.warn(ContentProcessor.TAG, `标题替换规则 "${rule.name}" 执行失败: ${e}`);
        }
      }
    }
    
    return processedTitle;
  }

  private removeDuplicateTitle(content: string, chapterTitle: string): RemoveTitleResult {
    if (!chapterTitle) {
      const result: RemoveTitleResult = { content: content, removed: false };
      return result;
    }
    
    try {
      const escapedBookName = this.escapeRegex(this.bookName);
      const escapedTitle = this.escapeRegex(chapterTitle).replace(SPACE_REGEX, '\\s*');
      
      const pattern = new RegExp(
        `^([\\s\\p{P}|${escapedBookName}])*${escapedTitle}([\\s]*)`,
        'u'
      );
      
      const match = content.match(pattern);
      if (match) {
        const result: RemoveTitleResult = {
          content: content.substring(match[0].length),
          removed: true
        };
        return result;
      }
    } catch (e) {
      Logger.warn(ContentProcessor.TAG, `移除重复标题失败: ${e}`);
    }
    
    const result: RemoveTitleResult = { content: content, removed: false };
    return result;
  }

  private reSegment(content: string): string {
    let result = content;
    
    result = result.replace(/\r\n/g, '\n');
    result = result.replace(/\r/g, '\n');
    
    result = result.replace(/<br\s*\/?>/gi, '\n');
    result = result.replace(/<p[^>]*>/gi, '\n');
    result = result.replace(/<\/p>/gi, '\n');
    result = result.replace(/<div[^>]*>/gi, '\n');
    result = result.replace(/<\/div>/gi, '\n');
    
    result = result.replace(/<[^>]+>/g, '');
    
    result = EntityDecoder.decode(result);
    
    result = result.replace(/[ \t]+/g, ' ');
    result = result.replace(/\n{3,}/g, '\n\n');
    
    const lines = result.split('\n');
    const processedLines: string[] = [];
    
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed) {
        processedLines.push(trimmed);
      }
    }
    
    return processedLines.join('\n');
  }

  private convertChinese(content: string): string {
    if (this.config.chineseConvertType === 0) {
      return content;
    }
    
    return content;
  }

  private applyReplaceRules(content: string): ReplaceResult {
    const appliedRules: ReplaceRule[] = [];
    let result = content;
    
    result = result.split('\n').map((line: string) => line.trim()).join('\n');
    
    for (const rule of this.contentReplaceRules) {
      if (!rule.pattern) continue;
      
      try {
        const before = result;
        result = this.applyReplace(result, rule);
        
        if (before !== result) {
          appliedRules.push(rule);
          Logger.debug(ContentProcessor.TAG, `内容规则 "${rule.name}" 已应用`);
        }
      } catch (e) {
        Logger.warn(ContentProcessor.TAG, `内容替换规则 "${rule.name}" 执行失败: ${e}`);
        
        if (e instanceof Error && e.message.includes('timeout')) {
          Logger.warn(ContentProcessor.TAG, `规则 "${rule.name}" 执行超时，已禁用`);
        }
      }
    }
    
    const replaceResult: ReplaceResult = { content: result, appliedRules: appliedRules };
    return replaceResult;
  }

  private applyReplace(content: string, rule: ReplaceRule): string {
    if (rule.isRegex) {
      try {
        const regex = this.getOrCreateRegex(rule.pattern);
        return content.replace(regex, rule.replacement);
      } catch (e) {
        Logger.warn(ContentProcessor.TAG, `正则表达式无效: ${rule.pattern}`);
        return content.replace(rule.pattern, rule.replacement);
      }
    } else {
      return content.split(rule.pattern).join(rule.replacement);
    }
  }

  private getOrCreateRegex(pattern: string): RegExp {
    let regex = this.regexCache.get(pattern);
    
    if (!regex) {
      regex = new RegExp(pattern, 'gs');
      this.regexCache.set(pattern, regex);
    }
    
    return regex;
  }

  private getDisplayTitle(title: string, useReplace: boolean): string {
    return this.processTitle(title, useReplace);
  }

  private formatContent(content: string, includeTitle: boolean): string[] {
    const lines = content.split('\n');
    const result: string[] = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();
      
      if (trimmed) {
        if (result.length === 0 && includeTitle) {
          result.push(trimmed);
        } else {
          result.push(this.config.paragraphIndent + trimmed);
        }
      }
    }
    
    return result;
  }

  private cleanText(text: string): string {
    if (!text) return '';
    
    return text
      .replace(/[\r\n\t]+/g, ' ')
      .replace(/\s+/g, ' ')
      .replace(PUNCTUATION_REGEX, '')
      .trim();
  }

  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  getTitleReplaceRules(): ReplaceRule[] {
    const result: ReplaceRule[] = [];
    for (const rule of this.titleReplaceRules) {
      result.push(rule);
    }
    return result;
  }

  getContentReplaceRules(): ReplaceRule[] {
    const result: ReplaceRule[] = [];
    for (const rule of this.contentReplaceRules) {
      result.push(rule);
    }
    return result;
  }

  clearCache(): void {
    this.regexCache.clear();
  }
}

export default ContentProcessor;
