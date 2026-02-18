# AstroRead 书源解析开发总结

## 已完成的功能

### 1. 搜索引擎 (BookSourceSearchEngine)
**文件**: `entry/src/main/ets/utils/BookSourceSearchEngine.ets`

#### 功能特性
- ✅ **多书源并发搜索** - 支持同时搜索多个书源，可配置并发数
- ✅ **请求频率控制** - 自动限制每个书源的请求频率，避免被封IP
- ✅ **动态URL构建** - 支持 `{{key}}`、`{{page}}` 占位符替换
- ✅ **JS动态URL** - 支持 `@js:` 前缀的JavaScript动态生成URL
- ✅ **自动编码** - 自动处理URL编码
- ✅ **结果聚合** - 自动去重，基于书名+作者

#### 支持的搜索规则
```javascript
// 基础规则
searchUrl: "https://example.com/search?q={{key}}&page={{page}}"

// JS动态规则
searchUrl: "@js:baseUrl + '/search?key=' + encodeURIComponent(key)"

// 搜索规则字段
searchRule: {
  bookList: "//div[@class='book-item']",  // 书籍列表选择器
  name: ".title@text",                      // 书名
  author: ".author@text",                   // 作者
  cover: ".cover@src",                      // 封面
  intro: ".intro@text",                     // 简介
  bookUrl: ".title@href"                    // 书籍链接
}
```

---

### 2. 调试工具 (BookSourceDebugger)
**文件**:
- `entry/src/main/ets/utils/BookSourceDebugger.ets`
- `entry/src/main/ets/components/BookSourceDebuggerComponent.ets`

#### 功能特性
- ✅ **三步调试** - 搜索测试、章节测试、正文测试
- ✅ **实时步骤显示** - 显示每个步骤的输入、输出、耗时
- ✅ **错误定位** - 精确定位失败的步骤和原因
- ✅ **规则验证** - 验证书源配置的完整性

#### 调试界面功能
```
┌─────────────────────────────────────┐
│  搜索测试 │ 章节测试 │ 正文测试      │
├─────────────────────────────────────┤
│  输入: [搜索关键词/URL]              │
│  [开始测试]                         │
├─────────────────────────────────────┤
│  执行步骤:                          │
│  ✅ 验证书源配置 (10ms)             │
│  ✅ 构建搜索 URL (5ms)              │
│  ✅ 发送网络请求 (245ms)            │
│  ✅ 解析书籍列表 (15ms)             │
│  ✅ 解析书籍详情 (30ms)             │
├─────────────────────────────────────┤
│  结果: 搜索成功，找到 10 本书        │
│  [书籍列表展示]                     │
└─────────────────────────────────────┘
```

---

### 3. 书源管理器 (BookSourceManager)
**文件**: `entry/src/main/ets/utils/BookSourceManager.ets`

#### 功能特性
- ✅ **格式兼容** - 支持 Legado 格式和 YCK 格式
- ✅ **URL导入** - 支持从网络 URL 导入书源
- ✅ **批量管理** - 添加、删除、启用、禁用书源
- ✅ **导入/导出** - JSON 格式和 YCK 格式互转

#### 支持的格式

**Legado 格式**:
```json
{
  "bookSourceName": "书源名称",
  "bookSourceUrl": "https://example.com",
  "searchUrl": "https://example.com/search?q={{key}}",
  "ruleSearch": {
    "bookList": "//div[@class='book']",
    "name": "//h3/text()",
    "author": "//span[@class='author']/text()"
  }
}
```

