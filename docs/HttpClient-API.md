# HttpClient API 文档

> 统一网络请求解决方案 - 支持 RESTful API、拦截器、缓存、重试、取消等

## 目录

- [快速开始](#快速开始)
- [核心接口](#核心接口)
- [请求配置](#请求配置)
- [拦截器](#拦截器)
- [错误处理](#错误处理)
- [缓存机制](#缓存机制)
- [重试策略](#重试策略)
- [请求取消](#请求取消)
- [高级用法](#高级用法)
- [最佳实践](#最佳实践)

---

## 快速开始

### 基本使用

```typescript
import HttpClient, { HttpMethod } from '../network/HttpClient';

// GET 请求
const response = await HttpClient.get('https://api.example.com/users');
console.log(response.data);     // 响应数据
console.log(response.status);   // 状态码
console.log(response.headers);  // 响应头

// POST 请求
const createResponse = await HttpClient.post('https://api.example.com/users', {
  name: '张三',
  age: 25
});

// PUT 请求
const updateResponse = await HttpClient.put('https://api.example.com/users/1', {
  name: '李四'
});

// DELETE 请求
const deleteResponse = await HttpClient.delete('https://api.example.com/users/1');
```

### 自定义配置

```typescript
import { createHttpClient } from '../network';

const client = createHttpClient({
  baseURL: 'https://api.example.com',
  timeout: 10000,
  headers: {
    'Authorization': 'Bearer token',
    'Content-Type': 'application/json'
  }
});

// 所有请求都会使用 baseURL 前缀
const response = await client.get('/users');  // 实际请求 https://api.example.com/users
```

---

## 核心接口

### IHttpClient 接口

```typescript
interface IHttpClient {
  // 基本请求方法
  request<T>(config: HttpRequestConfig): Promise<HttpResponse<T>>;
  get<T>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  post<T>(url: string, data?: unknown, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  put<T>(url: string, data?: unknown, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  delete<T>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  patch<T>(url: string, data?: unknown, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  head<T>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;
  options<T>(url: string, config?: HttpRequestConfig): Promise<HttpResponse<T>>;

  // 拦截器管理
  addRequestInterceptor(interceptor: RequestInterceptor): string;
  addResponseInterceptor(interceptor: ResponseInterceptor): string;
  removeRequestInterceptor(id: string): boolean;
  removeResponseInterceptor(id: string): boolean;

  // 配置管理
  setDefaultHeader(key: string, value: string): void;
  removeDefaultHeader(key: string): void;
  setBaseURL(url: string): void;
  setDefaultConfig(config: Partial<HttpClientConfig>): void;

  // 缓存管理
  clearCache(): void;
  getCacheStats(): CacheStats;

  // 监控
  getMetrics(): RequestMetrics[];
  clearMetrics(): void;

  // 取消请求
  abort(requestId: string): boolean;
  abortAll(): void;

  // 销毁
  destroy(): void;
}
```

### HttpResponse 响应

```typescript
interface HttpResponse<T = unknown> {
  data: T;                    // 响应数据
  status: number;             // HTTP 状态码
  statusText: string;         // 状态文本
  headers: HttpHeaders;       // 响应头
  config: HttpRequestConfig;  // 请求配置
  duration: number;           // 请求耗时（毫秒）
  cached: boolean;            // 是否来自缓存
  retries: number;            // 重试次数
}
```

---

## 请求配置

### HttpRequestConfig

```typescript
interface HttpRequestConfig {
  url: string;                              // 请求 URL（必填）
  method?: HttpMethod | string;             // 请求方法，默认 GET
  headers?: HttpHeaders | HttpHeaderMap;    // 请求头
  params?: Record<string, string | number | boolean> | URLSearchParams;  // URL 参数
  data?: string | object | ArrayBuffer | FormData;  // 请求体
  body?: string | object | ArrayBuffer;     // 请求体（同 data）
  timeout?: number;                         // 总超时时间（毫秒）
  connectTimeout?: number;                  // 连接超时（毫秒）
  readTimeout?: number;                     // 读取超时（毫秒）
  responseType?: { type: 'text' | 'json' | 'arraybuffer' | 'blob' };
  encoding?: string;                        // 字符编码
  charset?: string;                         // 字符集
  withCredentials?: boolean;                // 是否携带凭证
  maxRedirects?: number;                    // 最大重定向次数
  maxResponseSize?: number;                 // 最大响应大小（字节）
  validateStatus?: (status: number) => boolean;  // 状态码验证
  signal?: AbortSignal;                     // 取消信号
  abortController?: AbortController;        // 取消控制器
  cache?: RequestCacheConfig;               // 缓存配置
  retry?: RetryConfig;                      // 重试配置
  metadata?: Record<string, unknown>;       // 自定义元数据
}
```

### 使用示例

```typescript
// 完整配置示例
const response = await HttpClient.request({
  url: 'https://api.example.com/users',
  method: HttpMethod.POST,
  headers: {
    'Authorization': 'Bearer token',
    'Content-Type': 'application/json'
  },
  params: {
    page: 1,
    size: 20
  },
  data: {
    name: '张三',
    age: 25
  },
  timeout: 10000,
  responseType: { type: 'json' },
  cache: {
    enabled: true,
    ttl: 60000
  },
  retry: {
    maxRetries: 3,
    retryDelay: 1000
  }
});
```

---

## 拦截器

### 请求拦截器

```typescript
// 添加请求拦截器
const interceptorId = HttpClient.addRequestInterceptor({
  id: 'auth-interceptor',
  priority: 10,
  onRequest: (config) => {
    // 在请求发送前修改配置
    config.headers = {
      ...config.headers,
      'Authorization': `Bearer ${getToken()}`
    };
    return config;
  },
  onRequestError: (error) => {
    // 处理请求错误
    console.error('Request error:', error);
    return error;
  }
});

// 移除拦截器
HttpClient.removeRequestInterceptor(interceptorId);
```

### 响应拦截器

```typescript
// 添加响应拦截器
const responseInterceptorId = HttpClient.addResponseInterceptor({
  id: 'response-logger',
  priority: 10,
  onResponse: (response) => {
    // 处理响应数据
    console.log(`Response: ${response.status} ${response.config.url}`);
    return response;
  },
  onResponseError: (error) => {
    // 处理响应错误
    if (error.status === 401) {
      // Token 过期，跳转登录
      redirectToLogin();
    }
    return error;
  }
});
```

### 拦截器优先级

拦截器按优先级从小到大执行：
- 请求拦截器：priority 小的先执行
- 响应拦截器：priority 小的先执行

```typescript
// 认证拦截器（优先执行）
HttpClient.addRequestInterceptor({
  id: 'auth',
  priority: 1,
  onRequest: (config) => {
    config.headers['Authorization'] = `Bearer ${getToken()}`;
    return config;
  }
});

// 日志拦截器（后执行）
HttpClient.addRequestInterceptor({
  id: 'logger',
  priority: 100,
  onRequest: (config) => {
    console.log(`Request: ${config.method} ${config.url}`);
    return config;
  }
});
```

---

## 错误处理

### HttpError 类型

```typescript
interface HttpError extends Error {
  code: HttpErrorCode;       // 错误码
  message: string;           // 错误消息
  status?: number;           // HTTP 状态码
  statusText?: string;       // 状态文本
  headers?: HttpHeaders;     // 响应头
  config?: HttpRequestConfig; // 请求配置
  response?: HttpResponse;   // 响应对象
  isRetryable: boolean;      // 是否可重试
  timestamp: number;         // 时间戳
}

enum HttpErrorCode {
  UNKNOWN = 'UNKNOWN',
  TIMEOUT = 'TIMEOUT',
  NETWORK_ERROR = 'NETWORK_ERROR',
  CONNECTION_ERROR = 'CONNECTION_ERROR',
  SSL_ERROR = 'SSL_ERROR',
  ABORTED = 'ABORTED',
  INVALID_URL = 'INVALID_URL',
  INVALID_RESPONSE = 'INVALID_RESPONSE',
  PARSE_ERROR = 'PARSE_ERROR',
  TOO_LARGE = 'TOO_LARGE',
  HTTP_ERROR = 'HTTP_ERROR',
  REDIRECT_ERROR = 'REDIRECT_ERROR',
  CACHE_ERROR = 'CACHE_ERROR',
  CANCELLED = 'CANCELLED'
}
```

### 错误处理示例

```typescript
import { HttpErrorImpl, HttpErrorCode } from '../network';

try {
  const response = await HttpClient.get('https://api.example.com/users');
  console.log(response.data);
} catch (error) {
  if (error instanceof HttpErrorImpl) {
    switch (error.code) {
      case HttpErrorCode.TIMEOUT:
        console.error('请求超时');
        break;
      case HttpErrorCode.NETWORK_ERROR:
        console.error('网络错误');
        break;
      case HttpErrorCode.HTTP_ERROR:
        if (error.status === 401) {
          console.error('未授权，请登录');
        } else if (error.status === 404) {
          console.error('资源不存在');
        } else if (error.status === 500) {
          console.error('服务器错误');
        }
        break;
      default:
        console.error(`请求失败: ${error.message}`);
    }

    // 检查是否可重试
    if (error.isRetryable) {
      console.log('此错误可以重试');
    }
  }
}
```

---

## 缓存机制

### 缓存配置

```typescript
interface RequestCacheConfig {
  enabled: boolean;          // 是否启用缓存
  ttl?: number;              // 缓存时间（毫秒）
  key?: string;              // 自定义缓存键
  forceRefresh?: boolean;    // 强制刷新
  cacheMethod?: 'memory' | 'disk' | 'both';
}
```

### 使用示例

```typescript
// 启用缓存（默认配置）
const response = await HttpClient.get('https://api.example.com/users', {
  cache: {
    enabled: true,
    ttl: 5 * 60 * 1000  // 5 分钟
  }
});

// 自定义缓存键
const response = await HttpClient.get('https://api.example.com/users', {
  cache: {
    enabled: true,
    key: 'users-list-cache'
  }
});

// 强制刷新
const response = await HttpClient.get('https://api.example.com/users', {
  cache: {
    enabled: true,
    forceRefresh: true
  }
});

// 检查是否来自缓存
if (response.cached) {
  console.log('数据来自缓存');
}

// 获取缓存统计
const stats = HttpClient.getCacheStats();
console.log(`缓存命中率: ${stats.hitRate * 100}%`);
console.log(`缓存大小: ${stats.size}/${stats.maxSize}`);

// 清除缓存
HttpClient.clearCache();
```

---

## 重试策略

### 重试配置

```typescript
interface RetryConfig {
  maxRetries: number;        // 最大重试次数
  retryDelay?: number;       // 基础重试延迟（毫秒）
  retryDelayMultiplier?: number;  // 延迟倍数（指数退避）
  maxRetryDelay?: number;    // 最大延迟（毫秒）
  retryableStatusCodes?: number[];  // 可重试的状态码
  retryableErrors?: string[];       // 可重试的错误
  onRetry?: (attempt: number, error: Error, config: HttpRequestConfig) => boolean | Promise<boolean>;
}
```

### 使用示例

```typescript
// 基本重试配置
const response = await HttpClient.get('https://api.example.com/users', {
  retry: {
    maxRetries: 3,
    retryDelay: 1000,
    retryDelayMultiplier: 2,
    maxRetryDelay: 10000
  }
});

// 自定义重试条件
const response = await HttpClient.get('https://api.example.com/users', {
  retry: {
    maxRetries: 5,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504],
    onRetry: (attempt, error, config) => {
      console.log(`第 ${attempt} 次重试: ${error.message}`);
      return true;  // 返回 false 停止重试
    }
  }
});

// 查看重试次数
console.log(`请求重试了 ${response.retries} 次`);
```

---

## 请求取消

### 使用 AbortController

```typescript
import { AbortControllerImpl } from '../network';

// 创建取消控制器
const abortController = new AbortControllerImpl();

// 发起请求
const requestPromise = HttpClient.get('https://api.example.com/users', {
  abortController,
  timeout: 30000
});

// 取消请求
setTimeout(() => {
  abortController.abort('用户取消了请求');
}, 5000);

try {
  const response = await requestPromise;
} catch (error) {
  if (error.code === 'ABORTED') {
    console.log('请求被取消');
  }
}
```

### 使用 AbortManager

```typescript
import AbortManager from '../network/AbortController';

// 通过标签管理多个请求
const requestId1 = 'search-request-1';
const requestId2 = 'search-request-2';

// 创建带标签的控制器
AbortManager.getInstance().createController(requestId1, 30000);
AbortManager.getInstance().tagRequest(requestId1, 'search');

AbortManager.getInstance().createController(requestId2, 30000);
AbortManager.getInstance().tagRequest(requestId2, 'search');

// 取消所有带 'search' 标签的请求
AbortManager.getInstance().abortByTag('search');

// 取消所有请求
AbortManager.getInstance().abortAll();

// 获取活跃请求数量
const activeCount = AbortManager.getInstance().getActiveCount();
console.log(`当前有 ${activeCount} 个活跃请求`);
```

---

## 高级用法

### 批量请求

```typescript
// 并发请求
const [users, posts, comments] = await Promise.all([
  HttpClient.get('https://api.example.com/users'),
  HttpClient.get('https://api.example.com/posts'),
  HttpClient.get('https://api.example.com/comments')
]);

// 顺序请求
for (const userId of userIds) {
  const user = await HttpClient.get(`https://api.example.com/users/${userId}`);
  console.log(user.data.name);
}
```

### 请求监控

```typescript
// 获取请求指标
const metrics = HttpClient.getMetrics();

metrics.forEach(m => {
  console.log(`${m.method} ${m.url}`);
  console.log(`  状态: ${m.status}`);
  console.log(`  耗时: ${m.duration}ms`);
  console.log(`  缓存: ${m.cached ? '是' : '否'}`);
  console.log(`  重试: ${m.retries} 次`);
});

// 清除指标
HttpClient.clearMetrics();
```

### 文件上传

```typescript
// 上传 JSON 数据
const response = await HttpClient.post('https://api.example.com/upload', {
  name: 'file.txt',
  content: '文件内容'
});

// 上传 ArrayBuffer
const buffer = new ArrayBuffer(1024);
const response = await HttpClient.post('https://api.example.com/upload', buffer, {
  headers: {
    'Content-Type': 'application/octet-stream'
  }
});
```

### 自定义状态码验证

```typescript
// 将 404 视为成功
const response = await HttpClient.get('https://api.example.com/users', {
  validateStatus: (status) => status >= 200 && status < 500
});
```

---

## 最佳实践

### 1. 使用单例模式

```typescript
// ✅ 推荐：使用单例
import HttpClient from '../network/HttpClient';

const response = await HttpClient.get('/api/users');

// ❌ 不推荐：每次创建新实例
const client = new HttpClient();
```

### 2. 统一错误处理

```typescript
// ✅ 推荐：使用拦截器统一处理
HttpClient.addResponseInterceptor({
  id: 'error-handler',
  priority: 1,
  onResponseError: (error) => {
    if (error.status === 401) {
      // 统一处理 401
      redirectToLogin();
    }
    return error;
  }
});
```

### 3. 合理使用缓存

```typescript
// ✅ 推荐：对不常变化的数据使用缓存
const response = await HttpClient.get('/api/config', {
  cache: { enabled: true, ttl: 10 * 60 * 1000 }
});

// ❌ 不推荐：对实时数据使用缓存
const response = await HttpClient.get('/api/realtime-data', {
  cache: { enabled: true }  // 实时数据不应缓存
});
```

### 4. 设置合理的超时

```typescript
// ✅ 推荐：根据请求类型设置超时
const quickResponse = await HttpClient.get('/api/status', {
  timeout: 5000  // 快速请求
});

const slowResponse = await HttpClient.post('/api/report', data, {
  timeout: 60000  // 耗时操作
});
```

### 5. 及时清理资源

```typescript
// ✅ 推荐：在组件销毁时取消请求
onDestroy(() => {
  HttpClient.abortAll();
});
```

---

## API 参考

### HttpClient 方法

| 方法 | 说明 | 返回类型 |
|------|------|---------|
| `request(config)` | 发送请求 | `Promise<HttpResponse<T>>` |
| `get(url, config?)` | GET 请求 | `Promise<HttpResponse<T>>` |
| `post(url, data?, config?)` | POST 请求 | `Promise<HttpResponse<T>>` |
| `put(url, data?, config?)` | PUT 请求 | `Promise<HttpResponse<T>>` |
| `delete(url, config?)` | DELETE 请求 | `Promise<HttpResponse<T>>` |
| `patch(url, data?, config?)` | PATCH 请求 | `Promise<HttpResponse<T>>` |
| `head(url, config?)` | HEAD 请求 | `Promise<HttpResponse<T>>` |
| `options(url, config?)` | OPTIONS 请求 | `Promise<HttpResponse<T>>` |
| `addRequestInterceptor(interceptor)` | 添加请求拦截器 | `string` |
| `addResponseInterceptor(interceptor)` | 添加响应拦截器 | `string` |
| `removeRequestInterceptor(id)` | 移除请求拦截器 | `boolean` |
| `removeResponseInterceptor(id)` | 移除响应拦截器 | `boolean` |
| `setDefaultHeader(key, value)` | 设置默认请求头 | `void` |
| `removeDefaultHeader(key)` | 移除默认请求头 | `void` |
| `setBaseURL(url)` | 设置基础 URL | `void` |
| `clearCache()` | 清除缓存 | `void` |
| `getCacheStats()` | 获取缓存统计 | `CacheStats` |
| `getMetrics()` | 获取请求指标 | `RequestMetrics[]` |
| `abort(requestId)` | 取消指定请求 | `boolean` |
| `abortAll()` | 取消所有请求 | `void` |
| `destroy()` | 销毁客户端 | `void` |

---

> 文档版本: v1.0.0  
> 最后更新: 2026-02-17
