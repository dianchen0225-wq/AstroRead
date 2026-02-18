# AstroRead 完整 API 文档

> AstroRead 阅读应用核心 API 接口文档

## 目录

- [概述](#概述)
- [接口清单](#接口清单)
- [数据模型](#数据模型)
- [解析器模块 API](#解析器模块-api)
- [网络请求模块 API](#网络请求模块-api)
- [数据库模块 API](#数据库模块-api)
- [错误码](#错误码)
- [使用示例](#使用示例)

---

## 概述

AstroRead 是一款基于 HarmonyOS 的阅读应用，提供书籍搜索、阅读、书签管理等功能。本文档描述了核心模块的 API 接口。

### 模块架构

```
AstroRead
├── ParserFacade    # 解析器模块 - 内容解析
├── HttpClient      # 网络模块 - HTTP 请求
├── DatabaseManager # 数据库模块 - 数据存储
├── BookSource      # 书源模块 - 书源管理
└── Reader          # 阅读模块 - 阅读功能
```

---

## 接口清单

### 解析器模块 (ParserFacade)

| 接口名称 | 方法 | 功能描述 |
|---------|------|---------|
| parse | async | 解析内容 |
| parseSync | sync | 同步解析内容 |
| parseJSON | async | 解析 JSON |
| parseXML | async | 解析 XML |
| parseHTML | async | 解析 HTML |
| parseCSV | async | 解析 CSV |
| validate | sync | 验证内容格式 |
| format | sync | 格式化输出 |
| clearCache | sync | 清除缓存 |
| getCacheStats | sync | 获取缓存统计 |

### 网络请求模块 (HttpClient)

| 接口名称 | 方法 | 功能描述 |
|---------|------|---------|
| request | async | 发送请求 |
| get | async | GET 请求 |
| post | async | POST 请求 |
| put | async | PUT 请求 |
| delete | async | DELETE 请求 |
| patch | async | PATCH 请求 |
| addRequestInterceptor | sync | 添加请求拦截器 |
| addResponseInterceptor | sync | 添加响应拦截器 |
| clearCache | sync | 清除请求缓存 |
| abort | sync | 取消请求 |

### 数据库模块 (Repository)

| 接口名称 | 方法 | 功能描述 |
|---------|------|---------|
| insert | async | 插入数据 |
| update | async | 更新数据 |
| delete | async | 删除数据 |
| queryById | async | 按 ID 查询 |
| queryAll | async | 查询全部 |
| search | async | 搜索数据 |

---

## 数据模型

### Book - 书籍

```typescript
interface Book {
  id: string;              // 书籍唯一标识
  name: string;            // 书名
  author: string;          // 作者
  coverUrl?: string;       // 封面 URL
  intro?: string;          // 简介
  bookSourceId: string;    // 书源 ID
  bookSourceName: string;  // 书源名称
  bookUrl: string;         // 书籍详情页 URL
  chapterCount: number;    // 章节数量
  wordCount: number;       // 字数
  status: 'ongoing' | 'completed' | 'unknown';  // 连载状态
  lastChapter?: string;    // 最新章节
  lastReadTime?: number;   // 最后阅读时间
  createTime: number;      // 创建时间
  updateTime: number;      // 更新时间
}
```

| 字段名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|-----|--------|------|
| id | string | 是 | - | UUID 格式 |
| name | string | 是 | - | 书名，最大 200 字符 |
| author | string | 是 | - | 作者名，最大 100 字符 |
| coverUrl | string | 否 | null | 封面图片 URL |
| intro | string | 否 | null | 书籍简介 |
| bookSourceId | string | 是 | - | 关联的书源 ID |
| bookSourceName | string | 是 | - | 书源名称 |
| bookUrl | string | 是 | - | 书籍详情页 URL |
| chapterCount | number | 是 | 0 | 章节总数 |
| wordCount | number | 是 | 0 | 总字数 |
| status | string | 是 | 'unknown' | 连载状态 |
| lastChapter | string | 否 | null | 最新章节标题 |
| lastReadTime | number | 否 | null | 时间戳（毫秒） |
| createTime | number | 是 | - | 时间戳（毫秒） |
| updateTime | number | 是 | - | 时间戳（毫秒） |

### BookSource - 书源

```typescript
interface BookSource {
  id: string;              // 书源唯一标识
  name: string;            // 书源名称
  url: string;             // 书源地址
  type: 'text' | 'audio' | 'image';  // 书源类型
  enabled: boolean;        // 是否启用
  group?: string;          // 分组名称
  searchUrl?: string;      // 搜索 URL 模板
  exploreUrl?: string;     // 发现 URL JSON
  ruleSearch?: string;     // 搜索规则 JSON
  ruleBookInfo?: string;   // 书籍信息规则 JSON
  ruleToc?: string;        // 目录规则 JSON
  ruleContent?: string;    // 内容规则 JSON
  createTime: number;      // 创建时间
  updateTime: number;      // 更新时间
}
```

### Bookmark - 书签

```typescript
interface Bookmark {
  id: string;              // 书签唯一标识
  bookId: string;          // 关联书籍 ID
  chapterIndex: number;    // 章节索引
  chapterName: string;     // 章节名称
  position: number;        // 章节内位置
  content?: string;        // 书签内容预览
  createTime: number;      // 创建时间
}
```

### Chapter - 章节

```typescript
interface Chapter {
  id: string;              // 章节唯一标识
  bookId: string;          // 关联书籍 ID
  index: number;           // 章节索引
  name: string;            // 章节名称
  url: string;             // 章节 URL
  content?: string;        // 章节内容
  wordCount: number;       // 字数
  isVip: boolean;          // 是否 VIP 章节
  createTime: number;      // 创建时间
}
```

---

## 解析器模块 API

### ParserFacade

#### parse - 解析内容

**基本信息**

| 属性 | 值 |
|-----|-----|
| 接口名称 | parse |
| 方法类型 | async |
| 功能描述 | 自动检测内容类型并解析 |
| 返回类型 | `Promise<ParseResult<T>>` |

**参数说明**

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|-----|--------|------|
| content | string \| ArrayBuffer | 是 | - | 待解析内容 |
| type | ParserType \| string | 否 | auto | 指定解析类型 |
| options | ParseOptions | 否 | {} | 解析选项 |

**ParseOptions 选项**

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|-----|--------|------|
| encoding | string | 否 | 'utf-8' | 字符编码 |
| strict | boolean | 否 | false | 严格模式 |
| maxDepth | number | 否 | 100 | 最大嵌套深度 |
| timeout | number | 否 | 30000 | 超时时间（毫秒） |
| skipCache | boolean | 否 | false | 跳过缓存 |
| cacheKey | string | 否 | auto | 缓存键 |

**请求示例**

```typescript
import ParserFacade, { ParserType } from '../core/ParserFacade';

// 自动检测类型
const result = await ParserFacade.parse('{"name": "张三"}');

// 指定类型
const jsonResult = await ParserFacade.parse(
  '{"name": "张三"}',
  ParserType.JSON
);

// 带选项
const result = await ParserFacade.parse(content, ParserType.JSON, {
  strict: true,
  maxDepth: 50,
  timeout: 5000
});
```

**响应示例**

```typescript
// 成功响应
{
  data: { name: "张三" },
  status: 'success',
  errors: [],
  warnings: [],
  metadata: {
    parserType: 'json',
    parseTime: 5,
    dataSize: 18,
    cached: false,
    timestamp: 1708123456789,
    version: '1.0.0'
  }
}

// 失败响应
{
  data: null,
  status: 'failed',
  errors: [{
    code: 'SYNTAX_ERROR',
    message: 'Unexpected end of JSON input',
    severity: 'error',
    line: 1,
    column: 18
  }],
  warnings: [],
  metadata: {
    parserType: 'json',
    parseTime: 2,
    dataSize: 18,
    cached: false,
    timestamp: 1708123456789,
    version: '1.0.0'
  }
}
```

#### parseJSON - 解析 JSON

```typescript
const result = await ParserFacade.parseJSON('{"name": "张三"}');

// 支持带注释的 JSON
const result = await ParserFacade.parseJSON(`
{
  // 用户信息
  "name": "张三",
  "age": 25,  // 年龄
}
`);
```

#### parseXML - 解析 XML

```typescript
const result = await ParserFacade.parseXML(`
<?xml version="1.0"?>
<root>
  <user id="1">
    <name>张三</name>
  </user>
</root>
`);

// 访问解析结果
console.log(result.data.name);           // 'root'
console.log(result.data.children[0].name); // 'user'
```

#### parseHTML - 解析 HTML

```typescript
const result = await ParserFacade.parseHTML(`
<!DOCTYPE html>
<html>
<body>
  <div class="content">
    <h1>标题</h1>
    <p class="intro">段落内容</p>
  </div>
</body>
</html>
`);

// 获取文本内容
console.log(result.data.textContent);
```

#### parseCSV - 解析 CSV

```typescript
const result = await ParserFacade.parseCSV(`
name,age,city
张三,25,北京
李四,30,上海
`);

console.log(result.data.headers);  // ['name', 'age', 'city']
console.log(result.data.rows);     // [{ name: '张三', age: '25', city: '北京' }, ...]
```

#### validate - 验证内容

```typescript
const result = ParserFacade.validate('{"name": "张三"}', ParserType.JSON);

if (result.valid) {
  console.log('JSON 格式正确');
} else {
  console.log('错误:', result.errors);
}
```

#### format - 格式化输出

```typescript
const data = { name: '张三', age: 25 };

// 格式化为 JSON
const json = ParserFacade.formatJSON(data, { indent: 2 });

// 格式化为 XML
const xml = ParserFacade.formatXML(xmlNode, { indent: 2 });
```

---

## 网络请求模块 API

### HttpClient

#### request - 发送请求

**基本信息**

| 属性 | 值 |
|-----|-----|
| 接口名称 | request |
| 方法类型 | async |
| 功能描述 | 发送 HTTP 请求 |
| 返回类型 | `Promise<HttpResponse<T>>` |

**参数说明**

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|-----|--------|------|
| config | HttpRequestConfig | 是 | - | 请求配置 |

**HttpRequestConfig 配置**

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|-----|--------|------|
| url | string | 是 | - | 请求 URL |
| method | HttpMethod | 否 | GET | 请求方法 |
| headers | HttpHeaders | 否 | {} | 请求头 |
| params | object | 否 | {} | URL 参数 |
| data | any | 否 | - | 请求体 |
| timeout | number | 否 | 30000 | 超时时间 |
| cache | CacheConfig | 否 | - | 缓存配置 |
| retry | RetryConfig | 否 | - | 重试配置 |

**请求示例**

```typescript
import HttpClient, { HttpMethod } from '../network/HttpClient';

// GET 请求
const response = await HttpClient.get('https://api.example.com/users');

// POST 请求
const response = await HttpClient.post(
  'https://api.example.com/users',
  { name: '张三', age: 25 }
);

// 完整配置
const response = await HttpClient.request({
  url: 'https://api.example.com/users',
  method: HttpMethod.POST,
  headers: {
    'Authorization': 'Bearer token',
    'Content-Type': 'application/json'
  },
  data: { name: '张三' },
  timeout: 10000,
  cache: { enabled: true, ttl: 60000 },
  retry: { maxRetries: 3 }
});
```

**响应格式**

```typescript
interface HttpResponse<T> {
  data: T;              // 响应数据
  status: number;       // HTTP 状态码
  statusText: string;   // 状态文本
  headers: HttpHeaders; // 响应头
  config: HttpRequestConfig; // 请求配置
  duration: number;     // 请求耗时
  cached: boolean;      // 是否来自缓存
  retries: number;      // 重试次数
}
```

#### 拦截器

```typescript
// 添加请求拦截器
HttpClient.addRequestInterceptor({
  id: 'auth-interceptor',
  priority: 1,
  onRequest: (config) => {
    config.headers['Authorization'] = `Bearer ${getToken()}`;
    return config;
  },
  onRequestError: (error) => {
    console.error('Request error:', error);
    return error;
  }
});

// 添加响应拦截器
HttpClient.addResponseInterceptor({
  id: 'error-handler',
  priority: 1,
  onResponse: (response) => {
    console.log(`Response: ${response.status}`);
    return response;
  },
  onResponseError: (error) => {
    if (error.status === 401) {
      redirectToLogin();
    }
    return error;
  }
});
```

#### 缓存控制

```typescript
// 启用缓存
const response = await HttpClient.get(url, {
  cache: { enabled: true, ttl: 60000 }
});

// 强制刷新
const response = await HttpClient.get(url, {
  cache: { enabled: true, forceRefresh: true }
});

// 获取缓存统计
const stats = HttpClient.getCacheStats();
console.log(`命中率: ${stats.hitRate * 100}%`);

// 清除缓存
HttpClient.clearCache();
```

#### 请求取消

```typescript
import { AbortControllerImpl } from '../network/AbortController';

// 创建取消控制器
const abortController = new AbortControllerImpl();

// 发起请求
const requestPromise = HttpClient.get(url, {
  abortController,
  timeout: 30000
});

// 取消请求
abortController.abort('用户取消');

// 或取消所有请求
HttpClient.abortAll();
```

---

## 数据库模块 API

### BookRepository

#### insert - 插入书籍

```typescript
import { BookRepository } from '../utils/database/BookRepository';

const repo = BookRepository.getInstance();

const book: Book = {
  id: generateId(),
  name: '示例书籍',
  author: '示例作者',
  bookSourceId: 'source-1',
  bookSourceName: '示例书源',
  bookUrl: 'https://example.com/book/1',
  chapterCount: 100,
  wordCount: 1000000,
  status: 'ongoing',
  createTime: Date.now(),
  updateTime: Date.now()
};

const success = await repo.insert(book);
```

#### queryById - 查询书籍

```typescript
const book = await repo.queryById('book-id');

if (book) {
  console.log(`书名: ${book.name}`);
}
```

#### search - 搜索书籍

```typescript
const books = await repo.search('关键词');

books.forEach(book => {
  console.log(`${book.name} - ${book.author}`);
});
```

### BookSourceRepository

#### queryEnabled - 查询启用的书源

```typescript
import { BookSourceRepository } from '../utils/database/BookSourceRepository';

const repo = BookSourceRepository.getInstance();
const sources = await repo.queryEnabled();

sources.forEach(source => {
  console.log(`${source.name}: ${source.url}`);
});
```

#### toggleEnabled - 切换启用状态

```typescript
const success = await repo.toggleEnabled('source-id', false);
```

---

## 错误码

### 通用错误码 (00xxx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00000 | 成功 | - |
| 00001 | 未知错误 | 检查日志，联系开发者 |
| 00002 | 操作超时 | 增加超时时间或重试 |
| 00003 | 内存不足 | 清理缓存或重启应用 |

### 参数错误 (001xx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00101 | 参数缺失 | 检查必填参数 |
| 00102 | 参数格式错误 | 检查参数类型和格式 |
| 00103 | 参数值无效 | 检查参数取值范围 |
| 00104 | 参数长度超限 | 缩短参数值长度 |

### 权限错误 (002xx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00201 | 未授权访问 | 先进行登录认证 |
| 00202 | 权限不足 | 联系管理员获取权限 |
| 00203 | Token 过期 | 重新获取 Token |

### 资源错误 (003xx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00301 | 资源不存在 | 检查资源 ID 是否正确 |
| 00302 | 资源已存在 | 使用更新接口或更换 ID |
| 00303 | 资源已删除 | 无法恢复，需重新创建 |

### 网络错误 (005xx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00501 | 网络请求失败 | 检查网络连接 |
| 00502 | 网络超时 | 增加超时时间或重试 |
| 00503 | SSL 证书错误 | 检查证书配置 |
| 00504 | 请求被取消 | 正常行为，无需处理 |
| 00505 | 响应数据过大 | 增加 maxResponseSize |

### 数据库错误 (006xx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00601 | 数据库操作失败 | 检查数据格式和约束 |
| 00602 | 数据库连接失败 | 检查数据库配置 |
| 00603 | 数据库事务失败 | 重试操作 |

### 解析器错误 (007xx)

| 错误码 | 描述 | 解决方案 |
|-------|------|---------|
| 00701 | 解析失败 | 检查内容格式 |
| 00702 | 不支持的类型 | 使用支持的解析类型 |
| 00703 | 内容为空 | 提供有效内容 |
| 00704 | 深度超限 | 增加 maxDepth 参数 |
| 00705 | 编码错误 | 指定正确的编码 |

---

## 使用示例

### 场景一：搜索并添加书籍

```typescript
import HttpClient from '../network/HttpClient';
import ParserFacade, { ParserType } from '../core/ParserFacade';
import { BookRepository } from '../utils/database/BookRepository';
import { BookSourceRepository } from '../utils/database/BookSourceRepository';

async function searchAndAddBook(keyword: string): Promise<Book | null> {
  // 1. 获取启用的书源
  const sourceRepo = BookSourceRepository.getInstance();
  const sources = await sourceRepo.queryEnabled();

  if (sources.length === 0) {
    throw new Error('没有可用的书源');
  }

  // 2. 使用第一个书源搜索
  const source = sources[0];
  const searchUrl = source.searchUrl?.replace('{{key}}', encodeURIComponent(keyword));

  if (!searchUrl) {
    throw new Error('书源搜索 URL 配置错误');
  }

  // 3. 发送搜索请求
  const response = await HttpClient.get(searchUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0 ...',
      'Referer': source.url
    },
    timeout: 10000,
    retry: { maxRetries: 2 }
  });

  // 4. 解析搜索结果
  const parseResult = await ParserFacade.parse(response.data, ParserType.HTML);

  if (parseResult.status !== 'success') {
    throw new Error('解析搜索结果失败');
  }

  // 5. 提取书籍信息
  const bookInfo = extractBookInfo(parseResult.data, source);

  // 6. 保存到数据库
  const bookRepo = BookRepository.getInstance();
  await bookRepo.insert(bookInfo);

  return bookInfo;
}
```

### 场景二：批量导入书源

```typescript
import ParserFacade, { ParserType } from '../core/ParserFacade';
import { BookSourceRepository } from '../utils/database/BookSourceRepository';

async function importBookSources(jsonContent: string): Promise<number> {
  // 1. 解析 JSON
  const result = await ParserFacade.parseJSON(jsonContent);

  if (result.status !== 'success') {
    throw new Error('JSON 格式错误');
  }

  const sources = Array.isArray(result.data) ? result.data : [result.data];

  // 2. 验证书源格式
  const validSources = sources.filter(validateSource);

  // 3. 批量插入
  const repo = BookSourceRepository.getInstance();
  let count = 0;

  for (const source of validSources) {
    try {
      await repo.insert(source);
      count++;
    } catch (error) {
      console.warn(`导入书源失败: ${source.name}`, error);
    }
  }

  return count;
}

function validateSource(source: any): boolean {
  return source &&
    typeof source.name === 'string' &&
    typeof source.url === 'string';
}
```

### 场景三：阅读章节内容

```typescript
import HttpClient from '../network/HttpClient';
import ParserFacade, { ParserType } from '../core/ParserFacade';
import { ChapterRepository } from '../utils/database/ChapterRepository';

async function readChapter(chapterId: string): Promise<string> {
  const chapterRepo = ChapterRepository.getInstance();
  const chapter = await chapterRepo.queryById(chapterId);

  if (!chapter) {
    throw new Error('章节不存在');
  }

  // 检查是否已缓存内容
  if (chapter.content) {
    return chapter.content;
  }

  // 发送请求获取内容
  const response = await HttpClient.get(chapter.url, {
    cache: { enabled: true, ttl: 3600000 }  // 缓存 1 小时
  });

  // 解析内容
  const parseResult = await ParserFacade.parse(response.data, ParserType.HTML);
  const content = extractContent(parseResult.data);

  // 更新章节内容
  await chapterRepo.update(chapterId, {
    content,
    wordCount: content.length
  });

  return content;
}
```

### 场景四：带缓存的搜索

```typescript
import HttpClient from '../network/HttpClient';

async function cachedSearch(keyword: string): Promise<any> {
  const cacheKey = `search_${keyword}`;

  const response = await HttpClient.get('/api/search', {
    params: { q: keyword },
    cache: {
      enabled: true,
      key: cacheKey,
      ttl: 5 * 60 * 1000  // 5 分钟
    }
  });

  return response.data;
}
```

---

## 变更日志

### [1.0.0] - 2026-02-17

#### 新增
- 新增 ParserFacade 统一解析器接口
- 新增 HttpClient 统一网络请求接口
- 新增测试框架和测试套件
- 新增 API 文档规范

#### 变更
- 重构数据库模块接口
- 优化错误码体系

---

> 文档版本: v1.0.0  
> 最后更新: 2026-02-17  
> 维护者: AstroRead Team
