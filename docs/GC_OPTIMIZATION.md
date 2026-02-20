# GC性能优化建议

## 问题分析

根据日志分析，应用存在以下GC相关问题：

### 1. GC暂停时间长
- **YoungGC**: 平均10-30ms
- **OldGC**: 55-152ms（最大值）
- **影响**: OldGC暂停超过100ms时，用户可感知到UI卡顿

### 2. GC触发频繁
- **触发原因**: 
  - `ConcurrentMark finished` - 并发标记完成
  - `Memory reach limit` - 内存达到上限
  - `Idle time task` - 空闲时任务
- **频率**: YoungGC频繁发生，OldGC较少但影响大

### 3. 内存使用情况
- **Anno memory**: 30-70MB
- **Native memory**: 约2MB
- **Total committed**: 14MB左右

## 优化方案

### 1. 减少临时对象分配

#### 问题代码示例
```arkts
// ❌ 不好的做法 - 每次循环都创建新对象
async searchBooks(keyword: string, bookSources: BookSource[]): Promise<Book[]> {
  const results: Book[] = [];
  for (const source of bookSources) {
    const searchOptions = {  // 每次循环创建新对象
      key: keyword,
      page: 1,
      timeout: 10000
    };
    const books = await this.searchSingleSource(source, searchOptions);
    results.push(...books);
  }
  return results;
}
```

#### 优化后代码
```arkts
// ✅ 好的做法 - 复用对象
async searchBooks(keyword: string, bookSources: BookSource[]): Promise<Book[]> {
  const results: Book[] = [];
  const searchOptions: SearchOptions = {  // 在循环外创建
    key: keyword,
    page: 1,
    timeout: 10000
  };
  for (const source of bookSources) {
    const books = await this.searchSingleSource(source, searchOptions);
    results.push(...books);
  }
  return results;
}
```

### 2. 优化字符串操作

#### 问题代码示例
```arkts
// ❌ 不好的做法 - 频繁字符串拼接
let result = '';
for (const item of items) {
  result += item.name + ',' + item.value + ';';
}
```

#### 优化后代码
```arkts
// ✅ 好的做法 - 使用数组join
const parts: string[] = [];
for (const item of items) {
  parts.push(item.name, item.value);
}
const result = parts.join(',');
```

### 3. 使用对象池

```arkts
class BookPool {
  private pool: Book[] = [];
  private readonly maxSize = 100;

  acquire(): Book {
    if (this.pool.length > 0) {
      return this.pool.pop()!;
    }
    return {
      id: '',
      name: '',
      author: '',
      // ... 其他字段
    };
  }

  release(book: Book): void {
    if (this.pool.length < this.maxSize) {
      // 清理对象
      book.id = '';
      book.name = '';
      book.author = '';
      this.pool.push(book);
    }
  }
}
```

### 4. 优化列表渲染

#### 问题代码示例
```arkts
// ❌ 不好的做法 - 没有使用缓存
List() {
  ForEach(this.books, (book: Book) => {
    ListItem() {
      BookItem({ book: book })
    }
  })
}
```

#### 优化后代码
```arkts
// ✅ 好的做法 - 使用cachedCount和keyGenerator
List() {
  ForEach(this.books, (book: Book, index: number) => {
    ListItem() {
      BookItem({ book: book })
    }
  }, (book: Book, index: number) => `${book.id}_${index}`)
}
.cachedCount(10)  // 缓存10个子节点
```

### 5. 延迟加载和懒加载

```arkts
// ✅ 使用LazyForEach替代ForEach
LazyForEach(this.dataSource, (item: string) => {
  ListItem() {
    Text(item).width('100%').height(100).fontSize(16)
  }
}, (item: string) => item)
```

### 6. 优化网络请求并发控制

#### 当前问题
- 50个书源并发搜索会产生大量临时对象
- 每个请求都会创建Promise、回调函数、错误对象等

#### 优化建议
```arkts
// ✅ 使用更小的并发数
const CONCURRENT_LIMIT = 5;  // 从50降低到5

// ✅ 使用请求队列
class RequestQueue {
  private queue: Array<() => Promise<any>> = [];
  private running = 0;
  private readonly maxConcurrent: number;

  constructor(maxConcurrent: number = 5) {
    this.maxConcurrent = maxConcurrent;
  }

  async add<T>(request: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await request();
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });
      this.processQueue();
    });
  }

  private async processQueue(): Promise<void> {
    while (this.running < this.maxConcurrent && this.queue.length > 0) {
      this.running++;
      const request = this.queue.shift()!;
      try {
        await request();
      } finally {
        this.running--;
        this.processQueue();
      }
    }
  }
}
```

