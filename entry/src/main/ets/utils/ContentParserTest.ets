import { ContentParser, ParsedBookItem, ParsedChapterItem, ReplaceRuleConfig } from './ContentParser';
import { BookSource } from '../models/BookSource';

/**
 * ContentParser 功能测试
 */
export class ContentParserTest {
  
  /**
   * 测试JSONPath解析搜索结果
   */
  static testJsonPathSearch(): boolean {
    console.log('=== 测试JSONPath解析搜索结果 ===');
    
    // 模拟JSON数据
    const jsonData = `{
      "data": {
        "books": [
          {
            "name": "测试书籍1",
            "author": "作者1",
            "cover": "http://example.com/cover1.jpg",
            "intro": "这是书籍1的简介",
            "url": "/book/1"
          },
          {
            "name": "测试书籍2", 
            "author": "作者2",
            "cover": "http://example.com/cover2.jpg",
            "intro": "这是书籍2的简介",
            "url": "/book/2"
          }
        ]
      }
    }`;
    
    const bookSource: BookSource = {
      id: 'test-source',
      name: '测试书源',
      url: 'http://example.com',
      enabled: true,
      header: '',
      searchUrl: 'http://example.com/search?q={{key}}',
      searchRule: {
        bookList: '$.data.books',
        name: '$.name',
        author: '$.author',
        cover: '$.cover',
        intro: '$.intro',
        bookUrl: '$.url',
        nextUrl: undefined
      },
      findRule: undefined,
      chapterRule: {
        chapterList: '',
        chapterName: '',
        chapterUrl: '',
        nextUrl: undefined
      },
      contentRule: {
        content: '',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      },
      ruleType: 'jsonpath',
      sort: 0,
      lastUpdateTime: 0,
      addTime: 0
    };
    
    const results: ParsedBookItem[] = ContentParser.parseSearchResult(jsonData, bookSource);
    
    console.log(`解析结果数量: ${results.length}`);
    results.forEach((book: ParsedBookItem, index: number) => {
      console.log(`书籍${index + 1}: ${book.name} - ${book.author}`);
    });
    
    const success = results.length === 2 && 
                   results[0].name === '测试书籍1' && 
                   results[1].name === '测试书籍2';
    
    console.log(`测试结果: ${success ? '通过' : '失败'}`);
    return success;
  }
  
  /**
   * 测试正则表达式解析搜索结果
   */
  static testRegexSearch(): boolean {
    console.log('=== 测试正则表达式解析搜索结果 ===');
    
    // 模拟HTML数据 - 修复HTML结构确保正确匹配
    const htmlData = `
      <div class="book-item">
        <a href="/book/1">测试书籍1</a>
        <span class="author">作者1</span>
        <img src="cover1.jpg">
        <p class="intro">书籍1简介</p>
      </div>
      <div class="book-item">
        <a href="/book/2">测试书籍2</a>
        <span class="author">作者2</span>
        <img src="cover2.jpg">
        <p class="intro">书籍2简介</p>
      </div>
    `;
    
    const bookSource: BookSource = {
      id: 'test-source',
      name: '测试书源',
      url: 'http://example.com',
      enabled: true,
      header: '',
      searchUrl: 'http://example.com/search?q={{key}}',
      searchRule: {
        bookList: '<div class="book-item">([\\s\\S]*?)</div>', // 修复正则表达式
        name: '<a href="[^"]*">([^<]*)</a>',
        author: '<span class="author">([^<]*)</span>',
        cover: '<img src="([^"]*)">',
        intro: '<p class="intro">([^<]*)</p>',
        bookUrl: '<a href="([^"]*)">',
        nextUrl: undefined
      },
      findRule: undefined,
      chapterRule: {
        chapterList: '',
        chapterName: '',
        chapterUrl: '',
        nextUrl: undefined
      },
      contentRule: {
        content: '',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      },
      ruleType: 'regex',
      sort: 0,
      lastUpdateTime: 0,
      addTime: 0
    };
    
    const results: ParsedBookItem[] = ContentParser.parseSearchResult(htmlData, bookSource);
    
    console.log(`解析结果数量: ${results.length}`);
    results.forEach((book: ParsedBookItem, index: number) => {
      console.log(`书籍${index + 1}: 书名="${book.name}", 作者="${book.author}", 封面="${book.cover}", URL="${book.bookUrl}"`);
    });
    
    const success = results.length === 2 && 
                   results[0].name === '测试书籍1' && 
                   results[1].name === '测试书籍2';
    
    console.log(`测试结果: ${success ? '通过' : '失败'}`);
    return success;
  }
  
