/**
 * TestRunner - 测试运行器
 * 统一运行所有单元测试
 */

import securityUtilsTest from './SecurityUtils.test';
import safeRegexTest from './SafeRegex.test';
import semaphoreTest from './Semaphore.test';

export class TestRunner {
  private static instance: TestRunner | null = null;
  private passed: number = 0;
  private failed: number = 0;

  static getInstance(): TestRunner {
    if (!TestRunner.instance) {
      TestRunner.instance = new TestRunner();
    }
    return TestRunner.instance;
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('═══════════════════════════════════════════════════');
    console.log('  AstroRead 单元测试套件');
    console.log('═══════════════════════════════════════════════════\n');

    const startTime = Date.now();

    // 运行安全工具测试
    console.log('─────────────────────────────────────────────────');
    console.log('  SecurityUtils 测试');
    console.log('─────────────────────────────────────────────────');
    const securityResult = await securityUtilsTest.runAllTests();
    this.updateStats(securityUtilsTest);

    // 运行正则表达式测试
    console.log('\n─────────────────────────────────────────────────');
    console.log('  SafeRegex 测试');
    console.log('─────────────────────────────────────────────────');
    const regexResult = await safeRegexTest.runAllTests();
    this.updateStats(safeRegexTest);

    // 运行信号量测试
    console.log('\n─────────────────────────────────────────────────');
    console.log('  Semaphore 测试');
    console.log('─────────────────────────────────────────────────');
    const semaphoreResult = await semaphoreTest.runAllTests();
    this.updateStats(semaphoreTest);

    const endTime = Date.now();
    const duration = endTime - startTime;

    // 输出总结果
    console.log('\n═══════════════════════════════════════════════════');
    console.log('  测试结果汇总');
    console.log('═══════════════════════════════════════════════════');
    console.log(`  总测试数: ${this.passed + this.failed}`);
    console.log(`  通过: ${this.passed}`);
    console.log(`  失败: ${this.failed}`);
    console.log(`  耗时: ${duration}ms`);
    console.log('═══════════════════════════════════════════════════');

    const allPassed = securityResult && regexResult && semaphoreResult;

    if (allPassed) {
      console.log('✅ 所有测试通过！');
    } else {
      console.log('❌ 部分测试失败');
    }

    return allPassed;
  }

  /**
   * 更新统计
   */
  private updateStats(testInstance: { passed: number; failed: number }): void {
    this.passed += testInstance.passed;
    this.failed += testInstance.failed;
  }

  /**
   * 获取统计信息
   */
  getStats(): { passed: number; failed: number; total: number } {
    return {
      passed: this.passed,
      failed: this.failed,
      total: this.passed + this.failed,
    };
  }

  /**
   * 重置统计
   */
  reset(): void {
    this.passed = 0;
    this.failed = 0;
  }
}

// 导出单例
const testRunner = TestRunner.getInstance();
export default testRunner;

// 如果直接运行此文件，执行测试
if (require.main === module) {
  testRunner.runAllTests().then(success => {
    process.exit(success ? 0 : 1);
  });
}
