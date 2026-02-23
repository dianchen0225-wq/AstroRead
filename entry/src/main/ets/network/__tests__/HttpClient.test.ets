/**
 * HttpClient 单元测试
 * 符合 HarmonyOS 严格类型检查规范
 */
import defaultHttpClient from '../HttpClient';
import { HttpErrorImpl } from '../HttpError';
import { HttpRequestConfig, HttpHeaders, RequestCacheConfig, HttpResponse, RequestMetrics, JsonObject, JsonPrimitive, JsonArray } from '../interfaces/IHttpClient';
import { AppErrorCode } from '../../core/AppError';

// 测试专用的接口定义
interface TestData extends Record<string, JsonPrimitive | JsonArray | Record<string, JsonPrimitive>> {
  name: string;
  age: number;
}

interface TestHeaders extends HttpHeaders {
  'X-Custom-Header': string;
}

/**
 * HttpClient 测试套件
 */
export class HttpClientTest {
  
  /**
   * 测试前设置
   */
  setup(): void {
    // HttpClient 实例方法调用
  }

  /**
   * 测试后清理
   */
  teardown(): void {
    // Cleanup
  }

  /**
   * 测试基本 GET 请求
   */
  async testGetRequest(): Promise<boolean> {
    try {
      const config: HttpRequestConfig = {
        url: 'https://httpbin.org/get',
        timeout: 10000
      };
      
      const response: HttpResponse<string> = await defaultHttpClient.get<string>('https://httpbin.org/get', config);

      if (response.status !== 200) {
        console.error('GET request failed with status:', response.status);
        return false;
      }

      if (!response.data) {
        console.error('Response data is undefined');
        return false;
      }

      if (response.duration <= 0) {
        console.error('Invalid duration:', response.duration);
        return false;
      }

      console.log('✅ GET request test passed');
      return true;
    } catch (error) {
      console.error('GET request test failed:', error);
      return false;
    }
  }

  /**
   * 测试 POST 请求
   */
  async testPostRequest(): Promise<boolean> {
    try {
      const data: TestData = { name: '张三', age: 25 };
      const config: HttpRequestConfig = {
        url: 'https://httpbin.org/post',
        timeout: 10000
      };
      
      const response: HttpResponse<object> = await defaultHttpClient.post<object>('https://httpbin.org/post', data, config);

      if (response.status !== 200) {
        console.error('POST request failed with status:', response.status);
        return false;
      }

      if (!response.data) {
        console.error('Response data is undefined');
        return false;
      }

      console.log('✅ POST request test passed');
      return true;
    } catch (error) {
      console.error('POST request test failed:', error);
      return false;
    }
  }

  /**
   * 测试自定义头
   */
  async testCustomHeaders(): Promise<boolean> {
    try {
      const headers: TestHeaders = {
        'X-Custom-Header': 'test-value'
      };
      
      const config: HttpRequestConfig = {
        url: 'https://httpbin.org/headers',
        headers: headers,
        timeout: 10000
      };
      
      const response: HttpResponse<string> = await defaultHttpClient.get<string>('https://httpbin.org/headers', config);

      if (response.status !== 200) {
        console.error('Custom headers test failed with status:', response.status);
        return false;
      }

      console.log('✅ Custom headers test passed');
      return true;
    } catch (error) {
      console.error('Custom headers test failed:', error);
      return false;
    }
  }

  /**
   * 测试超时功能
   */
  async testTimeout(): Promise<boolean> {
    try {
      const config: HttpRequestConfig = {
        url: 'https://httpbin.org/delay/5',
        timeout: 1000
      };
      
      await defaultHttpClient.get<string>('https://httpbin.org/delay/5', config);
      
      console.error('Timeout test failed - request should have timed out');
      return false;
    } catch (error) {
      if (error instanceof HttpErrorImpl && error.code === AppErrorCode.TIMEOUT) {
        console.log('✅ Timeout test passed');
        return true;
      }
      
      console.error('Timeout test failed with unexpected error:', error);
      return false;
    }
  }

  /**
   * 测试缓存功能
   */
  async testCache(): Promise<boolean> {
    try {
      const url = 'https://httpbin.org/cache/60';
      const cacheConfig: RequestCacheConfig = { enabled: true, ttl: 60000 };

      const config1: HttpRequestConfig = {
        url: url,
        cache: cacheConfig,
        timeout: 10000
      };

      const config2: HttpRequestConfig = {
        url: url,
        cache: cacheConfig,
        timeout: 10000
      };

      const response1: HttpResponse<string> = await defaultHttpClient.get<string>(url, config1);
      const response2: HttpResponse<string> = await defaultHttpClient.get<string>(url, config2);

      if (response1.cached !== false) {
        console.error('First response should not be cached');
        return false;
      }

      if (response2.cached !== true) {
        console.error('Second response should be cached');
        return false;
      }

      console.log('✅ Cache test passed');
      return true;
    } catch (error) {
      console.error('Cache test failed:', error);
      return false;
    }
  }

  /**
   * 测试错误处理
   */
  async testErrorHandling(): Promise<boolean> {
    try {
      const config: HttpRequestConfig = {
        url: 'https://httpbin.org/status/404',
        timeout: 10000
      };
      
      await defaultHttpClient.get<string>('https://httpbin.org/status/404', config);
      
      console.error('Error handling test failed - request should have thrown error');
      return false;
    } catch (error) {
      if (error instanceof HttpErrorImpl && error.status === 404) {
        console.log('✅ Error handling test passed');
        return true;
      }
      
      console.error('Error handling test failed with unexpected error:', error);
      return false;
    }
  }

  /**
   * 测试指标记录
   */
  async testMetrics(): Promise<boolean> {
    try {
      const config: HttpRequestConfig = {
        url: 'https://httpbin.org/get',
        timeout: 10000
      };
      
      await defaultHttpClient.get<string>('https://httpbin.org/get', config);

      const metrics: RequestMetrics[] = defaultHttpClient.getMetrics();

      if (metrics.length === 0) {
        console.error('Metrics test failed - no metrics recorded');
        return false;
      }

      // 使用类型断言确保类型安全
      const firstMetric = metrics[0] as RequestMetrics;
      
      if (!firstMetric.url.includes('httpbin.org')) {
        console.error('Metrics test failed - invalid URL in metrics');
        return false;
      }

      if (firstMetric.success !== true) {
        console.error('Metrics test failed - request should be successful');
        return false;
      }

      console.log('✅ Metrics test passed');
      return true;
    } catch (error) {
      console.error('Metrics test failed:', error);
      return false;
    }
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting HttpClient tests...');
    
    this.setup();
    
    const tests: Promise<boolean>[] = [
      this.testGetRequest(),
      this.testPostRequest(),
      this.testCustomHeaders(),
      this.testTimeout(),
      this.testCache(),
      this.testErrorHandling(),
      this.testMetrics()
    ];

    const results: boolean[] = await Promise.all(tests);
    const passed: number = results.filter(result => result).length;
    const total: number = tests.length;

    this.teardown();

    console.log(`\n📊 Test Results: ${passed}/${total} tests passed`);
    
    if (passed === total) {
      console.log('✅ All HttpClient tests passed!');
    } else {
      console.log('❌ Some HttpClient tests failed');
    }

    return passed === total;
  }
}

const httpClientTest: HttpClientTest = new HttpClientTest();
export default httpClientTest;
