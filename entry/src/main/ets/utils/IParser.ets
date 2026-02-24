import { Result, ErrorCode, ErrorFactory, ParseErrorOptions } from '../core/Result';

export type JsonValue = string | number | boolean | object | null;
export type JsonData = Record<string, JsonValue>;
export type JsonArray = JsonValue[];

export class ParserResult {
  value: string = '';
  values: string[] = [];
  raw: JsonValue = null;

  constructor(value: string = '', values: string[] = [], raw: JsonValue = null) {
    this.value = value;
    this.values = values;
    this.raw = raw;
  }

  static empty(): ParserResult {
    return new ParserResult('', [], null);
  }

  static fromValue(value: string): ParserResult {
    return new ParserResult(value, [value], value);
  }

  static fromValues(values: string[]): ParserResult {
    return new ParserResult(values.length > 0 ? values[0] : '', values, values);
  }

  static fromRaw(raw: JsonValue | null): ParserResult {
    if (raw === null) {
      return ParserResult.empty();
    }
    if (typeof raw === 'string') {
      return ParserResult.fromValue(raw);
    }
    if (typeof raw === 'number' || typeof raw === 'boolean') {
      const str = String(raw);
      return ParserResult.fromValue(str);
    }
    if (Array.isArray(raw)) {
      const arr = raw as JsonValue[];
      const values = arr.map((item: JsonValue) => ParserResult.stringifyValue(item));
      return ParserResult.fromValues(values);
    }
    const str = JSON.stringify(raw);
    return ParserResult.fromValue(str);
  }

  static stringifyValue(value: JsonValue | null): string {
    if (value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value);
    }
    if (typeof value === 'object') {
      return JSON.stringify(value);
    }
    return '';
  }

  isEmpty(): boolean {
    return this.values.length === 0;
  }

  hasValue(): boolean {
    return this.values.length > 0;
  }

  first(): string {
    return this.value;
  }

  toArray(): string[] {
    return this.values;
  }
}

export class ParseOptions {
  baseUrl?: string = '';
  context?: Map<string, string>;
  flags?: string = '';

  constructor(baseUrl?: string, context?: Map<string, string>, flags?: string) {
    this.baseUrl = baseUrl;
    this.context = context;
    this.flags = flags;
  }
}

export enum ParserType {
  JSON = 'json',
  XPATH = 'xpath',
  REGEX = 'regex',
  CSS = 'css',
  JS = 'js',
  AUTO = 'auto'
}

export interface IParser {
  readonly type: ParserType;
  readonly name: string;

  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult>;

  parseList(content: string, rule: string, options?: ParseOptions): Result<string[]>;

  parseValue(content: string, rule: string, options?: ParseOptions): Result<string>;

  canHandle(rule: string): boolean;
}

export abstract class BaseParser implements IParser {
  abstract readonly type: ParserType;
  abstract readonly name: string;

  abstract parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult>;

  parseList(content: string, rule: string, options?: ParseOptions): Result<string[]> {
    const result = this.parse(content, rule, options);
    if (result.isErr()) {
      return Result.err(result.error!);
    }
    return Result.ok(result.data!.values);
  }

  parseValue(content: string, rule: string, options?: ParseOptions): Result<string> {
    const result = this.parse(content, rule, options);
    if (result.isErr()) {
      return Result.err(result.error!);
    }
    return Result.ok(result.data!.value);
  }

  abstract canHandle(rule: string): boolean;

  protected createEmptyResult(): Result<ParserResult> {
    return Result.ok(ParserResult.empty());
  }

  protected createErrorResult(message: string, code: ErrorCode = ErrorCode.PARSE_ERROR, details?: string): Result<ParserResult> {
    const errorOptions = new ParseErrorOptions();
    errorOptions.code = code;
    if (details) {
      errorOptions.details = details;
    }
    return Result.err(ErrorFactory.parse(message, errorOptions));
  }

  protected validateInput(content: string, rule: string): boolean {
    return !!(content && rule);
  }
}

export class ParserRegistry {
  private static instance: ParserRegistry | null = null;
  private parsers: Map<ParserType, BaseParser> = new Map();
  private defaultParser: BaseParser | null = null;

  private constructor() {}

  static getInstance(): ParserRegistry {
    if (!ParserRegistry.instance) {
      ParserRegistry.instance = new ParserRegistry();
    }
    return ParserRegistry.instance;
  }

  register(parser: BaseParser): void {
    this.parsers.set(parser.type, parser);
  }

  unregister(type: ParserType): boolean {
    return this.parsers.delete(type);
  }

  get(type: ParserType): BaseParser | null {
    const parser = this.parsers.get(type);
    return parser !== undefined ? parser : null;
  }

  setDefault(parser: BaseParser): void {
    this.defaultParser = parser;
  }

  getDefault(): BaseParser | null {
    const defaultParser = this.defaultParser;
    if (defaultParser) {
      return defaultParser;
    }
    const iteratorResult = this.parsers.values().next();
    const firstParser = iteratorResult.value as BaseParser | undefined;
    return firstParser !== undefined ? firstParser : null;
  }

  findParser(rule: string): BaseParser | null {
    for (const parser of this.parsers.values()) {
      if (parser.canHandle(rule)) {
        return parser;
      }
    }
    return this.getDefault();
  }

  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    const parser = this.findParser(rule);
    if (!parser) {
      return Result.err(ErrorCode.PARSE_ERROR, 'No suitable parser found');
    }
    return parser.parse(content, rule, options);
  }

  parseList(content: string, rule: string, options?: ParseOptions): Result<string[]> {
    const parser = this.findParser(rule);
    if (!parser) {
      return Result.err(ErrorCode.PARSE_ERROR, 'No suitable parser found');
    }
    return parser.parseList(content, rule, options);
  }

  parseValue(content: string, rule: string, options?: ParseOptions): Result<string> {
    const parser = this.findParser(rule);
    if (!parser) {
      return Result.err(ErrorCode.PARSE_ERROR, 'No suitable parser found');
    }
    return parser.parseValue(content, rule, options);
  }

  clear(): void {
    this.parsers.clear();
    this.defaultParser = null;
  }
}

export default ParserRegistry;
