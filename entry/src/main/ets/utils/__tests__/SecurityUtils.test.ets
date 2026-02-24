/**
 * SecurityUtils 单元测试
 * 测试路径安全、输入验证等核心安全功能
 */

import { SecurityUtils } from '../SecurityUtils';
import { PathValidationResult } from '../SecurityUtils';

export class SecurityUtilsTest {
  private passed: number = 0;
  private failed: number = 0;

  /**
   * 测试路径遍历攻击防护
   */
  testPathTraversalPrevention(): boolean {
    const testCases = [
      { input: '../../../etc/passwd', shouldBeValid: false, description: '上级目录遍历' },
      { input: '..\\..\\windows\\system32', shouldBeValid: false, description: 'Windows上级目录遍历' },
      { input: '/etc/passwd', shouldBeValid: false, description: '绝对路径' },
      { input: 'C:\\Windows\\System32', shouldBeValid: false, description: 'Windows绝对路径' },
      { input: 'normal_file.txt', shouldBeValid: true, description: '正常文件名' },
      { input: 'path/to/file.txt', shouldBeValid: true, description: '正常相对路径' },
      { input: 'file%2F..%2Fetc', shouldBeValid: false, description: 'URL编码遍历' },
      { input: 'file\x00.txt', shouldBeValid: false, description: '空字节注入' },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const result = SecurityUtils.validatePath(testCase.input);
      const isValid = result === PathValidationResult.VALID;

      if (isValid !== testCase.shouldBeValid) {
        console.error(`❌ testPathTraversalPrevention: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeValid ? '有效' : '无效'}, 实际: ${isValid ? '有效' : '无效'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testPathTraversalPrevention passed');
    }

    return allPassed;
  }

  /**
   * 测试文件名清理
   */
  testSanitizeFilename(): boolean {
    const testCases = [
      { input: 'file<name>.txt', expected: 'file_name_.txt', description: '移除尖括号' },
      { input: 'file:name|*.txt', expected: 'file_name_.txt', description: '移除Windows非法字符' },
      { input: 'normal.txt', expected: 'normal.txt', description: '正常文件名' },
      { input: '../../../etc/passwd', expected: '________etc_passwd', description: '清理路径遍历' },
      { input: 'file\x00.txt', expected: 'file_.txt', description: '移除空字节' },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const result = SecurityUtils.sanitizeFilename(testCase.input);

      if (result !== testCase.expected) {
        console.error(`❌ testSanitizeFilename: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testSanitizeFilename passed');
    }

    return allPassed;
  }

  /**
   * 测试输入验证
   */
  testValidateInput(): boolean {
    const testCases = [
      { input: 'normal input', min: 1, max: 100, pattern: undefined, shouldBeValid: true, description: '正常输入' },
      { input: '', min: 1, max: 100, pattern: undefined, shouldBeValid: false, description: '空字符串' },
      { input: 'a'.repeat(101), min: 1, max: 100, pattern: undefined, shouldBeValid: false, description: '超长字符串' },
      { input: 'test123', min: 1, max: 100, pattern: /^[a-z0-9]+$/, shouldBeValid: true, description: '匹配正则' },
      { input: 'TEST123', min: 1, max: 100, pattern: /^[a-z0-9]+$/, shouldBeValid: false, description: '不匹配正则' },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const result = SecurityUtils.validateInput(
        testCase.input,
        testCase.min,
        testCase.max,
        testCase.pattern
      );

      if (result !== testCase.shouldBeValid) {
        console.error(`❌ testValidateInput: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeValid ? '有效' : '无效'}, 实际: ${result ? '有效' : '无效'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testValidateInput passed');
    }

    return allPassed;
  }

  /**
   * 测试SQL注入防护
   */
  testSqlInjectionPrevention(): boolean {
    const testCases = [
      { input: "'; DROP TABLE users; --", shouldBeSafe: false, description: '经典SQL注入' },
      { input: "1 OR 1=1", shouldBeSafe: false, description: '布尔注入' },
      { input: "1; DELETE FROM users", shouldBeSafe: false, description: '堆叠查询' },
      { input: "normal_value", shouldBeSafe: true, description: '正常值' },
      { input: "user@example.com", shouldBeSafe: true, description: '邮箱地址' },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const isSafe = SecurityUtils.isSafeSqlInput(testCase.input);

      if (isSafe !== testCase.shouldBeSafe) {
        console.error(`❌ testSqlInjectionPrevention: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeSafe ? '安全' : '不安全'}, 实际: ${isSafe ? '安全' : '不安全'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testSqlInjectionPrevention passed');
    }

    return allPassed;
  }

  /**
   * 测试XSS防护
   */
  testXssPrevention(): boolean {
    const testCases = [
      { input: '<script>alert(1)</script>', shouldBeSafe: false, description: '脚本标签' },
      { input: 'javascript:alert(1)', shouldBeSafe: false, description: 'JavaScript协议' },
      { input: '<img src=x onerror=alert(1)>', shouldBeSafe: false, description: '事件处理器' },
      { input: 'normal text', shouldBeSafe: true, description: '正常文本' },
      { input: 'https://example.com', shouldBeSafe: true, description: '正常URL' },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const isSafe = SecurityUtils.isSafeXssInput(testCase.input);

      if (isSafe !== testCase.shouldBeSafe) {
        console.error(`❌ testXssPrevention: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeSafe ? '安全' : '不安全'}, 实际: ${isSafe ? '安全' : '不安全'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testXssPrevention passed');
    }

    return allPassed;
  }

  /**
   * 测试URL安全验证
   */
  testUrlValidation(): boolean {
    const testCases = [
      { url: 'http://example.com', shouldBeValid: true, description: 'HTTP URL' },
      { url: 'https://example.com', shouldBeValid: true, description: 'HTTPS URL' },
      { url: 'ftp://example.com', shouldBeValid: false, description: 'FTP URL' },
      { url: 'file:///etc/passwd', shouldBeValid: false, description: '文件协议' },
      { url: 'http://192.168.1.1', shouldBeValid: false, description: '内网IP' },
      { url: 'http://localhost:8080', shouldBeValid: false, description: '本地主机' },
      { url: 'not-a-url', shouldBeValid: false, description: '无效URL' },
    ];

    let allPassed = true;

    for (const testCase of testCases) {
      const result = SecurityUtils.validateUrl(testCase.url);
      const isValid = result === PathValidationResult.VALID;

      if (isValid !== testCase.shouldBeValid) {
        console.error(`❌ testUrlValidation: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeValid ? '有效' : '无效'}, 实际: ${isValid ? '有效' : '无效'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`✅ ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('✅ testUrlValidation passed');
    }

    return allPassed;
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting SecurityUtils tests...\n');

    this.testPathTraversalPrevention();
    this.testSanitizeFilename();
    this.testValidateInput();
    this.testSqlInjectionPrevention();
    this.testXssPrevention();
    this.testUrlValidation();

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
const securityUtilsTest: SecurityUtilsTest = new SecurityUtilsTest();
export default securityUtilsTest;