### 7. 优化数据库批量操作

#### 当前代码
```arkts
// ❌ 每次插入都创建新的valuesBucket
async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
  for (const chapter of chapters) {
    const valueBucket: relationalStore.ValuesBucket = {
      id: chapter.id,
      book_id: chapter.bookId,
      title: chapter.title,
      url: chapter.url,
      chapter_order: chapter.chapterOrder,
      is_vip: chapter.isVip
    };
    await this.rdbStore.insert('chapter', valueBucket);
  }
}
```

#### 优化后代码
```arkts
// ✅ 使用批量插入API
async batchUpsertChapters(chapters: Chapter[]): Promise<void> {
  const predicates = new relationalStore.RdbPredicates("chapter");
  const valueBucket: relationalStore.ValuesBucket = {
    chapters: chapters.map(c => ({
      id: c.id,
      book_id: c.bookId,
      title: c.title,
      url: c.url,
      chapter_order: c.chapterOrder,
      is_vip: c.isVip
    }))
  };
  await this.rdbStore.batchInsert('chapter', valueBucket);
}
```

### 8. 优化图片加载

```arkts
// ✅ 使用objectFit和缓存
Image(book.cover)
  .width(60)
  .height(80)
  .objectFit(ImageFit.Cover)
  .alt(this.placeholder)
  .cacheStrategy(CacheStrategy.Memory | CacheStrategy.Disk)
```

### 9. 使用更高效的数据结构

```arkts
// ✅ 对于频繁查找的场景，使用Map代替数组
class BookCache {
  private cache: Map<string, Book> = new Map();

  get(id: string): Book | undefined {
    return this.cache.get(id);
  }

  set(book: Book): void {
    this.cache.set(book.id, book);
  }

  has(id: string): boolean {
    return this.cache.has(id);
  }
}
```

### 10. 避免在循环中创建闭包

```arkts
// ❌ 不好的做法
for (let i = 0; i < items.length; i++) {
  setTimeout(() => {
    console.log(i);  // 每次循环都创建新的闭包
  }, 100);
}

// ✅ 好的做法
function logIndex(index: number): void {
  setTimeout(() => {
    console.log(index);
  }, 100);
}

for (let i = 0; i < items.length; i++) {
  logIndex(i);
}
```

## 监控和诊断

### 1. 使用DevEco Studio的Profiler

```arkts
import { hiPerformance } from '@kit.PerformanceAnalysisKit';

// 开始性能跟踪
hiPerformance.startTrace('search_operation');

try {
  await this.searchBooks(keyword, sources);
} finally {
  hiPerformance.finishTrace('search_operation');
}
```

### 2. 监控内存使用

```arkts
import { hiPerformance } from '@kit.PerformanceAnalysisKit';

const memoryInfo = hiPerformance.getJsHeapStats();
console.log(`Used: ${memoryInfo.used_heap_size}, Total: ${memoryInfo.total_heap_size}`);
```

### 3. 添加GC日志

```arkts
import { hiPerformance } from '@kit.PerformanceAnalysisKit';

hiPerformance.startHeapCapture('heap_snapshot');
// ... 执行操作
hiPerformance.stopHeapCapture('heap_snapshot');
```

## 预期效果

实施以上优化后，预期可以达到以下效果：

1. **GC暂停时间减少50%以上**
   - YoungGC: 从10-30ms降低到5-15ms
   - OldGC: 从55-152ms降低到30-80ms

2. **GC频率降低30%以上**
   - 通过减少临时对象分配，降低GC触发频率

3. **UI流畅度提升**
   - 掉帧次数减少60%以上
   - 用户感知的卡顿明显减少

4. **内存使用更稳定**
   - 内存峰值降低20-30%
   - 内存增长速度放缓

## 实施优先级

### 高优先级（立即实施）
1. 优化网络请求并发控制（从50降低到5-8）
2. 优化列表渲染缓存
3. 减少字符串拼接操作

### 中优先级（近期实施）
4. 使用对象池复用Book对象
5. 优化数据库批量操作
6. 优化图片加载策略

### 低优先级（长期优化）
7. 重构数据结构使用Map
8. 实现完整的内存监控
9. 添加自动化性能测试

## 参考资料

- [ArkTS性能优化最佳实践](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-performance-improvement-recommendation-0000001778097145)
- [ArkUI开发性能优化](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkui-arkts-performance-improvement-recommendation-0000001821007049)
- [Profiler性能调优](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/profiler-0000001774120621)
