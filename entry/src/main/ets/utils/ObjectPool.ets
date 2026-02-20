/**
 * ObjectPool - 对象池管理器
 * 用于减少GC压力，复用常用对象
 */

export interface Poolable {
  reset(): void;
}

export class ObjectPool<T extends Poolable> {
  private pool: T[] = [];
  private maxSize: number;
  private factory: () => T;

  constructor(factory: () => T, maxSize: number = 50) {
    this.factory = factory;
    this.maxSize = maxSize;
  }

  acquire(): T {
    if (this.pool.length > 0) {
      const obj = this.pool.pop()!;
      return obj;
    }
    return this.factory();
  }

  release(obj: T): void {
    if (this.pool.length < this.maxSize) {
      obj.reset();
      this.pool.push(obj);
    }
  }

  clear(): void {
    this.pool.length = 0;
  }

  size(): number {
    return this.pool.length;
  }
}

/**
 * StringBuilder - 字符串构建器
 * 用于减少字符串拼接产生的临时对象
 */
export class StringBuilder implements Poolable {
  private parts: string[] = [];
  private cachedResult: string | null = null;

  append(str: string): StringBuilder {
    if (str && str.length > 0) {
      this.parts.push(str);
      this.cachedResult = null;
    }
    return this;
  }

  appendLine(str: string = ''): StringBuilder {
    this.append(str + '\n');
    return this;
  }

  insert(index: number, str: string): StringBuilder {
    if (index >= 0 && index <= this.parts.length && str) {
      this.parts.splice(index, 0, str);
      this.cachedResult = null;
    }
    return this;
  }

  remove(start: number, length: number): StringBuilder {
    if (start >= 0 && length > 0) {
      this.parts.splice(start, length);
      this.cachedResult = null;
    }
    return this;
  }

  clear(): StringBuilder {
    this.parts.length = 0;
    this.cachedResult = null;
    return this;
  }

  toString(): string {
    if (this.cachedResult === null) {
      this.cachedResult = this.parts.join('');
    }
    return this.cachedResult;
  }

  length(): number {
    return this.toString().length;
  }

  isEmpty(): boolean {
    return this.parts.length === 0;
  }

  reset(): void {
    this.parts.length = 0;
    this.cachedResult = null;
  }
}

/**
 * StringBuilderPool - StringBuilder对象池
 */
export class StringBuilderPool {
  private static pool: ObjectPool<StringBuilder> = new ObjectPool<StringBuilder>(
    () => new StringBuilder(),
    20
  );

  static acquire(): StringBuilder {
    return StringBuilderPool.pool.acquire();
  }

  static release(builder: StringBuilder): void {
    StringBuilderPool.pool.release(builder);
  }

  static build(callback: (builder: StringBuilder) => void): string {
    const builder = StringBuilderPool.acquire();
    try {
      callback(builder);
      return builder.toString();
    } finally {
      StringBuilderPool.release(builder);
    }
  }
}

/**
 * ArrayPool - 数组对象池
 */
export class ArrayPool<T> {
  private pool: T[][] = [];
  private maxSize: number;

  constructor(maxSize: number = 30) {
    this.maxSize = maxSize;
  }

  acquire(): T[] {
    if (this.pool.length > 0) {
      const arr = this.pool.pop()!;
      return arr;
    }
    return [];
  }

  release(arr: T[]): void {
    if (this.pool.length < this.maxSize) {
      arr.length = 0;
      this.pool.push(arr);
    }
  }

  clear(): void {
    this.pool.length = 0;
  }
}

/**
 * MapPool - Map对象池
 */
export class MapPool<K, V> {
  private pool: Map<K, V>[] = [];
  private maxSize: number;

  constructor(maxSize: number = 20) {
    this.maxSize = maxSize;
  }

  acquire(): Map<K, V> {
    if (this.pool.length > 0) {
      const map = this.pool.pop()!;
      return map;
    }
    return new Map<K, V>();
  }

  release(map: Map<K, V>): void {
    if (this.pool.length < this.maxSize) {
      map.clear();
      this.pool.push(map);
    }
  }

  clear(): void {
    this.pool.length = 0;
  }
}

/**
 * StringCache - 字符串缓存
 * 用于缓存常用字符串，减少重复创建
 */
export class StringCache {
  private static cache: Map<string, string> = new Map();
  private static maxSize: number = 500;

  static get(str: string): string {
    const cached = StringCache.cache.get(str);
    if (cached !== undefined) {
      return cached;
    }

    if (StringCache.cache.size >= StringCache.maxSize) {
      const keys = Array.from(StringCache.cache.keys());
      if (keys.length > 0) {
        StringCache.cache.delete(keys[0]);
      }
    }

    StringCache.cache.set(str, str);
    return str;
  }

  static has(str: string): boolean {
    return StringCache.cache.has(str);
  }

  static clear(): void {
    StringCache.cache.clear();
  }

  static size(): number {
    return StringCache.cache.size;
  }
}

/**
 * StringIntern - 字符串驻留
 * 用于减少重复字符串的内存占用
 */
export class StringIntern {
  private static internPool: Map<string, string> = new Map();
  private static maxSize: number = 1000;

  static intern(str: string): string {
    if (!str || str.length === 0) {
      return str;
    }

    const existing = StringIntern.internPool.get(str);
    if (existing !== undefined) {
      return existing;
    }

    if (StringIntern.internPool.size >= StringIntern.maxSize) {
      const keys = Array.from(StringIntern.internPool.keys());
      const deleteCount = Math.floor(StringIntern.maxSize * 0.3);
      for (let i = 0; i < deleteCount; i++) {
        StringIntern.internPool.delete(keys[i]);
      }
    }

    StringIntern.internPool.set(str, str);
    return str;
  }

  static clear(): void {
    StringIntern.internPool.clear();
  }

  static size(): number {
    return StringIntern.internPool.size;
  }
}