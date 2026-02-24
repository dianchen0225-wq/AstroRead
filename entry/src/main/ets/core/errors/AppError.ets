/**
 * AppError - 应用错误类型定义
 * 提供统一的错误类型层次结构
 */

export enum ErrorType {
  NETWORK = 'NETWORK',
  HTTP = 'HTTP',
  PARSE = 'PARSE',
  VALIDATION = 'VALIDATION',
  DATABASE = 'DATABASE',
  FILE = 'FILE',
  SECURITY = 'SECURITY',
  TIMEOUT = 'TIMEOUT',
  CANCELLED = 'CANCELLED',
  NOT_FOUND = 'NOT_FOUND',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  BUSINESS = 'BUSINESS',
  UNKNOWN = 'UNKNOWN',
}

export enum ErrorSeverity {
  INFO = 'INFO',
  WARNING = 'WARNING',
  ERROR = 'ERROR',
  CRITICAL = 'CRITICAL',
}

export type ErrorContextValue = string | number | boolean | null;
export type ErrorContext = Map<string, ErrorContextValue>;
export type ErrorContextJson = Array<[string, ErrorContextValue]>;

export interface AppErrorOptions {
  severity?: ErrorSeverity;
  code?: string;
  cause?: Error;
  context?: ErrorContext;
  recoverable?: boolean;
  retryable?: boolean;
}

export interface NetworkErrorOptions {
  statusCode?: number;
  url?: string;
  method?: string;
  code?: string;
  cause?: Error;
  context?: ErrorContext;
  retryable?: boolean;
}

export interface HttpErrorOptions {
  url?: string;
  responseData?: string;
  code?: string;
  cause?: Error;
  context?: ErrorContext;
}

export interface ParseErrorOptions {
  data?: string;
  rule?: string;
  code?: string;
  cause?: Error;
  context?: ErrorContext;
}

export interface ValidationErrorOptions {
  field?: string;
  validationRule?: string;
  inputValue?: string;
  code?: string;
  context?: ErrorContext;
}

export interface DatabaseErrorOptions {
  sql?: string;
  operation?: string;
  code?: string;
  cause?: Error;
  context?: ErrorContext;
}

export interface FileErrorOptions {
  filePath?: string;
  operation?: string;
  code?: string;
  cause?: Error;
  context?: ErrorContext;
}

export interface SecurityErrorOptions {
  securityPolicy?: string;
  code?: string;
  context?: ErrorContext;
}

export interface TimeoutErrorOptions {
  timeoutMs?: number;
  operation?: string;
  code?: string;
  context?: ErrorContext;
}

export interface CancelledErrorOptions {
  reason?: string;
  code?: string;
  context?: ErrorContext;
}

export interface NotFoundErrorOptions {
  resourceType?: string;
  resourceId?: string;
  code?: string;
  context?: ErrorContext;
}

export interface AppErrorJson {
  name: string;
  message: string;
  type: ErrorType;
  severity: ErrorSeverity;
  code: string;
  timestamp: number;
  recoverable: boolean;
  retryable: boolean;
  context?: ErrorContextJson;
  cause?: string;
  stack?: string;
}

export class AppError extends Error {
  readonly type: ErrorType;
  readonly severity: ErrorSeverity;
  readonly code: string;
  readonly cause?: Error;
  readonly context?: ErrorContext;
  readonly timestamp: number;
  readonly recoverable: boolean;
  readonly retryable: boolean;

  constructor(
    message: string,
    type: ErrorType = ErrorType.UNKNOWN,
    options: AppErrorOptions = {} as AppErrorOptions
  ) {
    super(message);
    this.name = 'AppError';
    this.type = type;
    this.severity = options.severity ?? ErrorSeverity.ERROR;
    this.code = options.code ?? 'UNKNOWN_ERROR';
    this.cause = options.cause;
    this.context = options.context;
    this.timestamp = Date.now();
    this.recoverable = options.recoverable ?? false;
    this.retryable = options.retryable ?? false;
  }

