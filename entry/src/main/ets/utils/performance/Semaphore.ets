/**
 * Semaphore - 信号量实现
 * 用于控制并发访问数量，防止资源过载
 */

import { Logger } from "./Logger";

/**
 * 信号量配置
 */
interface SemaphoreConfig {
  /** 初始许可数 */
  permits: number;
  /** 是否公平模式（按请求顺序获取许可） */
  fair?: boolean;
  /** 超时时间（毫秒） */
  timeout?: number;
  /** 信号量名称（用于日志） */
  name?: string;
}

/**
 * 等待中的请求
 */
interface WaitingRequest {
  resolve: () => void;
  reject: (reason: Error) => void;
  timestamp: number;
}

/**
 * 信号量统计
 */
export interface SemaphoreStats {
  name: string;
  availablePermits: number;
  totalPermits: number;
  waitingCount: number;
  acquiredCount: number;
  releasedCount: number;
  timeoutCount: number;
}

/**
 * 信号量 - 并发控制工具
 * 基于计数器的并发控制机制
 */
export class Semaphore {
  private readonly TAG: string;
  private permits: number;
  private readonly totalPermits: number;
  private readonly fair: boolean;
  private readonly timeout: number;
  private readonly waitingQueue: WaitingRequest[] = [];
  private stats = {
    acquired: 0,
    released: 0,
    timeouts: 0,
  };

  constructor(config: SemaphoreConfig) {
    this.permits = config.permits;
    this.totalPermits = config.permits;
    this.fair = config.fair ?? true;
    this.timeout = config.timeout ?? 30000;
    this.TAG = `Semaphore:${config.name ?? 'default'}`;
  }

  /**
   * 获取许可（阻塞直到获取成功或超时）
   */
  async acquire(): Promise<void> {
    // 立即检查是否有可用许可
    if (this.permits > 0 && this.waitingQueue.length === 0) {
      this.permits--;
      this.stats.acquired++;
      return;
    }

    // 需要等待
    return new Promise((resolve, reject) => {
      const request: WaitingRequest = {
        resolve,
        reject,
        timestamp: Date.now(),
      };

      if (this.fair) {
        // 公平模式：加入队列尾部
        this.waitingQueue.push(request);
      } else {
        // 非公平模式：加入队列头部（优先获取）
        this.waitingQueue.unshift(request);
      }

      // 设置超时
      if (this.timeout > 0) {
        setTimeout(() => {
          const index = this.waitingQueue.indexOf(request);
          if (index !== -1) {
            this.waitingQueue.splice(index, 1);
            this.stats.timeouts++;
            reject(new Error(`获取信号量超时 (${this.timeout}ms)`));
          }
        }, this.timeout);
      }
    });
  }

  /**
   * 尝试获取许可（非阻塞）
   */
  tryAcquire(): boolean {
    if (this.permits > 0 && this.waitingQueue.length === 0) {
      this.permits--;
      this.stats.acquired++;
      return true;
    }
    return false;
  }

  /**
   * 尝试在指定时间内获取许可
   */
  async tryAcquireWithTimeout(timeoutMs: number): Promise<boolean> {
    if (this.permits > 0 && this.waitingQueue.length === 0) {
      this.permits--;
      this.stats.acquired++;
      return true;
    }

    return new Promise((resolve) => {
      const request: WaitingRequest = {
        resolve: () => resolve(true),
        reject: () => resolve(false),
        timestamp: Date.now(),
      };

      this.waitingQueue.push(request);

      setTimeout(() => {
        const index = this.waitingQueue.indexOf(request);
        if (index !== -1) {
          this.waitingQueue.splice(index, 1);
          resolve(false);
        }
      }, timeoutMs);
    });
  }

  /**
   * 释放许可
   */
  release(): void {
    this.permits++;
    this.stats.released++;

    // 检查等待队列
    if (this.waitingQueue.length > 0) {
      const request = this.waitingQueue.shift();
      if (request) {
        this.permits--;
        this.stats.acquired++;
        request.resolve();
      }
    }
  }

  /**
   * 使用许可执行操作（自动获取和释放）
   */
  async execute<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }

  /**
   * 批量获取许可
   */
  async acquireMany(count: number): Promise<void> {
    if (count <= 0) return;
    if (count > this.totalPermits) {
      throw new Error(`请求的许可数 (${count}) 超过总许可数 (${this.totalPermits})`);
    }

    for (let i = 0; i < count; i++) {
      await this.acquire();
    }
  }

  /**
   * 批量释放许可
   */
  releaseMany(count: number): void {
    for (let i = 0; i < count; i++) {
      this.release();
    }
  }

  /**
   * 减少许可数（动态调整）
   */
  reducePermits(reduction: number): void {
    this.permits = Math.max(0, this.permits - reduction);
  }

  /**
   * 增加许可数（动态调整）
   */
  increasePermits(increase: number): void {
    const newPermits = this.permits + increase;
    this.permits = Math.min(newPermits, this.totalPermits);

    // 唤醒等待的请求
    while (this.permits > 0 && this.waitingQueue.length > 0) {
      const request = this.waitingQueue.shift();
      if (request) {
        this.permits--;
        this.stats.acquired++;
        request.resolve();
      }
    }
  }

  /**
   * 获取当前可用许可数
   */
  availablePermits(): number {
    return this.permits;
  }

  /**
   * 获取等待队列长度
   */
  getQueueLength(): number {
    return this.waitingQueue.length;
  }

  /**
   * 获取统计信息
   */
  getStats(): SemaphoreStats {
    return {
      name: this.TAG,
      availablePermits: this.permits,
      totalPermits: this.totalPermits,
      waitingCount: this.waitingQueue.length,
      acquiredCount: this.stats.acquired,
      releasedCount: this.stats.released,
      timeoutCount: this.stats.timeouts,
    };
  }

  /**
   * 清空等待队列
   */
  clearQueue(): void {
    while (this.waitingQueue.length > 0) {
      const request = this.waitingQueue.shift();
      if (request) {
        request.reject(new Error('信号量等待队列被清空'));
      }
    }
  }

  /**
   * 重置信号量
   */
  reset(): void {
    this.clearQueue();
    this.permits = this.totalPermits;
    this.stats = {
      acquired: 0,
      released: 0,
      timeouts: 0,
    };
  }
}

