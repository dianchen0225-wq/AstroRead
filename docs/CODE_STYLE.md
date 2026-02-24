# AstroRead 代码风格指南

## 目录
1. [命名规范](#命名规范)
2. [文件组织](#文件组织)
3. [类型定义](#类型定义)
4. [函数规范](#函数规范)
5. [类与接口](#类与接口)
6. [错误处理](#错误处理)
7. [注释规范](#注释规范)
8. [最佳实践](#最佳实践)

---

## 命名规范

### 变量与参数
- 使用 **camelCase**（小驼峰）
- 布尔值以 `is`、`has`、`should`、`can` 开头

```typescript
// 正确
const bookList: Book[] = []
const isLoading: boolean = false
const hasMore: boolean = true

// 错误
const book_list = []
const loading = false
const HasMore = true
```

### 常量
- 使用 **UPPER_SNAKE_CASE**（全大写下划线分隔）
- 模块级常量必须使用此格式

```typescript
// 正确
const MAX_RETRY_COUNT = 3
const DEFAULT_TIMEOUT = 10000
const API_BASE_URL = 'https://api.example.com'

// 错误
const maxRetryCount = 3
const defaultTimeout = 10000
```

### 函数与方法
- 使用 **camelCase**
- 名称应为动词或动词短语

```typescript
// 正确
function fetchBookList(): Promise<Book[]> { }
function calculateTotalPrice(): number { }
function isBookAvailable(): boolean { }

// 错误
function bookList(): Promise<Book[]> { }
function BookList(): Promise<Book[]> { }
```

### 类与接口
- 使用 **PascalCase**（大驼峰）
- 接口**不使用** `I` 前缀
- 实现类**不使用** `Impl` 后缀

```typescript
// 正确
class HttpClient { }
interface HttpClient { }
class NetworkManager { }

// 错误
class HTTPClient { }
interface IHttpClient { }
class HttpClientImpl { }
```

### 枚举
- 枚举名使用 **PascalCase**
- 枚举值使用 **UPPER_SNAKE_CASE**

```typescript
// 正确
enum ErrorCode {
  NETWORK_ERROR = 100,
  PARSE_ERROR = 200,
  DATABASE_ERROR = 300
}

// 错误
enum errorCode {
  networkError = 100,
  ParseError = 200
}
```

### 私有成员
- 使用下划线 `_` 前缀

```typescript
class BookManager {
  private _instance: BookManager | null = null
  private _bookList: Book[] = []

  private _validateBook(book: Book): boolean { }
}
```

---

## 文件组织

### 目录结构
```
entry/src/main/ets/
├── common/          # 公共组件（导航、主题）
├── components/      # UI 组件
├── core/            # 核心模块（解析器、错误处理）
├── interfaces/      # 接口定义
├── models/          # 数据模型
├── network/         # 网络模块
├── pages/           # 页面
├── styles/          # 样式
├── utils/           # 工具类
│   └── database/    # 数据库相关
└── viewmodel/       # 视图模型
```

### 文件命名
- 使用 **PascalCase** 命名文件
- 文件名与导出的主要类名一致

```
// 正确
HttpClient.ets      -> class HttpClient
BookManager.ets     -> class BookManager
NetworkConfig.ets   -> class NetworkConfig

// 错误
http-client.ets
book_manager.ets
networkconfig.ets
```

### 导入顺序
1. 标准库
2. 第三方库
3. 项目内部模块
4. 类型导入

```typescript
// 1. 标准库
import http from '@ohos.net.http'
import relationalStore from '@ohos.data.relationalStore'

// 2. 第三方库
// (无)

// 3. 项目内部模块
import { Book } from '../models/Book'
import { Logger } from '../utils/Logger'
import { NetworkManager } from './NetworkManager'

// 4. 类型导入
import type { BookSource } from '../models/BookSource'
```

---

## 类型定义

### 显式类型注解
- 函数参数和返回值必须有类型注解
- 变量声明时类型可推断则省略

```typescript
// 正确
function fetchBook(id: string): Promise<Book | null> { }
const books: Book[] = []
const count = 10  // 类型可推断

// 错误
function fetchBook(id, options) { }
const books = []  // 类型不可推断
```

### 避免 any
- 禁止使用 `any` 类型
- 使用 `unknown` 或具体类型

```typescript
// 正确
function parseJson(text: string): unknown {
  return JSON.parse(text)
}

// 错误
function parseJson(text: string): any {
  return JSON.parse(text)
}
```

### 联合类型 vs 枚举
- 有限已知值使用枚举
- 开放值使用联合类型

```typescript
// 正确 - 有限值
enum BookStatus {
  READING = 'reading',
  FINISHED = 'finished',
  DROPPED = 'dropped'
}

// 正确 - 开放值
type ThemeMode = 'light' | 'dark' | 'auto'
```

---

## 函数规范

### 函数长度
- 单个函数不超过 **50 行**
- 超过时应拆分为多个小函数

### 参数数量
- 参数不超过 **4 个**
- 超过时使用配置对象

```typescript
// 正确
interface SearchOptions {
  keyword: string
  page?: number
  pageSize?: number
  timeout?: number
}

function searchBooks(options: SearchOptions): Promise<Book[]> { }

// 错误
function searchBooks(
  keyword: string,
  page: number,
  pageSize: number,
  timeout: number,
  retryCount: number
): Promise<Book[]> { }
```

### 纯函数优先
- 避免副作用
- 返回新对象而非修改原对象

```typescript
// 正确
function addBook(books: Book[], newBook: Book): Book[] {
  return [...books, newBook]
}

// 错误
function addBook(books: Book[], newBook: Book): void {
  books.push(newBook)
}
```

---

## 类与接口

### 单例模式
- 使用 `getInstance()` 静态方法
- 私有构造函数

```typescript
export class NetworkManager {
  private static instance: NetworkManager | null = null

  private constructor() { }

  static getInstance(): NetworkManager {
    if (!NetworkManager.instance) {
      NetworkManager.instance = new NetworkManager()
    }
    return NetworkManager.instance
  }
}
```

### 依赖注入
- 通过构造函数注入依赖
- 避免在类内部直接创建依赖

```typescript
// 正确
class BookSourceSearchEngine {
  constructor(
    private networkAdapter: NetworkAdapter,
    private htmlParser: HTMLParser
  ) { }
}

// 错误
class BookSourceSearchEngine {
  private networkAdapter = NetworkAdapter.getInstance()
  private htmlParser = HTMLParser.getInstance()
}
```

### 接口分离
- 接口应小而专注
- 遵循接口隔离原则

```typescript
// 正确
interface IReader {
  read(): Promise<string>
}

interface IWriter {
  write(content: string): Promise<void>
}

interface IReadWrite extends IReader, IWriter { }

// 错误
interface IFileHandler {
  read(): Promise<string>
  write(content: string): Promise<void>
  delete(): Promise<void>
  copy(dest: string): Promise<void>
  // ... 太多方法
}
```

---

## 错误处理

### 使用 Result<T> 模式
- 避免抛出异常
- 使用 `Result<T>` 返回结果

```typescript
// 正确
async function fetchBook(id: string): Promise<Result<Book>> {
  try {
    const response = await httpClient.get(`/books/${id}`)
    return Result.ok(response.data)
  } catch (error) {
    return Result.err(ErrorCode.NETWORK_ERROR, error.message)
  }
}

// 错误
async function fetchBook(id: string): Promise<Book> {
  const response = await httpClient.get(`/books/${id}`)
  if (!response.ok) {
    throw new Error('Failed to fetch book')
  }
  return response.data
}
```

### 错误分类
- 使用 `ErrorCode` 枚举
- 使用 `ErrorFactory` 创建错误

```typescript
// 正确
return Result.err(
  ErrorFactory.network('Connection timeout', {
    sourceId: source.id,
    retryCount: 2
  })
)

// 错误
return Result.err(ErrorCode.NETWORK_ERROR, 'Error')
```

---

## 注释规范

### 文件头注释
```typescript
/**
 * NetworkManager - 网络请求管理器
 * 负责HTTP请求的发送、重试、缓存等功能
 */
```

### 函数注释
```typescript
/**
 * 搜索书籍
 * @param keyword 搜索关键词
 * @param options 搜索选项
 * @returns 搜索结果列表
 * @throws {NetworkError} 网络请求失败时抛出
 */
async searchBooks(keyword: string, options?: SearchOptions): Promise<Book[]> { }
```

### 复杂逻辑注释
```typescript
// 计算指数退避延迟时间
// 公式: baseDelay * 2^attempt + randomJitter
const delay = this.calculateBackoffDelay(attempt, baseDelay, maxDelay)
```

### TODO 注释
```typescript
// TODO: 实现请求缓存机制
// FIXME: 处理并发请求时的竞态条件
// HACK: 临时解决方案，需要重构
```

---

## 最佳实践

### 避免魔法数字
```typescript
// 正确
const MAX_RETRY_COUNT = 3
const DEFAULT_TIMEOUT_MS = 10000

for (let i = 0; i < MAX_RETRY_COUNT; i++) { }

// 错误
for (let i = 0; i < 3; i++) { }
```

### 使用可选链
```typescript
// 正确
const name = book?.author?.name

// 错误
const name = book && book.author && book.author.name
```

### 使用空值合并
```typescript
// 正确
const pageSize = options.pageSize ?? 20

// 错误
const pageSize = options.pageSize ? options.pageSize : 20
```

### 异步操作
- 所有耗时操作使用 async/await
- 避免在主线程执行耗时操作

```typescript
// 正确
async function loadBooks(): Promise<Book[]> {
  const books = await databaseManager.getAllBooks()
  return books
}

// 错误
function loadBooks(): Book[] {
  return databaseManager.getAllBooksSync()  // 阻塞主线程
}
```

### 资源释放
- 使用 try-finally 确保资源释放

```typescript
// 正确
const httpRequest = http.createHttp()
try {
  const response = await httpRequest.request(url, options)
  return response
} finally {
  httpRequest.destroy()
}
```

---

## 检查清单

在提交代码前，请确保：

- [ ] 所有变量和函数使用正确的命名规范
- [ ] 没有使用 `any` 类型
- [ ] 函数参数不超过 4 个
- [ ] 函数长度不超过 50 行
- [ ] 使用 `Result<T>` 处理错误
- [ ] 添加了必要的注释
- [ ] 没有魔法数字
- [ ] 资源正确释放
- [ ] 异步操作使用 async/await
