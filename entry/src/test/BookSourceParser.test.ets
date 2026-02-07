import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ContentParser, ParsedBookItem, ParsedChapterItem, ReplaceRuleConfig, ReplaceRuleItem } from '../main/ets/utils/ContentParser';
import { NetworkManager } from '../main/ets/utils/NetworkManager';
import { BookSource, SearchRule, ChapterRule, ContentRule } from '../main/ets/models/BookSource';

// JSON测试数据接口定义
interface JsonBookItem {
  name: string;
  author: string;
  url: string;
}

interface JsonData {
  books: JsonBookItem[];
}

interface JsonRoot {
  data: JsonData;
}

export default function bookSourceParserTest() {
  describe('BookSourceParserTest', () => {
    let networkManager: NetworkManager;
    
    beforeAll(() => {
      networkManager = NetworkManager.getInstance();
    });
    
    beforeEach(() => {
      // 测试前的准备工作
    });
    
    afterEach(() => {
      // 测试后的清理工作
    });
    
    afterAll(() => {
      // 所有测试结束后的清理工作
    });
    
    // 测试XPath解析功能
    it('testXPathParsing', 0, () => {
      const html = `
        <div class="book-list">
          <div class="book-item">
            <h3 class="book-name">测试书籍1</h3>
            <p class="book-author">作者1</p>
            <a class="book-url" href="https://example.com/book1">详情</a>
          </div>
          <div class="book-item">
            <h3 class="book-name">测试书籍2</h3>
            <p class="book-author">作者2</p>
            <a class="book-url" href="https://example.com/book2">详情</a>
          </div>
        </div>
      `;
      
      const searchRule: SearchRule = {
        bookList: '//div[@class="book-item"]',
        name: '//h3[@class="book-name"]/text()',
        author: '//p[@class="book-author"]/text()',
        cover: undefined,
        intro: undefined,
        bookUrl: '//a[@class="book-url"]/@href',
        nextUrl: undefined
      };
      
      const chapterRule: ChapterRule = {
        chapterList: '//div[@class="chapter-item"]',
        chapterName: '//a/text()',
        chapterUrl: '//a/@href',
        nextUrl: undefined
      };
      
      const contentRule: ContentRule = {
        content: '//div[@class="content"]/text()',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      };
      
      const bookSource: BookSource = {
        id: 'test',
        name: '测试书源',
        url: 'https://example.com',
        enabled: true,
        header: undefined,
        searchUrl: 'https://example.com/search?key={{key}}',
        searchRule: searchRule,
        findRule: undefined,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: 'xpath',
        sort: 0,
        lastUpdateTime: Date.now(),
        addTime: Date.now()
      };
      
      const results = ContentParser.parseSearchResult(html, bookSource);
      expect(results.length).assertEqual(2);
      expect(results[0].name).assertEqual('测试书籍1');
      expect(results[0].author).assertEqual('作者1');
      expect(results[0].bookUrl).assertEqual('https://example.com/book1');
      expect(results[1].name).assertEqual('测试书籍2');
      expect(results[1].author).assertEqual('作者2');
      expect(results[1].bookUrl).assertEqual('https://example.com/book2');
    });
    
    // 测试JSONPath解析功能
    it('testJsonPathParsing', 0, () => {
      const jsonData: JsonRoot = {
        data: {
          books: [
            {
              name: 'JSON测试书籍1',
              author: 'JSON作者1',
              url: 'https://example.com/json1'
            } as JsonBookItem,
            {
              name: 'JSON测试书籍2',
              author: 'JSON作者2',
              url: 'https://example.com/json2'
            } as JsonBookItem
          ] as JsonBookItem[]
        } as JsonData
      };
      const json = JSON.stringify(jsonData);
      
      const searchRule: SearchRule = {
        bookList: '$.data.books',
        name: '$.name',
        author: '$.author',
        cover: undefined,
        intro: undefined,
        bookUrl: '$.url',
        nextUrl: undefined
      };
      
      const chapterRule: ChapterRule = {
        chapterList: '$.data.chapters',
        chapterName: '$.title',
        chapterUrl: '$.url',
        nextUrl: undefined
      };
      
      const contentRule: ContentRule = {
        content: '$.data.content',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      };
      
      const bookSource: BookSource = {
        id: 'test-json',
        name: 'JSON测试书源',
        url: 'https://example.com',
        enabled: true,
        header: undefined,
        searchUrl: 'https://example.com/search?key={{key}}',
        searchRule: searchRule,
        findRule: undefined,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: 'jsonpath',
        sort: 0,
        lastUpdateTime: Date.now(),
        addTime: Date.now()
      };
      
      const results = ContentParser.parseSearchResult(json, bookSource);
      expect(results.length).assertEqual(2);
      expect(results[0].name).assertEqual('JSON测试书籍1');
      expect(results[0].author).assertEqual('JSON作者1');
      expect(results[0].bookUrl).assertEqual('https://example.com/json1');
      expect(results[1].name).assertEqual('JSON测试书籍2');
      expect(results[1].author).assertEqual('JSON作者2');
      expect(results[1].bookUrl).assertEqual('https://example.com/json2');
    });
    
    // 测试正则表达式解析功能
    it('testRegexParsing', 0, () => {
      const html = `
        <div class="book-list">
          <div class="book-item">
            <h3>正则测试书籍1</h3>
            <p>作者：正则作者1</p>
            <a href="https://example.com/regex1">详情</a>
          </div>
          <div class="book-item">
            <h3>正则测试书籍2</h3>
            <p>作者：正则作者2</p>
            <a href="https://example.com/regex2">详情</a>
          </div>
        </div>
      `;
      
      const searchRule: SearchRule = {
        bookList: '<div class="book-item">[\\s\\S]*?</div>',
        name: '<h3>([\\s\\S]*?)</h3>',
        author: '<p>作者：([\\s\\S]*?)</p>',
        cover: undefined,
        intro: undefined,
        bookUrl: '<a href="([\\s\\S]*?)">详情</a>',
        nextUrl: undefined
      };
      
      const chapterRule: ChapterRule = {
        chapterList: '<div class="chapter-item">[\\s\\S]*?</div>',
        chapterName: '<a>([\\s\\S]*?)</a>',
        chapterUrl: '<a href="([\\s\\S]*?)">',
        nextUrl: undefined
      };
      
      const contentRule: ContentRule = {
        content: '<div class="content">([\\s\\S]*?)</div>',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      };
      
      const bookSource: BookSource = {
        id: 'test-regex',
        name: '正则测试书源',
        url: 'https://example.com',
        enabled: true,
        header: undefined,
        searchUrl: 'https://example.com/search?key={{key}}',
        searchRule: searchRule,
        findRule: undefined,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: 'regex',
        sort: 0,
        lastUpdateTime: Date.now(),
        addTime: Date.now()
      };
      
      const results = ContentParser.parseSearchResult(html, bookSource);
      expect(results.length).assertLargerOrEqual(0);
    });
    
    // 测试内容净化功能
    it('testContentPurification', 0, () => {
      const html = `
        <div class="content">
          <p>测试内容1</p>
          <p>测试内容2</p>
          <div class="ad">广告内容</div>
          <p>测试内容3</p>
        </div>
      `;
      
      const replaceRuleConfig: ReplaceRuleConfig = {
        removeTags: ['div'],
        removeHtmlTags: true,
        replace: [
          { from: '广告内容', to: '' } as ReplaceRuleItem
        ]
      };
      
      const purified = ContentParser.purifyContent(html, replaceRuleConfig);
      expect(purified).assertContain('测试内容1');
      expect(purified).assertContain('测试内容2');
      expect(purified).assertContain('测试内容3');
      expect(purified.indexOf('广告内容')).assertEqual(-1);
      expect(purified.indexOf('<div')).assertEqual(-1);
      expect(purified.indexOf('</div>')).assertEqual(-1);
    });
    
    // 测试章节列表解析
    it('testChapterListParsing', 0, () => {
      const html = `
        <div class="chapter-list">
          <a href="https://example.com/chapter1">第一章</a>
          <a href="https://example.com/chapter2">第二章</a>
          <a href="https://example.com/chapter3">第三章</a>
        </div>
      `;
      
      const searchRule: SearchRule = {
        bookList: '//div[@class="book-item"]',
        name: '//h3/text()',
        author: '//p/text()',
        cover: undefined,
        intro: undefined,
        bookUrl: '//a/@href',
        nextUrl: undefined
      };
      
      const chapterRule: ChapterRule = {
        chapterList: '//a',
        chapterName: '//text()',
        chapterUrl: '//@href',
        nextUrl: undefined
      };
      
      const contentRule: ContentRule = {
        content: '//div[@class="content"]/text()',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      };
      
      const bookSource: BookSource = {
        id: 'test-chapter',
        name: '章节测试书源',
        url: 'https://example.com',
        enabled: true,
        header: undefined,
        searchUrl: 'https://example.com/search?key={{key}}',
        searchRule: searchRule,
        findRule: undefined,
        chapterRule: chapterRule,
        contentRule: contentRule,
        ruleType: 'xpath',
        sort: 0,
        lastUpdateTime: Date.now(),
        addTime: Date.now()
      };
      
      const chapters = ContentParser.parseChapterList(html, bookSource);
      expect(chapters.length).assertEqual(3);
      expect(chapters[0].title).assertEqual('第一章');
      expect(chapters[0].url).assertEqual('https://example.com/chapter1');
      expect(chapters[1].title).assertEqual('第二章');
      expect(chapters[1].url).assertEqual('https://example.com/chapter2');
      expect(chapters[2].title).assertEqual('第三章');
      expect(chapters[2].url).assertEqual('https://example.com/chapter3');
    });
    
    // 测试HTML实体解码
    it('testHtmlEntityDecoding', 0, () => {
      const html = '&lt;p&gt;测试内容&lt;/p&gt; &nbsp; &amp; &quot; &apos;';
      const decoded = ContentParser.decodeHtmlEntities(html);
      expect(decoded).assertEqual('<p>测试内容</p>   & " \'');
    });
  });
}