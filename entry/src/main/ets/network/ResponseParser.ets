/**
 * ResponseParser - 响应解析器
 * 负责解析HTTP响应数据和响应头
 */

import {
  HttpRequestConfig,
  HttpResponse,
  HttpHeaders
} from './interfaces/IHttpClient';
import { ConfigManager } from './HttpClientConfig';

/**
 * 响应解析器
 */
export class ResponseParser {
  /**
   * 解析响应数据
   */
  static parseResponseData<T>(
    data: string | ArrayBuffer,
    config: HttpRequestConfig
  ): T {
    const responseType = config.responseType?.type ?? 'text';

    if (responseType === 'json') {
      try {
        if (typeof data === 'string') {
          return JSON.parse(data) as T;
        }
        return data as T;
      } catch {
        return data as T;
      }
    }

    return data as T;
  }

  /**
   * 解析响应头
   */
  static parseResponseHeaders(header: Record<string, string>): HttpHeaders {
    const result: HttpHeaders = {};

    // 常用响应头映射
    const headerMappings: Record<string, keyof HttpHeaders> = {
      'content-type': 'Content-Type',
      'cache-control': 'Cache-Control',
      'set-cookie': 'Set-Cookie',
      'user-agent': 'UserAgent',
      'authorization': 'Authorization'
    };
    const entries = Object.entries(header);
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const key = entry[0];
      const value = entry[1];
      const normalizedKey = key.toLowerCase();
      const mappedKey = headerMappings[normalizedKey];
      
      if (mappedKey) {
        result[mappedKey] = value;
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  /**
   * 创建响应对象
   */
  static createResponse<T>(
    data: T,
    status: number,
    headers: HttpHeaders,
    config: HttpRequestConfig,
    duration: number,
    cached: boolean = false,
    retries: number = 0
  ): HttpResponse<T> {
    return {
      data,
      status,
      statusText: ConfigManager.getStatusText(status),
      headers,
      config,
      duration,
      cached,
      retries
    };
  }

  /**
   * 估算数据大小
   */
  static estimateSize(data: ESObject): number {
    if (typeof data === 'string') {
      return data.length;
    }
    if (data instanceof ArrayBuffer) {
      return data.byteLength;
    }
    if (typeof data === 'object' && data !== null) {
      return JSON.stringify(data).length;
    }
    return 0;
  }

  /**
   * 提取Set-Cookie头
   */
  static extractSetCookie(headers: HttpHeaders): string | undefined {
    return headers['Set-Cookie'];
  }
}

export default ResponseParser;