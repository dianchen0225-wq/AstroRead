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
      engine.clearContext();
    });

    describe('基础功能测试', () => {
      it('应该正确设置内容并检测JSON', () => {
        const jsonContent = '{"name": "test", "value": 123}';
        engine.setContent(jsonContent);

        const result = engine.getString('$.name');
        expect(result).assertEqual('test');
      });

      it('应该正确设置HTML内容', () => {
        const htmlContent = '<html><body><div class="title">Hello World</div></body></html>';
        engine.setContent(htmlContent);

        const result = engine.getString('.title');
        expect(result).assertEqual('Hello World');
      });

      it('应该正确处理空规则', () => {
        engine.setContent('test content');

        const result = engine.getString('');
        expect(result).assertEqual('');
      });
    });

    describe('CSS选择器规则测试', () => {
      beforeEach(() => {
        engine.setContent(`
          <html>
            <body>
              <div class="book-name">书名测试</div>
              <div class="author">作者测试</div>
              <a class="book-url" href="/book/123">链接</a>
            </body>
          </html>
        `, 'https://example.com');
      });

      it('应该正确提取class选择器内容', () => {
        const result = engine.getString('.book-name');
        expect(result).assertEqual('书名测试');
      });

      it('应该正确提取多个元素', () => {
        const results = engine.getStringList('div');
        expect(results !== null).assertTrue();
        if (results !== null) {
          expect(results.length).assertLarger(0);
        }
      });

      it('应该正确处理URL转换', () => {
        const result = engine.getString('a.book-url@href', true);
        expect(result).assertEqual('https://example.com/book/123');
      });
    });

    describe('JSON规则测试', () => {
      interface BookItem {
        name: string;
        author: string;
      }

      interface DataItem {
        bookList: BookItem[];
        total: number;
      }

      interface JsonData {
        data: DataItem;
      }

      beforeEach(() => {
        const book1: BookItem = { name: '书籍1', author: '作者1' };
        const book2: BookItem = { name: '书籍2', author: '作者2' };

        const jsonData: JsonData = {
          data: {
            bookList: [book1, book2],
            total: 100
          }
        };
        engine.setContent(JSON.stringify(jsonData));
      });

      it('应该正确提取JSONPath值', () => {
        const result = engine.getString('$.data.total');
        expect(result).assertEqual('100');
      });

      it('应该正确提取JSON数组', () => {
        const results = engine.getStringList('$.data.bookList[*].name');
        expect(results !== null).assertTrue();
        if (results !== null) {
          expect(results.length).assertEqual(2);
          expect(results[0]).assertEqual('书籍1');
        }
      });

      it('应该正确处理@json前缀', () => {
        const result = engine.getString('@json:$.data.total');
        expect(result).assertEqual('100');
      });
    });

    describe('XPath规则测试', () => {
      beforeEach(() => {
        engine.setContent(`
          <html>
            <body>
              <div id="content">
                <p class="chapter">第一章</p>
                <p class="chapter">第二章</p>
              </div>
            </body>
          </html>
        `);
      });

      it('应该正确识别XPath规则', () => {
        const result = engine.getString('@XPath://div[@id="content"]/p[1]');
        expect(result).assertContain('第一章');
      });
    });

    describe('正则表达式规则测试', () => {
      beforeEach(() => {
        engine.setContent('书名：斗破苍穹 作者：天蚕土豆 章节：第1234章');
      });

      it('应该正确提取正则匹配结果', () => {
        const result = engine.getString('##书名：(.+?) 作者');
        expect(result).assertEqual('斗破苍穹');
      });

      it('应该正确提取正则列表', () => {
        const results = engine.getStringList('##第(\\d+)章');
        expect(results !== null).assertTrue();
        if (results !== null) {
          expect(results.length).assertLarger(0);
        }
      });
    });

    describe('正则替换规则测试', () => {
      beforeEach(() => {
        engine.setContent('测试内容：广告[广告内容]结束');
      });

      it('应该正确执行正则替换', () => {
        const rule = '##\\[广告内容\\]##';
        const result = engine.getString(rule);
        expect(result).assertEqual('测试内容：广告结束');
      });

      it('应该正确执行带替换值的正则替换', () => {
        const rule = '##广告##替换文本##';
        const result = engine.getString(rule);
        expect(result).assertEqual('测试内容：替换文本[广告内容]结束');
      });

      it('应该正确处理replaceFirst模式', () => {
        engine.setContent('aaa bbb aaa');
        const rule = '##aaa##X##X##first';
        const result = engine.getString(rule);
        expect(result).assertEqual('X');
      });
    });

    describe('变量规则测试', () => {
      it('应该正确存储和获取变量', () => {
        engine.setContent('<div>测试内容</div>');
        engine.putVariable('testVar', '变量值');

        const value = engine.getVariable('testVar');
        expect(value).assertEqual('变量值');
      });

      it('应该正确处理@put规则', () => {
        engine.setContent('<div class="book-name">书名测试</div>');

        const result = engine.getString('@put:{name:.book-name}{{@get:{name}}}');
        expect(result).assertEqual('书名测试');
        expect(engine.getVariable('name')).assertEqual('书名测试');
      });

      it('应该正确处理@get规则', () => {
        engine.setContent('<div>测试</div>');
        engine.putVariable('stored', '存储的值');

        const result = engine.getString('@get:{stored}');
        expect(result).assertEqual('存储的值');
      });
    });

    describe('变量作用域测试', () => {
      it('应该正确管理作用域层级', () => {
        engine.putVariable('global', '全局值');

        engine.pushScope();
        engine.putVariable('local', '局部值');

        expect(engine.getVariable('global')).assertEqual('全局值');
        expect(engine.getVariable('local')).assertEqual('局部值');

        engine.popScope();

        expect(engine.getVariable('global')).assertEqual('全局值');
        expect(engine.getVariable('local')).assertEqual('');
      });
    });

    describe('规则缓存测试', () => {
      it('应该正确缓存规则解析结果', () => {
        engine.setContent('<div class="test">内容</div>');

        const result1 = engine.getString('.test');
        const result2 = engine.getString('.test');

        expect(result1).assertEqual(result2);
        expect(result1).assertEqual('内容');
      });
    });

    describe('复杂规则组合测试', () => {
      beforeEach(() => {
        engine.setContent(`
          <div class="book-item">
            <span class="name">书名A</span>
            <span class="author">作者A</span>
          </div>
          <div class="book-item">
            <span class="name">书名B</span>
            <span class="author">作者B</span>
          </div>
        `);
      });

      it('应该正确处理&&组合规则', () => {
        const result = engine.getString('.book-item .name&&.book-item .author');
        expect(result).assertContain('书名A');
        expect(result).assertContain('作者A');
      });

      it('应该正确处理||或规则', () => {
        const result = engine.getString('.nonexistent||.name');
        expect(result).assertContain('书名');
      });
    });

    describe('URL处理测试', () => {
      beforeEach(() => {
        engine.setContent('<a href="/book/123">链接</a><img src="images/cover.jpg"/>', 'https://example.com/page.html');
      });

      it('应该正确转换相对URL为绝对URL', () => {
        const result = engine.getString('a@href', true);
        expect(result).assertEqual('https://example.com/book/123');
      });

      it('应该正确处理图片URL', () => {
        const result = engine.getString('img@src', true);
        expect(result).assertEqual('https://example.com/images/cover.jpg');
      });
    });

    describe('HTML实体解码测试', () => {
      it('应该正确解码HTML实体', () => {
        engine.setContent('<div>&lt;测试&gt;&amp;&quot;引号&quot;</div>');
        const result = engine.getString('div');
        expect(result).assertContain('<测试>');
        expect(result).assertContain('&');
        expect(result).assertContain('"引号"');
      });
    });
  });

  describe('SourceRule', () => {
    it('应该正确解析CSS选择器规则', () => {
      const rule = new SourceRule('.book-name', RuleMode.Default, false);
      expect(rule.mode).assertEqual(RuleMode.Default);
      expect(rule.rule).assertEqual('.book-name');
    });

    it('应该正确解析XPath规则', () => {
      const rule = new SourceRule('@XPath://div[@class="name"]', RuleMode.Default, false);
      expect(rule.mode).assertEqual(RuleMode.XPath);
      expect(rule.rule).assertEqual('//div[@class="name"]');
    });

    it('应该正确解析JSON规则', () => {
      const rule = new SourceRule('$.data.name', RuleMode.Default, true);
      expect(rule.mode).assertEqual(RuleMode.Json);
      expect(rule.rule).assertEqual('$.data.name');
    });

    it('应该正确解析正则替换规则', () => {
      const rule = new SourceRule('.name##测试##替换##first', RuleMode.Default, false);
      expect(rule.replaceRegex).assertEqual('测试');
      expect(rule.replacement).assertEqual('替换');
      expect(rule.replaceFirst).assertTrue();
    });

    it('应该正确解析@put规则', () => {
      const rule = new SourceRule('@put:{name:.book-name}', RuleMode.Default, false);
      expect(rule.putMap.has('name')).assertTrue();
    });
  });

  describe('VariableScope', () => {
    let scope: VariableScope;

    beforeEach(() => {
      scope = new VariableScope();
    });

    it('应该正确存储和获取变量', () => {
      scope.put('key1', 'value1');
      expect(scope.get('key1')).assertEqual('value1');
    });

    it('应该正确处理作用域层级', () => {
      scope.put('global', 'globalValue');

      scope.pushScope();
      scope.put('local', 'localValue');

      expect(scope.get('global')).assertEqual('globalValue');
      expect(scope.get('local')).assertEqual('localValue');

      scope.popScope();

      expect(scope.get('global')).assertEqual('globalValue');
      expect(scope.get('local')).assertEqual('');
    });

    it('应该正确获取所有变量', () => {
      scope.put('key1', 'value1');
      scope.put('key2', 'value2');

      const all = scope.getAll();
      expect(all.size).assertEqual(2);
      expect(all.get('key1')).assertEqual('value1');
      expect(all.get('key2')).assertEqual('value2');
    });
  });

  describe('BookSourceBuilder', () => {
    it('应该正确构建书源', () => {
      const searchRule: SearchRule = {
        bookList: '.book-item',
        name: '.name',
        author: '.author',
        cover: '.cover@src',
        intro: '.intro',
        bookUrl: '.url@href',
        nextUrl: undefined
      };

      const source = new BookSourceBuilder('test-id', '测试书源', 'https://example.com')
        .setSearchUrl('/search?key={{key}}')
        .setSearchRule(searchRule)
        .setHeader('{"User-Agent": "Test"}')
        .setGroup('测试分组')
        .setEnabled(true)
        .setRuleType('xpath')
        .build();

      expect(source.id).assertEqual('test-id');
      expect(source.name).assertEqual('测试书源');
      expect(source.url).assertEqual('https://example.com');
      expect(source.metadata.enabled).assertTrue();
      expect(source.metadata.bookSourceGroup).assertEqual('测试分组');
      expect(source.legacy.searchUrl).assertEqual('/search?key={{key}}');
      expect(source.legacy.ruleType).assertEqual('xpath');
    });
  });

  describe('BookSourceConverter', () => {
    it('应该正确转换书源为兼容格式', () => {
      const searchRule: SearchRule = {
        bookList: '.item',
        name: '.name',
        author: '.author',
        cover: undefined,
        intro: undefined,
        bookUrl: '.url',
        nextUrl: undefined
      };

      const source = new BookSourceBuilder('id1', '书源1', 'https://test.com')
        .setSearchUrl('/search')
        .setSearchRule(searchRule)
        .build();

      const compat = BookSourceConverter.toCompat(source);

      expect(compat.id).assertEqual('id1');
      expect(compat.name).assertEqual('书源1');
      expect(compat.searchUrl).assertEqual('/search');
    });

    it('应该正确从兼容格式转换', () => {
      const searchRule: SearchRule = {
        bookList: '.item',
        name: '.name',
        author: '.author',
        cover: undefined,
        intro: undefined,
        bookUrl: '.url',
        nextUrl: undefined
      };

      const tocRule: TocRule = {
        chapterList: '.chapter',
        chapterName: '.name',
        chapterUrl: '.url',
        nextUrl: undefined
      };

      const contentRule: ContentRule = {
        content: '.content',
        nextUrl: undefined,
        prevUrl: undefined
      };

      const compat: BookSourceCompat = {
        id: 'id2',
        name: '书源2',
        url: 'https://test2.com',
        enabled: true,
        header: undefined,
        searchUrl: '/search2',
        searchRule: searchRule,
        findRule: undefined,
        chapterRule: tocRule,
        contentRule: contentRule,
        ruleType: 'xpath',
        sort: 0,
        lastUpdateTime: Date.now(),
        addTime: Date.now()
      };

      const source = BookSourceConverter.fromCompat(compat);

      expect(source.id).assertEqual('id2');
      expect(source.name).assertEqual('书源2');
      expect(source.metadata.enabled).assertTrue();
    });

    it('应该正确序列化和反序列化', () => {
      const source = new BookSourceBuilder('id3', '书源3', 'https://test3.com')
        .setSearchUrl('/search3')
        .build();

      const json = BookSourceConverter.toJson(source);
      const restored = BookSourceConverter.fromJson(json);

      expect(restored !== null).assertTrue();
      expect(restored!.id).assertEqual('id3');
      expect(restored!.name).assertEqual('书源3');
    });
  });
}
