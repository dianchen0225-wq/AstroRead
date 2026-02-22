/**
 * AppError - 应用程序统一错误基类
 * 所有应用级错误都应继承此类
 */

export enum AppErrorCode {
  UNKNOWN = 'UNKNOWN',
  
  // 网络错误 (1xx)
  NETWORK_ERROR = 'NETWORK_100',
  TIMEOUT = 'NETWORK_101',
  CONNECTION_ERROR = 'NETWORK_102',
  SSL_ERROR = 'NETWORK_103',
  ABORTED = 'NETWORK_104',
  INVALID_URL = 'NETWORK_105',
  HTTP_ERROR = 'NETWORK_106',
  REDIRECT_ERROR = 'NETWORK_107',
  
  // 解析错误 (2xx)
  PARSE_ERROR = 'PARSE_200',
  INVALID_INPUT = 'PARSE_201',
  EMPTY_INPUT = 'PARSE_202',
  SYNTAX_ERROR = 'PARSE_203',
  ENCODING_ERROR = 'PARSE_204',
  DEPTH_EXCEEDED = 'PARSE_205',
  INVALID_FORMAT = 'PARSE_206',
  UNSUPPORTED_TYPE = 'PARSE_207',
  
  // 书源错误 (3xx)
  SOURCE_NOT_FOUND = 'SOURCE_300',
  SOURCE_DISABLED = 'SOURCE_301',
  SOURCE_UNHEALTHY = 'SOURCE_302',
  RULE_NOT_FOUND = 'SOURCE_303',
  
  // 缓存错误 (4xx)
  CACHE_ERROR = 'CACHE_400',
  CACHE_MISS = 'CACHE_401',
  CACHE_EXPIRED = 'CACHE_402',
  
  // 业务错误 (5xx)
  BOOK_NOT_FOUND = 'BUSINESS_500',
  CHAPTER_NOT_FOUND = 'BUSINESS_501',
  CONTENT_EMPTY = 'BUSINESS_502',
  OPERATION_FAILED = 'BUSINESS_503'
}

export enum ErrorCategory {
  NETWORK = 'network',
  PARSE = 'parse',
  SOURCE = 'source',
  CACHE = 'cache',
  BUSINESS = 'business',
  UNKNOWN = 'unknown'
}

export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export interface AppErrorOptions {
  category?: ErrorCategory;
  severity?: ErrorSeverity;
  cause?: Error;
  context?: Map<string, string | number | boolean | object | null>;
  recoverable?: boolean;
  retryable?: boolean;
  sourceId?: string;
  sourceName?: string;
}

export interface AppErrorJSON {
  name: string;
  code: AppErrorCode;
  message: string;
  category: ErrorCategory;
  severity: ErrorSeverity;
  timestamp: number;
  recoverable: boolean;
  retryable: boolean;
  sourceId?: string;
  sourceName?: string;
  cause?: string;
}

export abstract class AppError extends Error {
  readonly code: AppErrorCode;
  readonly category: ErrorCategory;
  readonly severity: ErrorSeverity;
  readonly timestamp: number;
  readonly recoverable: boolean;
  readonly retryable: boolean;
  readonly sourceId?: string;
  readonly sourceName?: string;
  readonly cause?: Error;
  readonly context?: Map<string, string | number | boolean | object | null>;

  constructor(
    code: AppErrorCode,
    message: string,
    options?: AppErrorOptions
  ) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.category = options?.category ?? this.inferCategory(code);
    this.severity = options?.severity ?? this.inferSeverity(code);
    this.timestamp = Date.now();
    this.recoverable = options?.recoverable ?? this.inferRecoverable(code);
    this.retryable = options?.retryable ?? this.inferRetryable(code);
    this.sourceId = options?.sourceId;
    this.sourceName = options?.sourceName;
    this.cause = options?.cause;
    this.context = options?.context;
  }

  private inferCategory(code: AppErrorCode): ErrorCategory {
    const codeStr = code.toString();
    if (codeStr.startsWith('NETWORK')) return ErrorCategory.NETWORK;
    if (codeStr.startsWith('PARSE')) return ErrorCategory.PARSE;
    if (codeStr.startsWith('SOURCE')) return ErrorCategory.SOURCE;
    if (codeStr.startsWith('CACHE')) return ErrorCategory.CACHE;
    if (codeStr.startsWith('BUSINESS')) return ErrorCategory.BUSINESS;
    return ErrorCategory.UNKNOWN;
  }

  private inferSeverity(code: AppErrorCode): ErrorSeverity {
    const criticalCodes = [
      AppErrorCode.SSL_ERROR,
      AppErrorCode.SOURCE_DISABLED,
      AppErrorCode.OPERATION_FAILED
    ];
    
    const highCodes = [
      AppErrorCode.NETWORK_ERROR,
      AppErrorCode.TIMEOUT,
      AppErrorCode.HTTP_ERROR,
      AppErrorCode.SOURCE_UNHEALTHY
    ];

    if (criticalCodes.includes(code)) return ErrorSeverity.CRITICAL;
    if (highCodes.includes(code)) return ErrorSeverity.HIGH;
    if (code.toString().startsWith('PARSE')) return ErrorSeverity.MEDIUM;
    return ErrorSeverity.LOW;
  }

  private inferRecoverable(code: AppErrorCode): boolean {
    const unrecoverableCodes = [
      AppErrorCode.SOURCE_DISABLED,
      AppErrorCode.INVALID_URL,
      AppErrorCode.SYNTAX_ERROR,
      AppErrorCode.UNSUPPORTED_TYPE
    ];
    return !unrecoverableCodes.includes(code);
  }

  private inferRetryable(code: AppErrorCode): boolean {
    const retryableCodes = [
      AppErrorCode.NETWORK_ERROR,
      AppErrorCode.TIMEOUT,
      AppErrorCode.CONNECTION_ERROR,
      AppErrorCode.HTTP_ERROR,
      AppErrorCode.CACHE_MISS
    ];
    return retryableCodes.includes(code);
  }

  toJSON(): AppErrorJSON {
    return {
      name: this.name,
      code: this.code,
      message: this.message,
      category: this.category,
      severity: this.severity,
      timestamp: this.timestamp,
      recoverable: this.recoverable,
      retryable: this.retryable,
      sourceId: this.sourceId,
      sourceName: this.sourceName,
      cause: this.cause?.message
    };
  }

  toUserMessage(): string {
    switch (this.category) {
      case ErrorCategory.NETWORK:
        return '网络请求失败，请检查网络连接后重试';
      case ErrorCategory.PARSE:
        return '数据解析失败，请稍后重试';
      case ErrorCategory.SOURCE:
        return '书源暂时不可用，正在尝试其他书源';
      case ErrorCategory.CACHE:
        return '缓存数据不可用';
      case ErrorCategory.BUSINESS:
        return this.message;
      default:
        return '操作失败，请稍后重试';
    }
  }

  static fromError(error: Error): AppError {
    if (error instanceof AppError) {
      return error;
    }
    
    return new (class extends AppError {
      constructor() {
        super(AppErrorCode.UNKNOWN, error.message, { cause: error });
      }
    })();
  }
}

