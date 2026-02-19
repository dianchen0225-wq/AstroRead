/**
 * ParserFacade - 解析器统一门面类
 * 提供统一的解析服务入口，支持缓存、异步处理、自动检测
 */

import {
  IParser,
  ParserType,
  ParseOptions,
  ParseResult,
  ValidationResult,
  FormatOptions,
  ParserRegistry,
  XmlNode,
  HtmlNode,
  CsvResult,
  JsonObject,
  JsonValue,
  ParseErrorInfo,
  ParseMetadata,
  ParseStatus
} from '../interfaces/IParser';
import { ParserAdapter } from './ParserAdapter';
import { ParserError, ParserErrorCode } from './ParserError';
import { JSONParserAdapter } from './adapters/JSONParserAdapter';
import { XMLParserAdapter } from './adapters/XMLParserAdapter';
import { HTMLParserAdapter } from './adapters/HTMLParserAdapter';
import { CSVParserAdapter } from './adapters/CSVParserAdapter';
import { Logger } from '../utils/Logger';
import { util } from '@kit.ArkTS';

// JSON 值包装接口
interface JsonValueWrapper {
  value: JsonValue;
}

export interface ParserFacadeOptions {
  enableCache?: boolean;
  cacheTTL?: number;
  maxCacheSize?: number;
  autoDetect?: boolean;
  defaultTimeout?: number;
}
export interface ParseResultCache {
  key: string;
  result: ParseResult<object>;
  timestamp: number;
  hits: number;
}

// 缓存统计条目接口
export interface CacheStatsEntry {
  key: string;
  hits: number;
  age: number;
}

// 缓存统计接口
export interface CacheStats {
  size: number;
  maxSize: number;
  ttl: number;
  hitRate: number;
  entries: CacheStatsEntry[];
}

// 批量解析项接口
export interface BatchParseItem {
  content: string | ArrayBuffer;
  type?: ParserType | string;
  options?: ParseOptions;
}

export class ParserFacade implements ParserRegistry {
  private static instance: ParserFacade | null = null;

  private parsers: Map<ParserType, ParserAdapter<object>> = new Map();
  private extensionMap: Map<string, ParserType> = new Map();
  private cache: Map<string, ParseResultCache> = new Map();

  private readonly TAG = 'ParserFacade';

  private options: Required<ParserFacadeOptions> = {
    enableCache: true,
    cacheTTL: 5 * 60 * 1000,
    maxCacheSize: 100,
    autoDetect: true,
    defaultTimeout: 30000
  };

  private constructor(options?: ParserFacadeOptions) {
    if (options) {
      this.options = this.mergeOptions(options);
    }

    this.registerDefaultAdapters();
  }

  private mergeOptions(options: ParserFacadeOptions): Required<ParserFacadeOptions> {
    const merged: Required<ParserFacadeOptions> = {
      enableCache: this.options.enableCache,
      cacheTTL: this.options.cacheTTL,
      maxCacheSize: this.options.maxCacheSize,
      autoDetect: this.options.autoDetect,
      defaultTimeout: this.options.defaultTimeout
    };

    if (options.enableCache !== undefined) {
      merged.enableCache = options.enableCache;
    }
    if (options.cacheTTL !== undefined) {
      merged.cacheTTL = options.cacheTTL;
    }
    if (options.maxCacheSize !== undefined) {
      merged.maxCacheSize = options.maxCacheSize;
    }
    if (options.autoDetect !== undefined) {
      merged.autoDetect = options.autoDetect;
    }
    if (options.defaultTimeout !== undefined) {
      merged.defaultTimeout = options.defaultTimeout;
    }

    return merged;
  }

  static getInstance(options?: ParserFacadeOptions): ParserFacade {
    if (!ParserFacade.instance) {
      ParserFacade.instance = new ParserFacade(options);
    }
    return ParserFacade.instance;
  }

