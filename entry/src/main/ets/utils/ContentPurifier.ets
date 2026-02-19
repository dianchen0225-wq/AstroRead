/**
 * ContentPurifier - 内容净化器
 * 用于净化书籍简介和正文内容，移除广告、HTML标签、冗余信息等
 */

import { Logger } from './Logger';

export interface PurifyConfig {
  maxLength: number;
  removeHtmlTags: boolean;
  removeAds: boolean;
  removeDuplicatePunctuation: boolean;
  preserveParagraphs: boolean;
  adKeywords: string[];
  customBlacklist: string[];
}

export interface PurifyResult {
  original: string;
  purified: string;
  wasTruncated: boolean;
  removedAds: number;
  removedHtmlTags: number;
}

export interface RemoveAdsResult {
  text: string;
  removed: number;
}

const DEFAULT_AD_KEYWORDS: string[] = [
  '广告', '推广', '点击阅读', '下载APP', '下载app', '下载应用',
  'advertisement', 'download app', 'click here', 'click to read',
  '关注公众号', '扫码阅读', '微信关注', '微信公众号',
  '立即下载', '免费下载', '限时免费', '首月免费',
  '看全集', '阅读全文', '继续阅读', '更多精彩',
  'www.', 'http://', 'https://', '.com', '.cn',
  'APP下载', 'APP内阅读', '打开APP', '使用APP'
];

const DEFAULT_CONFIG: PurifyConfig = {
  maxLength: 500,
  removeHtmlTags: true,
  removeAds: true,
  removeDuplicatePunctuation: true,
  preserveParagraphs: true,
  adKeywords: DEFAULT_AD_KEYWORDS,
  customBlacklist: []
};

const HTML_TAG_REGEX = /<[^>]*>/g;
const HTML_ENTITY_NBSP = /&nbsp;/g;
const HTML_ENTITY_LT = /&lt;/g;
const HTML_ENTITY_GT = /&gt;/g;
const HTML_ENTITY_AMP = /&amp;/g;
const HTML_ENTITY_QUOT = /&quot;/g;
const HTML_ENTITY_APOS = /&#39;/g;
const HTML_ENTITY_HEX = /&#x([0-9a-fA-F]+);/g;
const HTML_ENTITY_DEC = /&#(\d+);/g;
const DUPLICATE_PUNCTUATION_REGEX = /([！？。，、；：""''（）【】《》\s])\1+/g;
const WHITESPACE_REGEX = /\s+/g;
const CONTROL_CHAR_REGEX = /[\x00-\x1F\x7F]/g;
const BR_TAG_REGEX = /<br\s*\/?>/gi;
const P_TAG_OPEN_REGEX = /<p[^>]*>/gi;
const P_TAG_CLOSE_REGEX = /<\/p>/gi;
const DIV_TAG_REGEX = /<\/?div[^>]*>/gi;
const SPAN_TAG_REGEX = /<\/?span[^>]*>/gi;

export class ContentPurifier {
  private static readonly TAG = 'ContentPurifier';
  private static instance: ContentPurifier | null = null;
  
  private config: PurifyConfig;
  private adKeywordPatterns: RegExp[] = [];
  
  private constructor(config?: Partial<PurifyConfig>) {
    this.config = this.mergeConfig(DEFAULT_CONFIG, config);
    this.buildAdPatterns();
  }
  
  static getInstance(config?: Partial<PurifyConfig>): ContentPurifier {
    if (!ContentPurifier.instance) {
      ContentPurifier.instance = new ContentPurifier(config);
    }
    return ContentPurifier.instance;
  }
  
  static resetInstance(): void {
    ContentPurifier.instance = null;
  }
  
