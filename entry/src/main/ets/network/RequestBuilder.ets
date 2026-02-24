/**
 * RequestBuilder - 请求构建器
 * 负责构建HTTP请求选项和URL
 */
import { http } from '@kit.NetworkKit';
import {
  HttpRequestConfig,
  HttpMethod,
  HttpHeaderMap,
  HttpParams,
  HttpData,
  HttpParamEntry,
  HttpUrlSearchParams
} from './interfaces/IHttpClient';
import { ConfigManager } from './HttpClientConfig';

export class RequestBuilder {
  static buildUrl(config: HttpRequestConfig, baseURL: string): string {
    let url = config.url;
    
    if (baseURL && !url.startsWith('http')) {
      url = baseURL + (url.startsWith('/') ? url : '/' + url);
    }
    
    if (config.params) {
      const queryString = RequestBuilder.paramsToString(config.params);
      if (queryString) {
        url += (url.includes('?') ? '&' : '?') + queryString;
      }
    }

    return url;
  }

  static buildRequestOptions(
    config: HttpRequestConfig,
    configManager: ConfigManager
  ): http.HttpRequestOptions {
    const headers = RequestBuilder.headersToRecord(config.headers as HttpHeaderMap);
    
    const requestOptions: http.HttpRequestOptions = {
      method: RequestBuilder.mapMethod(config.method ?? HttpMethod.GET),
      header: headers,
      connectTimeout: config.connectTimeout ?? configManager.getConfig().connectTimeout,
      readTimeout: config.readTimeout ?? configManager.getConfig().readTimeout,
      expectDataType: RequestBuilder.mapDataType(config.responseType?.type ?? 'text')
    };

    RequestBuilder.handleRequestBody(requestOptions, config, headers);

    return requestOptions;
  }

  private static handleRequestBody(
    requestOptions: http.HttpRequestOptions,
    config: HttpRequestConfig,
    headers: Record<string, string>
  ): void {
    const data: HttpData | undefined = config.data ?? config.body;
    
    if (!data) {
      return;
    }

    if (typeof data === 'object' && !(data instanceof ArrayBuffer)) {
      requestOptions.extraData = JSON.stringify(data);
      if (!headers['Content-Type']) {
        const newHeaders: Record<string, string> = {};
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          newHeaders[key] = headers[key];
        }
        newHeaders['Content-Type'] = 'application/json';
        requestOptions.header = newHeaders;
      }
    } else {
      requestOptions.extraData = data as string | ArrayBuffer;
    }
  }

  static paramsToString(params: HttpParams | HttpUrlSearchParams | string): string {
    if (params instanceof Map) {
      const parts: string[] = [];
      params.forEach((entry: HttpParamEntry, key: string) => {
        parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(entry.value.toString())}`);
      });
      return parts.join('&');
    }
    if (typeof params === 'string') {
      return params;
    }
    return params.toString();
  }

  static paramsToRecord(params?: HttpParams | HttpUrlSearchParams | string): Map<string, string> {
    const result: Map<string, string> = new Map();
    
    if (!params) {
      return result;
    }

    if (params instanceof Map) {
      params.forEach((entry: HttpParamEntry, key: string) => {
        result.set(key, entry.value.toString());
      });
    } else if (typeof params === 'string') {
      const queryString = params.startsWith('?') ? params.substring(1) : params;
      const pairs = queryString.split('&');
      for (let i = 0; i < pairs.length; i++) {
        const pair = pairs[i];
        const eqIndex = pair.indexOf('=');
        if (eqIndex > 0) {
          const key = pair.substring(0, eqIndex);
          const value = pair.substring(eqIndex + 1);
          if (key.length > 0) {
            result.set(decodeURIComponent(key), decodeURIComponent(value));
          }
        }
      }
    } else {
      const queryString = (params as HttpUrlSearchParams).toString();
      const pairs = queryString.split('&');
      for (let i = 0; i < pairs.length; i++) {
        const pair = pairs[i];
        const eqIndex = pair.indexOf('=');
        if (eqIndex > 0) {
          const key = pair.substring(0, eqIndex);
          const value = pair.substring(eqIndex + 1);
          if (key.length > 0) {
            result.set(decodeURIComponent(key), decodeURIComponent(value));
          }
        }
      }
    }

    return result;
  }

  static headersToRecord(headers: HttpHeaderMap): Record<string, string> {
    const result: Record<string, string> = {};
    headers.forEach((value: string, key: string) => {
      result[key] = value;
    });
    return result;
  }

  static mapMethod(method: HttpMethod | string): http.RequestMethod {
    if (method === HttpMethod.GET || method === 'GET') {
      return http.RequestMethod.GET;
    }
    if (method === HttpMethod.POST || method === 'POST') {
      return http.RequestMethod.POST;
    }
    if (method === HttpMethod.PUT || method === 'PUT') {
      return http.RequestMethod.PUT;
    }
    if (method === HttpMethod.DELETE || method === 'DELETE') {
      return http.RequestMethod.DELETE;
    }
    if (method === HttpMethod.HEAD || method === 'HEAD') {
      return http.RequestMethod.HEAD;
    }
    if (method === HttpMethod.OPTIONS || method === 'OPTIONS') {
      return http.RequestMethod.OPTIONS;
    }
    if (method === 'PATCH') {
      return http.RequestMethod.OPTIONS;
    }
    return http.RequestMethod.GET;
  }

  static mapDataType(type: string): http.HttpDataType {
    if (type === 'text' || type === 'json') {
      return http.HttpDataType.STRING;
    }
    if (type === 'arraybuffer' || type === 'blob') {
      return http.HttpDataType.ARRAY_BUFFER;
    }
    return http.HttpDataType.STRING;
  }

  static createRequestConfig(
    method: HttpMethod | string,
    url: string,
    data?: HttpData,
    config?: HttpRequestConfig
  ): HttpRequestConfig {
    const result: HttpRequestConfig = {
      url: url,
      method: method,
      data: data
    };
    
    if (config) {
      if (config.params) result.params = config.params;
      if (config.headers) result.headers = config.headers;
      if (config.connectTimeout) result.connectTimeout = config.connectTimeout;
      if (config.readTimeout) result.readTimeout = config.readTimeout;
      if (config.responseType) result.responseType = config.responseType;
      if (config.body) result.body = config.body;
    }
    
    return result;
  }
}

export default RequestBuilder;
