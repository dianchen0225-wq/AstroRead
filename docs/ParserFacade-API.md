# ParserFacade API 文档

> 统一解析器接口层 - 支持 JSON、XML、HTML、CSV 等多种格式

## 目录

- [快速开始](#快速开始)
- [核心接口](#核心接口)
- [适配器详解](#适配器详解)
- [错误处理](#错误处理)
- [缓存机制](#缓存机制)
- [高级用法](#高级用法)
- [最佳实践](#最佳实践)

---

## 快速开始

### 基本使用

```typescript
import ParserFacade, { ParserType } from '../core/ParserFacade';

// 获取单例实例
const parser = ParserFacade.getInstance();

// 自动检测类型并解析
const result = await parser.parse('{"name": "张三", "age": 25}');
console.log(result.data); // { name: "张三", age: 25 }

// 指定类型解析
const jsonResult = await parser.parseJSON('{"key": "value"}');
const xmlResult = await parser.parseXML('<root><item>text</item></root>');
const htmlResult = await parser.parseHTML('<div class="content">Hello</div>');
const csvResult = await parser.parseCSV('name,age\n张三,25\n李四,30');
```

### 同步解析

```typescript
// 同步解析（适用于小数据量）
const result = parser.parseSync('{"name": "张三"}', ParserType.JSON);
console.log(result.data);
```

---

## 核心接口

### IParser 接口

```typescript
interface IParser<T = unknown, R = ParseResult<T>> {
  // 解析器类型
  readonly type: ParserType;
  // 版本号
  readonly version: string;
  // 支持的文件扩展名
  readonly supportedExtensions: string[];

  // 异步解析
  parse(content: string | ArrayBuffer, options?: ParseOptions): Promise<R>;
  
  // 同步解析
  parseSync(content: string | ArrayBuffer, options?: ParseOptions): R;
  
  // 验证内容
  validate(content: string | ArrayBuffer, options?: ParseOptions): ValidationResult;
  
  // 格式化输出
  format(data: T, options?: FormatOptions): string;
  
  // 检测是否可解析
  canParse(content: string | ArrayBuffer, hint?: string): boolean;
}
```

### ParseOptions 配置

```typescript
interface ParseOptions {
  // 字符编码
  encoding?: string;           // 默认: 'utf-8'
  
  // 严格模式
  strict?: boolean;            // 默认: false
  
  // 最大嵌套深度
  maxDepth?: number;           // 默认: 100
  
  // 超时时间（毫秒）
  timeout?: number;            // 默认: 30000
  
  // 缓存键
  cacheKey?: string;
  
  // 跳过缓存
  skipCache?: boolean;         // 默认: false
  
  // 自定义规则
  customRules?: Record<string, unknown>;
}
```

### ParseResult 结果

```typescript
interface ParseResult<T = unknown> {
  // 解析后的数据
  data: T;
  
  // 解析状态
  status: ParseStatus;         // 'success' | 'partial' | 'failed' | 'pending'
  
  // 错误信息
  errors: ParseErrorInfo[];
  
  // 警告信息
  warnings: ParseWarningInfo[];
  
  // 元数据
  metadata: ParseMetadata;
  
  // 原始内容
  raw?: string;
}
```

---

## 适配器详解

### JSONParserAdapter

支持标准 JSON、带注释 JSON、宽松 JSON 格式。

```typescript
import { JSONParserAdapter } from '../core/adapters/JSONParserAdapter';

const jsonParser = new JSONParserAdapter();

// 解析带注释的 JSON
const result = await jsonParser.parse(`
{
  // 这是注释
  "name": "张三",
  "age": 25,  // 支持尾随逗号
}
`);

// JSONPath 查询
const data = { users: [{ name: '张三' }, { name: '李四' }] };
const name = jsonParser.query(data, '$.users[0].name');  // "张三"

// 设置值
const modified = jsonParser.set(data, '$.users[0].name', '王五');

// 格式化输出
const formatted = jsonParser.format(data, { indent: 2 });
```

### XMLParserAdapter

支持标准 XML、带命名空间 XML。

```typescript
import { XMLParserAdapter } from '../core/adapters/XMLParserAdapter';

const xmlParser = new XMLParserAdapter();

const result = await xmlParser.parse(`
<?xml version="1.0"?>
<root>
  <user id="1">
    <name>张三</name>
    <age>25</age>
  </user>
</root>
`);

// XPath 查询
const users = xmlParser.query(result.data, '/root/user');

// 获取文本内容
const text = xmlParser.getTextContent(result.data);

// 格式化输出
const formatted = xmlParser.format(result.data, { indent: 2 });
```

### HTMLParserAdapter

支持标准 HTML、XHTML、HTML5。

```typescript
import { HTMLParserAdapter } from '../core/adapters/HTMLParserAdapter';

const htmlParser = new HTMLParserAdapter();

const result = await htmlParser.parse(`
<!DOCTYPE html>
<html>
<head><title>示例</title></head>
<body>
  <div class="content">
    <h1>标题</h1>
    <p class="intro">段落内容</p>
  </div>
</body>
</html>
`);

// CSS 选择器查询
const paragraphs = htmlParser.query(result.data, '.intro');
const h1Elements = htmlParser.query(result.data, 'h1');

// 获取属性
const classValue = htmlParser.getAttribute(paragraphs[0], 'class');

// 获取文本内容
const text = htmlParser.getTextContent(result.data);
```

### CSVParserAdapter

支持标准 CSV、自定义分隔符、带引号 CSV。

```typescript
import { CSVParserAdapter } from '../core/adapters/CSVParserAdapter';

const csvParser = new CSVParserAdapter();

const result = await csvParser.parse(`
name,age,city
张三,25,北京
李四,30,上海
王五,28,广州
`, {
  delimiter: ',',      // 分隔符
  hasHeader: true,     // 是否有表头
  skipEmptyLines: true // 跳过空行
});

// 访问数据
console.log(result.data.headers);  // ['name', 'age', 'city']
console.log(result.data.rows);     // [{ name: '张三', age: '25', city: '北京' }, ...]

// 查询
const beijingUsers = csvParser.query(result.data, 'city[北京]');

// 获取列
const names = csvParser.getColumn(result.data, 'name');

// 获取唯一值
const cities = csvParser.getUniqueValues(result.data, 'city');

// 过滤
const adults = csvParser.filter(result.data, row => parseInt(row.age) >= 25);

// 排序
const sorted = csvParser.sort(result.data, 'age', false);  // 降序

// 格式化输出
const formatted = csvParser.format(result.data, {
  customRules: { delimiter: ';' }
});
```

---

## 错误处理

### 统一错误类型

```typescript
import { ParserError, ParserErrorCode } from '../core/ParserError';

try {
  const result = await parser.parse('invalid json', ParserType.JSON);
} catch (error) {
  if (error instanceof ParserError) {
    console.log('错误码:', error.code);
    console.log('错误消息:', error.message);
    console.log('解析器类型:', error.parserType);
    console.log('行号:', error.line);
    console.log('列号:', error.column);
    console.log('上下文:', error.context);
  }
}
```

### 错误码列表

| 错误码 | 说明 |
|--------|------|
| `PARSER_UNKNOWN` | 未知错误 |
| `PARSER_INVALID_INPUT` | 无效输入 |
| `PARSER_EMPTY_INPUT` | 空输入 |
| `PARSER_SYNTAX_ERROR` | 语法错误 |
| `PARSER_ENCODING_ERROR` | 编码错误 |
| `PARSER_TIMEOUT` | 超时 |
| `PARSER_DEPTH_EXCEEDED` | 深度超限 |
| `PARSER_INVALID_FORMAT` | 格式无效 |
| `PARSER_UNSUPPORTED_TYPE` | 不支持的类型 |
| `PARSER_PARSE_FAILED` | 解析失败 |
| `PARSER_ADAPTER_NOT_FOUND` | 适配器未找到 |

### 结果中的错误处理

```typescript
const result = await parser.parse(content, ParserType.JSON);

if (result.status === 'failed') {
  for (const error of result.errors) {
    console.error(`[${error.severity}] ${error.code}: ${error.message}`);
    if (error.line) {
      console.error(`  位置: 行 ${error.line}, 列 ${error.column}`);
    }
  }
}

// 处理警告
for (const warning of result.warnings) {
  console.warn(`[${warning.severity}] ${warning.code}: ${warning.message}`);
}
```

---

## 缓存机制

### 启用缓存

```typescript
const parser = ParserFacade.getInstance({
  enableCache: true,
  cacheTTL: 5 * 60 * 1000,  // 5分钟
  maxCacheSize: 100
});
```

### 缓存操作

```typescript
// 使用自定义缓存键
const result = await parser.parse(content, ParserType.JSON, {
  cacheKey: 'my-unique-key'
});

// 跳过缓存
const freshResult = await parser.parse(content, ParserType.JSON, {
  skipCache: true
});

// 获取缓存统计
const stats = parser.getCacheStats();
console.log('缓存大小:', stats.size);
console.log('命中率:', stats.hitRate);

// 清除缓存
parser.clearCache();
```

---

## 高级用法

### 批量解析

```typescript
const items = [
  { content: '{"a": 1}', type: ParserType.JSON },
  { content: '<root/>', type: ParserType.XML },
  { content: 'name,value\na,1', type: ParserType.CSV }
];

const results = await parser.parseBatch(items);
```

### 回退解析

```typescript
// 尝试多种解析器，返回第一个成功的
const result = await parser.parseWithFallback(content, [
  ParserType.JSON,
  ParserType.XML,
  ParserType.CSV
]);
```

### 自定义适配器

```typescript
import { ParserAdapter } from '../core/ParserAdapter';
import { ParserType, ParseResult, ParseOptions } from '../interfaces/IParser';

class CustomParserAdapter extends ParserAdapter<string> {
  readonly type = ParserType.TEXT;
  readonly name = 'CustomParser';
  readonly version = '1.0.0';
  readonly supportedExtensions = ['custom'];
  readonly priority = 50;

  protected async doParse(content: string, options: ParseOptions): Promise<ParseResult<string>> {
    // 实现自定义解析逻辑
    return {
      data: content.toUpperCase(),
      status: 'success' as never,
      errors: [],
      warnings: [],
      metadata: {
        parserType: this.type,
        parseTime: 0,
        dataSize: content.length,
        cached: false,
        timestamp: Date.now(),
        version: this.version
      }
    };
  }

  protected doParseSync(content: string, options: ParseOptions): ParseResult<string> {
    // 同步版本
    return this.doParse(content, options) as unknown as ParseResult<string>;
  }

  protected doValidate(content: string): { errors: ParseErrorInfo[]; warnings: ParseWarningInfo[] } {
    return { errors: [], warnings: [] };
  }

  protected detectContent(content: string): boolean {
    return content.startsWith('CUSTOM:');
  }

  format(data: string): string {
    return data;
  }
}

// 注册自定义适配器
parser.register(new CustomParserAdapter());
```

---

## 最佳实践

### 1. 使用单例模式

```typescript
// ✅ 推荐：使用单例
const parser = ParserFacade.getInstance();

// ❌ 不推荐：每次创建新实例
const parser = new ParserFacade();
```

### 2. 合理使用缓存

```typescript
// ✅ 推荐：对于重复解析相同内容，使用缓存
const result = await parser.parse(largeContent, ParserType.JSON, {
  cacheKey: 'unique-key'
});

// ❌ 不推荐：对于一次性内容使用缓存
const result = await parser.parse(oneTimeContent, ParserType.JSON, {
  cacheKey: 'unique-key'  // 浪费缓存空间
});
```

### 3. 错误处理

```typescript
// ✅ 推荐：检查结果状态
const result = await parser.parse(content, ParserType.JSON);
if (result.status !== 'failed' as never) {
  // 使用 result.data
} else {
  // 处理错误
  console.error(result.errors);
}

// ❌ 不推荐：假设解析成功
const result = await parser.parse(content, ParserType.JSON);
console.log(result.data.property);  // 可能抛出异常
```

### 4. 性能优化

```typescript
// ✅ 推荐：大数据量使用异步
const result = await parser.parse(largeContent, ParserType.JSON);

// ✅ 推荐：小数据量使用同步
const result = parser.parseSync(smallContent, ParserType.JSON);

// ✅ 推荐：设置合理的超时
const result = await parser.parse(content, ParserType.JSON, {
  timeout: 5000  // 5秒超时
});
```

### 5. 类型安全

```typescript
// ✅ 推荐：使用泛型指定返回类型
interface User {
  name: string;
  age: number;
}

const result = await parser.parse<User>(content, ParserType.JSON);
const user: User = result.data;
```

---

## API 参考

### ParserFacade

| 方法 | 说明 | 返回类型 |
|------|------|---------|
| `getInstance(options?)` | 获取单例实例 | `ParserFacade` |
| `parse(content, type?, options?)` | 异步解析 | `Promise<ParseResult<T>>` |
| `parseSync(content, type?, options?)` | 同步解析 | `ParseResult<T>` |
| `parseJSON(content, options?)` | 解析 JSON | `Promise<ParseResult<T>>` |
| `parseXML(content, options?)` | 解析 XML | `Promise<ParseResult<XmlNode>>` |
| `parseHTML(content, options?)` | 解析 HTML | `Promise<ParseResult<HtmlNode>>` |
| `parseCSV(content, options?)` | 解析 CSV | `Promise<ParseResult<CsvResult>>` |
| `validate(content, type?, options?)` | 验证内容 | `ValidationResult` |
| `format(data, type, options?)` | 格式化输出 | `string` |
| `parseBatch(items)` | 批量解析 | `Promise<ParseResult<T>[]>` |
| `parseWithFallback(content, types, options?)` | 回退解析 | `Promise<ParseResult<T>>` |
| `clearCache()` | 清除缓存 | `void` |
| `getCacheStats()` | 获取缓存统计 | `CacheStats` |
| `register(parser)` | 注册适配器 | `void` |
| `unregister(type)` | 注销适配器 | `boolean` |

---

> 文档版本: v1.0.0  
> 最后更新: 2026-02-17
