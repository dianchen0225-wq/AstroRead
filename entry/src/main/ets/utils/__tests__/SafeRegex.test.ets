/**
 * SafeRegex 单元测试
 * 测试正则表达式安全执行功能
 */

import { SafeRegex } from '../SafeRegex';

export class SafeRegexTest {
  private passed: number = 0;
  private failed: number = 0;

  /**
   * 测试安全的正则表达式执行
   */
  testSafeExecute(): boolean {
    const testCases = [
      {
        pattern: /hello/g,
        input: 'hello world hello',
        expected: ['hello', 'hello'],
        description: '全局匹配'
      },
      {
        pattern: /\d+/,
        input: 'abc123def',
        expected: ['123'],
        description: '数字匹配'
      },
      {
        pattern: /^test$/,
        input: 'test',
        expected: ['test'],
        description: '精确匹配'
      },
      {
        pattern: /no-match/,
        input: 'hello world',
        expected: null,
        description: '无匹配'
      },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      try {
        const result = SafeRegex.safeExecute(testCase.pattern, testCase.input);

        if (testCase.expected === null) {
          if (result !== null) {
            console.error(`❌ testSafeExecute: ${testCase.description}`);
            console.error(`   期望: null, 实际: ${JSON.stringify(result)}`);
            this.failed++;
            allPassed = false;
            continue;
          }
        } else {
          if (result === null) {
            console.error(`❌ testSafeExecute: ${testCase.description}`);
            console.error(`   期望: ${JSON.stringify(testCase.expected)}, 实际: null`);
            this.failed++;
            allPassed = false;
            continue;
          }

          if (result.length !== testCase.expected.length) {
            console.error(`❌ testSafeExecute: ${testCase.description}`);
            console.error(`   期望长度: ${testCase.expected.length}, 实际长度: ${result.length}`);
            this.failed++;
            allPassed = false;
            continue;
          }
        }

        console.log(`✅ ${testCase.description}`);
      } catch (error) {
        console.error(`❌ testSafeExecute: ${testCase.description}`);
        console.error(`   异常: ${error instanceof Error ? error.message : String(error)}`);
        this.failed++;
        allPassed = false;
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testSafeExecute passed');
    }

    return allPassed;
  }

  /**
   * 测试ReDoS防护
   */
  testReDoSProtection(): boolean {
    // 构造可能导致ReDoS的模式
    const evilPattern = /(a+)+$/;
    const evilInput = 'a'.repeat(100) + 'b'; // 这种输入会导致灾难性回溯

    try {
      const startTime = Date.now();
      const result = SafeRegex.safeExecute(evilPattern, evilInput, { timeout: 100 });
      const endTime = Date.now();

      // 应该返回null（超时）而不是卡住
      if (result !== null) {
        console.error('❌ testReDoSProtection: 应该超时返回null');
        this.failed++;
        return false;
      }

      // 执行时间应该接近超时时间而不是很长
      if (endTime - startTime > 200) {
        console.error(`❌ testReDoSProtection: 执行时间过长 (${endTime - startTime}ms)`);
        this.failed++;
        return false;
      }

      console.log('✅ ReDoS防护测试通过');
      this.passed++;
      console.log('✅ testReDoSProtection passed');
      return true;
    } catch (error) {
      console.error(`❌ testReDoSProtection: 异常 ${error instanceof Error ? error.message : String(error)}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试正则表达式验证
   */
  testValidatePattern(): boolean {
    const testCases = [
      {
        pattern: /simple/,
        shouldBeValid: true,
        description: '简单模式'
      },
      {
        pattern: /(a+)+/,
        shouldBeValid: false,
        description: '危险模式 - 嵌套量词'
      },
      {
        pattern: /(a*)*/,
        shouldBeValid: false,
        description: '危险模式 - 嵌套星号'
      },
      {
        pattern: /(a+)*b+/,
        shouldBeValid: false,
        description: '危险模式 - 混合嵌套'
      },
      {
        pattern: /(?:a+)+/,
        shouldBeValid: false,
        description: '危险模式 - 非捕获组嵌套'
      },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const isValid = SafeRegex.validatePattern(testCase.pattern);

      if (isValid !== testCase.shouldBeValid) {
        console.error(`❌ testValidatePattern: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeValid ? '有效' : '无效'}, 实际: ${isValid ? '有效' : '无效'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testValidatePattern passed');
    }

    return allPassed;
  }

  /**
   * 测试字符串转义
   */
  testEscapeString(): boolean {
    const testCases = [
      {
        input: 'hello.world',
        expected: 'hello\\.world',
        description: '转义点号'
      },
      {
        input: 'a*b+c?',
        expected: 'a\\*b\\+c\\?',
        description: '转义量词'
      },
      {
        input: '[test]',
        expected: '\\[test\\]',
        description: '转义方括号'
      },
      {
        input: '(group)',
        expected: '\\(group\\)',
        description: '转义圆括号'
      },
      {
        input: 'normal',
        expected: 'normal',
        description: '无需转义'
      },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const result = SafeRegex.escapeString(testCase.input);

      if (result !== testCase.expected) {
        console.error(`❌ testEscapeString: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testEscapeString passed');
    }

    return allPassed;
  }

  /**
   * 测试创建安全正则
   */
  testCreateSafeRegex(): boolean {
    const testCases = [
      {
        pattern: 'hello',
        flags: '',
        shouldSucceed: true,
        description: '简单字符串'
      },
      {
        pattern: '(a+)+',
        flags: '',
        shouldSucceed: false,
        description: '危险模式'
      },
      {
        pattern: '\\d+',
        flags: 'g',
        shouldSucceed: true,
        description: '带转义字符'
      },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      try {
        const result = SafeRegex.createSafeRegex(testCase.pattern, testCase.flags);

        if (testCase.shouldSucceed) {
          if (result === null) {
            console.error(`❌ testCreateSafeRegex: ${testCase.description}`);
            console.error(`   期望: 成功, 实际: 失败`);
            this.failed++;
            allPassed = false;
          } else {
            console.log(`✅ ${testCase.description}`);
          }
        } else {
          if (result !== null) {
            console.error(`❌ testCreateSafeRegex: ${testCase.description}`);
            console.error(`   期望: 失败, 实际: 成功`);
            this.failed++;
            allPassed = false;
          } else {
            console.log(`✅ ${testCase.description}`);
          }
        }
      } catch (error) {
        if (testCase.shouldSucceed) {
          console.error(`❌ testCreateSafeRegex: ${testCase.description}`);
          console.error(`   异常: ${error instanceof Error ? error.message : String(error)}`);
          this.failed++;
          allPassed = false;
        } else {
          console.log(`✅ ${testCase.description} (预期失败)`);
        }
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testCreateSafeRegex passed');
    }

    return allPassed;
  }

  /**
   * 测试测试方法（仅测试，不提取）
   */
  testSafeTest(): boolean {
    const testCases = [
      {
        pattern: /hello/,
        input: 'hello world',
        expected: true,
        description: '匹配成功'
      },
      {
        pattern: /test/,
        input: 'hello world',
        expected: false,
        description: '匹配失败'
      },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      try {
        const result = SafeRegex.safeTest(testCase.pattern, testCase.input);

        if (result !== testCase.expected) {
          console.error(`❌ testSafeTest: ${testCase.description}`);
          console.error(`   期望: ${testCase.expected}, 实际: ${result}`);
          this.failed++;
          allPassed = false;
        } else {
          console.log(`✅ ${testCase.description}`);
        }
      } catch (error) {
        console.error(`❌ testSafeTest: ${testCase.description}`);
        console.error(`   异常: ${error instanceof Error ? error.message : String(error)}`);
        this.failed++;
        allPassed = false;
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testSafeTest passed');
    }

    return allPassed;
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting SafeRegex tests...\n');

    this.testSafeExecute();
    this.testReDoSProtection();
    this.testValidatePattern();
    this.testEscapeString();
    this.testCreateSafeRegex();
    this.testSafeTest();

    const total: number = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);

    if (this.failed > 0) {
      console.log(`❌ ${this.failed} tests failed`);
    } else {
      console.log('✅ All tests passed!');
    }

    return this.failed === 0;
  }
}

// 导出测试实例
const safeRegexTest: SafeRegexTest = new SafeRegexTest();
export default safeRegexTest;
