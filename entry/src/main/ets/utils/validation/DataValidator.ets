import { Logger } from "../performance/Logger";
import { HtmlUtils } from "../content/HtmlUtils";
import { TextCleaner } from "../../core/utils/TextCleaner";
import { StringUtils } from "../content/StringUtils";

export interface ValidationRule {
  name: string;
  required: boolean;
  minLength?: number;
  maxLength?: number;
  pattern?: RegExp;
  validator?: (value: string) => boolean;
  errorMessage?: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
  cleanedData?: string;
  metadata?: MetadataRecord;
}

export interface MetadataRecord {
  originalLength?: number;
  cleanedLength?: number;
  reductionRatio?: number;
  replacementRatio?: number;
  fieldCount?: number;
  hasTitle?: boolean;
  hasAuthor?: boolean;
  hasCover?: boolean;
  hasDescription?: boolean;
}

export interface CleaningOptions {
  stripHtmlTags: boolean;
  normalizeWhitespace: boolean;
  removeScripts: boolean;
  removeStyles: boolean;
  removeComments: boolean;
  decodeEntities: boolean;
  trimContent: boolean;
  removeEmptyLines: boolean;
  maxLineLength: number;
}

export interface BookDataValidation {
  title: ValidationRule;
  author: ValidationRule;
  coverUrl: ValidationRule;
  bookUrl: ValidationRule;
  description: ValidationRule;
  lastChapter: ValidationRule;
  category: ValidationRule;
}

const DEFAULT_CLEANING_OPTIONS: CleaningOptions = {
  stripHtmlTags: false,
  normalizeWhitespace: true,
  removeScripts: true,
  removeStyles: true,
  removeComments: true,
  decodeEntities: true,
  trimContent: true,
  removeEmptyLines: true,
  maxLineLength: 10000
};

const SUSPICIOUS_PATTERNS: RegExp[] = [
  /<script[^>]*>[\s\S]*?<\/script>/gi,
  /javascript:/gi,
  /on\w+\s*=/gi,
  /data:text\/html/gi,
  /vbscript:/gi
];

const JUNK_PATTERNS: RegExp[] = [
  /广告[\s\S]*?(?=<|$)/gi,
  /推荐阅读[\s\S]*?(?=<|$)/gi,
  /猜你喜欢[\s\S]*?(?=<|$)/gi,
  /相关推荐[\s\S]*?(?=<|$)/gi,
  /热门推荐[\s\S]*?(?=<|$)/gi
];

export class DataValidator {
  private static instance: DataValidator | null = null;

  private constructor() {
    // 使用 HtmlUtils 替代 htmlEntityMap
  }

  static getInstance(): DataValidator {
    if (!DataValidator.instance) {
      DataValidator.instance = new DataValidator();
    }
    return DataValidator.instance;
  }