export class NetworkAppError extends AppError {
  readonly statusCode?: number;
  readonly statusText?: string;

  constructor(
    code: AppErrorCode,
    message: string,
    options?: AppErrorOptions & { statusCode?: number; statusText?: string }
  ) {
    super(code, message, { ...options, category: ErrorCategory.NETWORK });
    this.statusCode = options?.statusCode;
    this.statusText = options?.statusText;
  }

  static timeout(message: string = 'Request timeout'): NetworkAppError {
    return new NetworkAppError(AppErrorCode.TIMEOUT, message, {
      severity: ErrorSeverity.HIGH,
      retryable: true
    });
  }

  static networkError(message: string = 'Network error'): NetworkAppError {
    return new NetworkAppError(AppErrorCode.NETWORK_ERROR, message, {
      severity: ErrorSeverity.HIGH,
      retryable: true
    });
  }

  static httpError(status: number, statusText: string): NetworkAppError {
    return new NetworkAppError(AppErrorCode.HTTP_ERROR, `HTTP ${status}: ${statusText}`, {
      statusCode: status,
      statusText,
      severity: status >= 500 ? ErrorSeverity.HIGH : ErrorSeverity.MEDIUM,
      retryable: status >= 500 || status === 429
    });
  }
}

export class ParseAppError extends AppError {
  readonly line?: number;
  readonly column?: number;

  constructor(
    code: AppErrorCode,
    message: string,
    options?: AppErrorOptions & { line?: number; column?: number }
  ) {
    super(code, message, { ...options, category: ErrorCategory.PARSE });
    this.line = options?.line;
    this.column = options?.column;
  }

  static invalidInput(message: string = 'Invalid input'): ParseAppError {
    return new ParseAppError(AppErrorCode.INVALID_INPUT, message, {
      recoverable: false
    });
  }

  static emptyInput(): ParseAppError {
    return new ParseAppError(AppErrorCode.EMPTY_INPUT, 'Input content is empty');
  }

  static syntaxError(message: string, line?: number, column?: number): ParseAppError {
    return new ParseAppError(AppErrorCode.SYNTAX_ERROR, message, {
      line,
      column,
      recoverable: false
    });
  }
}

export class SourceAppError extends AppError {
  constructor(
    code: AppErrorCode,
    message: string,
    options?: AppErrorOptions
  ) {
    super(code, message, { ...options, category: ErrorCategory.SOURCE });
  }

  static notFound(sourceId: string, sourceName?: string): SourceAppError {
    return new SourceAppError(AppErrorCode.SOURCE_NOT_FOUND, `Source not found: ${sourceName ?? sourceId}`, {
      sourceId,
      sourceName,
      recoverable: false
    });
  }

  static disabled(sourceId: string, sourceName?: string): SourceAppError {
    return new SourceAppError(AppErrorCode.SOURCE_DISABLED, `Source disabled: ${sourceName ?? sourceId}`, {
      sourceId,
      sourceName,
      recoverable: false,
      severity: ErrorSeverity.CRITICAL
    });
  }

  static unhealthy(sourceId: string, sourceName?: string): SourceAppError {
    return new SourceAppError(AppErrorCode.SOURCE_UNHEALTHY, `Source unhealthy: ${sourceName ?? sourceId}`, {
      sourceId,
      sourceName,
      severity: ErrorSeverity.HIGH,
      retryable: true
    });
  }
}

export class BusinessAppError extends AppError {
  constructor(
    code: AppErrorCode,
    message: string,
    options?: AppErrorOptions
  ) {
    super(code, message, { ...options, category: ErrorCategory.BUSINESS });
  }

  static bookNotFound(bookId: string): BusinessAppError {
    return new BusinessAppError(AppErrorCode.BOOK_NOT_FOUND, `Book not found: ${bookId}`, {
      recoverable: false
    });
  }

  static chapterNotFound(chapterId: string): BusinessAppError {
    return new BusinessAppError(AppErrorCode.CHAPTER_NOT_FOUND, `Chapter not found: ${chapterId}`, {
      recoverable: false
    });
  }

  static contentEmpty(): BusinessAppError {
    return new BusinessAppError(AppErrorCode.CONTENT_EMPTY, 'Chapter content is empty');
  }
}

export default AppError;
