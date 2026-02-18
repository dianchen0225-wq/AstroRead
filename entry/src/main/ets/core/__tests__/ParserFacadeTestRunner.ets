 /**
 * ParserFacade 测试运行器
 * 用于执行 ParserFacade 单元测试
 */

import parserFacadeTest from './ParserFacade.test';

/**
 * ParserFacade 测试运行器
 */
export class ParserFacadeTestRunner {
  
  /**
   * 运行 ParserFacade 测试套件
   */
  static async runTests(): Promise<boolean> {
    console.log('🚀 Starting ParserFacade Test Runner...\n');
    
    const startTime = Date.now();
    const success = await parserFacadeTest.runAllTests();
    const endTime = Date.now();
    
    console.log(`\n⏱️  Test duration: ${endTime - startTime}ms`);
    
    if (success) {
      console.log('✅ ParserFacade tests completed successfully!');
    } else {
      console.log('❌ ParserFacade tests failed!');
    }
    
    return success;
  }
}

export default ParserFacadeTestRunner;