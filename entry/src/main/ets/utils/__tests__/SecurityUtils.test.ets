/**
 * SecurityUtils 单元测试
 * 测试路径安全、输入验证等核心安全功能
 */

import { SecurityUtils } from '../security/SecurityUtils';

interface PathTestCase {
  input: string;
  basePath: string;
  shouldBeSafe: boolean;
  description: string;
}

interface FilenameTestCase {
  input: string;
  expected: string;
  description: string;
}

interface ExtensionTestCase {
  fileName: string;
  expected: boolean;
  description: string;
}

interface PathNormalizationTestCase {
  input: string;
  expected: string;
  description: string;
}

interface DeepDecodeTestCase {
  input: string;
  contains: string;
  description: string;
}

interface BuildPathTestCase {
  basePath: string;
  fileName: string;
  expected: string;
  description: string;
}

interface FileExtensionTestCase {
  fileName: string;
  expected: string;
  description: string;
}

interface EscapeRegexTestCase {
  input: string;
  description: string;
}

interface HtmlEntityTestCase {
  input: string;
  expected: string;
  description: string;
}

export class SecurityUtilsTest {
  passed: number = 0;
  failed: number = 0;

  /**
   * 测试路径遍历攻击防护
   */
  testPathTraversalPrevention(): boolean {
    const testCases: PathTestCase[] = [
      { input: '../../../etc/passwd', basePath: '/app/data', shouldBeSafe: false, description: '上级目录遍历' },
      { input: '..\\..\\windows\\system32', basePath: '/app/data', shouldBeSafe: false, description: 'Windows上级目录遍历' },
      { input: '/etc/passwd', basePath: '/app/data', shouldBeSafe: false, description: '绝对路径' },
      { input: 'C:\\Windows\\System32', basePath: '/app/data', shouldBeSafe: false, description: 'Windows绝对路径' },
      { input: 'normal_file.txt', basePath: '/app/data', shouldBeSafe: true, description: '正常文件名' },
      { input: 'path/to/file.txt', basePath: '/app/data', shouldBeSafe: true, description: '正常相对路径' },
      { input: 'file%2F..%2Fetc', basePath: '/app/data', shouldBeSafe: false, description: 'URL编码遍历' },
      { input: 'file\x00.txt', basePath: '/app/data', shouldBeSafe: false, description: '空字节注入' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const isSafe: boolean = SecurityUtils.isSafePath(testCase.input, testCase.basePath);

      if (isSafe !== testCase.shouldBeSafe) {
        console.error(`testPathTraversalPrevention: ${testCase.description}`);
        console.error(`   期望: ${testCase.shouldBeSafe ? '安全' : '不安全'}, 实际: ${isSafe ? '安全' : '不安全'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testPathTraversalPrevention passed');
    }

    return allPassed;
  }

  /**
   * 测试文件名清理
   */
  testSanitizeFilename(): boolean {
    const testCases: FilenameTestCase[] = [
      { input: 'file<name>.txt', expected: 'file_name_.txt', description: '移除尖括号' },
      { input: 'file:name|*.txt', expected: 'file_name_.txt', description: '移除Windows非法字符' },
      { input: 'normal.txt', expected: 'normal.txt', description: '正常文件名' },
      { input: '../../../etc/passwd', expected: '________etc_passwd', description: '清理路径遍历' },
      { input: 'file\x00.txt', expected: 'file_.txt', description: '移除空字节' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const result: string = SecurityUtils.sanitizeFileName(testCase.input);

      if (result !== testCase.expected) {
        console.error(`testSanitizeFilename: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testSanitizeFilename passed');
    }

    return allPassed;
  }

  /**
   * 测试文件扩展名验证
   */
  testExtensionValidation(): boolean {
    const testCases: ExtensionTestCase[] = [
      { fileName: 'document.txt', expected: true, description: 'txt扩展名' },
      { fileName: 'data.json', expected: true, description: 'json扩展名' },
      { fileName: 'config.xml', expected: true, description: 'xml扩展名' },
      { fileName: 'book.epub', expected: true, description: 'epub扩展名' },
      { fileName: 'document.pdf', expected: true, description: 'pdf扩展名' },
      { fileName: 'script.exe', expected: false, description: 'exe扩展名' },
      { fileName: 'document', expected: false, description: '无扩展名' },
      { fileName: 'file.bat', expected: false, description: 'bat扩展名' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const isValid: boolean = SecurityUtils.isAllowedExtension(testCase.fileName);

      if (isValid !== testCase.expected) {
        console.error(`testExtensionValidation: ${testCase.description}`);
        console.error(`   期望: ${testCase.expected ? '允许' : '不允许'}, 实际: ${isValid ? '允许' : '不允许'}`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testExtensionValidation passed');
    }

    return allPassed;
  }

  /**
   * 测试路径规范化
   */
  testPathNormalization(): boolean {
    const testCases: PathNormalizationTestCase[] = [
      { input: 'path//to///file', expected: 'path/to/file', description: '移除多余斜杠' },
      { input: 'path/./to/./file', expected: 'path/to/file', description: '移除当前目录引用' },
      { input: './path/to/file', expected: 'path/to/file', description: '移除开头当前目录' },
      { input: 'path\\to\\file', expected: 'path/to/file', description: '统一路径分隔符' },
      { input: 'path/to/file/', expected: 'path/to/file', description: '移除结尾斜杠' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const result: string = SecurityUtils.normalizePath(testCase.input);

      if (result !== testCase.expected) {
        console.error(`testPathNormalization: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testPathNormalization passed');
    }

    return allPassed;
  }

  /**
   * 测试深度解码
   */
  testDeepDecode(): boolean {
    const testCases: DeepDecodeTestCase[] = [
      { input: 'file%2Fpath', contains: 'file/path', description: 'URL解码' },
      { input: '&lt;script&gt;', contains: '<script>', description: 'HTML实体解码' },
      { input: 'file%252Fpath', contains: 'file/path', description: '双重URL编码' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const result: string = SecurityUtils.deepDecodePath(testCase.input);

      if (!result.includes(testCase.contains)) {
        console.error(`testDeepDecode: ${testCase.description}`);
        console.error(`   期望包含: "${testCase.contains}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testDeepDecode passed');
    }

    return allPassed;
  }

  /**
   * 测试路径构建
   */
  testBuildSafePath(): boolean {
    const testCases: BuildPathTestCase[] = [
      { basePath: '/app/data', fileName: 'file.txt', expected: '/app/data/file.txt', description: '正常路径构建' },
      { basePath: '/app/data/', fileName: 'file.txt', expected: '/app/data/file.txt', description: '带斜杠的基础路径' },
      { basePath: '/app/data', fileName: '../../../etc/passwd', expected: '/app/data/________etc_passwd', description: '危险文件名清理' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const result: string = SecurityUtils.buildSafePath(testCase.basePath, testCase.fileName);

      if (result !== testCase.expected) {
        console.error(`testBuildSafePath: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testBuildSafePath passed');
    }

    return allPassed;
  }

  /**
   * 测试文件扩展名获取
   */
  testGetFileExtension(): boolean {
    const testCases: FileExtensionTestCase[] = [
      { fileName: 'document.txt', expected: '.txt', description: '正常扩展名' },
      { fileName: 'archive.tar.gz', expected: '.gz', description: '多扩展名' },
      { fileName: 'DOCUMENT.PDF', expected: '.pdf', description: '大写扩展名' },
      { fileName: 'noextension', expected: '', description: '无扩展名' },
      { fileName: '.hidden', expected: '', description: '隐藏文件' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const result: string = SecurityUtils.getFileExtension(testCase.fileName);

      if (result !== testCase.expected) {
        console.error(`testGetFileExtension: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testGetFileExtension passed');
    }

    return allPassed;
  }

  /**
   * 测试正则表达式转义
   */
  testEscapeRegex(): boolean {
    const testCases: EscapeRegexTestCase[] = [
      { input: 'file.name', description: '转义点号' },
      { input: 'file[name]', description: '转义方括号' },
      { input: 'file(name)', description: '转义圆括号' },
      { input: 'file*name', description: '转义星号' },
      { input: 'file+name', description: '转义加号' },
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const escaped: string = SecurityUtils.escapeRegex(testCase.input);
      // 验证转义后的字符串可以安全用于正则表达式
      const regex: RegExp = new RegExp(`^${escaped}$`);
      const matches: boolean = regex.test(testCase.input);

      if (!matches) {
        console.error(`testEscapeRegex: ${testCase.description}`);
        console.error(`   转义后: "${escaped}", 无法匹配原始输入`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testEscapeRegex passed');
    }

    return allPassed;
  }

  /**
   * 测试HTML实体解码
   */
  testDecodeHtmlEntities(): boolean {
    const testCase1: HtmlEntityTestCase = { input: '&lt;script&gt;', expected: '<script>', description: '基本HTML实体' };
    const testCase2: HtmlEntityTestCase = { input: '&amp;', expected: '&', description: 'amp实体' };
    const testCase3: HtmlEntityTestCase = { input: '&quot;test&quot;', expected: '"test"', description: 'quot实体' };
    const testCase4: HtmlEntityTestCase = { input: '&#65;', expected: 'A', description: '数字实体' };
    const testCase5: HtmlEntityTestCase = { input: '&#x41;', expected: 'A', description: '十六进制实体' };
    const testCases: HtmlEntityTestCase[] = [
      testCase1,
      testCase2,
      testCase3,
      testCase4,
      testCase5
    ];

    let allPassed: boolean = true;

    for (const testCase of testCases) {
      const result: string = SecurityUtils.decodeHtmlEntities(testCase.input);

      if (result !== testCase.expected) {
        console.error(`testDecodeHtmlEntities: ${testCase.description}`);
        console.error(`   期望: "${testCase.expected}", 实际: "${result}"`);
        this.failed++;
        allPassed = false;
      } else {
        console.log(`[PASS] ${testCase.description}`);
      }
    }

    if (allPassed) {
      this.passed++;
      console.log('[PASS] testDecodeHtmlEntities passed');
    }

    return allPassed;
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('[INFO] Starting SecurityUtils tests...\n');

    this.testPathTraversalPrevention();
    this.testSanitizeFilename();
    this.testExtensionValidation();
    this.testPathNormalization();
    this.testDeepDecode();
    this.testBuildSafePath();
    this.testGetFileExtension();
    this.testEscapeRegex();
    this.testDecodeHtmlEntities();

    const total: number = this.passed + this.failed;
    console.log(`\n[INFO] Test Results: ${this.passed}/${total} tests passed`);

    if (this.failed > 0) {
      console.log(`[FAIL] ${this.failed} tests failed`);
    } else {
      console.log('[PASS] All tests passed!');
    }

    return this.failed === 0;
  }
}

// 导出测试实例
const securityUtilsTest: SecurityUtilsTest = new SecurityUtilsTest();
export default securityUtilsTest;
