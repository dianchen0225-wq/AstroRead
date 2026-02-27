import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { EnhancedRuleEngine, RuleMode, SourceRule, RuleCache, VariableScope } from '../../../main/ets/utils/parser/EnhancedRuleEngine';
import { BookSourceBuilder, BookSourceConverter, SearchRule, TocRule, ContentRule, BookSourceCompat } from '../../../main/ets/models/BookSource';

export default function EnhancedRuleEngineTest() {
  describe('EnhancedRuleEngine', () => {
    let engine: EnhancedRuleEngine;

    beforeEach(() => {
      engine = new EnhancedRuleEngine();
      RuleCache.clear();
    });

    afterEach(() => {
      if (engine) {
        engine.clearContext();
      }
    });

    it('shouldCorrectlySetContentAndDetectJson', 0, () => {
      const jsonContent = '{"name": "test", "value": 123}';
      engine.setContent(jsonContent);

      const result = engine.getString('$.name');
      expect(result).assertEqual('test');
    });

    it('shouldCorrectlySetHtmlContent', 0, () => {
      const htmlContent = '<html><body><div class="title">Hello World</div></body></html>';
      engine.setContent(htmlContent);

      const result = engine.getString('.title');
      expect(result).assertEqual('Hello World');
    });

    it('shouldCorrectlyHandleEmptyRule', 0, () => {
      engine.setContent('test content');

      const result = engine.getString('');
      expect(result).assertEqual('');
    });

    it('shouldCorrectlyExtractClassSelectorContent', 0, () => {
      engine.setContent(`
        <html>
          <body>
            <div class="book-name">书名测试</div>
            <div class="author">作者测试</div>
            <a class="book-url" href="/book/123">链接</a>
          </body>
        </html>
      `);

      expect(engine.getString('.book-name')).assertEqual('书名测试');
      expect(engine.getString('.author')).assertEqual('作者测试');
    });

    it('shouldCorrectlyExtractMultipleElements', 0, () => {
      engine.setContent(`
        <html>
          <body>
            <div class="item">项目1</div>
            <div class="item">项目2</div>
            <div class="item">项目3</div>
          </body>
        </html>
      `);

      const results = engine.getStringList('.item');
      expect(results !== null).assertTrue();
      if (results) {
        expect(results.length).assertEqual(3);
        expect(results[0]).assertEqual('项目1');
        expect(results[1]).assertEqual('项目2');
      }
    });

    it('shouldCorrectlyHandleUrlConversion', 0, () => {
      engine.setContent(`
        <html>
          <body>
            <a class="link" href="/book/123">链接</a>
            <img class="cover" src="/images/cover.jpg" />
          </body>
        </html>
      `, 'https://example.com');

      expect(engine.getString('.link@href', true)).assertEqual('https://example.com/book/123');
      expect(engine.getString('.cover@src', true)).assertEqual('https://example.com/images/cover.jpg');
    });
  });
}
