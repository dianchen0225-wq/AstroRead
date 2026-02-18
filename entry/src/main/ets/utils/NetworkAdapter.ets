/**
 * NetworkAdapter - 网络适配器
 * 使用鸿蒙原生 @ohos.net.http 实现
 */

import http from '@ohos.net.http';
import { Logger } from './Logger';

export enum NetworkType {
  NATIVE = 'native'
}

export interface NetworkRequestOptions {
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
  timeout?: number;
  charset?: string;
  type?: string;
}

export class NetworkAdapter {
  private static instance: NetworkAdapter | null = null;
  private readonly TAG = 'NetworkAdapter';
  private defaultHeaders: Map<string, string> = new Map();

  private constructor() {}

  static getInstance(): NetworkAdapter {
    if (!NetworkAdapter.instance) {
      NetworkAdapter.instance = new NetworkAdapter();
    }
    return NetworkAdapter.instance;
  }

  async request(url: string, options?: NetworkRequestOptions): Promise<string> {
    const opts: NetworkRequestOptions = options ?? {};
    return this.nativeRequest(url, opts);
  }

  async get(url: string, headers?: Record<string, string>): Promise<string> {
    const opts: NetworkRequestOptions = {
      method: 'GET',
      headers: headers
    };
    return this.request(url, opts);
  }

  async post(url: string, body: string, headers?: Record<string, string>): Promise<string> {
    const opts: NetworkRequestOptions = {
      method: 'POST',
      body: body,
      headers: headers
    };
    return this.request(url, opts);
  }

  private async nativeRequest(url: string, options: NetworkRequestOptions): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void) => {
      const httpRequest = http.createHttp();

      const method: 'GET' | 'POST' = options.method || 'GET';
      const headers: Record<string, string> = options.headers || {};
      
      this.defaultHeaders.forEach((value: string, key: string) => {
        if (!headers[key]) {
          headers[key] = value;
        }
      });

      const requestOptions: http.HttpRequestOptions = {
        method: method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: headers,
        extraData: options.body || '',
        readTimeout: options.timeout || 30000,
        connectTimeout: options.timeout || 30000,
      };

      httpRequest.request(url, requestOptions, (err: Error | null, data: http.HttpResponse) => {
        if (!err && data) {
          resolve(data.result.toString());
        } else {
          reject(new Error(`HTTP Error: ${err?.message || 'Unknown error'}`));
        }
        httpRequest.destroy();
      });
    });
  }

  setDefaultHeader(key: string, value: string): void {
    this.defaultHeaders.set(key, value);
  }

  removeDefaultHeader(key: string): void {
    this.defaultHeaders.delete(key);
  }

  clearCookies(): void {
    Logger.info(this.TAG, 'Cookies cleared (no-op for native HTTP)');
  }
}

export default NetworkAdapter.getInstance();
