export enum ErrorCode {
  SUCCESS = 0,
  UNKNOWN_ERROR = 1,
  NETWORK_ERROR = 100,
  NETWORK_TIMEOUT = 101,
  NETWORK_CONNECTION_FAILED = 102,
  NETWORK_SSL_ERROR = 103,
  NETWORK_DNS_ERROR = 104,
  PARSE_ERROR = 200,
  PARSE_JSON_ERROR = 201,
  PARSE_HTML_ERROR = 202,
  PARSE_XPATH_ERROR = 203,
  PARSE_REGEX_ERROR = 204,
  PARSE_CSS_SELECTOR_ERROR = 205,
  DATABASE_ERROR = 300,
  DATABASE_QUERY_ERROR = 301,
  DATABASE_INSERT_ERROR = 302,
  DATABASE_UPDATE_ERROR = 303,
  DATABASE_DELETE_ERROR = 304,
  FILE_ERROR = 400,
  FILE_NOT_FOUND = 401,
  FILE_PERMISSION_DENIED = 402,
  FILE_READ_ERROR = 403,
  FILE_WRITE_ERROR = 404,
  VALIDATION_ERROR = 500,
  VALIDATION_REQUIRED_FIELD = 501,
  VALIDATION_INVALID_FORMAT = 502,
  VALIDATION_OUT_OF_RANGE = 503,
  SOURCE_ERROR = 600,
  SOURCE_NOT_FOUND = 601,
  SOURCE_DISABLED = 602,
  SOURCE_RULE_INVALID = 603,
  HTTP_ERROR = 700,
  HTTP_400 = 740,
  HTTP_401 = 741,
  HTTP_403 = 743,
  HTTP_404 = 744,
  HTTP_429 = 749,
  HTTP_500 = 750,
  HTTP_502 = 752,
  HTTP_503 = 753,
  HTTP_504 = 754
}

export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export enum ErrorRecoverability {
  RECOVERABLE = 'recoverable',
  RETRYABLE = 'retryable',
  NON_RECOVERABLE = 'non_recoverable'
}

export class AppErrorDetail {
  code: ErrorCode = ErrorCode.UNKNOWN_ERROR;
  message: string = '';
  severity: ErrorSeverity = ErrorSeverity.MEDIUM;
  recoverability: ErrorRecoverability = ErrorRecoverability.RECOVERABLE;
  userMessage: string = '';
  details?: string = undefined;
  sourceId?: string = undefined;
  sourceName?: string = undefined;
  timestamp: number = 0;
  retryCount?: number = undefined;
  maxRetries?: number = undefined;
}

export class AppErrorOptions {
  severity?: ErrorSeverity = undefined;
  recoverability?: ErrorRecoverability = undefined;
  userMessage?: string = undefined;
  details?: string = undefined;
  sourceId?: string = undefined;
  sourceName?: string = undefined;
  retryCount?: number = undefined;
  maxRetries?: number = undefined;
}

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly severity: ErrorSeverity;
  readonly recoverability: ErrorRecoverability;
  readonly userMessage: string;
  readonly details?: string;
  readonly sourceId?: string;
  readonly sourceName?: string;
  readonly timestamp: number;
  readonly retryCount: number;
  readonly maxRetries: number;

  constructor(
    code: ErrorCode,
    message: string,
    options?: AppErrorOptions
  ) {
    super(message);
    this.code = code;
    this.severity = options?.severity ?? ErrorSeverity.MEDIUM;
    this.recoverability = options?.recoverability ?? ErrorRecoverability.RECOVERABLE;
    this.userMessage = options?.userMessage ?? this.getDefaultUserMessage(code);
    this.details = options?.details;
    this.sourceId = options?.sourceId;
    this.sourceName = options?.sourceName;
    this.timestamp = Date.now();
    this.retryCount = options?.retryCount ?? 0;
    this.maxRetries = options?.maxRetries ?? 3;
  }

  private getDefaultUserMessage(code: ErrorCode): string {
    if (code === ErrorCode.NETWORK_ERROR || code === ErrorCode.NETWORK_CONNECTION_FAILED) {
      return '网络连接失败，请检查网络设置';
    }
    if (code === ErrorCode.NETWORK_TIMEOUT) {
      return '请求超时，请稍后重试';
    }
    if (code === ErrorCode.NETWORK_SSL_ERROR) {
      return '安全连接失败，请检查网络环境';
    }
    if (code === ErrorCode.PARSE_ERROR || code === ErrorCode.PARSE_JSON_ERROR) {
      return '数据解析失败，请重试';
    }
    if (code === ErrorCode.DATABASE_ERROR) {
      return '数据库操作失败，请重试';
    }
    if (code === ErrorCode.FILE_ERROR || code === ErrorCode.FILE_PERMISSION_DENIED) {
      return '文件操作失败，请检查权限';
    }
    if (code === ErrorCode.SOURCE_NOT_FOUND) {
      return '书源不存在';
    }
    if (code === ErrorCode.SOURCE_DISABLED) {
      return '书源已禁用';
    }
    if (code === ErrorCode.HTTP_404) {
      return '资源不存在';
    }
    if (code === ErrorCode.HTTP_429) {
      return '请求过于频繁，请稍后重试';
    }
    if (code >= ErrorCode.HTTP_500 && code <= ErrorCode.HTTP_504) {
      return '服务器暂时不可用，请稍后重试';
    }
    return '操作失败，请重试';
  }

  isRetryable(): boolean {
    return this.recoverability === ErrorRecoverability.RETRYABLE &&
      this.retryCount < this.maxRetries;
  }

  isRecoverable(): boolean {
    return this.recoverability !== ErrorRecoverability.NON_RECOVERABLE;
  }

  toDetail(): AppErrorDetail {
    return {
      code: this.code,
      message: this.message,
      severity: this.severity,
      recoverability: this.recoverability,
      userMessage: this.userMessage,
      details: this.details,
      sourceId: this.sourceId,
      sourceName: this.sourceName,
      timestamp: this.timestamp,
      retryCount: this.retryCount,
      maxRetries: this.maxRetries
    };
  }
}

