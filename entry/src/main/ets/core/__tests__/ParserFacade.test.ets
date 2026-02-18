/**
 * ParserFacade 单元测试
 * 符合 HarmonyOS 严格类型检查规范
 */

import { ParserFacade } from '../ParserFacade';
import { ParserType, ParseStatus, ParseResult } from '../../interfaces/IParser';

// 测试专用的接口定义
interface TestData {
  name: string;
  age: number;
}

// 测试专用的类型定义
interface BatchParseItem {
  content: string;
  type?: ParserType;
}

// 缓存条目接口
interface CacheEntry {
  key: string;
  hits: number;
  age: number;
}

// 缓存统计接口
interface CacheStats {
  size: number;
  maxSize: number;
  ttl: number;
  hitRate: number;
  entries: CacheEntry[];
}

// 批量解析项接口
interface BatchItem {
  content: string | ArrayBuffer;
  type?: ParserType | string;
  options?: import('../../interfaces/IParser').ParseOptions;
}

/**
 * ParserFacade 测试套件
 */
export class ParserFacadeTest {

  private parser: ParserFacade | null = null;

  /**
   * 测试前设置
   */
  setup(): void {
    this.parser = ParserFacade.getInstance();
  }

  /**
   * 测试后清理
   */
  teardown(): void {
    if (this.parser) {
      this.parser.clearCache();
    }
  }

