/**
 * ParserAdapter - 解析器适配器基类
 * 提供通用的解析逻辑和可扩展架构
 */

import {
  IParserAdapter,
  ParserType,
  ParseOptions,
  ParseResult,
  ParseStatus,
  ValidationResult,
  ValidateResultWithoutValid,
  FormatOptions,
  ParseErrorInfo,
  ParseWarningInfo,
  ParseMetadata
} from '../interfaces/IParser';
import { ParserError, ParserWarning, ParserErrorCode, ParseResultBuilder } from './ParserError';
import { Logger } from '../utils/Logger';
import { util } from '@kit.ArkTS';

interface CacheEntry<T> {
  result: ParseResult<T>;
  timestamp: number;
}

interface CacheStats {
  size: number;
  maxSize: number;
  ttl: number;
}

class DefaultParseOptions implements ParseOptions {
  encoding: string = 'utf-8';
  strict: boolean = false;
  maxDepth: number = 100;
  timeout: number = 30000;
  skipCache: boolean = false;
}
export abstract class ParserAdapter<T> implements IParserAdapter<T> {
  abstract readonly type: ParserType;
  abstract readonly name: string;
  abstract readonly version: string;
  abstract readonly supportedExtensions: string[];
  abstract readonly priority: number;

  protected readonly defaultOptions: ParseOptions = new DefaultParseOptions();

  async parse(content: string | ArrayBuffer, options?: ParseOptions): Promise<ParseResult<T>> {
    const startTime: number = Date.now();
    const mergedOptions: ParseOptions = this.mergeOptions(options);

    try {
      this.validateInput(content);

      const stringContent: string = this.toStringContent(content, mergedOptions.encoding);

      const result: ParseResult<T> = await this.doParse(stringContent, mergedOptions);

      const parseTime: number = Date.now() - startTime;
      result.metadata.parseTime = parseTime;
      result.metadata.dataSize = stringContent.length;

      return result;
    } catch (error) {
      const parseTime: number = Date.now() - startTime;
      return this.createErrorResult(error as Error, mergedOptions, parseTime);
    }
  }

  parseSync(content: string | ArrayBuffer, options?: ParseOptions): ParseResult<T> {
    const startTime: number = Date.now();
    const mergedOptions: ParseOptions = this.mergeOptions(options);

    try {
      this.validateInput(content);

      const stringContent: string = this.toStringContent(content, mergedOptions.encoding);

      const result: ParseResult<T> = this.doParseSync(stringContent, mergedOptions);

      const parseTime: number = Date.now() - startTime;
      result.metadata.parseTime = parseTime;
      result.metadata.dataSize = stringContent.length;

      return result;
    } catch (error) {
      const parseTime: number = Date.now() - startTime;
      return this.createErrorResult(error as Error, mergedOptions, parseTime);
    }
  }