export type ResultErrOptions = AppErrorOptions;

export class MatchHandlers<T, U> {
  ok: (data: T) => U = (_data: T) => undefined as U;
  err: (error: AppError) => U = (_error: AppError) => undefined as U;

  constructor(okHandler: (data: T) => U, errHandler: (error: AppError) => U) {
    this.ok = okHandler;
    this.err = errHandler;
  }
}

export class Result<T> {
  readonly success: boolean;
  readonly data?: T;
  readonly error?: AppError;

  private constructor(success: boolean, data?: T, error?: AppError) {
    this.success = success;
    this.data = data;
    this.error = error;
  }

  static ok<T>(data: T): Result<T> {
    return new Result<T>(true, data, undefined);
  }

  static err<T>(error: AppError | ErrorCode, message?: string, options?: ResultErrOptions): Result<T> {
    const appError = error instanceof AppError
      ? error
      : new AppError(error, message ?? 'Unknown error', options);
    return new Result<T>(false, undefined, appError);
  }

  static fromThrow<T>(fn: () => T): Result<T> {
    try {
      return Result.ok(fn());
    } catch (e) {
      if (e instanceof AppError) {
        return Result.err(e);
      }
      return Result.err(ErrorCode.UNKNOWN_ERROR, e instanceof Error ? e.message : String(e));
    }
  }

  static async fromAsync<T>(promise: Promise<T>): Promise<Result<T>> {
    try {
      const data = await promise;
      return Result.ok(data);
    } catch (e) {
      if (e instanceof AppError) {
        return Result.err(e);
      }
      return Result.err(ErrorCode.UNKNOWN_ERROR, e instanceof Error ? e.message : String(e));
    }
  }

  isOk(): boolean {
    return this.success;
  }

  isErr(): boolean {
    return !this.success;
  }

  unwrap(): T {
    if (!this.success || this.data === undefined) {
      throw this.error ?? new AppError(ErrorCode.UNKNOWN_ERROR, 'Cannot unwrap error result');
    }
    return this.data;
  }

  unwrapOr(defaultValue: T): T {
    return this.success && this.data !== undefined ? this.data : defaultValue;
  }

  unwrapOrElse(fn: (error: AppError) => T): T {
    return this.success && this.data !== undefined ? this.data : fn(this.error!);
  }

  expect(message: string): T {
    if (!this.success || this.data === undefined) {
      throw new AppError(ErrorCode.UNKNOWN_ERROR, message, { details: this.error?.message });
    }
    return this.data;
  }

  map<U>(fn: (data: T) => U): Result<U> {
    if (this.success && this.data !== undefined) {
      return Result.fromThrow(() => fn(this.data!));
    }
    return Result.err(this.error!);
  }

  async mapAsync<U>(fn: (data: T) => Promise<U>): Promise<Result<U>> {
    if (this.success && this.data !== undefined) {
      return Result.fromAsync(fn(this.data!));
    }
    return Result.err(this.error!);
  }

  mapErr(fn: (error: AppError) => AppError): Result<T> {
    if (this.success) {
      return Result.ok(this.data!);
    }
    return Result.err(fn(this.error!));
  }

  andThen<U>(fn: (data: T) => Result<U>): Result<U> {
    if (this.success && this.data !== undefined) {
      return fn(this.data);
    }
    return Result.err(this.error!);
  }

  async andThenAsync<U>(fn: (data: T) => Promise<Result<U>>): Promise<Result<U>> {
    if (this.success && this.data !== undefined) {
      return fn(this.data);
    }
    return Result.err(this.error!);
  }

  orElse(fn: (error: AppError) => Result<T>): Result<T> {
    if (this.success) {
      return Result.ok(this.data!);
    }
    return fn(this.error!);
  }

