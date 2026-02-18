/**
 * Network Module - 统一网络请求模块
 * 导出所有网络相关类型和类
 */

import { HttpClient } from './HttpClient';
import { HttpClientConfig } from './interfaces/IHttpClient';

export * from './interfaces/IHttpClient';
export * from './HttpError';
export * from './InterceptorManager';
export * from './RequestCache';
export * from './RetryHandler';
export * from './AbortController';
export * from './HttpClient';

export function createHttpClient(config?: HttpClientConfig): HttpClient {
  return HttpClient.getInstance(config);
}

export { HttpClient };
