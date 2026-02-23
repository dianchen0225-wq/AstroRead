/**
 * HttpError - 统一 HTTP 错误处理
 * 继承自 AppError，提供 HTTP 特有的错误信息
 */

import { HttpErrorCode, HttpHeaders, HttpRequestConfig, HttpResponse, HttpError } from './interfaces/IHttpClient';
import {
  AppError,
  AppErrorCode,
  ErrorCategory,
  ErrorSeverity,
  AppErrorOptions,
  AppErrorJSON
} from '../core/AppError';

interface HttpErrorOptions {
  status?: number;
  statusText?: string;
  headers?: HttpHeaders;
  config?: HttpRequestConfig;
  response?: HttpResponse;
  request?: HttpRequestConfig;
  cause?: Error;
}

class HttpErrorOptionsImpl implements HttpErrorOptions {
  status?: number;
  statusText?: string;
  headers?: HttpHeaders;
  config?: HttpRequestConfig;
  response?: HttpResponse;
  request?: HttpRequestConfig;
  cause?: Error;

  constructor(config?: HttpRequestConfig, cause?: Error) {
    this.config = config;
    this.cause = cause;
  }
}

interface HttpErrorJSON {
  name: string;
  code: AppErrorCode;
  message: string;
  status?: number;
  statusText?: string;
  isRetryable: boolean;
  timestamp: number;
  url?: string;
}

function mapHttpErrorCode(code: HttpErrorCode): AppErrorCode {
  const mapping: Record<string, AppErrorCode> = {
    [HttpErrorCode.TIMEOUT]: AppErrorCode.TIMEOUT,
    [HttpErrorCode.NETWORK_ERROR]: AppErrorCode.NETWORK_ERROR,
    [HttpErrorCode.CONNECTION_ERROR]: AppErrorCode.CONNECTION_ERROR,
    [HttpErrorCode.SSL_ERROR]: AppErrorCode.SSL_ERROR,
    [HttpErrorCode.ABORTED]: AppErrorCode.ABORTED,
    [HttpErrorCode.INVALID_URL]: AppErrorCode.INVALID_URL,
    [HttpErrorCode.HTTP_ERROR]: AppErrorCode.HTTP_ERROR,
    [HttpErrorCode.REDIRECT_ERROR]: AppErrorCode.REDIRECT_ERROR,
    [HttpErrorCode.CACHE_ERROR]: AppErrorCode.CACHE_ERROR
  };
  return mapping[code] ?? AppErrorCode.UNKNOWN;
}

export class HttpErrorImpl extends AppError implements HttpError {
  readonly httpCode: HttpErrorCode;
  readonly status?: number;
  readonly statusText?: string;
  readonly headers?: HttpHeaders;
  readonly config?: HttpRequestConfig;
  readonly response?: HttpResponse;
  readonly request?: HttpRequestConfig;
  readonly isRetryable: boolean;

  constructor(
    code: HttpErrorCode,
    message: string,
    options?: HttpErrorOptions
  ) {
    const appCode = mapHttpErrorCode(code);
    const appOptions: AppErrorOptions = {
      category: ErrorCategory.NETWORK,
      severity: HttpErrorImpl.inferSeverityFromCode(code, options?.status),
      recoverable: HttpErrorImpl.inferRecoverableFromCode(code),
      retryable: HttpErrorImpl.checkRetryable(code, options?.status),
      cause: options?.cause
    };

    super(appCode, message, appOptions);

    this.httpCode = code;
    this.name = 'HttpError';
    this.status = options?.status;
    this.statusText = options?.statusText;
    this.headers = options?.headers;
    this.config = options?.config;
    this.response = options?.response;
    this.request = options?.request;
    this.isRetryable = this.retryable;
  }

  private static inferSeverityFromCode(code: HttpErrorCode, status?: number): ErrorSeverity {
    if (code === HttpErrorCode.SSL_ERROR) return ErrorSeverity.CRITICAL;
    if (code === HttpErrorCode.TIMEOUT || code === HttpErrorCode.NETWORK_ERROR) {
      return ErrorSeverity.HIGH;
    }
    if (code === HttpErrorCode.HTTP_ERROR && status) {
      if (status >= 500) return ErrorSeverity.HIGH;
      if (status >= 400) return ErrorSeverity.MEDIUM;
    }
    return ErrorSeverity.MEDIUM;
  }

