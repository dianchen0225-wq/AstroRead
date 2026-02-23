
/**
 * HttpClient 接口定义
 * 统一网络请求接口规范
 */

import { AppErrorCode } from '../../core/AppError';

type URLSearchParams = HttpUrlSearchParams;

export enum HttpMethod {
  GET = 'GET',
  POST = 'POST',
  PUT = 'PUT',
  DELETE = 'DELETE',
  PATCH = 'PATCH',
  HEAD = 'HEAD',
  OPTIONS = 'OPTIONS'
}

export enum HttpContentType {
  JSON = 'application/json',
  FORM_URLENCODED = 'application/x-www-form-urlencoded',
  FORM_DATA = 'multipart/form-data',
  TEXT = 'text/plain',
  HTML = 'text/html',
  XML = 'application/xml',
  OCTET_STREAM = 'application/octet-stream'
}

export enum HttpStatus {
  CONTINUE = 100,
  SWITCHING_PROTOCOLS = 101,
  OK = 200,
  CREATED = 201,
  ACCEPTED = 202,
  NO_CONTENT = 204,
  MOVED_PERMANENTLY = 301,
  FOUND = 302,
  SEE_OTHER = 303,
  NOT_MODIFIED = 304,
  TEMPORARY_REDIRECT = 307,
  PERMANENT_REDIRECT = 308,
  BAD_REQUEST = 400,
  UNAUTHORIZED = 401,
  FORBIDDEN = 403,
  NOT_FOUND = 404,
  METHOD_NOT_ALLOWED = 405,
  REQUEST_TIMEOUT = 408,
  CONFLICT = 409,
  PAYLOAD_TOO_LARGE = 413,
  URI_TOO_LONG = 414,
  UNSUPPORTED_MEDIA_TYPE = 415,
  TOO_MANY_REQUESTS = 429,
  INTERNAL_SERVER_ERROR = 500,
  NOT_IMPLEMENTED = 501,
  BAD_GATEWAY = 502,
  SERVICE_UNAVAILABLE = 503,
  GATEWAY_TIMEOUT = 504
}

export type HttpHeaderMap = Map<string, string>;
export type HttpHeaderValue = string | string[] | number | boolean;
export interface HttpHeaders extends Record<string, string | undefined> {
  'Content-Type'?: string;
  'Accept'?: string;
  'Authorization'?: string;
  'User-Agent'?: string;
  UserAgent?: string;
  'Referer'?: string;
  'Cookie'?: string;
  'Cache-Control'?: string;
  'Pragma'?: string;
  'Accept-Encoding'?: string;
  'Accept-Language'?: string;
  'Connection'?: string;
  'Host'?: string;
  'Origin'?: string;
  'Set-Cookie'?: string;
  'Location'?: string;
  'ETag'?: string;
  'Last-Modified'?: string;
  'Content-Length'?: string;
  'Content-Encoding'?: string;
  'Transfer-Encoding'?: string;
  'Date'?: string;
  'Server'?: string;
  'X-Request-Id'?: string;
  'X-RateLimit-Limit'?: string;
  'X-RateLimit-Remaining'?: string;
  'Retry-After'?: string;
  'WWW-Authenticate'?: string;
  'Access-Control-Allow-Origin'?: string;
  'Access-Control-Allow-Methods'?: string;
  'Access-Control-Allow-Headers'?: string;
  'Access-Control-Allow-Credentials'?: string;
}

export interface HttpParamEntry {
  value: string | number | boolean;
}

export type HttpParams = Map<string, HttpParamEntry>;

export type JsonPrimitive = string | number | boolean | null;
export type JsonArray = JsonPrimitive[];
export type JsonObject = Record<string, JsonPrimitive | JsonArray | Record<string, JsonPrimitive>>;

export type HttpData = string | JsonObject | ArrayBuffer;
export type HttpBody = string | JsonObject | ArrayBuffer;

export interface RequestMetadata {
  requestId?: string;
  source?: string;
  tags?: string[];
  customData?: Map<string, string>;
}

export interface HttpParamsRecordEntry {
  key: string;
  value: string | number | boolean;
}

export type HttpParamsRecord = HttpParamsRecordEntry[];

export interface HttpResponseType {
  type: 'text' | 'json' | 'arraybuffer' | 'blob';
}

export interface RequestCacheConfig {
  enabled: boolean;
  ttl?: number;
  key?: string;
  forceRefresh?: boolean;
  cacheMethod?: 'memory' | 'disk' | 'both';
}

export interface RetryConfig {
  maxRetries: number;
  retryDelay?: number;
  retryDelayMultiplier?: number;
  maxRetryDelay?: number;
  retryableStatusCodes?: number[];
  retryableErrors?: string[];
  onRetry?: (attempt: number, error: Error, config: HttpRequestConfig) => boolean | Promise<boolean>;
}

export interface HttpAbortEvent {
  type: string;
  target?: HttpAbortSignal;
  currentTarget?: HttpAbortSignal;
  defaultPrevented: boolean;
  preventDefault(): void;
}

export type HttpAbortEventListener = (event: HttpAbortEvent) => void;

export interface HttpAbortSignal {
  aborted: boolean;
  reason?: string;
  onabort?: HttpAbortEventListener | null;
  addEventListener(type: string, callback: HttpAbortEventListener): void;
  removeEventListener(type: string, callback: HttpAbortEventListener): void;
  throwIfAborted(): void;
}

export interface HttpAbortController {
  signal: HttpAbortSignal;
  abort(reason?: string): void;
}
export interface HttpUrlSearchParams {
  append(name: string, value: string): void;
  delete(name: string): void;
  get(name: string): string | null;
  getAll(name: string): string[];
  has(name: string): boolean;
  set(name: string, value: string): void;
  toString(): string;
}