  match<U>(handlers: MatchHandlers<T, U>): U {
    if (this.success && this.data !== undefined) {
      return handlers.ok(this.data);
    }
    return handlers.err(this.error!);
  }
}

export class NetworkErrorOptions {
  code?: ErrorCode = undefined;
  sourceId?: string = undefined;
  sourceName?: string = undefined;
  retryCount?: number = undefined;
}

export class TimeoutErrorOptions {
  sourceId?: string = undefined;
  sourceName?: string = undefined;
  retryCount?: number = undefined;
}

export class ParseErrorOptions {
  code?: ErrorCode = undefined;
  details?: string = undefined;
}

export class DatabaseErrorOptions {
  code?: ErrorCode = undefined;
  details?: string = undefined;
}

export class FileErrorOptions {
  code?: ErrorCode = undefined;
  details?: string = undefined;
}

export class ValidationErrorOptions {
  code?: ErrorCode = undefined;
  userMessage?: string = undefined;
}

export class SourceErrorOptions {
  code?: ErrorCode = undefined;
  sourceId?: string = undefined;
  sourceName?: string = undefined;
}

export class HttpErrorOptions {
  sourceId?: string = undefined;
  sourceName?: string = undefined;
}

export class ErrorFactory {
  static network(message: string, options?: NetworkErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.MEDIUM,
      recoverability: ErrorRecoverability.RETRYABLE,
      sourceId: options?.sourceId,
      sourceName: options?.sourceName,
      retryCount: options?.retryCount
    };
    return new AppError(options?.code ?? ErrorCode.NETWORK_ERROR, message, errorOptions);
  }

  static timeout(message: string = 'Request timeout', options?: TimeoutErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.MEDIUM,
      recoverability: ErrorRecoverability.RETRYABLE,
      sourceId: options?.sourceId,
      sourceName: options?.sourceName,
      retryCount: options?.retryCount
    };
    return new AppError(ErrorCode.NETWORK_TIMEOUT, message, errorOptions);
  }

  static parse(message: string, options?: ParseErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.LOW,
      recoverability: ErrorRecoverability.NON_RECOVERABLE,
      details: options?.details
    };
    return new AppError(options?.code ?? ErrorCode.PARSE_ERROR, message, errorOptions);
  }

  static database(message: string, options?: DatabaseErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.HIGH,
      recoverability: ErrorRecoverability.NON_RECOVERABLE,
      details: options?.details
    };
    return new AppError(options?.code ?? ErrorCode.DATABASE_ERROR, message, errorOptions);
  }

  static file(message: string, options?: FileErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.MEDIUM,
      recoverability: ErrorRecoverability.NON_RECOVERABLE,
      details: options?.details
    };
    return new AppError(options?.code ?? ErrorCode.FILE_ERROR, message, errorOptions);
  }

  static validation(message: string, options?: ValidationErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.LOW,
      recoverability: ErrorRecoverability.NON_RECOVERABLE,
      userMessage: options?.userMessage ?? message
    };
    return new AppError(options?.code ?? ErrorCode.VALIDATION_ERROR, message, errorOptions);
  }

  static source(message: string, options?: SourceErrorOptions): AppError {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.MEDIUM,
      recoverability: ErrorRecoverability.NON_RECOVERABLE,
      sourceId: options?.sourceId,
      sourceName: options?.sourceName
    };
    return new AppError(options?.code ?? ErrorCode.SOURCE_ERROR, message, errorOptions);
  }

  static http(statusCode: number, message: string, options?: HttpErrorOptions): AppError {
    let code: ErrorCode;
    let severity = ErrorSeverity.MEDIUM;
    let recoverability = ErrorRecoverability.NON_RECOVERABLE;

    switch (statusCode) {
      case 400:
        code = ErrorCode.HTTP_400;
        break;
      case 401:
        code = ErrorCode.HTTP_401;
        severity = ErrorSeverity.HIGH;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      case 403:
        code = ErrorCode.HTTP_403;
        severity = ErrorSeverity.HIGH;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      case 404:
        code = ErrorCode.HTTP_404;
        break;
      case 429:
        code = ErrorCode.HTTP_429;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      case 500:
        code = ErrorCode.HTTP_500;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      case 502:
        code = ErrorCode.HTTP_502;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      case 503:
        code = ErrorCode.HTTP_503;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      case 504:
        code = ErrorCode.HTTP_504;
        recoverability = ErrorRecoverability.RETRYABLE;
        break;
      default:
        code = ErrorCode.HTTP_ERROR;
        if (statusCode >= 500) {
          recoverability = ErrorRecoverability.RETRYABLE;
        }
    }

    const errorOptions: AppErrorOptions = {
      severity: severity,
      recoverability: recoverability,
      sourceId: options?.sourceId,
      sourceName: options?.sourceName
    };
    return new AppError(code, message, errorOptions);
  }
}

export function isAppError(error: Object | null): boolean {
  return error instanceof AppError;
}

export function isResult<T>(value: Object | null): boolean {
  return value instanceof Result;
}
