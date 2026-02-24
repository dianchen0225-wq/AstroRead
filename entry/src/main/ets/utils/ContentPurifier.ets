/**
 * ContentPurifier - 内容净化器
 * 用于净化书籍简介和正文内容，移除广告、HTML标签、冗余信息等
 * 优化版本：复用 HtmlUtils 和 TextCleaner 避免重复代码
 * 增强版：添加更完善的XSS防护和HTML净化规则
 */

import { Logger } from './Logger';
import { HtmlUtils, SanitizeOptions } from './HtmlUtils';
import { TextCleaner } from '../core/utils/TextCleaner';

export interface PurifyConfig {
  maxLength: number;
  removeHtmlTags: boolean;
  removeAds: boolean;
  removeDuplicatePunctuation: boolean;
  preserveParagraphs: boolean;
  adKeywords: string[];
  customBlacklist: string[];
  // 增强XSS防护配置
  enableXssProtection: boolean;
  removeScripts: boolean;
  removeIframes: boolean;
  removeDangerousAttrs: boolean;
  sanitizeUrls: boolean;
}

export interface PurifyResult {
  original: string;
  purified: string;
  wasTruncated: boolean;
  removedAds: number;
  removedHtmlTags: number;
  xssThreatsRemoved: number;
}

export interface RemoveAdsResult {
  text: string;
  removed: number;
}

export interface XssRemovalResult {
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
  customBlacklist: [],
  // 默认启用XSS防护
  enableXssProtection: true,
  removeScripts: true,
  removeIframes: true,
  removeDangerousAttrs: true,
  sanitizeUrls: true
};

// 正则表达式常量 - 仅保留ContentPurifier特有的模式
const DUPLICATE_PUNCTUATION_REGEX = /([！？。，、；：""''（）【】《》\s])\1+/g;
const BR_TAG_REGEX = /<br\s*\/?>/gi;
const P_TAG_OPEN_REGEX = /<p[^>]*>/gi;
const P_TAG_CLOSE_REGEX = /<\/p>/gi;
const DIV_TAG_REGEX = /<\/?div[^>]*>/gi;
const SPAN_TAG_REGEX = /<\/?span[^>]*>/gi;

// XSS防护 - 危险标签正则
const SCRIPT_TAG_REGEX = /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi;
const IFRAME_TAG_REGEX = /<iframe\b[^>]*>[\s\S]*?<\/iframe>/gi;
const OBJECT_TAG_REGEX = /<object\b[^>]*>[\s\S]*?<\/object>/gi;
const EMBED_TAG_REGEX = /<embed\b[^>]*\/?>/gi;
const APPLET_TAG_REGEX = /<applet\b[^>]*>[\s\S]*?<\/applet>/gi;
const FORM_TAG_REGEX = /<form\b[^>]*>[\s\S]*?<\/form>/gi;
const META_TAG_REGEX = /<meta\b[^>]*>/gi;
const BASE_TAG_REGEX = /<base\b[^>]*>/gi;
const LINK_TAG_REGEX = /<link\b[^>]*>/gi;
const STYLE_TAG_REGEX = /<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi;

// XSS防护 - 危险属性正则（事件处理器）
const EVENT_HANDLER_REGEX = /\s+on\w+\s*=\s*["'][^"']*["']/gi;
const EVENT_HANDLER_UNQUOTED_REGEX = /\s+on\w+\s*=\s*[^\s>]+/gi;