export interface HttpRequestConfig {
  url: string;
  method?: HttpMethod | string;
  headers?: HttpHeaders | HttpHeaderMap;
  params?: HttpParams | HttpUrlSearchParams;
  data?: HttpData;
  body?: HttpBody;
  timeout?: number;
  connectTimeout?: number;
  readTimeout?: number;
  responseType?: HttpResponseType;
  encoding?: string;
  charset?: string;
  withCredentials?: boolean;
  maxRedirects?: number;
  maxResponseSize?: number;
  validateStatus?: (status: number) => boolean;
  signal?: HttpAbortSignal;
  abortController?: HttpAbortController;
  cache?: RequestCacheConfig;
  retry?: RetryConfig;
  metadata?: RequestMetadata;
}

export interface HttpResponse<T = void> {
  data: T;
  status: number;
  statusText: string;
  headers: HttpHeaders;
  config: HttpRequestConfig;
  request?: HttpRequestConfig;
  duration: number;
  cached: boolean;
  retries: number;
}

export interface HttpError extends Error {
  code: HttpErrorCode | AppErrorCode;
  message: string;
  status?: number;
  statusText?: string;
  headers?: HttpHeaders;
  config?: HttpRequestConfig;
  response?: HttpResponse<void>;
  request?: HttpRequestConfig;
  isRetryable: boolean;
  timestamp: number;
}

export enum HttpErrorCode {
  UNKNOWN = 'UNKNOWN',
  TIMEOUT = 'TIMEOUT',
  NETWORK_ERROR = 'NETWORK_ERROR',
  CONNECTION_ERROR = 'CONNECTION_ERROR',
  SSL_ERROR = 'SSL_ERROR',
  ABORTED = 'ABORTED',
  INVALID_URL = 'INVALID_URL',
  INVALID_RESPONSE = 'INVALID_RESPONSE',
  PARSE_ERROR = 'PARSE_ERROR',
  TOO_LARGE = 'TOO_LARGE',
  HTTP_ERROR = 'HTTP_ERROR',
  REDIRECT_ERROR = 'REDIRECT_ERROR',
  CACHE_ERROR = 'CACHE_ERROR',
  CANCELLED = 'CANCELLED'
}

export interface RequestInterceptor {
  id: string;
  priority: number;
  onRequest?: (config: HttpRequestConfig) => HttpRequestConfig | Promise<HttpRequestConfig>;
  onRequestError?: (error: HttpError) => HttpError | Promise<HttpError>;
}

export interface ResponseInterceptor {
  id: string;
  priority: number;
  onResponse?: (response: HttpResponse<void>) => HttpResponse<void> | Promise<HttpResponse<void>>;
  onResponseError?: (error: HttpError) => HttpError | Promise<HttpError>;
}

export interface ProgressEvent {
  loaded: number;
  total: number;
  progress: number;
  timestamp: number;
}

export interface MetricsMetadata {
  customData?: Map<string, string>;
}

export interface RequestMetrics {
  requestId: string;
  url: string;
  method: string;
  startTime: number;
  endTime?: number;
  duration?: number;
  status?: number;
  success: boolean;
  cached: boolean;
  retries: number;
  error?: string;
  requestSize?: number;
  responseSize?: number;
  metadata?: MetricsMetadata;
}

export interface HttpClientConfig {
  baseURL?: string;
  timeout?: number;
  connectTimeout?: number;
  readTimeout?: number;
  headers?: HttpHeaders;
  withCredentials?: boolean;
  maxRedirects?: number;
  maxResponseSize?: number;
  responseType?: HttpResponseType;
  validateStatus?: (status: number) => boolean;
  cache?: RequestCacheConfig;
  retry?: RetryConfig;
  enableLogging?: boolean;
  enableMetrics?: boolean;
  userAgentPool?: string[];
  refererPool?: string[];
}
export interface IHttpClient {
  request<T = Record<string, string>>(config: HttpRequestConfig): Promise<HttpResponse<T>>;
  get<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  post<T = Record<string, string>>(url: string, data?: HttpData, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  put<T = Record<string, string>>(url: string, data?: HttpData, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  delete<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  patch<T = Record<string, string>>(url: string, data?: HttpData, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  head<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  options<T = Record<string, string>>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;

  addRequestInterceptor(interceptor: RequestInterceptor): string;
  addResponseInterceptor(interceptor: ResponseInterceptor): string;
  removeRequestInterceptor(id: string): boolean;
  removeResponseInterceptor(id: string): boolean;

  setDefaultHeader(key: string, value: string): void;
  removeDefaultHeader(key: string): void;
  setBaseURL(url: string): void;
  setDefaultConfig(config: Partial<HttpClientConfig>): void;

  clearCache(): void;
  getCacheStats(): CacheStats;

  getMetrics(): RequestMetrics[];
  clearMetrics(): void;

  abort(requestId: string): boolean;
  abortAll(): void;

  destroy(): void;
}

export interface CacheEntryInfo {
  key: string;
  size: number;
  age: number;
  hits: number;
}

export interface CacheStats {
  size: number;
  maxSize: number;
  hitRate: number;
  missRate: number;
  entries: CacheEntryInfo[];
}

export interface Cookie {
  name: string;
  value: string;
  domain?: string;
  path?: string;
  expires?: number;
  maxAge?: number;
  secure?: boolean;
  httpOnly?: boolean;
  sameSite?: 'Strict' | 'Lax' | 'None';
}

export interface CookieStore {
  set(url: string, cookie: Cookie | string): void;
  get(url: string, name?: string): Cookie | Cookie[] | undefined;
  delete(url: string, name?: string): boolean;
  clear(): void;
  getAll(): Cookie[];
}
