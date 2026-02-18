/**
 * ParserError - 统一错误处理类
 * 标准化不同解析器的异常输出
 */

import {
  ParseErrorInfo,
  ParseWarningInfo,
  ParserType,
  ParseStatus,
  ParseMetadata,
  ParseResult
} from '../interfaces/IParser';

export enum ParserErrorCode {
  UNKNOWN = 'PARSER_UNKNOWN',
  INVALID_INPUT = 'PARSER_INVALID_INPUT',
  EMPTY_INPUT = 'PARSER_EMPTY_INPUT',
  SYNTAX_ERROR = 'PARSER_SYNTAX_ERROR',
  ENCODING_ERROR = 'PARSER_ENCODING_ERROR',
  TIMEOUT = 'PARSER_TIMEOUT',
  DEPTH_EXCEEDED = 'PARSER_DEPTH_EXCEEDED',
  INVALID_FORMAT = 'PARSER_INVALID_FORMAT',
  SCHEMA_VIOLATION = 'PARSER_SCHEMA_VIOLATION',
  UNSUPPORTED_TYPE = 'PARSER_UNSUPPORTED_TYPE',
  PARSE_FAILED = 'PARSER_PARSE_FAILED',
  VALIDATION_FAILED = 'PARSER_VALIDATION_FAILED',
  CACHE_ERROR = 'PARSER_CACHE_ERROR',
  ADAPTER_NOT_FOUND = 'PARSER_ADAPTER_NOT_FOUND',
  RESOURCE_EXHAUSTED = 'PARSER_RESOURCE_EXHAUSTED'
}

export interface ParserErrorOptions {
  line?: number;
  column?: number;
  context?: string;
  cause?: Error;
}

export class ParserErrorJSON {
  name: string;
  code: ParserErrorCode;
  message: string;
  parserType: ParserType;
  line?: number;
  column?: number;
  context?: string;
  timestamp: number;
  cause?: string;

  constructor(
    name: string,
    code: ParserErrorCode,
    message: string,
    parserType: ParserType,
    timestamp: number,
    line?: number,
    column?: number,
    context?: string,
    cause?: string
  ) {
    this.name = name;
    this.code = code;
    this.message = message;
    this.parserType = parserType;
    this.timestamp = timestamp;
    this.line = line;
    this.column = column;
    this.context = context;
    this.cause = cause;
  }
}

export class ParserError extends Error {
  readonly code: ParserErrorCode;
  readonly parserType: ParserType;
  readonly line?: number;
  readonly column?: number;
  readonly context?: string;
  readonly cause?: Error;
  readonly timestamp: number;

  constructor(
    code: ParserErrorCode,
    message: string,
    parserType: ParserType = ParserType.TEXT,
    options?: ParserErrorOptions
  ) {
    super(message);
    this.name = 'ParserError';
    this.code = code;
    this.parserType = parserType;
    this.line = options?.line;
    this.column = options?.column;
    this.context = options?.context;
    this.cause = options?.cause;
    this.timestamp = Date.now();
  }

  toErrorInfo(): ParseErrorInfo {
    return {
      code: this.code,
      message: this.message,
      line: this.line,
      column: this.column,
      context: this.context,
      severity: this.isCritical() ? 'critical' : 'error'
    };
  }

  isCritical(): boolean {
    return [
      ParserErrorCode.RESOURCE_EXHAUSTED,
      ParserErrorCode.ADAPTER_NOT_FOUND,
      ParserErrorCode.TIMEOUT
    ].includes(this.code);
  }

  toJSON(): ParserErrorJSON {
    return new ParserErrorJSON(
      this.name,
      this.code,
      this.message,
      this.parserType,
      this.timestamp,
      this.line,
      this.column,
      this.context,
      this.cause?.message
    );
  }

  static fromError(error: Error, parserType: ParserType = ParserType.TEXT): ParserError {
    if (error instanceof ParserError) {
      return error;
    }
    return new ParserError(
      ParserErrorCode.UNKNOWN,
      error.message,
      parserType,
      { cause: error }
    );
  }

  static invalidInput(parserType: ParserType, message?: string): ParserError {
    return new ParserError(
      ParserErrorCode.INVALID_INPUT,
      message || 'Invalid input provided',
      parserType
    );
  }

  static emptyInput(parserType: ParserType): ParserError {
    return new ParserError(
      ParserErrorCode.EMPTY_INPUT,
      'Input content is empty',
      parserType
    );
  }

  static syntaxError(
    parserType: ParserType,
    message: string,
    line?: number,
    column?: number,
    context?: string
  ): ParserError {
    const options: ParserErrorOptions = { line, column, context };
    return new ParserError(
      ParserErrorCode.SYNTAX_ERROR,
      message,
      parserType,
      options
    );
  }