  /**
   * 测试内容净化功能
   */
  static testContentPurification(): boolean {
    console.log('=== 测试内容净化功能 ===');
    
    // 修复测试内容，确保正则表达式能正确匹配
    const dirtyContent = `
      <div class="content">
        <script>alert('恶意脚本')</script>
        <p>这是第一段文本。</p>
        <p>这是第二段文本。</p>
        <div class="ad">广告内容</div>
        &nbsp;&nbsp;多个空格&nbsp;&nbsp;
        <br><br>
        重复标点！！！！！
      </div>
    `;
    
    // 修复replaceRule配置，使用正确的JSON字符串格式
    const replaceRuleConfig: ReplaceRuleConfig = {
      removeHtmlTags: true,
      removeTags: ['script', 'div'],
      replace: [
        { from: '广告内容', to: '' },
        { from: '\\n\\n+', to: '\\n' }
      ]
    };
    
    const bookSource: BookSource = {
      id: 'test-source',
      name: '测试书源',
      url: 'http://example.com',
      enabled: true,
      header: '',
      searchUrl: '',
      searchRule: {
        bookList: '',
        name: '',
        author: '',
        cover: '',
        intro: '',
        bookUrl: '',
        nextUrl: undefined
      },
      findRule: undefined,
      chapterRule: {
        chapterList: '',
        chapterName: '',
        chapterUrl: '',
        nextUrl: undefined
      },
      contentRule: {
        content: '<div class="content">([\\s\\S]*?)</div>',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: JSON.stringify(replaceRuleConfig) // 修复：使用JSON字符串
      },
      ruleType: 'regex',
      sort: 0,
      lastUpdateTime: 0,
      addTime: 0
    };
    
    const purified = ContentParser.parseChapterContent(dirtyContent, bookSource);
    
    console.log('净化前内容长度:', dirtyContent.length);
    console.log('净化后内容长度:', purified.length);
    console.log('净化后内容:', purified);
    
    const success = purified.includes('这是第一段文本') && 
                   purified.includes('这是第二段文本') && 
                   !purified.includes('恶意脚本') && 
                   !purified.includes('广告内容') &&
                   !purified.includes('<script>') &&
                   !purified.includes('<div>');
    
    console.log(`测试结果: ${success ? '通过' : '失败'}`);
    return success;
  }
  
  /**
   * 测试章节解析功能
   */
  static testChapterParsing(): boolean {
    console.log('=== 测试章节解析功能 ===');
    
    // 模拟章节列表HTML
    const chapterHtml = `
      <ul class="chapter-list">
        <li><a href="/chapter/1">第一章 开始</a></li>
        <li><a href="/chapter/2">第二章 发展</a></li>
        <li><a href="/chapter/3">第三章 结束 (VIP)</a></li>
      </ul>
    `;
    
    const bookSource: BookSource = {
      id: 'test-source',
      name: '测试书源',
      url: 'http://example.com',
      enabled: true,
      header: '',
      searchUrl: '',
      searchRule: {
        bookList: '',
        name: '',
        author: '',
        cover: '',
        intro: '',
        bookUrl: '',
        nextUrl: undefined
      },
      findRule: undefined,
      chapterRule: {
        chapterList: '<li>([\\s\\S]*?)</li>',
        chapterName: '<a[^>]*>([^<]*)</a>',
        chapterUrl: '<a href="([^"]*)">',
        nextUrl: undefined
      },
      contentRule: {
        content: '',
        nextUrl: undefined,
        prevUrl: undefined,
        replaceRule: undefined
      },
      ruleType: 'regex',
      sort: 0,
      lastUpdateTime: 0,
      addTime: 0
    };
    
    const chapters = ContentParser.parseChapterList(chapterHtml, bookSource);
    
    console.log(`解析章节数量: ${chapters.length}`);
    chapters.forEach((chapter: ParsedChapterItem, index: number) => {
      console.log(`章节${index + 1}: "${chapter.title}" - ${chapter.url} ${chapter.isVip ? '(VIP)' : ''}`);
    });
    
    const success = chapters.length === 3 && 
                   chapters[0].title === '第一章 开始' &&
                   chapters[1].title === '第二章 发展' &&
                   chapters[2].title === '第三章 结束 (VIP)' &&
                   chapters[2].isVip === true;
    
    console.log(`测试结果: ${success ? '通过' : '失败'}`);
    return success;
  }
  