  validate(content: string | ArrayBuffer, options?: ParseOptions): ValidationResult {
    const errors: ParseErrorInfo[] = [];
    const warnings: ParseWarningInfo[] = [];

    try {
      this.validateInput(content);

      const stringContent = this.toStringContent(content, options?.encoding ?? 'utf-8');

      const customValidation: ValidateResultWithoutValid = this.doValidate(stringContent, options);
      for (const error of customValidation.errors) {
        errors.push(error);
      }
      for (const warning of customValidation.warnings) {
        warnings.push(warning);
      }
    } catch (error) {
      if (error instanceof ParserError) {
        errors.push(error.toErrorInfo());
      } else {
        errors.push({
          code: ParserErrorCode.VALIDATION_FAILED,
          message: (error as Error).message,
          severity: 'error'
        });
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings
    };
  }

  abstract format(data: T, options?: FormatOptions): string;

  canParse(content: string | ArrayBuffer, hint?: string): boolean {
    if (hint) {
      const ext: string = hint.toLowerCase().replace(/^\./, '');
      return this.supportedExtensions.includes(ext);
    }

    const stringContent: string = this.toStringContent(content, 'utf-8');
    return this.detectContent(stringContent);
  }

  async adapt(content: string | ArrayBuffer, options?: ParseOptions): Promise<ParseResult<T>> {
    return this.parse(content, options);
  }

  adaptSync(content: string | ArrayBuffer, options?: ParseOptions): ParseResult<T> {
    return this.parseSync(content, options);
  }

  protected abstract doParse(content: string, options: ParseOptions): Promise<ParseResult<T>>;
  protected abstract doParseSync(content: string, options: ParseOptions): ParseResult<T>;
  protected abstract doValidate(content: string, options?: ParseOptions): ValidateResultWithoutValid;
  protected abstract detectContent(content: string): boolean;

  protected validateInput(content: string | ArrayBuffer): void {
    if (content === null || content === undefined) {
      throw ParserError.invalidInput(this.type, 'Content cannot be null or undefined');
    }

    if (typeof content === 'string' && content.length === 0) {
      throw ParserError.emptyInput(this.type);
    }

    if (content instanceof ArrayBuffer && content.byteLength === 0) {
      throw ParserError.emptyInput(this.type);
    }
  }

  protected mergeOptions(options?: ParseOptions): ParseOptions {
    const merged: ParseOptions = {
      encoding: this.defaultOptions.encoding,
      strict: this.defaultOptions.strict,
      maxDepth: this.defaultOptions.maxDepth,
      timeout: this.defaultOptions.timeout,
      skipCache: this.defaultOptions.skipCache
    };

    if (options !== undefined) {
      if (options.encoding !== undefined) {
        merged.encoding = options.encoding;
      }
      if (options.strict !== undefined) {
        merged.strict = options.strict;
      }
      if (options.maxDepth !== undefined) {
        merged.maxDepth = options.maxDepth;
      }
      if (options.timeout !== undefined) {
        merged.timeout = options.timeout;
      }
      if (options.cacheKey !== undefined) {
        merged.cacheKey = options.cacheKey;
      }
      if (options.skipCache !== undefined) {
        merged.skipCache = options.skipCache;
      }
      if (options.customRules !== undefined) {
        merged.customRules = options.customRules;
      }
    }

    return merged;
  }

  protected toStringContent(content: string | ArrayBuffer, encoding: string = 'utf-8'): string {
    if (typeof content === 'string') {
      return content;
    }

    const decoder: util.TextDecoder = new util.TextDecoder(encoding);
    return decoder.decodeToString(new Uint8Array(content));
  }

  protected createErrorResult(error: Error, _options: ParseOptions, parseTime: number): ParseResult<T> {
    const parserError: ParserError = ParserError.fromError(error, this.type);
    const errorInfo: ParseErrorInfo = parserError.toErrorInfo();

    const metadata: ParseMetadata = {
      parserType: this.type,
      parseTime,
      dataSize: 0,
      cached: false,
      timestamp: Date.now(),
      version: this.version
    };

    return {
      data: new Object() as T,
      status: ParseStatus.FAILED,
      errors: [errorInfo],
      warnings: [],
      metadata
    };
  }

  protected createMetadata(_options: ParseOptions, cached: boolean = false): Partial<ParseMetadata> {
    return {
      parserType: this.type,
      cached,
      timestamp: Date.now(),
      version: this.version
    };
  }

  protected addWarning(builder: ParseResultBuilder<T>, code: string, message: string): void {
    builder.addWarning(new ParserWarning(code, message));
  }

  protected logPerformance(parseTime: number, dataSize: number): void {
    if (parseTime > 1000) {
      Logger.warn(
        `ParserAdapter.${this.name}`,
        `Slow parse detected: ${parseTime}ms for ${dataSize} bytes`
      );
    }
  }
}

export abstract class CachingParserAdapter<T> extends ParserAdapter<T> {
  private cache: Map<string, CacheEntry<T>> = new Map();
  private readonly cacheTTL: number = 5 * 60 * 1000; // 5 minutes
  private readonly maxCacheSize: number = 100;

  override async parse(content: string | ArrayBuffer, options?: ParseOptions): Promise<ParseResult<T>> {
    const cacheKey = options?.cacheKey ?? this.generateCacheKey(content);

    if (!options?.skipCache) {
      const cached = this.getFromCache(cacheKey);
      if (cached) {
        cached.metadata.cached = true;
        return cached;
      }
    }

    const result = await super.parse(content, options);

    if (result.status !== 'failed' && !options?.skipCache) {
      this.setCache(cacheKey, result);
    }

    return result;
  }

  protected generateCacheKey(content: string | ArrayBuffer): string {
    const str: string = typeof content === 'string' ? content : this.toStringContent(content);
    let hash: number = 0;
    for (let i = 0; i < Math.min(str.length, 1000); i++) {
      const char: number = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return `${this.type}_${hash}_${str.length}`;
  }

  protected getFromCache(key: string): ParseResult<T> | null {
    const cached = this.cache.get(key);
    if (!cached) {
      return null;
    }

    if (Date.now() - cached.timestamp > this.cacheTTL) {
      this.cache.delete(key);
      return null;
    }

    return cached.result;
  }

  protected setCache(key: string, result: ParseResult<T>): void {
    if (this.cache.size >= this.maxCacheSize) {
      this.evictOldest();
    }

    this.cache.set(key, {
      result,
      timestamp: Date.now()
    });
  }

  private evictOldest(): void {
    let oldestKey: string | null = null;
    let oldestTime: number = Infinity;

    this.cache.forEach((value: CacheEntry<T>, key: string) => {
      if (value.timestamp < oldestTime) {
        oldestTime = value.timestamp;
        oldestKey = key;
      }
    });

    if (oldestKey) {
      this.cache.delete(oldestKey);
    }
  }

  clearCache(): void {
    this.cache.clear();
  }

  getCacheStats(): CacheStats {
    const stats: CacheStats = {
      size: this.cache.size,
      maxSize: this.maxCacheSize,
      ttl: this.cacheTTL
    };
    return stats;
  }
}