  private mergeConfig(base: PurifyConfig, override?: Partial<PurifyConfig>): PurifyConfig {
    if (!override) return base;
    
    const merged: PurifyConfig = {
      maxLength: override.maxLength !== undefined ? override.maxLength : base.maxLength,
      removeHtmlTags: override.removeHtmlTags !== undefined ? override.removeHtmlTags : base.removeHtmlTags,
      removeAds: override.removeAds !== undefined ? override.removeAds : base.removeAds,
      removeDuplicatePunctuation: override.removeDuplicatePunctuation !== undefined ? override.removeDuplicatePunctuation : base.removeDuplicatePunctuation,
      preserveParagraphs: override.preserveParagraphs !== undefined ? override.preserveParagraphs : base.preserveParagraphs,
      adKeywords: override.adKeywords !== undefined ? override.adKeywords : base.adKeywords,
      customBlacklist: override.customBlacklist !== undefined ? override.customBlacklist : base.customBlacklist
    };
    return merged;
  }
  
  private buildAdPatterns(): void {
    this.adKeywordPatterns = [];
    const allKeywords: string[] = [];
    
    for (const keyword of this.config.adKeywords) {
      allKeywords.push(keyword);
    }
    for (const keyword of this.config.customBlacklist) {
      allKeywords.push(keyword);
    }
    
    for (const keyword of allKeywords) {
      try {
        const pattern = new RegExp(keyword, 'gi');
        this.adKeywordPatterns.push(pattern);
      } catch (e) {
        Logger.warn(ContentPurifier.TAG, `无效的关键词模式: ${keyword}`);
      }
    }
  }
  
  updateConfig(config: Partial<PurifyConfig>): void {
    this.config = this.mergeConfig(this.config, config);
    this.buildAdPatterns();
  }
  
  purify(raw: string): PurifyResult {
    if (!raw || raw.trim().length === 0) {
      return {
        original: raw || '',
        purified: '',
        wasTruncated: false,
        removedAds: 0,
        removedHtmlTags: 0
      };
    }
    
    let text = raw;
    let removedHtmlTags = 0;
    let removedAds = 0;
    
    if (this.config.preserveParagraphs) {
      text = text.replace(BR_TAG_REGEX, '\n');
      text = text.replace(P_TAG_CLOSE_REGEX, '\n');
      text = text.replace(P_TAG_OPEN_REGEX, '');
      text = text.replace(DIV_TAG_REGEX, '\n');
      text = text.replace(SPAN_TAG_REGEX, '');
    }
    
    if (this.config.removeHtmlTags) {
      const beforeCount = text.length;
      text = this.removeHtmlTags(text);
      removedHtmlTags = beforeCount - text.length;
    }
    
    text = this.decodeHtmlEntities(text);
    
    text = text.replace(CONTROL_CHAR_REGEX, '');
    
    if (this.config.removeAds) {
      const result = this.removeAdsContent(text);
      text = result.text;
      removedAds = result.removed;
    }
    
    if (this.config.removeDuplicatePunctuation) {
      text = text.replace(DUPLICATE_PUNCTUATION_REGEX, '$1');
    }
    
    text = text.replace(WHITESPACE_REGEX, ' ');
    
    text = this.cleanParagraphs(text);
    
    let wasTruncated = false;
    if (text.length > this.config.maxLength) {
      text = this.smartTruncate(text, this.config.maxLength);
      wasTruncated = true;
    }
    
    text = text.trim();
    return {
      original: raw,
      purified: text,
      wasTruncated: wasTruncated,
      removedAds: removedAds,
      removedHtmlTags: removedHtmlTags
    } as PurifyResult;
  }
  
  purifyIntro(raw: string): string {
    const result = this.purify(raw);
    return result.purified;
  }
  
  purifyContent(raw: string, maxLength: number = 0): string {
    const originalMaxLength = this.config.maxLength;
    if (maxLength > 0) {
      this.config.maxLength = maxLength;
    }
    
    const result = this.purify(raw);
    this.config.maxLength = originalMaxLength;
    
    return result.purified;
  }
  
  private removeHtmlTags(text: string): string {
    return text.replace(HTML_TAG_REGEX, '');
  }
  