**YCK 格式** (https://www.yck.email):
```json
{
  "bookSourceName": "书源名称",
  "bookSourceUrl": "https://example.com",
  "searchUrl": "https://example.com/search?q={{key}}",
  "ruleSearch": {
    "bookList": ".book-list .item",
    "name": ".title",
    "author": ".author",
    "coverUrl": ".cover@src",
    "introduce": ".intro",
    "bookUrl": ".title@href"
  },
  "ruleToc": {
    "chapterList": ".chapter-list a",
    "chapterName": "text",
    "chapterUrl": "href"
  },
  "ruleContent": {
    "content": "#content@html"
  }
}
```

---

### 4. HTML解析器 (HTMLParser)
**文件**: `entry/src/main/ets/utils/HTMLParser.ets`

#### 支持的解析方式
- ✅ **CSS Selector** - `.book-item`, `#main`, `div.title`
- ✅ **XPath** - `//div[@class='book']//a/@href`
- ✅ **JSONPath** - `$.data.books[*].name`
- ✅ **正则表达式** - `##title="([^"]+)"`

#### 使用示例
```typescript
import HTMLParser from './utils/HTMLParser';

// CSS Selector
const titles = HTMLParser.parse(html, '.book-title');

// XPath
const links = HTMLParser.parse(html, '//a[@class="title"]/@href');

// JSONPath (API返回JSON)
const names = HTMLParser.parse(jsonStr, '$.data.books[*].name');

// 正则
const matches = HTMLParser.parse(html, '##<h1>(.*?)</h1>');
```

---

### 5. JS引擎 (EnhancedJSEngine)
**文件**: `entry/src/main/ets/utils/EnhancedJSEngine.ets`

#### 支持的 Java 对象方法
```javascript
// 网络请求
java.ajax(url)
java.get(url, headers)
java.post(url, body, headers)

// 编码/解码
java.base64Encode(str)
java.base64Decode(str)
java.md5Encode(str)
java.encodeURI(str)
java.decodeURI(str)

// HTML 解析
java.getElements(html, rule)     // 返回数组
java.getString(html, rule)       // 返回字符串
java.parseHtml(html)             // 返回 DOM 对象

// URL 处理
java.resolveUrl(baseUrl, relativeUrl)

// 字符串处理
java.replace(str, pattern, replacement)
java.trim(str)
java.split(str, separator)
java.join(arr, separator)

// 缓存
java.put(key, value)
java.get(key)

// 日志
java.log(msg)
java.longToast(msg)
```

---

## 使用示例

### 基本搜索流程
```typescript
import BookSourceManager from './utils/BookSourceManager';

// 1. 导入书源
const sources = await BookSourceManager.importSources(`
[
  {
    "bookSourceName": "测试书源",
    "bookSourceUrl": "https://example.com",
    "searchUrl": "https://example.com/search?q={{key}}",
    "ruleSearch": {
      "bookList": ".book-item",
      "name": ".title",
      "author": ".author",
      "bookUrl": ".title@href"
    }
  }
]
`);

// 2. 添加书源
BookSourceManager.addSources(sources);

// 3. 搜索
const { results, books } = await BookSourceManager.searchBooks('斗破苍穹');

// 4. 展示结果
books.forEach(book => {
  console.log(`${book.name} - ${book.author}`);
});
```

### 调试书源
```typescript
import BookSourceManager from './utils/BookSourceManager';

// 获取书源
const source = BookSourceManager.getAllSources()[0];

// 测试搜索
const result = await BookSourceManager.debugSearch(source, '测试关键词');
console.log(result.steps);  // 查看每步执行详情
console.log(result.books);  // 查看解析结果

// 验证规则
const validation = BookSourceManager.validateSource(source);
if (!validation.valid) {
  console.log(validation.errors);  // 查看错误信息
}
```

### 在 UI 中使用调试组件
```typescript
import { BookSourceDebuggerComponent } from './components/BookSourceDebuggerComponent';

@Entry
@Component
struct DebugPage {
  @State source: BookSource = { /* ... */ };

  build() {
    Column() {
      BookSourceDebuggerComponent({
        source: this.source
      })
    }
  }
}
```

---

## 下一步优化

1. **智能重试机制**
   - 检测网站返回的 403/503 错误，自动切换 User-Agent
   - 实现指数退避重试策略

2. **书源订阅更新**
   - 支持书源仓库订阅（类似 Legado 的书源订阅）
   - 自动检测书源更新

3. **验证码处理**
   - 集成验证码识别服务
   - 支持打码平台对接

4. **性能优化**
   - 实现章节内容预加载
   - 图片懒加载

5. **书源分享**
   - 生成书源二维码
   - 一键分享书源

---

## 参考资源

- **Legado 书源规则**: https://www.yuque.com/legado/wiki/syrules
- **YCK 书源仓库**: https://www.yck.email/yuedu/tools/index/id/shuyuan.html
- **阅读3.0 书源**: https://github.com/gedoor/legado

---

**最后更新**: 2026-02-16
**版本**: v1.2.0