  toJSON(): AppErrorJson {
    const result: AppErrorJson = {
      name: this.name,
      message: this.message,
      type: this.type,
      severity: this.severity,
      code: this.code,
      timestamp: this.timestamp,
      recoverable: this.recoverable,
      retryable: this.retryable,
    };
    if (this.context !== undefined) {
      result.context = Array.from(this.context.entries());
    }
    if (this.cause !== undefined) {
      result.cause = this.cause.message;
    }
    if (this.stack !== undefined) {
      result.stack = this.stack;
    }
    return result;
  }

  getUserMessage(): string {
    switch (this.type) {
      case ErrorType.NETWORK:
        return '网络连接失败，请检查网络设置';
      case ErrorType.HTTP:
        return '服务器响应异常，请稍后重试';
      case ErrorType.PARSE:
        return '数据解析失败，请检查数据源';
      case ErrorType.VALIDATION:
        return '输入数据验证失败，请检查输入内容';
      case ErrorType.DATABASE:
        return '数据存储失败，请稍后重试';
      case ErrorType.FILE:
        return '文件操作失败，请检查文件权限';
      case ErrorType.SECURITY:
        return '安全验证失败，请检查配置';
      case ErrorType.TIMEOUT:
        return '操作超时，请稍后重试';
      case ErrorType.CANCELLED:
        return '操作已取消';
      case ErrorType.NOT_FOUND:
        return '请求的资源不存在';
      case ErrorType.UNAUTHORIZED:
        return '未授权访问，请重新登录';
      case ErrorType.FORBIDDEN:
        return '禁止访问该资源';
      default:
        return '发生未知错误，请稍后重试';
    }
  }
}

export class NetworkError extends AppError {
  readonly statusCode?: number;
  readonly url?: string;
  readonly method?: string;

  constructor(
    message: string,
    options: NetworkErrorOptions = {} as NetworkErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.ERROR,
      code: options.code ?? 'NETWORK_ERROR',
      cause: options.cause,
      context: options.context,
      recoverable: true,
      retryable: options.retryable ?? true,
    };
    super(message, ErrorType.NETWORK, appErrorOptions);
    this.name = 'NetworkError';
    this.statusCode = options.statusCode;
    this.url = options.url;
    this.method = options.method;
  }
}

export class HttpError extends AppError {
  readonly statusCode: number;
  readonly url?: string;
  readonly responseData?: string;

  constructor(
    message: string,
    statusCode: number,
    options: HttpErrorOptions = {} as HttpErrorOptions
  ) {
    const severity = statusCode >= 500 ? ErrorSeverity.ERROR : ErrorSeverity.WARNING;
    const retryable = statusCode >= 500 || statusCode === 429;
    const appErrorOptions: AppErrorOptions = {
      severity,
      code: options.code ?? `HTTP_${statusCode}`,
      cause: options.cause,
      context: options.context,
      recoverable: true,
      retryable,
    };
    super(message, ErrorType.HTTP, appErrorOptions);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.url = options.url;
    this.responseData = options.responseData;
  }
}

export class ParseError extends AppError {
  readonly data?: string;
  readonly rule?: string;

  constructor(
    message: string,
    options: ParseErrorOptions = {} as ParseErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.WARNING,
      code: options.code ?? 'PARSE_ERROR',
      cause: options.cause,
      context: options.context,
      recoverable: true,
      retryable: false,
    };
    super(message, ErrorType.PARSE, appErrorOptions);
    this.name = 'ParseError';
    this.data = options.data;
    this.rule = options.rule;
  }
}

export class ValidationError extends AppError {
  readonly field?: string;
  readonly validationRule?: string;
  readonly inputValue?: string;

  constructor(
    message: string,
    options: ValidationErrorOptions = {} as ValidationErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.WARNING,
      code: options.code ?? 'VALIDATION_ERROR',
      context: options.context,
      recoverable: true,
      retryable: false,
    };
    super(message, ErrorType.VALIDATION, appErrorOptions);
    this.name = 'ValidationError';
    this.field = options.field;
    this.validationRule = options.validationRule;
    this.inputValue = options.inputValue;
  }
}

export class DatabaseError extends AppError {
  readonly sql?: string;
  readonly operation?: string;

  constructor(
    message: string,
    options: DatabaseErrorOptions = {} as DatabaseErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.ERROR,
      code: options.code ?? 'DATABASE_ERROR',
      cause: options.cause,
      context: options.context,
      recoverable: true,
      retryable: true,
    };
    super(message, ErrorType.DATABASE, appErrorOptions);
    this.name = 'DatabaseError';
    this.sql = options.sql;
    this.operation = options.operation;
  }
}

