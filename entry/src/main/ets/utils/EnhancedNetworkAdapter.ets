/**
 * EnhancedNetworkAdapter - 增强版网络适配器
 * 提供更强的反爬虫能力和错误处理
 */

import http from '@ohos.net.http';
import { Logger } from './Logger';

export interface EnhancedRequestOptions {
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
  timeout?: number;
  retryCount?: number;
  retryDelay?: number;
}

export class EnhancedNetworkAdapter {
  private static instance: EnhancedNetworkAdapter | null = null;
  private readonly TAG = 'EnhancedNetworkAdapter';
  private userAgentIndex: number = 0;

  // 扩展的User-Agent列表
  private readonly USER_AGENTS: string[] = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1'
  ];

  private constructor() {}

  static getInstance(): EnhancedNetworkAdapter {
    if (!EnhancedNetworkAdapter.instance) {
      EnhancedNetworkAdapter.instance = new EnhancedNetworkAdapter();
    }
    return EnhancedNetworkAdapter.instance;
  }

  /**
   * 获取随机User-Agent
   */
  private getRandomUserAgent(): string {
    const ua = this.USER_AGENTS[this.userAgentIndex];
    this.userAgentIndex = (this.userAgentIndex + 1) % this.USER_AGENTS.length;
    return ua;
  }

  /**
   * 构建完整的反爬虫请求头
   */
  private buildAntiScrapingHeaders(url: string, customHeaders?: Record<string, string>): Record<string, string> {
    const headers: Record<string, string> = {};

    // 1. 随机User-Agent
    headers['User-Agent'] = this.getRandomUserAgent();

    // 2. 标准浏览器请求头
    headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';
    headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6';
    headers['Accept-Encoding'] = 'gzip, deflate, br';
    headers['Cache-Control'] = 'max-age=0';
    headers['Connection'] = 'keep-alive';

    // 3. Chrome特有的安全头
    headers['Sec-Ch-Ua'] = '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"';
    headers['Sec-Ch-Ua-Mobile'] = '?0';
    headers['Sec-Ch-Ua-Platform'] = '"Windows"';
    headers['Sec-Fetch-Dest'] = 'document';
    headers['Sec-Fetch-Mode'] = 'navigate';
    headers['Sec-Fetch-Site'] = 'none';
    headers['Sec-Fetch-User'] = '?1';
    headers['Upgrade-Insecure-Requests'] = '1';

    // 4. 根据URL设置Referer
    try {
      const urlObj = new URL(url);
      headers['Referer'] = `${urlObj.protocol}//${urlObj.hostname}/`;
      headers['Origin'] = `${urlObj.protocol}//${urlObj.hostname}`;
    } catch (e) {
      Logger.warn(this.TAG, `解析URL失败: ${url}`);
    }

    // 5. 合并自定义请求头(优先级更高)
    if (customHeaders) {
      const keys = Object.keys(customHeaders);
      for (const key of keys) {
        headers[key] = customHeaders[key];
      }
    }

    return headers;
  }

  /**
   * 增强版请求方法(带重试和反爬虫)
   */
  async request(url: string, options?: EnhancedRequestOptions): Promise<string> {
    const maxRetries = options?.retryCount || 3;
    const retryDelay = options?.retryDelay || 1000;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // 每次重试前延迟
        if (attempt > 0) {
          const delay = Math.min(retryDelay * Math.pow(2, attempt - 1), 5000);
          Logger.info(this.TAG, `重试请求: ${url}, 第${attempt}次, 延迟${delay}ms`);
          await this.sleep(delay);
        }

        const result = await this.executeRequest(url, options);
        return result;

      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        const errorMsg = lastError.message.toLowerCase();

        // 403错误可能是反爬虫,尝试轮换UA
        if (errorMsg.includes('403')) {
          Logger.warn(this.TAG, `403错误,尝试轮换User-Agent: ${url}`);
          continue;
        }

        // 404错误不重试
        if (errorMsg.includes('404')) {
          Logger.error(this.TAG, `404错误,不重试: ${url}`);
          throw lastError;
        }

        // SSL错误不重试
        if (errorMsg.includes('ssl') || errorMsg.includes('certificate')) {
          Logger.error(this.TAG, `SSL错误,不重试: ${url}`);
          throw lastError;
        }

        // 超时和网络错误可以重试
        if (errorMsg.includes('timeout') || errorMsg.includes('network') || errorMsg.includes('dns')) {
          Logger.warn(this.TAG, `${errorMsg.includes('timeout') ? '超时' : '网络'}错误,准备重试: ${url}`);
          continue;
        }

        // 其他错误也重试
        Logger.warn(this.TAG, `请求失败,准备重试: ${url}, 错误: ${errorMsg}`);
      }
    }

    throw lastError || new Error('Max retries exceeded');
  }

  /**
   * 执行单次请求
   */
  private async executeRequest(url: string, options?: EnhancedRequestOptions): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const httpRequest = http.createHttp();

      const method: 'GET' | 'POST' = options?.method || 'GET';
      const headers = this.buildAntiScrapingHeaders(url, options?.headers);
      const timeout = Math.min(options?.timeout || 10000, 30000);

      const requestOptions: http.HttpRequestOptions = {
        method: method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: headers,
        extraData: options?.body || '',
        readTimeout: timeout,
        connectTimeout: timeout,
      };

      Logger.debug(this.TAG, `发起请求: ${url}, 方法: ${method}, 超时: ${timeout}ms`);
      Logger.debug(this.TAG, `请求头: User-Agent=${headers['User-Agent']}`);

      httpRequest.request(url, requestOptions, (err, data) => {
        if (!err && data) {
          const responseCode = data.responseCode;
          const result = data.result.toString();

          Logger.debug(this.TAG, `请求完成: ${url}, 状态码: ${responseCode}, 响应长度: ${result.length}`);

          if (responseCode >= 200 && responseCode < 300) {
            resolve(result);
          } else if (responseCode === 403) {
            reject(new Error('访问被拒绝(403)，可能触发了反爬机制'));
          } else if (responseCode === 404) {
            reject(new Error('页面不存在(404)'));
          } else if (responseCode >= 500) {
            reject(new Error(`服务器错误(${responseCode})`));
          } else {
            reject(new Error(`HTTP ${responseCode}: ${result.substring(0, 200)}`));
          }
        } else {
          const errorMsg = err?.message || 'Unknown error';
          Logger.error(this.TAG, `请求失败: ${url}, 错误: ${errorMsg}`);
          reject(new Error(errorMsg));
        }
        httpRequest.destroy();
      });
    });
  }

  /**
   * 延迟方法
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * GET请求
   */
  async get(url: string, headers?: Record<string, string>, timeout?: number): Promise<string> {
    return this.request(url, {
      method: 'GET',
      headers: headers,
      timeout: timeout
    });
  }

  /**
   * POST请求
   */
  async post(url: string, body: string, headers?: Record<string, string>, timeout?: number): Promise<string> {
    return this.request(url, {
      method: 'POST',
      body: body,
      headers: headers,
      timeout: timeout
    });
  }
}

export const enhancedNetworkAdapter = EnhancedNetworkAdapter.getInstance();
