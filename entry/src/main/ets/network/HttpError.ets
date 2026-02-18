
/**
 * HttpError - 统一 HTTP 错误处理
 */

import { HttpErrorCode, HttpError, HttpHeaders, HttpRequestConfig, HttpResponse } from './interfaces/IHttpClient';
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
  code: HttpErrorCode;
  message: string;
  status?: number;
  statusText?: string;
  isRetryable: boolean;
  timestamp: number;
  url?: string;
}

export class HttpErrorImpl extends Error implements HttpError {
  readonly code: HttpErrorCode;
  readonly status?: number;
  readonly statusText?: string;
  readonly headers?: HttpHeaders;
  readonly config?: HttpRequestConfig;
  readonly response?: HttpResponse;
  readonly request?: HttpRequestConfig;
  readonly isRetryable: boolean;
  readonly timestamp: number;
  cause?: Error;
  constructor(
    code: HttpErrorCode,
    message: string,
    options?: HttpErrorOptions
  ) {
    super(message);
    this.name = 'HttpError';
    this.code = code;
    this.status = options?.status;
    this.statusText = options?.statusText;
    this.headers = options?.headers;
    this.config = options?.config;
    this.response = options?.response;
    this.request = options?.request;
    this.timestamp = Date.now();
    this.isRetryable = this.checkRetryable();
    if (options?.cause) {
      this.cause = options.cause;
    }
  }

  private checkRetryable(): boolean {
    if (this.code === HttpErrorCode.ABORTED || this.code === HttpErrorCode.CANCELLED) {
      return false;
    }

    if (this.code === HttpErrorCode.TIMEOUT || this.code === HttpErrorCode.NETWORK_ERROR) {
      return true;
    }

    if (this.code === HttpErrorCode.HTTP_ERROR && this.status) {
      const retryableStatusCodes = [408, 429, 500, 502, 503, 504];
      return retryableStatusCodes.includes(this.status);
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
  toJSON(): HttpErrorJSON {
    const jsonObj: HttpErrorJSON = {
      name: this.name,
      code: this.code,
      message: this.message,
      status: this.status,
      statusText: this.statusText,
      isRetryable: this.isRetryable,
      timestamp: this.timestamp,
      url: this.config?.url
    };
    return jsonObj;
  }

  toString(): string {
    let str = `HttpError [${this.code}]: ${this.message}`;
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
