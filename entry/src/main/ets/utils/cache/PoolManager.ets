/**
 * PoolManager - 对象池管理器
 * 统一管理各种对象池，优化对象创建和复用
 */

import { Logger } from '../performance/Logger';

/**
 * 可池化对象接口
 */
export interface Poolable {
  /** 重置对象状态 */
  reset(): void;
  /** 检查对象是否有效 */
  isValid?(): boolean;
}

/**
 * 对象池配置
 */
interface PoolConfig {
  /** 池最大容量 */
  maxSize: number;
  /** 初始对象数 */
  initialSize?: number;
  /** 对象过期时间（毫秒） */
  expiryTime?: number;
  /** 是否启用统计 */
  enableStats?: boolean;
}

/**
 * 池化对象包装
 */
interface PooledObject<T> {
  obj: T;
  createdAt: number;
  lastUsed: number;
  useCount: number;
}

/**
 * 对象池统计
 */
interface PoolStats {
  name: string;
  size: number;
  maxSize: number;
  acquired: number;
  released: number;
  hits: number;
  misses: number;
  hitRate: number;
}

/**
 * 统计计数器
 */
interface PoolCounters {
  acquired: number;
  released: number;
  hits: number;
  misses: number;
}

/**
 * 通用对象池
 */
export class ObjectPool<T extends Poolable> {
  private readonly TAG: string;
  private pool: PooledObject<T>[] = [];
  private config: Required<PoolConfig>;
  private factory: () => T;
  private stats: PoolCounters = {
    acquired: 0,
    released: 0,
    hits: 0,
    misses: 0,
  };

  constructor(
    name: string,
    factory: () => T,
    config: PoolConfig
  ) {
    this.TAG = `ObjectPool:${name}`;
    this.factory = factory;
    this.config = {
      maxSize: config.maxSize,
      initialSize: config.initialSize ?? 0,
      expiryTime: config.expiryTime ?? 0,
      enableStats: config.enableStats ?? false,
    };

    // 初始化对象
    this.initialize();
  }

  /**
   * 初始化池
   */
  private initialize(): void {
    for (let i = 0; i < this.config.initialSize; i++) {
      const obj = this.createPooledObject();
      this.pool.push(obj);
    }

    if (this.config.initialSize > 0) {
      Logger.debug(this.TAG, `初始化完成，预创建 ${this.config.initialSize} 个对象`);
    }
  }

  /**
   * 创建池化对象
   */
  private createPooledObject(): PooledObject<T> {
    return {
      obj: this.factory(),
      createdAt: Date.now(),
      lastUsed: Date.now(),
      useCount: 0,
    };
  }

  /**
   * 获取对象
   */
  acquire(): T {
    this.stats.acquired++;

    // 从池中获取可用对象
    while (this.pool.length > 0) {
      const pooled = this.pool.pop()!;

      // 检查对象是否过期
      if (this.config.expiryTime > 0) {
        const age = Date.now() - pooled.createdAt;
        if (age > this.config.expiryTime) {
          Logger.debug(this.TAG, '对象已过期，丢弃');
          continue;
        }
      }

      // 检查对象是否有效
      if (pooled.obj.isValid && !pooled.obj.isValid()) {
        Logger.debug(this.TAG, '对象无效，丢弃');
        continue;
      }

      pooled.lastUsed = Date.now();
      pooled.useCount++;
      this.stats.hits++;

      if (this.config.enableStats) {
        Logger.debug(this.TAG, `获取对象（命中），使用次数: ${pooled.useCount}`);
      }

      return pooled.obj;
    }

    // 池为空，创建新对象
    this.stats.misses++;
    const obj = this.factory();

    if (this.config.enableStats) {
      Logger.debug(this.TAG, '获取对象（未命中），创建新对象');
    }

    return obj;
  }

  /**
   * 释放对象回池
   */
  release(obj: T): void {
    this.stats.released++;

    // 检查池是否已满
    if (this.pool.length >= this.config.maxSize) {
      Logger.debug(this.TAG, '池已满，对象被丢弃');
      return;
    }

    // 重置对象状态
    try {
      obj.reset();
    } catch (error) {
      Logger.warn(this.TAG, `重置对象失败: ${error}`);
      return;
    }

    // 检查对象是否有效
    if (obj.isValid && !obj.isValid()) {
      Logger.debug(this.TAG, '对象无效，不回收');
      return;
    }

    // 回收对象
    const pooled: PooledObject<T> = {
      obj,
      createdAt: Date.now(),
      lastUsed: Date.now(),
      useCount: 0,
    };

    this.pool.push(pooled);

    if (this.config.enableStats) {
      Logger.debug(this.TAG, `释放对象，当前池大小: ${this.pool.length}`);
    }
  }

