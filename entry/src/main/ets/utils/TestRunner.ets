import { ContentParserTest } from './ContentParserTest';

/**
 * 测试运行器 - 用于验证ContentParser修复效果
 */
export class TestRunner {
  
  /**
   * 运行所有测试并显示结果
   */
  static runTests(): void {
    console.log('🚀 开始运行ContentParser测试套件...\n');
    
    const startTime = Date.now();
    const success = ContentParserTest.runAllTests();
    const endTime = Date.now();
    
    console.log(`\n⏱️  测试耗时: ${endTime - startTime}ms`);
    
    if (success) {
      console.log('✅ 所有测试通过！ContentParser修复成功。');
    } else {
      console.log('❌ 部分测试失败，请检查修复内容。');
    }
  }
  
  /**
   * 单独运行特定测试
   */
  static runSpecificTest(testName: string): void {
    console.log(`🔍 运行特定测试: ${testName}\n`);
    
    let result = false;
    
    switch (testName) {
      case 'jsonpath':
        result = ContentParserTest.testJsonPathSearch();
        break;
      case 'regex':
        result = ContentParserTest.testRegexSearch();
        break;
      case 'purification':
        result = ContentParserTest.testContentPurification();
        break;
      case 'chapter':
        result = ContentParserTest.testChapterParsing();
        break;
      case 'error':
        result = ContentParserTest.testErrorHandling();
        break;
      default:
        console.log('❌ 未知测试名称');
        return;
    }
    
    console.log(`\n${result ? '✅' : '❌'} ${testName}测试: ${result ? '通过' : '失败'}`);
  }
}