  private decodeHtmlEntities(text: string): string {
    let result = text;
    
    result = result.replace(HTML_ENTITY_NBSP, ' ');
    result = result.replace(HTML_ENTITY_LT, '<');
    result = result.replace(HTML_ENTITY_GT, '>');
    result = result.replace(HTML_ENTITY_AMP, '&');
    result = result.replace(HTML_ENTITY_QUOT, '"');
    result = result.replace(HTML_ENTITY_APOS, "'");
    
    result = result.replace(HTML_ENTITY_HEX, (_match: string, hex: string): string => {
      const code = parseInt(hex, 16);
      return String.fromCharCode(code);
    });
    
    result = result.replace(HTML_ENTITY_DEC, (_match: string, dec: string): string => {
      const code = parseInt(dec, 10);
      return String.fromCharCode(code);
    });
    
    return result;
  }
  
  private removeAdsContent(text: string): RemoveAdsResult {
    let removed = 0;
    const lines = text.split('\n');
    const filteredLines: string[] = [];
    
    for (const line of lines) {
      const trimmedLine = line.trim();
      let isAd = false;
      
      if (trimmedLine.length === 0) {
        filteredLines.push(line);
        continue;
      }
      
      for (const pattern of this.adKeywordPatterns) {
        if (pattern.test(trimmedLine)) {
          isAd = true;
          removed++;
          break;
        }
      }
      
      if (!isAd) {
        filteredLines.push(line);
      }
    }
    const result: RemoveAdsResult = {
      text: filteredLines.join('\n'),
      removed: removed
    } as RemoveAdsResult;
    return result;
  }
  
  private cleanParagraphs(text: string): string {
    const lines = text.split('\n');
    const cleanedLines: string[] = [];
    
    for (const line of lines) {
      const trimmed = line.trim();
      
      if (trimmed.length === 0) {
        if (cleanedLines.length > 0 && cleanedLines[cleanedLines.length - 1].length > 0) {
          cleanedLines.push('');
        }
        continue;
      }
      
      if (/^[\d\s\-\.\,]+$/.test(trimmed)) {
        continue;
      }
      
      if (/^[^\w\u4e00-\u9fa5]+$/.test(trimmed)) {
        continue;
      }
      
      cleanedLines.push(trimmed);
    }
    
    while (cleanedLines.length > 0 && cleanedLines[cleanedLines.length - 1].length === 0) {
      cleanedLines.pop();
    }
    
    return cleanedLines.join('\n').replace(/\n{3,}/g, '\n\n');
  }
  
  private smartTruncate(text: string, maxLength: number): string {
    if (text.length <= maxLength) {
      return text;
    }
    
    const truncateLength = maxLength - 3;
    if (truncateLength <= 0) {
      return '...';
    }
    
    let truncated = text.substring(0, truncateLength);
    
    const lastSentenceEnd = Math.max(
      truncated.lastIndexOf('。'),
      truncated.lastIndexOf('！'),
      truncated.lastIndexOf('？'),
      truncated.lastIndexOf('.'),
      truncated.lastIndexOf('!'),
      truncated.lastIndexOf('?')
    );
    
    if (lastSentenceEnd > truncateLength * 0.5) {
      truncated = truncated.substring(0, lastSentenceEnd + 1);
    } else {
      const lastSpace = truncated.lastIndexOf(' ');
      if (lastSpace > truncateLength * 0.7) {
        truncated = truncated.substring(0, lastSpace);
      }
    }
    
    return truncated + '...';
  }
  
  static purifyStatic(raw: string, config?: Partial<PurifyConfig>): string {
    const purifier = ContentPurifier.getInstance(config);
    return purifier.purifyIntro(raw);
  }
  
  static purifyIntroStatic(raw: string): string {
    return ContentPurifier.purifyStatic(raw, { maxLength: 500 });
  }
  
  static purifyContentStatic(raw: string, maxLength: number = 0): string {
    const purifier = ContentPurifier.getInstance({ maxLength: maxLength > 0 ? maxLength : 10000 });
    return purifier.purifyContent(raw, maxLength);
  }
}

export function purifyIntro(raw: string): string {
  return ContentPurifier.purifyIntroStatic(raw);
}

export function purifyContent(raw: string, maxLength: number = 0): string {
  return ContentPurifier.purifyContentStatic(raw, maxLength);
}