  /**
   * 使用对象（自动获取和释放）
   */
  use<R>(callback: (obj: T) => R): R {
    const obj = this.acquire();
    try {
      return callback(obj);
    } finally {
      this.release(obj);
    }
  }

  /**
   * 异步使用对象
   */
  async useAsync<R>(callback: (obj: T) => Promise<R>): Promise<R> {
    const obj = this.acquire();
    try {
      return await callback(obj);
    } finally {
      this.release(obj);
    }
  }

  /**
   * 清空池
   */
  clear(): void {
    this.pool.length = 0;
    Logger.debug(this.TAG, '池已清空');
  }

  /**
   * 获取池大小
   */
  size(): number {
    return this.pool.length;
  }

  /**
   * 获取统计信息
   */
  getStats(): PoolStats {
    const total = this.stats.hits + this.stats.misses;
    return {
      name: this.TAG,
      size: this.pool.length,
      maxSize: this.config.maxSize,
      acquired: this.stats.acquired,
      released: this.stats.released,
      hits: this.stats.hits,
      misses: this.stats.misses,
      hitRate: total > 0 ? this.stats.hits / total : 0,
    };
  }

  /**
   * 重置统计
   */
  resetStats(): void {
    this.stats = {
      acquired: 0,
      released: 0,
      hits: 0,
      misses: 0,
    } as PoolCounters;
  }
}

/**
 * 字符串构建器（池化版本）
 */
export class PooledStringBuilder implements Poolable {
  private parts: string[] = [];
  private cachedResult: string | null = null;

  append(str: string): PooledStringBuilder {
    if (str && str.length > 0) {
      this.parts.push(str);
      this.cachedResult = null;
    }
    return this;
  }

  appendLine(str: string = ''): PooledStringBuilder {
    this.append(str + '\n');
    return this;
  }

  insert(index: number, str: string): PooledStringBuilder {
    if (index >= 0 && index <= this.parts.length && str) {
      this.parts.splice(index, 0, str);
      this.cachedResult = null;
    }
    return this;
  }

  clear(): PooledStringBuilder {
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
 * 数组构建器（池化版本）
 */
export class PooledArrayBuilder<T> implements Poolable {
  private items: T[] = [];

  push(...items: T[]): PooledArrayBuilder<T> {
    this.items.push(...items);
    return this;
  }

  pop(): T | undefined {
    return this.items.pop();
  }

  get(index: number): T | undefined {
    return this.items[index];
  }

  set(index: number, value: T): PooledArrayBuilder<T> {
    this.items[index] = value;
    return this;
  }

  remove(index: number): PooledArrayBuilder<T> {
    this.items.splice(index, 1);
    return this;
  }

  clear(): PooledArrayBuilder<T> {
    this.items.length = 0;
    return this;
  }

  toArray(): T[] {
    return [...this.items];
  }

  size(): number {
    return this.items.length;
  }

  isEmpty(): boolean {
    return this.items.length === 0;
  }

  reset(): void {
    this.items.length = 0;
  }
}

/**
 * 对象池管理器
 */
export class PoolManager {
  private static pools: Map<string, ObjectPool<Poolable>> = new Map();

  /**
   * 注册对象池
   */
  static registerPool<T extends Poolable>(
    name: string,
    factory: () => T,
    config: PoolConfig
  ): ObjectPool<T> {
    const pool = new ObjectPool<T>(name, factory, config);
    PoolManager.pools.set(name, pool as ObjectPool<Poolable>);
    return pool;
  }

  /**
   * 获取对象池
   */
  static getPool<T extends Poolable>(name: string): ObjectPool<T> | undefined {
    return PoolManager.pools.get(name) as ObjectPool<T> | undefined;
  }

  /**
   * 获取所有统计信息
   */
  static getAllStats(): PoolStats[] {
    const stats: PoolStats[] = [];
    PoolManager.pools.forEach(pool => {
      stats.push(pool.getStats());
    });
    return stats;
  }

  /**
   * 清空所有池
   */
  static clearAll(): void {
    PoolManager.pools.forEach(pool => pool.clear());
    Logger.debug('PoolManager', '所有对象池已清空');
  }

  /**
   * 重置所有统计
   */
  static resetAllStats(): void {
    PoolManager.pools.forEach(pool => pool.resetStats());
  }
}

/**
 * 预定义的字符串构建器池
 */
export const StringBuilderPool = PoolManager.registerPool(
  'StringBuilder',
  () => new PooledStringBuilder(),
  {
    maxSize: 30,
    initialSize: 5,
    enableStats: false,
  }
);

/**
 * 预定义的数组构建器池
 */
export const ArrayBuilderPool = PoolManager.registerPool(
  'ArrayBuilder',
  () => new PooledArrayBuilder<object>(),
  {
    maxSize: 20,
    initialSize: 3,
    enableStats: false,
  }
);