// XSS防护 - 危险URL协议
const DANGEROUS_URL_REGEX = /(href|src|action|formaction|background|poster)\s*=\s*["']?\s*(javascript|vbscript|data|file):[^"'>\s]*/gi;

// XSS防护 - CSS表达式
const CSS_EXPRESSION_REGEX = /expression\s*\([^)]*\)/gi;
const CSS_IMPORT_REGEX = /@import\s+/gi;
const CSS_URL_JAVASCRIPT_REGEX = /url\s*\(\s*["']?\s*javascript:/gi;

// XSS防护 - HTML实体编码绕过检测
const HTML_ENTITY_BYPASS_REGEX = /&#(?:x[0-9a-fA-F]+|[0-9]+);?/gi;

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
      customBlacklist: override.customBlacklist !== undefined ? override.customBlacklist : base.customBlacklist,
      // XSS防护配置
      enableXssProtection: override.enableXssProtection !== undefined ? override.enableXssProtection : base.enableXssProtection,
      removeScripts: override.removeScripts !== undefined ? override.removeScripts : base.removeScripts,
      removeIframes: override.removeIframes !== undefined ? override.removeIframes : base.removeIframes,
      removeDangerousAttrs: override.removeDangerousAttrs !== undefined ? override.removeDangerousAttrs : base.removeDangerousAttrs,
      sanitizeUrls: override.sanitizeUrls !== undefined ? override.sanitizeUrls : base.sanitizeUrls
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
        removedHtmlTags: 0,
        xssThreatsRemoved: 0
      };
    }
    
    let text = raw;
    let removedHtmlTags = 0;
    let removedAds = 0;
    let xssThreatsRemoved = 0;
    
    // 第一步：XSS防护 - 移除危险标签和属性
    if (this.config.enableXssProtection) {
      const xssResult = this.removeXssThreats(text);
      text = xssResult.text;
      xssThreatsRemoved = xssResult.removed;
    }
    
    if (this.config.preserveParagraphs) {
      text = text.replace(BR_TAG_REGEX, '\n');
      text = text.replace(P_TAG_CLOSE_REGEX, '\n');
      text = text.replace(P_TAG_OPEN_REGEX, '');
      text = text.replace(DIV_TAG_REGEX, '\n');
      text = text.replace(SPAN_TAG_REGEX, '');
    }
    
    if (this.config.removeHtmlTags) {
      const beforeCount = text.length;
      text = HtmlUtils.removeHtmlTags(text);
      removedHtmlTags = beforeCount - text.length;
    }
    
    text = HtmlUtils.decodeHtmlEntities(text);
    
    text = TextCleaner.removeControlChars(text);
    
    if (this.config.removeAds) {
      const result = this.removeAdsContent(text);
      text = result.text;
      removedAds = result.removed;
    }
    
    if (this.config.removeDuplicatePunctuation) {
      text = text.replace(DUPLICATE_PUNCTUATION_REGEX, '$1');
    }
    
    text = TextCleaner.cleanWhitespace(text);
    
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
      removedHtmlTags: removedHtmlTags,
      xssThreatsRemoved: xssThreatsRemoved
    } as PurifyResult;
  }
  
  /**
   * 移除XSS威胁
   * 增强版：多层次XSS防护
   */
  private removeXssThreats(text: string): XssRemovalResult {
    let removed = 0;
    let result = text;
    
    // 1. 移除危险标签
    if (this.config.removeScripts) {
      const before = result.length;
      result = result.replace(SCRIPT_TAG_REGEX, '');
      result = result.replace(STYLE_TAG_REGEX, '');
      removed += (before - result.length) > 0 ? 1 : 0;
    }
    
    if (this.config.removeIframes) {
      const before = result.length;
      result = result.replace(IFRAME_TAG_REGEX, '');
      result = result.replace(OBJECT_TAG_REGEX, '');
      result = result.replace(EMBED_TAG_REGEX, '');
      result = result.replace(APPLET_TAG_REGEX, '');
      removed += (before - result.length) > 0 ? 1 : 0;
    }
    
    // 移除其他危险标签
    const before = result.length;
    result = result.replace(FORM_TAG_REGEX, '');
    result = result.replace(META_TAG_REGEX, '');
    result = result.replace(BASE_TAG_REGEX, '');
    result = result.replace(LINK_TAG_REGEX, '');
    removed += (before - result.length) > 0 ? 1 : 0;
    
    // 2. 移除危险属性（事件处理器）
    if (this.config.removeDangerousAttrs) {
      result = result.replace(EVENT_HANDLER_REGEX, '');
      result = result.replace(EVENT_HANDLER_UNQUOTED_REGEX, '');
    }
    
    // 3. 清理危险URL协议
    if (this.config.sanitizeUrls) {
      result = result.replace(DANGEROUS_URL_REGEX, '$1=""');
    }
    
    // 4. 清理CSS表达式
    result = result.replace(CSS_EXPRESSION_REGEX, '');
    result = result.replace(CSS_IMPORT_REGEX, '');
    result = result.replace(CSS_URL_JAVASCRIPT_REGEX, 'url(');
    
    // 5. 使用HtmlUtils进行二次净化
    const sanitizeOptions: SanitizeOptions = {
      allowTags: ['p', 'br', 'b', 'i', 'u', 'strong', 'em', 'span', 'div', 'a', 'img', 
                  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'blockquote',
                  'pre', 'code', 'table', 'thead', 'tbody', 'tr', 'td', 'th'],
      allowAttrs: ['href', 'src', 'alt', 'title', 'class'],
      allowDataAttrs: false,
      removeComments: true
    };
    result = HtmlUtils.sanitizeHtml(result, sanitizeOptions);
    
    return { text: result, removed: removed };
  }
  
  /**
   * 静态方法：快速净化HTML内容（用于XSS防护）
   */
  static sanitizeHtml(html: string): string {
    const purifier = ContentPurifier.getInstance({ 
      enableXssProtection: true,
      removeScripts: true,
      removeIframes: true,
      removeDangerousAttrs: true,
      sanitizeUrls: true,
      removeHtmlTags: false,
      removeAds: false
    });
    const result = purifier.purify(html);
    return result.purified;
  }
  
  /**
   * 静态方法：净化并移除所有HTML标签
   */
  static sanitizeAndStripHtml(html: string): string {
    const purifier = ContentPurifier.getInstance({ 
      enableXssProtection: true,
      removeScripts: true,
      removeIframes: true,
      removeDangerousAttrs: true,
      sanitizeUrls: true,
      removeHtmlTags: true,
      removeAds: true
    });
    const result = purifier.purify(html);
    return result.purified;
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