  /**
   * 测试异常情况处理
   */
  static testErrorHandling(): boolean {
    console.log('=== 测试异常情况处理 ===');
    
    let successCount = 0;
    
    // 测试1：空输入
    try {
      const emptyResult = ContentParser.parseSearchResult('', {} as BookSource);
      if (emptyResult.length === 0) {
        console.log('空输入测试: 通过');
        successCount++;
      }
    } catch (error) {
      console.log('空输入测试: 通过（正确处理异常）');
      successCount++;
    }
    
    // 测试2：无效JSON
    try {
      const invalidJson = '{invalid json}';
      const bookSource: BookSource = {
        id: 'test',
        name: 'test',
        url: 'http://example.com',
        enabled: true,
        header: '',
        searchUrl: '',
        searchRule: {
          bookList: '$.data',
          name: '$.name',
          author: '$.author',
          cover: '$.cover',
          intro: '$.intro',
          bookUrl: '$.url',
          nextUrl: undefined
        },
        findRule: undefined,
        chapterRule: {
          chapterList: '',
          chapterName: '',
          chapterUrl: '',
          nextUrl: undefined
        },
        contentRule: {
          content: '',
          nextUrl: undefined,
          prevUrl: undefined,
          replaceRule: undefined
        },
        ruleType: 'jsonpath',
        sort: 0,
        lastUpdateTime: 0,
        addTime: 0
      };
      const result = ContentParser.parseSearchResult(invalidJson, bookSource);
      if (result.length === 0) {
        console.log('无效JSON测试: 通过');
        successCount++;
      }
    } catch (error) {
      console.log('无效JSON测试: 通过（正确处理异常）');
      successCount++;
    }
    
    // 测试3：无效正则表达式
    try {
      const html = '<div>test</div>';
      const bookSource: BookSource = {
        id: 'test',
        name: 'test',
        url: 'http://example.com',
        enabled: true,
        header: '',
        searchUrl: '',
        searchRule: {
          bookList: 'invalid[regex', // 无效的正则表达式
          name: '$.name',
          author: '$.author',
          cover: '$.cover',
          intro: '$.intro',
          bookUrl: '$.url',
          nextUrl: undefined
        },
        findRule: undefined,
        chapterRule: {
          chapterList: '',
          chapterName: '',
          chapterUrl: '',
          nextUrl: undefined
        },
        contentRule: {
          content: '',
          nextUrl: undefined,
          prevUrl: undefined,
          replaceRule: undefined
        },
        ruleType: 'regex',
        sort: 0,
        lastUpdateTime: 0,
        addTime: 0
      };
      const result = ContentParser.parseSearchResult(html, bookSource);
      if (result.length === 0) {
        console.log('无效正则表达式测试: 通过');
        successCount++;
      }
    } catch (error) {
      console.log('无效正则表达式测试: 通过（正确处理异常）');
      successCount++;
    }
    
    const success = successCount === 3;
    console.log(`异常处理测试结果: ${success ? '通过' : '失败'} (${successCount}/3)`);
    return success;
  }
  
  /**
   * 运行所有测试
   */
  static runAllTests(): boolean {
    console.log('开始运行ContentParser测试...\n');
    
    let passed = 0;
    let total = 5;
    
    try {
      if (ContentParserTest.testJsonPathSearch()) passed++;
    } catch (error) {
      console.error('JSONPath测试失败:', error);
    }
    
    try {
      if (ContentParserTest.testRegexSearch()) passed++;
    } catch (error) {
      console.error('正则表达式测试失败:', error);
    }
    
    try {
      if (ContentParserTest.testContentPurification()) passed++;
    } catch (error) {
      console.error('内容净化测试失败:', error);
    }
    
    try {
      if (ContentParserTest.testChapterParsing()) passed++;
    } catch (error) {
      console.error('章节解析测试失败:', error);
    }
    
    try {
      if (ContentParserTest.testErrorHandling()) passed++;
    } catch (error) {
      console.error('异常处理测试失败:', error);
    }
    
    console.log(`\n测试完成: ${passed}/${total} 通过`);
    return passed === total;
  }
}