  validateContent(content: string, options?: CleaningOptions): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];
    const metadata: MetadataRecord = {};

    if (!content || content.length === 0) {
      return {
        valid: false,
        errors: ['内容为空'],
        warnings: []
      };
    }

    metadata.originalLength = content.length;

    const replacementCount = (content.match(/\uFFFD/g) || []).length;
    const replacementRatio = replacementCount / content.length;
    if (replacementRatio > 0.05) {
      errors.push(`内容包含 ${(replacementRatio * 100).toFixed(1)}% 的乱码字符`);
    } else if (replacementRatio > 0.01) {
      warnings.push(`内容包含少量乱码字符 (${(replacementRatio * 100).toFixed(1)}%)`);
    }
    metadata.replacementRatio = replacementRatio;

    for (const pattern of SUSPICIOUS_PATTERNS) {
      if (pattern.test(content)) {
        warnings.push(`检测到可疑内容: ${pattern.source.substring(0, 30)}...`);
      }
    }

    const cleanedData = this.cleanContent(content, options);
    metadata.cleanedLength = cleanedData.length;
    metadata.reductionRatio = 1 - (cleanedData.length / content.length);

    const valid = errors.length === 0;

    return {
      valid,
      errors,
      warnings,
      cleanedData,
      metadata
    };
  }

  validateBookData(data: Map<string, string>): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    const title = data.get('title') || '';
    const bookUrl = data.get('bookUrl') || '';
    const coverUrl = data.get('coverUrl') || '';
    const author = data.get('author') || '';
    const description = data.get('description') || '';

    if (!title || title.trim().length === 0) {
      errors.push('书名不能为空');
    } else if (title.length < 2) {
      warnings.push('书名过短');
    } else if (title.length > 100) {
      warnings.push('书名过长，可能包含多余内容');
    }

    if (!bookUrl || bookUrl.trim().length === 0) {
      errors.push('书籍链接不能为空');
    } else if (!this.isValidUrl(bookUrl)) {
      errors.push('书籍链接格式无效');
    }

    if (coverUrl && !this.isValidUrl(coverUrl)) {
      warnings.push('封面链接格式无效');
    }

    if (author && author.length > 50) {
      warnings.push('作者名称过长');
    }

    if (description && description.length < 10) {
      warnings.push('简介内容过短');
    }

    const valid = errors.length === 0;

    const metadata: MetadataRecord = {
      fieldCount: data.size,
      hasTitle: !!title,
      hasAuthor: !!author,
      hasCover: !!coverUrl,
      hasDescription: !!description
    };

    return {
      valid,
      errors,
      warnings,
      metadata
    };
  }

  validateChapterData(data: Map<string, string>): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    const title = data.get('title') || '';
    const url = data.get('url') || '';

    if (!title || title.trim().length === 0) {
      errors.push('章节标题不能为空');
    }

    if (!url || url.trim().length === 0) {
      errors.push('章节链接不能为空');
    } else if (!this.isValidUrl(url)) {
      errors.push('章节链接格式无效');
    }

    const valid = errors.length === 0;

    return {
      valid,
      errors,
      warnings
    };
  }

  cleanContent(content: string, options?: CleaningOptions): string {
    const opts: CleaningOptions = options ? this.mergeOptions(options) : DEFAULT_CLEANING_OPTIONS;
    let result = content;

    if (opts.removeComments) {
      result = result.replace(/<!--[\s\S]*?-->/g, '');
    }

    if (opts.removeScripts) {
      result = result.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    }

    if (opts.removeStyles) {
      result = result.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
    }

    if (opts.stripHtmlTags) {
      result = HtmlUtils.removeHtmlTags(result);
    }

    if (opts.decodeEntities) {
      result = HtmlUtils.decodeHtmlEntities(result);
    }

    for (const pattern of JUNK_PATTERNS) {
      result = result.replace(pattern, '');
    }

    if (opts.normalizeWhitespace) {
      result = TextCleaner.cleanLineBreaks(result);
      result = TextCleaner.normalizeWhitespace(result);
    }

    if (opts.removeEmptyLines) {
      result = result.replace(/\n\s*\n\s*\n/g, '\n\n');
    }

    if (opts.maxLineLength > 0) {
      const lines = result.split('\n');
      const truncatedLines: string[] = [];
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.length > opts.maxLineLength) {
          truncatedLines.push(line.substring(0, opts.maxLineLength) + '...');
        } else {
          truncatedLines.push(line);
        }
      }
      result = truncatedLines.join('\n');
    }

    if (opts.trimContent) {
      result = result.trim();
    }

    return result;
  }

  private mergeOptions(options: CleaningOptions): CleaningOptions {
    return {
      stripHtmlTags: options.stripHtmlTags !== undefined ? options.stripHtmlTags : DEFAULT_CLEANING_OPTIONS.stripHtmlTags,
      normalizeWhitespace: options.normalizeWhitespace !== undefined ? options.normalizeWhitespace : DEFAULT_CLEANING_OPTIONS.normalizeWhitespace,
      removeScripts: options.removeScripts !== undefined ? options.removeScripts : DEFAULT_CLEANING_OPTIONS.removeScripts,
      removeStyles: options.removeStyles !== undefined ? options.removeStyles : DEFAULT_CLEANING_OPTIONS.removeStyles,
      removeComments: options.removeComments !== undefined ? options.removeComments : DEFAULT_CLEANING_OPTIONS.removeComments,
      decodeEntities: options.decodeEntities !== undefined ? options.decodeEntities : DEFAULT_CLEANING_OPTIONS.decodeEntities,
      trimContent: options.trimContent !== undefined ? options.trimContent : DEFAULT_CLEANING_OPTIONS.trimContent,
      removeEmptyLines: options.removeEmptyLines !== undefined ? options.removeEmptyLines : DEFAULT_CLEANING_OPTIONS.removeEmptyLines,
      maxLineLength: options.maxLineLength !== undefined ? options.maxLineLength : DEFAULT_CLEANING_OPTIONS.maxLineLength
    };
  }

  private isValidUrl(url: string): boolean {
    return StringUtils.isValidUrl(url);
  }

  extractTextFromHtml(html: string): string {
    return HtmlUtils.extractText(html);
  }

  sanitizeUrl(url: string): string {
    if (!url) return '';

    let sanitized = url.trim();

    sanitized = sanitized.replace(/[\x00-\x1f\x7f]/g, '');

    try {
      const decoded = decodeURIComponent(sanitized);
      sanitized = encodeURIComponent(decoded);
    } catch {
      // URL 可能已经是编码状态
    }

    return sanitized;
  }

  normalizeBookTitle(title: string): string {
    if (!title) return '';

    let normalized = title.trim();

    normalized = normalized.replace(/【[^】]*】/g, '');
    normalized = normalized.replace(/\[[^\]]*\]/g, '');
    normalized = normalized.replace(/\([^)]*\)/g, '');

    normalized = normalized.replace(/\s+/g, ' ');

    normalized = normalized.trim();

    return normalized;
  }

  normalizeAuthorName(author: string): string {
    if (!author) return '';

    let normalized = author.trim();

    const prefixes = ['作者:', '作者：', '著:', '著：', '文:', '文：'];
    for (const prefix of prefixes) {
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length).trim();
      }
    }

    normalized = normalized.replace(/[\/、,，].*$/, '').trim();

    return normalized;
  }
}

export default DataValidator.getInstance();
