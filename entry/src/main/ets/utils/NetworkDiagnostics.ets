/**
 * NetworkDiagnostics - 网络诊断工具
 * 用于检测网络连接状态和书源可用性
 */

import http from '@ohos.net.http';
import { Logger } from './performance/Logger';

export interface DiagnosticResult {
  url: string;
  success: boolean;
  responseTime: number;
  statusCode?: number;
  error?: string;
}

export interface NetworkStatus {
  isConnected: boolean;
  latency: number;
  lastCheckTime: number;
}

export class NetworkDiagnostics {
  private static instance: NetworkDiagnostics | null = null;
  private readonly TAG = 'NetworkDiagnostics';

  // 测试URL列表(用于检测网络连接)
  private readonly TEST_URLS: string[] = [
    'https://www.baidu.com',
    'https://www.qq.com',
    'https://www.bing.com',
    'https://www.taobao.com'
  ];

  private constructor() {}

  static getInstance(): NetworkDiagnostics {
    if (!NetworkDiagnostics.instance) {
      NetworkDiagnostics.instance = new NetworkDiagnostics();
    }
    return NetworkDiagnostics.instance;
  }

  /**
   * 检测网络连接状态
   */
  async checkNetworkConnection(): Promise<NetworkStatus> {
    const startTime = Date.now();
    let isConnected = false;
    let minLatency = Infinity;

    for (const url of this.TEST_URLS) {
      try {
        const result = await this.testUrl(url, 5000);
        if (result.success) {
          isConnected = true;
          minLatency = Math.min(minLatency, result.responseTime);
        }
      } catch (error) {
        Logger.debug(this.TAG, `测试URL失败: ${url}`);
      }
    }

    return {
      isConnected: isConnected,
      latency: isConnected ? minLatency : -1,
      lastCheckTime: Date.now()
    };
  }

  /**
   * 测试单个URL
   */
  async testUrl(url: string, timeout: number = 10000): Promise<DiagnosticResult> {
    const startTime = Date.now();

    return new Promise<DiagnosticResult>((resolve) => {
      const httpRequest = http.createHttp();

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        readTimeout: timeout,
        connectTimeout: timeout,
      };

      Logger.debug(this.TAG, `测试URL: ${url}`);

      httpRequest.request(url, requestOptions, (err, data) => {
        const responseTime = Date.now() - startTime;

        if (!err && data) {
          const statusCode = data.responseCode;
          const success = statusCode >= 200 && statusCode < 400;

          Logger.debug(this.TAG, `URL测试完成: ${url}, 状态码: ${statusCode}, 响应时间: ${responseTime}ms`);

          resolve({
            url: url,
            success: success,
            responseTime: responseTime,
            statusCode: statusCode
          });
        } else {
          const errorMsg = err?.message || 'Unknown error';
          Logger.warn(this.TAG, `URL测试失败: ${url}, 错误: ${errorMsg}`);

          resolve({
            url: url,
            success: false,
            responseTime: responseTime,
            error: errorMsg
          });
        }

        httpRequest.destroy();
      });
    });
  }

  /**
   * 批量测试书源URL
   */
  async testBookSourceUrls(urls: string[]): Promise<DiagnosticResult[]> {
    const results: DiagnosticResult[] = [];

    Logger.info(this.TAG, `开始批量测试 ${urls.length} 个书源URL`);

    for (const url of urls) {
      const result = await this.testUrl(url, 10000);
      results.push(result);

      // 每次测试间隔100ms,避免过快请求
      await this.sleep(100);
    }

    const successCount = results.filter(r => r.success).length;
    Logger.info(this.TAG, `批量测试完成: ${successCount}/${urls.length} 成功`);

    return results;
  }

  /**
   * 生成网络诊断报告
   */
  async generateDiagnosticReport(): Promise<string> {
    const report: string[] = [];

    report.push('=== 网络诊断报告 ===');
    report.push('');

    // 1. 检测网络连接
    report.push('1. 网络连接状态:');
    const networkStatus = await this.checkNetworkConnection();
    report.push(`   连接状态: ${networkStatus.isConnected ? '已连接' : '未连接'}`);
    if (networkStatus.isConnected) {
      report.push(`   网络延迟: ${networkStatus.latency}ms`);
    }
    report.push('');

    // 2. 测试基础URL
    report.push('2. 基础URL测试:');
    for (const url of this.TEST_URLS) {
      const result = await this.testUrl(url, 5000);
      const status = result.success ? `✓ 成功 (${result.responseTime}ms)` : `✗ 失败 (${result.error})`;
      report.push(`   ${url}: ${status}`);
    }
    report.push('');

    // 3. 统计信息
    const testResults = await this.testBookSourceUrls(this.TEST_URLS);
    const successCount = testResults.filter(r => r.success).length;
    const avgResponseTime = testResults
      .filter(r => r.success)
      .reduce((sum, r) => sum + r.responseTime, 0) / successCount;

    report.push('3. 统计信息:');
    report.push(`   测试URL数: ${testResults.length}`);
    report.push(`   成功数: ${successCount}`);
    report.push(`   失败数: ${testResults.length - successCount}`);
    if (successCount > 0) {
      report.push(`   平均响应时间: ${Math.round(avgResponseTime)}ms`);
    }
    report.push('');

    report.push(`诊断时间: ${new Date().toLocaleString()}`);

    return report.join('\n');
  }

  /**
   * 快速网络检测
   */
  async quickNetworkCheck(): Promise<boolean> {
    try {
      const result = await this.testUrl('https://www.baidu.com', 3000);
      return result.success;
    } catch (error) {
      return false;
    }
  }

  /**
   * 延迟方法
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export const networkDiagnostics = NetworkDiagnostics.getInstance();