  private static inferRecoverableFromCode(code: HttpErrorCode): boolean {
    const unrecoverableCodes = [
      HttpErrorCode.INVALID_URL,
      HttpErrorCode.ABORTED,
      HttpErrorCode.CANCELLED
    ];
    return !unrecoverableCodes.includes(code);
  }

  private static checkRetryable(code: HttpErrorCode, status?: number): boolean {
    if (code === HttpErrorCode.ABORTED || code === HttpErrorCode.CANCELLED) {
      return false;
    }

    if (code === HttpErrorCode.TIMEOUT || code === HttpErrorCode.NETWORK_ERROR) {
      return true;
    }

    if (code === HttpErrorCode.HTTP_ERROR && status) {
      const retryableStatusCodes = [408, 429, 500, 502, 503, 504];
      return retryableStatusCodes.includes(status);
    }

    return false;
  }



  static timeout(message: string = 'Request timeout', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.TIMEOUT, message, options);
  }

  static networkError(message: string = 'Network error', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.NETWORK_ERROR, message, options);
  }

  static connectionError(message: string = 'Connection failed', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.CONNECTION_ERROR, message, options);
  }

  static sslError(message: string = 'SSL certificate error', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.SSL_ERROR, message, options);
  }

  static aborted(message: string = 'Request aborted', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.ABORTED, message, options);
  }

  static cancelled(message: string = 'Request cancelled', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.CANCELLED, message, options);
  }

  static invalidUrl(url: string, config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.INVALID_URL, `Invalid URL: ${url}`, options);
  }

  static invalidResponse(message: string = 'Invalid response', config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.INVALID_RESPONSE, message, options);
  }

  static parseError(message: string, config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(HttpErrorCode.PARSE_ERROR, `Parse error: ${message}`, options);
  }

  static tooLarge(size: number, maxSize: number, config?: HttpRequestConfig): HttpErrorImpl {
    const options: HttpErrorOptions = { config: config };
    return new HttpErrorImpl(
      HttpErrorCode.TOO_LARGE,
      `Response too large: ${size} bytes (max: ${maxSize})`,
      options
    );
  }

  static httpError(
    status: number,
    statusText: string,
    options?: HttpErrorOptions
  ): HttpErrorImpl {
    const errorOptions: HttpErrorOptions = {
      status,
      statusText,
      headers: options?.headers,
      config: options?.config,
      response: options?.response
    };
    return new HttpErrorImpl(
      HttpErrorCode.HTTP_ERROR,
      `HTTP Error ${status}: ${statusText}`,
      errorOptions
    );
  }

  static redirectError(message: string, config?: HttpRequestConfig): HttpErrorImpl {
    return new HttpErrorImpl(HttpErrorCode.REDIRECT_ERROR, message, { config });
  }

  static cacheError(message: string, config?: HttpRequestConfig): HttpErrorImpl {
    return new HttpErrorImpl(HttpErrorCode.CACHE_ERROR, message, { config });
  }

  static fromError(error: Error, config?: HttpRequestConfig): HttpErrorImpl {
    const message = error.message.toLowerCase();

    if (message.includes('timeout')) {
      return HttpErrorImpl.timeout(error.message, config);
    }

    if (message.includes('abort') || message.includes('cancel')) {
      return HttpErrorImpl.aborted(error.message, config);
    }

    if (message.includes('ssl') || message.includes('certificate')) {
      return HttpErrorImpl.sslError(error.message, config);
    }

    if (message.includes('network') || message.includes('connection') || message.includes('econnrefused')) {
      return HttpErrorImpl.networkError(error.message, config);
    }

    return new HttpErrorImpl(HttpErrorCode.UNKNOWN, error.message, new HttpErrorOptionsImpl(config, error));
  }

  toJSON(): AppErrorJSON {
    const baseJson = super.toJSON();
    return baseJson;
  }

  toHttpErrorJSON(): HttpErrorJSON {
    return {
      name: this.name,
      code: super.code,
      message: this.message,
      status: this.status,
      statusText: this.statusText,
      isRetryable: this.isRetryable,
      timestamp: this.timestamp,
      url: this.config?.url
    };
  }

  toString(): string {
    let str = `HttpError [${this.httpCode}]: ${this.message}`;
    if (this.status) {
      str += ` (status: ${this.status})`;
    }
    if (this.config?.url) {
      str += ` - ${this.config.url}`;
    }
    return str;
  }
}

export default HttpErrorImpl;