  private registerDefaultAdapters(): void {
    this.register(new JSONParserAdapter());
    this.register(new XMLParserAdapter());
    this.register(new HTMLParserAdapter());
    this.register(new CSVParserAdapter());

    Logger.info(this.TAG, `Registered ${this.parsers.size} default parsers`);
  }
  register<T>(parser: IParser<T>): void {
    if (!(parser instanceof ParserAdapter)) {
      Logger.warn(this.TAG, `Parser ${parser.constructor.name} is not a ParserAdapter, some features may not work`);
      return;
    }

    const adapter: ParserAdapter<T> = parser;
    this.parsers.set(adapter.type, adapter as ParserAdapter<object>);

    for (const ext of adapter.supportedExtensions) {
      this.extensionMap.set(ext.toLowerCase(), adapter.type);
    }

    Logger.debug(this.TAG, `Registered parser: ${adapter.name} (${adapter.type})`);
  }

  unregister(type: ParserType): boolean {
    const parser: ParserAdapter<object> | undefined = this.parsers.get(type);
    if (!parser) {
      return false;
    }

    this.parsers.delete(type);

    for (const ext of parser.supportedExtensions) {
      this.extensionMap.delete(ext.toLowerCase());
    }

    return true;
  }

  get(type: ParserType): IParser<object> | undefined {
    return this.parsers.get(type);
  }
  getAll(): IParser<object>[] {
    return Array.from(this.parsers.values());
  }

  findByExtension(ext: string): IParser<object> | undefined {
    const normalizedExt = ext.toLowerCase().replace(/^\./, '');
    const type = this.extensionMap.get(normalizedExt);
    return type ? this.parsers.get(type) : undefined;
  }

  findByContent(content: string | ArrayBuffer): IParser<object> | undefined {
    for (const parser of this.parsers.values()) {
      if (parser.canParse(content)) {
        return parser;
      }
    }

    return undefined;
  }

  async parse<T extends object = object>(
    content: string | ArrayBuffer,
    type?: ParserType | string,
    options?: ParseOptions
  ): Promise<ParseResult<T>> {
    const startTime = Date.now();

    try {
      const parser = this.resolveParser(content, type);
      if (!parser) {
        throw ParserError.adapterNotFound(type as ParserType ?? ParserType.TEXT);
      }

      const cacheKey = this.generateCacheKey(content, parser.type, options);
      if (this.options.enableCache && !options?.skipCache) {
        const cached = this.getFromCache(cacheKey);
        if (cached) {
          Logger.debug(this.TAG, `Cache hit for ${parser.type}`);
          return cached as ParseResult<T>;
        }
      }

      const result: ParseResult<T> = await parser.parse(content, this.mergeParseOptions(options)) as ParseResult<T>;

      if (this.options.enableCache && result.status !== ParseStatus.FAILED) {
        this.setCache(cacheKey, result);
      }

      this.logPerformance(parser.type, Date.now() - startTime, content);

      return result;
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      Logger.error(this.TAG, `Parse failed: ${err.message}`);
      throw err;
    }
  }

  parseSync<T extends object = object>(
    content: string | ArrayBuffer,
    type?: ParserType | string,
    options?: ParseOptions
  ): ParseResult<T> {
    const parser = this.resolveParser(content, type);
    if (!parser) {
      throw ParserError.adapterNotFound(type as ParserType ?? ParserType.TEXT);
    }

    return parser.parseSync(content, options) as ParseResult<T>;
  }
  async parseJSON<T extends object = JsonObject>(content: string, options?: ParseOptions): Promise<ParseResult<T>> {
    return this.parse<T>(content, ParserType.JSON, options);
  }

  async parseXML(content: string, options?: ParseOptions): Promise<ParseResult<XmlNode>> {
    return this.parse<XmlNode>(content, ParserType.XML, options);
  }

  async parseHTML(content: string, options?: ParseOptions): Promise<ParseResult<HtmlNode>> {
    return this.parse<HtmlNode>(content, ParserType.HTML, options);
  }

  async parseCSV(content: string, options?: ParseOptions): Promise<ParseResult<CsvResult>> {
    return this.parse<CsvResult>(content, ParserType.CSV, options);
  }

