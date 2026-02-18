/**
 * IParser - 解析器接口规范
 * 定义统一的解析、验证、格式化方法
 */

export enum ParserType {
  JSON = 'json',
  XML = 'xml',
  HTML = 'html',
  CSV = 'csv',
  TEXT = 'text',
  BINARY = 'binary'
}

export enum ParseStatus {
  SUCCESS = 'success',
  PARTIAL = 'partial',
  FAILED = 'failed',
  PENDING = 'pending'
}

export interface ParseOptions {
  encoding?: string;
  strict?: boolean;
  maxDepth?: number;
  timeout?: number;
  cacheKey?: string;
  skipCache?: boolean;
  customRules?: Map<string, string>;
}

export interface ParseResult<T = object> {
  data: T;
  status: ParseStatus;
  errors: ParseErrorInfo[];
  warnings: ParseWarningInfo[];
  metadata: ParseMetadata;
  raw?: string;
}

export interface ParseErrorInfo {
  code: string;
  message: string;
  line?: number;
  column?: number;
  context?: string;
  severity: 'error' | 'critical';
}

export interface ParseWarningInfo {
  code: string;
  message: string;
  line?: number;
  column?: number;
  severity: 'warning' | 'info';
}

export interface ParseMetadata {
  parserType: ParserType;
  parseTime: number;
  dataSize: number;
  cached: boolean;
  timestamp: number;
  version: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ParseErrorInfo[];
  warnings: ParseWarningInfo[];
}

export interface ValidateResultWithoutValid {
  errors: ParseErrorInfo[];
  warnings: ParseWarningInfo[];
}

export interface FormatOptions {
  indent?: number;
  compact?: boolean;
  preserveOrder?: boolean;
  includeNulls?: boolean;
  customFormatters?: Map<string, (value: string) => string>;
  customRules?: Map<string, string>;
}

export interface IParser<T = object, R = ParseResult<T>> {
  readonly type: ParserType;
  readonly version: string;
  readonly supportedExtensions: string[];

  parse(content: string | ArrayBuffer, options?: ParseOptions): Promise<R>;
  parseSync(content: string | ArrayBuffer, options?: ParseOptions): R;
  validate(content: string | ArrayBuffer, options?: ParseOptions): ValidationResult;
  format(data: T, options?: FormatOptions): string;
  canParse(content: string | ArrayBuffer, hint?: string): boolean;
  getSchema?(): Map<string, string>;
}

export interface IParserAdapter<T = object> extends IParser<T> {
  readonly name: string;
  readonly priority: number;

  adapt(content: string | ArrayBuffer, options?: ParseOptions): Promise<ParseResult<T>>;
  adaptSync(content: string | ArrayBuffer, options?: ParseOptions): ParseResult<T>;
}

export type ParserFactory = () => IParser<object>;

export interface ParserRegistry {
  register(parser: IParser<object>): void;
  unregister(type: ParserType): boolean;
  get(type: ParserType): IParser<object> | undefined;
  getAll(): IParser<object>[];
  findByExtension(ext: string): IParser<object> | undefined;
  findByContent(content: string | ArrayBuffer): IParser<object> | undefined;
}
export class JsonObject {
  private data: Map<string, JsonValue> = new Map();

  get(key: string): JsonValue | undefined {
    return this.data.get(key);
  }

  set(key: string, value: JsonValue): void {
    this.data.set(key, value);
  }

  has(key: string): boolean {
    return this.data.has(key);
  }

  delete(key: string): boolean {
    return this.data.delete(key);
  }

  keys(): IterableIterator<string> {
    return this.data.keys();
  }

  values(): IterableIterator<JsonValue> {
    return this.data.values();
  }

  entries(): IterableIterator<[string, JsonValue]> {
    return this.data.entries();
  }

  forEach(callback: (value: JsonValue, key: string) => void): void {
    this.data.forEach(callback);
  }

  get size(): number {
    return this.data.size;
  }
}
export type JsonArray = JsonValue[];
export type JsonValue = string | number | boolean | null | JsonObject | JsonArray;

export interface XmlNode {
  type: 'element' | 'text' | 'comment' | 'cdata' | 'processing-instruction';
  name?: string;
  value?: string;
  attributes?: Map<string, string>;
  children?: XmlNode[];
  parent?: XmlNode;
}

export interface HtmlNode extends XmlNode {
  tagName?: string;
  innerHTML?: string;
  outerHTML?: string;
  textContent?: string;
}
export interface CsvRow {
  values: string[];
}

export interface CsvResult {
  headers: string[];
  rows: CsvRow[];
  rowCount: number;
  columnCount: number;
}