  /**
   * 测试基本 JSON 解析
   */
  async testJSONParser(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '{"name": "张三", "age": 25}';
      const result: ParseResult<TestData> = this.parser.parseSync(content, ParserType.JSON);

      if (result.status !== ParseStatus.SUCCESS) {
        console.error('JSON parse failed with status:', result.status);
        return false;
      }

      if (!result.data) {
        console.error('Parsed data is undefined');
        return false;
      }

      const data = result.data;
      if (data.name !== '张三' || data.age !== 25) {
        console.error('Parsed data does not match expected values');
        return false;
      }

      if (result.errors.length > 0) {
        console.error('Unexpected errors in parse result');
        return false;
      }

      console.log('✅ JSON parser test passed');
      return true;
    } catch (error) {
      console.error('JSON parser test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试 XML 解析
   */
  async testXMLParser(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '<root><name>张三</name><age>25</age></root>';
      const result: ParseResult<Record<string, string>> = this.parser.parseSync(content, ParserType.XML);

      if (result.status !== ParseStatus.SUCCESS) {
        console.error('XML parse failed with status:', result.status);
        return false;
      }

      if (!result.data) {
        console.error('Parsed data is undefined');
        return false;
      }

      console.log('✅ XML parser test passed');
      return true;
    } catch (error) {
      console.error('XML parser test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试 HTML 解析
   */
  async testHTMLParser(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '<div class="container"><h1>标题</h1><p>段落</p></div>';
      const result: ParseResult<Record<string, string>> = this.parser.parseSync(content, ParserType.HTML);

      if (result.status !== ParseStatus.SUCCESS) {
        console.error('HTML parse failed with status:', result.status);
        return false;
      }

      if (!result.data) {
        console.error('Parsed data is undefined');
        return false;
      }

      console.log('✅ HTML parser test passed');
      return true;
    } catch (error) {
      console.error('HTML parser test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试 CSV 解析
   */
  async testCSVParser(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = 'name,age,city\n张三,25,北京\n李四,30,上海';
      const result: ParseResult<Array<Record<string, string>>> = this.parser.parseSync(content, ParserType.CSV);

      if (result.status !== ParseStatus.SUCCESS) {
        console.error('CSV parse failed with status:', result.status);
        return false;
      }

      if (!result.data) {
        console.error('Parsed data is undefined');
        return false;
      }

      console.log('✅ CSV parser test passed');
      return true;
    } catch (error) {
      console.error('CSV parser test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试缓存功能
   */
  async testCache(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '{"name": "张三"}';

      const result1: ParseResult<TestData> = this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'test-cache-key'
      });

      const result2: ParseResult<TestData> = this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'test-cache-key'
      });

      if (result1.metadata.cached !== false) {
        console.error('First response should not be cached');
        return false;
      }

      if (result2.metadata.cached !== true) {
        console.error('Second response should be cached');
        return false;
      }

      console.log('✅ Cache test passed');
      return true;
    } catch (error) {
      console.error('Cache test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试缓存跳过功能
   */
  async testSkipCache(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '{"name": "张三"}';

      this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'skip-cache-test'
      });

      const result: ParseResult<TestData> = this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'skip-cache-test',
        skipCache: true
      });

      if (result.metadata.cached !== false) {
        console.error('Response should not be cached when skipCache is true');
        return false;
      }

      console.log('✅ Skip cache test passed');
      return true;
    } catch (error) {
      console.error('Skip cache test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试缓存清理
   */
  async testClearCache(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '{"name": "张三"}';

      this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'clear-cache-test'
      });

      this.parser.clearCache();

      const result: ParseResult<TestData> = this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'clear-cache-test'
      });

      if (result.metadata.cached !== false) {
        console.error('Response should not be cached after clearCache');
        return false;
      }

      console.log('✅ Clear cache test passed');
      return true;
    } catch (error) {
      console.error('Clear cache test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试缓存统计
   */
  async testCacheStats(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '{"name": "张三"}';

      this.parser.parseSync(content, ParserType.JSON, {
        cacheKey: 'stats-test'
      });

      const stats: CacheStats = this.parser.getCacheStats() as CacheStats;

      if (stats.size !== 1) {
        console.error('Cache stats size should be 1');
        return false;
      }

      if (stats.maxSize !== 10) {
        console.error('Cache stats maxSize should be 10');
        return false;
      }

      console.log('✅ Cache stats test passed');
      return true;
    } catch (error) {
      console.error('Cache stats test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试自动检测
   */
  async testAutoDetection(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const jsonContent = '{"name": "张三"}';
      const xmlContent = '<root><item/></root>';
      const htmlContent = '<!DOCTYPE html><html><body>Test</body></html>';
      const csvContent = 'name,age\n张三,25\n李四,30';

      const jsonResult: ParseResult<TestData> = this.parser.parseSync(jsonContent);
      const xmlResult: ParseResult<Record<string, string>> = this.parser.parseSync(xmlContent);
      const htmlResult: ParseResult<Record<string, string>> = this.parser.parseSync(htmlContent);
      const csvResult: ParseResult<Array<Record<string, string>>> = this.parser.parseSync(csvContent);

      if (jsonResult.metadata.parserType !== ParserType.JSON) {
        console.error('JSON content should be detected as JSON');
        return false;
      }

      if (xmlResult.metadata.parserType !== ParserType.XML) {
        console.error('XML content should be detected as XML');
        return false;
      }

      if (htmlResult.metadata.parserType !== ParserType.HTML) {
        console.error('HTML content should be detected as HTML');
        return false;
      }

      if (csvResult.metadata.parserType !== ParserType.CSV) {
        console.error('CSV content should be detected as CSV');
        return false;
      }

      console.log('✅ Auto detection test passed');
      return true;
    } catch (error) {
      console.error('Auto detection test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试错误处理
   */
  async testErrorHandling(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const result: ParseResult<Record<string, string>> = this.parser.parseSync('', ParserType.JSON);

      if (result.status !== ParseStatus.FAILED) {
        console.error('Empty content should result in failed status');
        return false;
      }

      if (result.errors.length === 0) {
        console.error('Empty content should generate errors');
        return false;
      }

      console.log('✅ Error handling test passed');
      return true;
    } catch (error) {
      console.error('Error handling test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试批量操作
   */
  async testBatchOperations(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const items: BatchParseItem[] = [
        { content: '{"a": 1}', type: ParserType.JSON },
        { content: '<root/>', type: ParserType.XML },
        { content: 'name,value\na,1', type: ParserType.CSV }
      ];

      const batchItems: BatchItem[] = [];
      for (const item of items) {
        const batchItem: BatchItem = {
          content: item.content,
          type: item.type
        };
        batchItems.push(batchItem);
      }
      const parser: ParserFacade = this.parser!;
      const results: ParseResult<Record<string, string>>[] = await parser.parseBatch<Record<string, string>>(batchItems);

      if (results.length !== 3) {
        console.error('Batch parse should return 3 results');
        return false;
      }

      if (results[0].status !== ParseStatus.SUCCESS) {
        console.error('First batch item should succeed');
        return false;
      }

      if (results[1].status !== ParseStatus.SUCCESS) {
        console.error('Second batch item should succeed');
        return false;
      }

      if (results[2].status !== ParseStatus.SUCCESS) {
        console.error('Third batch item should succeed');
        return false;
      }

      console.log('✅ Batch operations test passed');
      return true;
    } catch (error) {
      console.error('Batch operations test failed:', error.message);
      return false;
    }
  }

  /**
   * 测试回退解析
   */
  async testFallback(): Promise<boolean> {
    try {
      if (!this.parser) {
        console.error('Parser not initialized');
        return false;
      }

      const content = '{"name": "张三"}';
      const parser: ParserFacade = this.parser!;
      const fallbackTypes: ParserType[] = [ParserType.XML, ParserType.JSON];
      const result: ParseResult<TestData> = await parser.parseWithFallback<TestData>(content, fallbackTypes);

      if (result.status !== ParseStatus.SUCCESS) {
        console.error('Fallback parse should succeed');
        return false;
      }

      if (result.metadata.parserType !== ParserType.JSON) {
        console.error('Fallback should use JSON parser');
        return false;
      }

      console.log('✅ Fallback test passed');
      return true;
    } catch (error) {
      console.error('Fallback test failed:', error.message);
      return false;
    }
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting ParserFacade tests...');

    this.setup();

    const tests: Promise<boolean>[] = [
      this.testJSONParser(),
      this.testXMLParser(),
      this.testHTMLParser(),
      this.testCSVParser(),
      this.testCache(),
      this.testSkipCache(),
      this.testClearCache(),
      this.testCacheStats(),
      this.testAutoDetection(),
      this.testErrorHandling(),
      this.testBatchOperations(),
      this.testFallback()
    ];

    const results: boolean[] = await Promise.all(tests);
    let passed: number = 0;
    for (const result of results) {
      if (result) {
        passed++;
      }
    }
    const total: number = tests.length;

    this.teardown();

    console.log(`\n📊 Test Results: ${passed}/${total} tests passed`);

    if (passed === total) {
      console.log('✅ All ParserFacade tests passed!');
    } else {
      console.log('❌ Some ParserFacade tests failed');
    }

    return passed === total;
  }
}

const parserFacadeTest = new ParserFacadeTest();
export default parserFacadeTest;