  validate(
    content: string | ArrayBuffer,
    type?: ParserType | string,
    options?: ParseOptions
  ): ValidationResult {
    const parser = this.resolveParser(content, type);
    if (!parser) {
      const errorInfo: ParseErrorInfo = {
        code: ParserErrorCode.ADAPTER_NOT_FOUND,
        message: `No parser found for type: ${type}`,
        severity: 'critical'
      };
      return {
        valid: false,
        errors: [errorInfo],
        warnings: []
      };
    }

    return parser.validate(content, options);
  }

  format<T extends object = object>(
    data: T,
    type: ParserType,
    options?: FormatOptions
  ): string {
    const parser = this.parsers.get(type);
    if (!parser) {
      throw ParserError.adapterNotFound(type);
    }

    return parser.format(data, options);
  }

  formatJSON(data: JsonValue, options?: FormatOptions): string {
    const parser = this.parsers.get(ParserType.JSON);
    if (!parser) {
      throw ParserError.adapterNotFound(ParserType.JSON);
    }

    // JsonValue 可能是基本类型,需要转换为 object
    const wrapper: JsonValueWrapper = { value: data };
    const objectData = typeof data === 'object' && data !== null ? data : wrapper;
    return parser.format(objectData, options);
  }

  formatXML(data: XmlNode, options?: FormatOptions): string {
    return this.format(data, ParserType.XML, options);
  }

  formatHTML(data: HtmlNode, options?: FormatOptions): string {
    return this.format(data, ParserType.HTML, options);
  }

  formatCSV(data: CsvResult, options?: FormatOptions): string {
    return this.format(data, ParserType.CSV, options);
  }

  private resolveParser(content: string | ArrayBuffer, type?: ParserType | string): ParserAdapter<object> | undefined {
    if (type) {
      const parserType = typeof type === 'string' ? this.extensionMap.get(type.toLowerCase().replace(/^\./, '')) ?? type as ParserType : type;
      return this.parsers.get(parserType);
    }

    if (this.options.autoDetect) {
      return this.findByContent(content) as ParserAdapter<object>;
    }

    return undefined;
  }

  private generateCacheKey(content: string | ArrayBuffer, type: ParserType, options?: ParseOptions): string {
    if (options?.cacheKey) {
      return options.cacheKey;
    }

    const str = typeof content === 'string' ? content : new util.TextDecoder('utf-8').decodeToString(new Uint8Array(content));
    
    let contentHash = 0;
    for (let i = 0; i < Math.min(str.length, 1000); i++) {
      const char = str.charCodeAt(i);
      contentHash = ((contentHash << 5) - contentHash) + char;
      contentHash = contentHash & contentHash;
    }

    let optionsHash = 0;
    if (options?.customRules) {
      try {
        const customRules = options.customRules;
        customRules.forEach((value: string, key: string) => {
          for (let i = 0; i < Math.min(key.length, 50); i++) {
            const char = key.charCodeAt(i);
            optionsHash = ((optionsHash << 5) - optionsHash) + char;
            optionsHash = optionsHash & optionsHash;
          }
          for (let i = 0; i < Math.min(value.length, 100); i++) {
            const char = value.charCodeAt(i);
            optionsHash = ((optionsHash << 5) - optionsHash) + char;
            optionsHash = optionsHash & optionsHash;
          }
        });
      } catch (e) {
        Logger.warn(this.TAG, `Failed to hash customRules: ${e}`);
      }
    }

    return `${type}_${contentHash}_${str.length}_${optionsHash}`;
  }

  private getFromCache(key: string): ParseResult<object> | null {
    const cached = this.cache.get(key);
    if (!cached) {
      return null;
    }

    if (Date.now() - cached.timestamp > this.options.cacheTTL) {
      this.cache.delete(key);
      return null;
    }

    cached.hits++;
    return cached.result;
  }

  private setCache(key: string, result: ParseResult<object>): void {
    if (this.cache.size >= this.options.maxCacheSize) {
      this.evictLRU();
    }

    const cacheEntry: ParseResultCache = {
      key,
      result,
      timestamp: Date.now(),
      hits: 0
    };
    this.cache.set(key, cacheEntry);
  }