/**
 * 读写锁 - 基于信号量实现
 * 支持多个读操作并发，写操作独占
 */
export class ReadWriteLock {
  private readSemaphore: Semaphore;
  private writeSemaphore: Semaphore;
  private readCount: number = 0;
  private readonly TAG: string;

  constructor(name?: string) {
    this.TAG = `ReadWriteLock:${name ?? 'default'}`;
    this.readSemaphore = new Semaphore({ permits: 1, name: `${this.TAG}:read` });
    this.writeSemaphore = new Semaphore({ permits: 1, name: `${this.TAG}:write` });
  }

  /**
   * 获取读锁
   */
  async acquireRead(): Promise<void> {
    await this.readSemaphore.acquire();
    this.readCount++;
    if (this.readCount === 1) {
      // 第一个读者获取写锁
      await this.writeSemaphore.acquire();
    }
    this.readSemaphore.release();
  }

  /**
   * 释放读锁
   */
  releaseRead(): void {
    this.readSemaphore.acquire().then(() => {
      this.readCount--;
      if (this.readCount === 0) {
        // 最后一个读者释放写锁
        this.writeSemaphore.release();
      }
      this.readSemaphore.release();
    });
  }

  /**
   * 获取写锁
   */
  async acquireWrite(): Promise<void> {
    await this.writeSemaphore.acquire();
  }

  /**
   * 释放写锁
   */
  releaseWrite(): void {
    this.writeSemaphore.release();
  }

  /**
   * 尝试在指定时间内获取读锁
   */
  async tryAcquireWithTimeout(timeoutMs: number): Promise<boolean> {
    const startTime: number = Date.now();

    // 尝试获取读信号量
    const readAcquired: boolean = await this.readSemaphore.tryAcquireWithTimeout(timeoutMs);
    if (!readAcquired) {
      return false;
    }

    this.readCount++;
    if (this.readCount === 1) {
      // 第一个读者需要获取写锁
      const remainingTime: number = timeoutMs - (Date.now() - startTime);
      if (remainingTime <= 0) {
        this.readCount--;
        this.readSemaphore.release();
        return false;
      }

      const writeAcquired: boolean = await this.writeSemaphore.tryAcquireWithTimeout(remainingTime);
      if (!writeAcquired) {
        this.readCount--;
        this.readSemaphore.release();
        return false;
      }
    }

    this.readSemaphore.release();
    return true;
  }

  /**
   * 执行读操作
   */
  async read<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquireRead();
    try {
      return await fn();
    } finally {
      this.releaseRead();
    }
  }

  /**
   * 执行写操作
   */
  async write<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquireWrite();
    try {
      return await fn();
    } finally {
      this.releaseWrite();
    }
  }
}

/**
 * 并发控制器 - 管理多个信号量
 */
export class ConcurrencyController {
  private semaphores: Map<string, Semaphore> = new Map();
  private readonly defaultPermits: number;

  constructor(defaultPermits: number = 10) {
    this.defaultPermits = defaultPermits;
  }

  /**
   * 获取或创建信号量
   */
  getSemaphore(name: string, permits?: number): Semaphore {
    let semaphore = this.semaphores.get(name);
    if (!semaphore) {
      semaphore = new Semaphore({
        permits: permits ?? this.defaultPermits,
        name,
      });
      this.semaphores.set(name, semaphore);
    }
    return semaphore;
  }

  /**
   * 获取许可
   */
  async acquire(resource: string): Promise<void> {
    const semaphore = this.getSemaphore(resource);
    await semaphore.acquire();
  }

  /**
   * 释放许可
   */
  release(resource: string): void {
    const semaphore = this.semaphores.get(resource);
    if (semaphore) {
      semaphore.release();
    }
  }

  /**
   * 执行操作
   */
  async execute<T>(resource: string, fn: () => Promise<T>): Promise<T> {
    const semaphore = this.getSemaphore(resource);
    return semaphore.execute(fn);
  }

  /**
   * 获取所有统计信息
   */
  getAllStats(): SemaphoreStats[] {
    const stats: SemaphoreStats[] = [];
    this.semaphores.forEach(semaphore => {
      stats.push(semaphore.getStats());
    });
    return stats;
  }

  /**
   * 清空所有信号量
   */
  clearAll(): void {
    this.semaphores.forEach(semaphore => {
      semaphore.clearQueue();
    });
    this.semaphores.clear();
  }
}

// 导出默认实例
export const globalConcurrencyController = new ConcurrencyController();
