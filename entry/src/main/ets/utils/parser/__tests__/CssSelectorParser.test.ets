/**
 * CssSelectorParser XPath 增强功能测试
 */

import { CssSelectorParser } from '../CssSelectorParser';

export class CssSelectorParserTest {
  private passed: number = 0;
  private failed: number = 0;

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('\n📋 CssSelectorParser XPath 增强测试\n');

    // 测试 convertXPathToCss 方法
    this.testConvertXPathToCss();

    // 测试 XPath 选择器
    this.testXPathSelectors();

    // 输出结果
    console.log(`\n📊 测试结果: ${this.passed} 通过, ${this.failed} 失败`);

    return this.failed === 0;
  }

  /**
   * 测试 convertXPathToCss 方法
   */
  private testConvertXPathToCss(): void {
    console.log('─────────────────────────────────────────────────');
    console.log('  convertXPathToCss 测试');
    console.log('─────────────────────────────────────────────────');

    const testCases: Array<{ xpath: string; expected: string; description: string }> = [
      // 1. //tag -> tag (后代选择器)
      { xpath: '//div', expected: 'div', description: '//tag 转换为 tag' },
      { xpath: '//span', expected: 'span', description: '//span 转换为 span' },

      // 2. /tag -> > tag (子选择器)
      { xpath: '//div/span', expected: 'div > span', description: '//div/span 转换为 div > span' },
      { xpath: '//table/tr/td', expected: 'table > tr > td', description: '//table/tr/td 转换为 table > tr > td' },

      // 3. [@class="value"] -> .value
      { xpath: '//div[@class="content"]', expected: 'div.content', description: '[@class="value"] 转换为 .value' },
      { xpath: '//span[@class="highlight active"]', expected: 'span.highlight.active', description: '多class转换为多class选择器' },

      // 4. [@id="value"] -> #value
      { xpath: '//div[@id="main"]', expected: 'div#main', description: '[@id="value"] 转换为 #value' },

      // 5. [N] -> :nth-of-type(N)
      { xpath: '//div[1]', expected: 'div:nth-of-type(1)', description: '[N] 转换为 :nth-of-type(N)' },
      { xpath: '//tr[3]', expected: 'tr:nth-of-type(3)', description: '[3] 转换为 :nth-of-type(3)' },

      // 6. @attr -> [attr]
      { xpath: '//div[@data-id]', expected: 'div[data-id]', description: '[@attr] 转换为 [attr]' },

      // 7. [contains(@class,"value")] -> [class*="value"]
      { xpath: '//div[contains(@class,"item")]', expected: 'div[class*="item"]', description: 'contains(@class) 转换为 [class*=]' },
      { xpath: '//a[contains(@href,"example")]', expected: 'a[href*="example"]', description: 'contains(@href) 转换为 [href*=]' },

      // 8. [starts-with(@attr,"value")] -> [attr^="value"]
      { xpath: '//a[starts-with(@href,"https")]', expected: 'a[href^="https"]', description: 'starts-with 转换为 [attr^=]' },

      // 9. [ends-with(@attr,"value")] -> [attr$="value"]
      { xpath: '//img[ends-with(@src,".png")]', expected: 'img[src$=".png"]', description: 'ends-with 转换为 [attr$=]' },

      // 10. 复杂组合
      { xpath: '//div[@class="container"]//span[@class="text"]', expected: 'div.container span.text', description: '复杂后代选择器' },
      { xpath: '//ul/li[2]/a', expected: 'ul > li:nth-of-type(2) > a', description: '路径+索引组合' },

      // 11. position() 语法
      { xpath: '//tr[position()>1]', expected: 'tr:nth-of-type(n+1)', description: 'position()>N' },
      { xpath: '//li[position()=3]', expected: 'li:nth-of-type(3)', description: 'position()=N' },

      // 12. last() 语法
      { xpath: '//tr[last()]', expected: 'tr:last-of-type', description: 'last()' },
      { xpath: '//tr[last()-1]', expected: 'tr:nth-last-of-type(1)', description: 'last()-N' },

      // 13. not() 语法
      { xpath: '//div[not(@class)]', expected: 'div:not([class])', description: 'not(@attr)' },
      { xpath: '//div[not(contains(@class,"exclude"))]', expected: 'div:not([class*="exclude"])', description: 'not(contains())' },
    ];

    for (const testCase of testCases) {
      const result = CssSelectorParser.convertXPathToCss(testCase.xpath);
      const passed = result === testCase.expected;

      if (passed) {
        this.passed++;
        console.log(`  ✅ ${testCase.description}`);
        console.log(`     ${testCase.xpath} -> ${result}`);
      } else {
        this.failed++;
        console.log(`  ❌ ${testCase.description}`);
        console.log(`     输入: ${testCase.xpath}`);
        console.log(`     期望: ${testCase.expected}`);
        console.log(`     实际: ${result}`);
      }
    }
  }

  /**
   * 测试 XPath 选择器
   */
  private testXPathSelectors(): void {
    console.log('\n─────────────────────────────────────────────────');
    console.log('  XPath 选择器测试');
    console.log('─────────────────────────────────────────────────');

    const testHtml = `
      <html>
        <body>
          <div id="main" class="container">
            <h1 class="title">标题</h1>
            <div class="content">
              <p class="text">第一段</p>
              <p class="text highlight">第二段</p>
              <p class="text">第三段</p>
            </div>
            <ul class="list">
              <li>项目1</li>
              <li>项目2</li>
              <li>项目3</li>
            </ul>
          </div>
          <div class="sidebar">
            <a href="https://example.com" class="link">链接</a>
          </div>
        </body>
      </html>
    `;

    const testCases: Array<{ xpath: string; expectedCount: number; description: string }> = [
      { xpath: '//div', expectedCount: 3, description: '//div 选择所有div' },
      { xpath: '//div[@class="container"]', expectedCount: 1, description: '//div[@class="container"] 选择特定class的div' },
      { xpath: '//div[@id="main"]', expectedCount: 1, description: '//div[@id="main"] 选择特定id的div' },
      { xpath: '//p[@class="text"]', expectedCount: 3, description: '//p[@class="text"] 选择所有text类的p' },
      { xpath: '//p[1]', expectedCount: 1, description: '//p[1] 选择第一个p' },
      { xpath: '//ul/li', expectedCount: 3, description: '//ul/li 选择ul下的li' },
      { xpath: '//div[@class="content"]/p', expectedCount: 3, description: '//div[@class="content"]/p 选择content div下的p' },
      { xpath: '//div//p', expectedCount: 3, description: '//div//p 选择div后代中的所有p' },
      { xpath: '//a[contains(@href,"example")]', expectedCount: 1, description: '//a[contains(@href,"example")]' },
      { xpath: '//li[last()]', expectedCount: 1, description: '//li[last()] 选择最后一个li' },
    ];

    for (const testCase of testCases) {
      const elements = CssSelectorParser.selectElements(testHtml, testCase.xpath);
      const passed = elements.length === testCase.expectedCount;

      if (passed) {
        this.passed++;
        console.log(`  ✅ ${testCase.description}`);
        console.log(`     ${testCase.xpath} -> 找到 ${elements.length} 个元素`);
      } else {
        this.failed++;
        console.log(`  ❌ ${testCase.description}`);
        console.log(`     选择器: ${testCase.xpath}`);
        console.log(`     期望: ${testCase.expectedCount} 个元素`);
        console.log(`     实际: ${elements.length} 个元素`);
      }
    }
  }
}

// 导出测试实例
const cssSelectorParserTest = new CssSelectorParserTest();
export default cssSelectorParserTest;