  private evictLRU(): void {
    let lruKey: string | null = null;
    let lruHits = Infinity;

    this.cache.forEach((value, key) => {
      if (value.hits < lruHits) {
        lruHits = value.hits;
        lruKey = key;
      }
    });

    if (lruKey) {
      this.cache.delete(lruKey);
      Logger.debug(this.TAG, `Evicted cache entry: ${lruKey}`);
    }
  }

  private logPerformance(type: ParserType, parseTime: number, content: string | ArrayBuffer): void {
    const size = typeof content === 'string' ? content.length : content.byteLength;

    if (parseTime > 1000) {
      Logger.warn(this.TAG, `Slow parse: ${type} took ${parseTime}ms for ${size} bytes`);
    } else {
      Logger.debug(this.TAG, `Parsed ${type} in ${parseTime}ms (${size} bytes)`);
    }
  }

  clearCache(): void {
    this.cache.clear();
    Logger.info(this.TAG, 'Cache cleared');
  }

  getCacheStats(): CacheStats {
    let totalHits = 0;
    const entries: CacheStatsEntry[] = [];

    this.cache.forEach((value, key) => {
      totalHits += value.hits;
      const entry: CacheStatsEntry = {
        key,
        hits: value.hits,
        age: Date.now() - value.timestamp
      };
      entries.push(entry);
    });

    const stats: CacheStats = {
      size: this.cache.size,
      maxSize: this.options.maxCacheSize,
      ttl: this.options.cacheTTL,
      hitRate: this.cache.size > 0 ? totalHits / this.cache.size : 0,
      entries
    };
    return stats;
  }

  setOptions(options: Partial<ParserFacadeOptions>): void {
    this.options = this.mergeOptions(options as ParserFacadeOptions);
  }

  getOptions(): Required<ParserFacadeOptions> {
    const currentOptions: Required<ParserFacadeOptions> = {
      enableCache: this.options.enableCache,
      cacheTTL: this.options.cacheTTL,
      maxCacheSize: this.options.maxCacheSize,
      autoDetect: this.options.autoDetect,
      defaultTimeout: this.options.defaultTimeout
    };
    return currentOptions;
  }

  private mergeParseOptions(options?: ParseOptions): ParseOptions {
    const merged: ParseOptions = {
      timeout: this.options.defaultTimeout
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

  async parseBatch<T extends object = object>(
    items: BatchParseItem[]
  ): Promise<ParseResult<T>[]> {
    return Promise.all(
      items.map(item => this.parse<T>(item.content, item.type, item.options))
    );
  }

  async parseWithFallback<T extends object = object>(
    content: string | ArrayBuffer,
    types: ParserType[],
    options?: ParseOptions
  ): Promise<ParseResult<T>> {
    const errors: Error[] = [];

    for (const type of types) {
      try {
        const result = await this.parse<T>(content, type, options);
        if (result.status !== ParseStatus.FAILED) {
          return result;
        }
      } catch (error) {
        const err = error instanceof Error ? error : new Error(String(error));
        errors.push(err);
      }
    }

    const errorInfos: ParseErrorInfo[] = errors.map((e: Error): ParseErrorInfo => ({
      code: ParserErrorCode.PARSE_FAILED,
      message: e.message,
      severity: 'error'
    }));

    const metadata: ParseMetadata = {
      parserType: ParserType.TEXT,
      parseTime: 0,
      dataSize: 0,
      cached: false,
      timestamp: Date.now(),
      version: '1.0.0'
    };

    const failedResult: ParseResult<T> = {
      data: new Object() as T,
      status: ParseStatus.FAILED,
      errors: errorInfos,
      warnings: [],
      metadata
    };
    return failedResult;
  }

  destroy(): void {
    this.clearCache();
    this.parsers.clear();
    this.extensionMap.clear();
    ParserFacade.instance = null;
    Logger.info(this.TAG, 'ParserFacade destroyed');
  }
}

export default ParserFacade.getInstance();