  static timeout(parserType: ParserType, timeout: number): ParserError {
    return new ParserError(
      ParserErrorCode.TIMEOUT,
      `Parse operation timed out after ${timeout}ms`,
      parserType
    );
  }

  static unsupportedType(type: string): ParserError {
    return new ParserError(
      ParserErrorCode.UNSUPPORTED_TYPE,
      `Unsupported parser type: ${type}`,
      ParserType.TEXT
    );
  }

  static adapterNotFound(parserType: ParserType): ParserError {
    return new ParserError(
      ParserErrorCode.ADAPTER_NOT_FOUND,
      `No adapter found for parser type: ${parserType}`,
      parserType
    );
  }
}

export interface ParserWarningOptions {
  line?: number;
  column?: number;
  severity?: 'warning' | 'info';
}

export class ParserWarning {
  readonly code: string;
  readonly message: string;
  readonly line?: number;
  readonly column?: number;
  readonly severity: 'warning' | 'info';
  readonly timestamp: number;

  constructor(
    code: string,
    message: string,
    options?: ParserWarningOptions
  ) {
    this.code = code;
    this.message = message;
    this.line = options?.line;
    this.column = options?.column;
    this.severity = options?.severity ?? 'warning';
    this.timestamp = Date.now();
  }

  toWarningInfo(): ParseWarningInfo {
    return {
      code: this.code,
      message: this.message,
      line: this.line,
      column: this.column,
      severity: this.severity
    };
  }

  static deprecatedFeature(feature: string, alternative?: string): ParserWarning {
    const message = alternative
      ? `Deprecated feature: ${feature}. Use ${alternative} instead.`
      : `Deprecated feature: ${feature}`;
    return new ParserWarning('DEPRECATED_FEATURE', message);
  }

  static performanceHint(hint: string): ParserWarning {
    const options: ParserWarningOptions = { severity: 'info' };
    return new ParserWarning('PERFORMANCE_HINT', hint, options);
  }

  static partialResult(reason: string): ParserWarning {
    return new ParserWarning('PARTIAL_RESULT', `Partial result due to: ${reason}`);
  }
}

export class ParseResultBuilder<T> {
  private data: T;
  private errors: ParseErrorInfo[] = [];
  private warnings: ParseWarningInfo[] = [];
  private metadata: Partial<ParseMetadata> = {};
  private raw?: string;
  private status: ParseStatus = ParseStatus.SUCCESS;

  constructor(data: T) {
    this.data = data;
  }

  addError(error: ParseErrorInfo | ParserError): ParseResultBuilder<T> {
    const errorInfo = error instanceof ParserError ? error.toErrorInfo() : error;
    this.errors.push(errorInfo);
    if (errorInfo.severity === 'critical') {
      this.status = ParseStatus.FAILED;
    } else if (this.status === ParseStatus.SUCCESS) {
      this.status = ParseStatus.PARTIAL;
    }
    return this;
  }

  addWarning(warning: ParseWarningInfo | ParserWarning): ParseResultBuilder<T> {
    const warningInfo = warning instanceof ParserWarning ? warning.toWarningInfo() : warning;
    this.warnings.push(warningInfo);
    return this;
  }

  setMetadata(metadata: Partial<ParseMetadata>): ParseResultBuilder<T> {
    if (metadata.parserType !== undefined) {
      this.metadata.parserType = metadata.parserType;
    }
    if (metadata.parseTime !== undefined) {
      this.metadata.parseTime = metadata.parseTime;
    }
    if (metadata.dataSize !== undefined) {
      this.metadata.dataSize = metadata.dataSize;
    }
    if (metadata.cached !== undefined) {
      this.metadata.cached = metadata.cached;
    }
    if (metadata.timestamp !== undefined) {
      this.metadata.timestamp = metadata.timestamp;
    }
    if (metadata.version !== undefined) {
      this.metadata.version = metadata.version;
    }
    return this;
  }

  setRaw(raw: string): ParseResultBuilder<T> {
    this.raw = raw;
    return this;
  }

  setStatus(status: ParseStatus): ParseResultBuilder<T> {
    this.status = status;
    return this;
  }

  setData(data: T): ParseResultBuilder<T> {
    this.data = data;
    return this;
  }

  build(): ParseResult<T> {
    return {
      data: this.data,
      status: this.status,
      errors: this.errors,
      warnings: this.warnings,
      metadata: {
        parserType: this.metadata.parserType ?? ParserType.TEXT,
        parseTime: this.metadata.parseTime ?? 0,
        dataSize: this.metadata.dataSize ?? 0,
        cached: this.metadata.cached ?? false,
        timestamp: this.metadata.timestamp ?? Date.now(),
        version: this.metadata.version ?? '1.0.0'
      },
      raw: this.raw
    };
  }
}
