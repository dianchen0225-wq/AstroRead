/**
 * InterceptorManager - 拦截器管理器
 * 管理请求和响应拦截器
 */

import {
  RequestInterceptor,
  ResponseInterceptor,
  HttpRequestConfig,
  HttpResponse,
  HttpError,
  HttpErrorCode
} from './interfaces/IHttpClient';

type RequestInterceptorHandler = (config: HttpRequestConfig) => HttpRequestConfig | Promise<HttpRequestConfig>;
type RequestErrorHandler = (error: HttpError) => HttpError | Promise<HttpError>;
type ResponseInterceptorHandler = (response: HttpResponse<ESObject>) => HttpResponse<ESObject> | Promise<HttpResponse<ESObject>>;
type ResponseErrorHandler = (error: HttpError) => HttpError | Promise<HttpError>;
interface InternalRequestInterceptor extends RequestInterceptor {
  handler: RequestInterceptorHandler;
  errorHandler?: RequestErrorHandler;
}

interface InternalResponseInterceptor extends ResponseInterceptor {
  handler: ResponseInterceptorHandler;
  errorHandler?: ResponseErrorHandler;
}

interface InterceptorOptions {
  priority?: number;
  id?: string;
}

export class InterceptorManager {
  private requestInterceptors: Map<string, InternalRequestInterceptor> = new Map();
  private responseInterceptors: Map<string, InternalResponseInterceptor> = new Map();
  private interceptorIdCounter: number = 0;
  useRequestInterceptor(
    handler: RequestInterceptorHandler,
    errorHandler?: RequestErrorHandler,
    options?: InterceptorOptions
  ): string {
    const id = options?.id ?? `request_${++this.interceptorIdCounter}`;
    const priority = options?.priority ?? 0;

    const interceptor: InternalRequestInterceptor = {
      id,
      priority,
      handler,
      errorHandler,
      onRequest: handler,
      onRequestError: errorHandler
    };

    this.requestInterceptors.set(id, interceptor);
    return id;
  }
  useResponseInterceptor(
    handler: ResponseInterceptorHandler,
    errorHandler?: ResponseErrorHandler,
    options?: InterceptorOptions
  ): string {
    const id = options?.id ?? `response_${++this.interceptorIdCounter}`;
    const priority = options?.priority ?? 0;

    const interceptor: InternalResponseInterceptor = {
      id,
      priority,
      handler,
      errorHandler,
      onResponse: handler,
      onResponseError: errorHandler
    };

    this.responseInterceptors.set(id, interceptor);
    return id;
  }

  removeRequestInterceptor(id: string): boolean {
    return this.requestInterceptors.delete(id);
  }

  removeResponseInterceptor(id: string): boolean {
    return this.responseInterceptors.delete(id);
  }

  clear(): void {
    this.requestInterceptors.clear();
    this.responseInterceptors.clear();
  }

  async applyRequestInterceptors(config: HttpRequestConfig): Promise<HttpRequestConfig> {
    const sortedInterceptors = this.getSortedRequestInterceptors();

    let processedConfig = config;
    for (const interceptor of sortedInterceptors) {
      try {
        const result = interceptor.handler(processedConfig);
        processedConfig = result instanceof Promise ? await result : result;
      } catch (error) {
        if (interceptor.errorHandler) {
          const httpError = this.toHttpError(error);
          const errorResult = interceptor.errorHandler(httpError);
          const processedError = errorResult instanceof Promise ? await errorResult : errorResult;
          throw processedError;
        }
        throw this.toHttpError(error);
      }
    }

    return processedConfig;
  }

  async applyResponseInterceptors<T = void>(response: HttpResponse<T>): Promise<HttpResponse<T>> {
    const sortedInterceptors = this.getSortedResponseInterceptors();

    let processedResponse: HttpResponse<ESObject> = response as HttpResponse<ESObject>;
    for (const interceptor of sortedInterceptors) {
      try {
        const result = interceptor.handler(processedResponse);
        if (result instanceof Promise) {
          processedResponse = await result;
        } else {
          processedResponse = result;
        }
      } catch (error) {
        if (interceptor.errorHandler) {
          const httpError = this.toHttpError(error as Error);
          const errorResult = interceptor.errorHandler(httpError);
          if (errorResult instanceof Promise) {
            const processedError = await errorResult;
            throw processedError;
          } else {
            throw errorResult;
          }
        }
        throw this.toHttpError(error as Error);
      }
    }

    return processedResponse as HttpResponse<T>;
  }

  private toHttpError(error: Error): HttpError {
    const message = error.message;
    const httpError: HttpError = {
      code: 'INTERCEPTOR_ERROR' as HttpErrorCode,
      message,
      name: 'InterceptorError',
      isRetryable: false,
      timestamp: Date.now()
    };
    return httpError;
  }

  async applyRequestErrorInterceptors(error: HttpError): Promise<HttpError> {
    const sortedInterceptors = this.getSortedRequestInterceptors();

    let processedError = error;

    for (const interceptor of sortedInterceptors) {
      if (interceptor.errorHandler) {
        try {
          const result = interceptor.errorHandler(processedError);
          if (result instanceof Promise) {
            processedError = await result;
          } else {
            processedError = result;
          }
        } catch (err) {
          processedError = err as HttpError;
        }
      }
    }

    return processedError;
  }

  async applyResponseErrorInterceptors(error: HttpError): Promise<HttpError> {
    const sortedInterceptors = this.getSortedResponseInterceptors();

    let processedError = error;

    for (const interceptor of sortedInterceptors) {
      if (interceptor.errorHandler) {
        try {
          const result = interceptor.errorHandler(processedError);
          if (result instanceof Promise) {
            processedError = await result;
          } else {
            processedError = result;
          }
        } catch (err) {
          processedError = err as HttpError;
        }
      }
    }

    return processedError;
  }

  private getSortedRequestInterceptors(): InternalRequestInterceptor[] {
    return Array.from(this.requestInterceptors.values())
      .sort((a, b) => a.priority - b.priority);
  }

  private getSortedResponseInterceptors(): InternalResponseInterceptor[] {
    return Array.from(this.responseInterceptors.values())
      .sort((a, b) => a.priority - b.priority);
  }

  getRequestInterceptorIds(): string[] {
    return Array.from(this.requestInterceptors.keys());
  }

  getResponseInterceptorIds(): string[] {
    return Array.from(this.responseInterceptors.keys());
  }

  hasRequestInterceptor(id: string): boolean {
    return this.requestInterceptors.has(id);
  }

  hasResponseInterceptor(id: string): boolean {
    return this.responseInterceptors.has(id);
  }
}

export default InterceptorManager;
