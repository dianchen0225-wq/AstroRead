/**
 * ParserError - 统一错误处理类
 * 继承自 AppError，提供解析器特有的错误信息
 */

import {
  ParseErrorInfo,
  ParserType,
  ParseStatus,
  ParseMetadata,
  ParseResult
} from '../interfaces/IParser';
import {
  AppError,
  AppErrorCode,
  ErrorCategory,
  ErrorSeverity,
  AppErrorOptions
} from './AppError';

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
  CACHE_MISS = 'PARSER_CACHE_MISS',
  ADAPTER_NOT_FOUND = 'PARSER_ADAPTER_NOT_FOUND',
  RESOURCE_EXHAUSTED = 'PARSER_RESOURCE_EXHAUSTED',
  HTTP_ERROR = 'PARSER_HTTP_ERROR',
  NETWORK_ERROR = 'PARSER_NETWORK_ERROR',
  SECURITY_VIOLATION = 'PARSER_SECURITY_VIOLATION'
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

function mapParserErrorCode(code: ParserErrorCode): AppErrorCode {
  const mapping: Record<string, AppErrorCode> = {
    [ParserErrorCode.INVALID_INPUT]: AppErrorCode.INVALID_INPUT,
    [ParserErrorCode.EMPTY_INPUT]: AppErrorCode.EMPTY_INPUT,
    [ParserErrorCode.SYNTAX_ERROR]: AppErrorCode.SYNTAX_ERROR,
    [ParserErrorCode.ENCODING_ERROR]: AppErrorCode.ENCODING_ERROR,
    [ParserErrorCode.TIMEOUT]: AppErrorCode.TIMEOUT,
    [ParserErrorCode.UNSUPPORTED_TYPE]: AppErrorCode.UNSUPPORTED_TYPE
  };
  return mapping[code] ?? AppErrorCode.PARSE_ERROR;
}

export class ParserError extends AppError {
  readonly parserCode: ParserErrorCode;
  readonly parserType: ParserType;
  readonly line?: number;
  readonly column?: number;
  readonly context?: string;

  constructor(
    code: ParserErrorCode,
    message: string,
    parserType: ParserType = ParserType.TEXT,
    options?: ParserErrorOptions
  ) {
    const appCode = mapParserErrorCode(code);
    const appOptions: AppErrorOptions = {
      category: ErrorCategory.PARSE,
      severity: ParserError.inferSeverityFromCode(code),
      recoverable: ParserError.inferRecoverableFromCode(code),
      cause: options?.cause
    };

    super(appCode, message, appOptions);
    
    this.parserCode = code;
    this.name = 'ParserError';
    this.parserType = parserType;
    this.line = options?.line;
    this.column = options?.column;
    this.context = options?.context;
  }

  private static inferSeverityFromCode(code: ParserErrorCode): ErrorSeverity {
    const criticalCodes = [
      ParserErrorCode.RESOURCE_EXHAUSTED,
      ParserErrorCode.ADAPTER_NOT_FOUND,
      ParserErrorCode.TIMEOUT
    ];
    
    const highCodes = [
      ParserErrorCode.SYNTAX_ERROR,
      ParserErrorCode.INVALID_FORMAT
    ];

    if (criticalCodes.includes(code)) return ErrorSeverity.CRITICAL;
    if (highCodes.includes(code)) return ErrorSeverity.HIGH;
    return ErrorSeverity.MEDIUM;
  }

  private static inferRecoverableFromCode(code: ParserErrorCode): boolean {
    const unrecoverableCodes = [
      ParserErrorCode.INVALID_INPUT,
      ParserErrorCode.SYNTAX_ERROR,
      ParserErrorCode.UNSUPPORTED_TYPE,
      ParserErrorCode.ADAPTER_NOT_FOUND
    ];
    return !unrecoverableCodes.includes(code);
  }

  get code(): AppErrorCode {
    return super.code;
  }

  toErrorInfo(): ParseErrorInfo {
    return {
      code: this.parserCode,
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
    ].includes(this.parserCode);
  }

  toJSON(): ParserErrorJSON {
    return new ParserErrorJSON(
      this.name,
      this.parserCode,
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