export class FileError extends AppError {
  readonly filePath?: string;
  readonly operation?: string;

  constructor(
    message: string,
    options: FileErrorOptions = {} as FileErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.ERROR,
      code: options.code ?? 'FILE_ERROR',
      cause: options.cause,
      context: options.context,
      recoverable: false,
      retryable: false,
    };
    super(message, ErrorType.FILE, appErrorOptions);
    this.name = 'FileError';
    this.filePath = options.filePath;
    this.operation = options.operation;
  }
}

export class SecurityError extends AppError {
  readonly securityPolicy?: string;

  constructor(
    message: string,
    options: SecurityErrorOptions = {} as SecurityErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.CRITICAL,
      code: options.code ?? 'SECURITY_ERROR',
      context: options.context,
      recoverable: false,
      retryable: false,
    };
    super(message, ErrorType.SECURITY, appErrorOptions);
    this.name = 'SecurityError';
    this.securityPolicy = options.securityPolicy;
  }
}

export class TimeoutError extends AppError {
  readonly timeoutMs?: number;
  readonly operation?: string;

  constructor(
    message: string,
    options: TimeoutErrorOptions = {} as TimeoutErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.WARNING,
      code: options.code ?? 'TIMEOUT_ERROR',
      context: options.context,
      recoverable: true,
      retryable: true,
    };
    super(message, ErrorType.TIMEOUT, appErrorOptions);
    this.name = 'TimeoutError';
    this.timeoutMs = options.timeoutMs;
    this.operation = options.operation;
  }
}

export class CancelledError extends AppError {
  readonly reason?: string;

  constructor(
    message: string = '操作已取消',
    options: CancelledErrorOptions = {} as CancelledErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.INFO,
      code: options.code ?? 'CANCELLED',
      context: options.context,
      recoverable: true,
      retryable: false,
    };
    super(message, ErrorType.CANCELLED, appErrorOptions);
    this.name = 'CancelledError';
    this.reason = options.reason;
  }
}

export class NotFoundError extends AppError {
  readonly resourceType?: string;
  readonly resourceId?: string;

  constructor(
    message: string,
    options: NotFoundErrorOptions = {} as NotFoundErrorOptions
  ) {
    const appErrorOptions: AppErrorOptions = {
      severity: ErrorSeverity.WARNING,
      code: options.code ?? 'NOT_FOUND',
      context: options.context,
      recoverable: true,
      retryable: false,
    };
    super(message, ErrorType.NOT_FOUND, appErrorOptions);
    this.name = 'NotFoundError';
    this.resourceType = options.resourceType;
    this.resourceId = options.resourceId;
  }
}

export class ErrorUtils {
  static isRetryable(error: Error): boolean {
    if (error instanceof AppError) {
      return error.retryable;
    }

    const retryablePatterns: string[] = [
      'network',
      'timeout',
      'ECONNRESET',
      'ETIMEDOUT',
      'ECONNREFUSED',
      '503',
      '502',
      '504',
      '429',
    ];

    const errorMessage = error.message.toLowerCase();
    return retryablePatterns.some(pattern => errorMessage.includes(pattern.toLowerCase()));
  }

  static isCancelled(error: Error): boolean {
    if (error instanceof CancelledError) {
      return true;
    }

    const cancelPatterns: string[] = ['cancelled', 'canceled', 'abort', '中断'];
    const errorMessage = error.message.toLowerCase();
    return cancelPatterns.some(pattern => errorMessage.includes(pattern));
  }

  static toAppError(error: Error | string): AppError {
    if (error instanceof AppError) {
      return error;
    }

    if (error instanceof Error) {
      return new AppError(error.message, ErrorType.UNKNOWN, {
        cause: error,
      });
    }

    return new AppError(error, ErrorType.UNKNOWN);
  }

  static createContext(entries: Array<[string, string | number | boolean | null]>): ErrorContext {
    const result: ErrorContext = new Map<string, ErrorContextValue>();
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      result.set(entry[0], entry[1]);
    }
    return result;
  }
}
