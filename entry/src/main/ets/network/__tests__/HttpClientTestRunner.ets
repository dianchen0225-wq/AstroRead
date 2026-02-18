/**
 * HttpClient 测试运行器
 * 用于执行 HttpClient 单元测试
 */

import httpClientTest from './HttpClient.test';

/**
 * HttpClient 测试运行器
 */
export class HttpClientTestRunner {
  
  /**
   * 运行 HttpClient 测试套件
   */
  static async runTests(): Promise<boolean> {
    console.log('🚀 Starting HttpClient Test Runner...\n');
    
    const startTime = Date.now();
    const success = await httpClientTest.runAllTests();
    const endTime = Date.now();
    
    console.log(`\n⏱️  Test duration: ${endTime - startTime}ms`);
    
    if (success) {
      console.log('✅ HttpClient tests completed successfully!');
    } else {
      console.log('❌ HttpClient tests failed!');
    }
    
    return success;
  }
}

export default HttpClientTestRunner;