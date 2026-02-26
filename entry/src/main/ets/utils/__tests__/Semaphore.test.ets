/**
 * Semaphore 单元测试
 * 测试信号量并发控制功能
 */

import { Semaphore, ReadWriteLock, ConcurrencyController, SemaphoreStats } from '../performance/Semaphore';

export class SemaphoreTest {
  passed: number = 0;
  failed: number = 0;

  /**
   * 测试基本信号量功能
   */
  async testBasicSemaphore(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 2, name: 'test-basic' });

    try {
      // 测试初始状态
      if (semaphore.availablePermits() !== 2) {
        console.error('❌ testBasicSemaphore: 初始许可数错误');
        this.failed++;
        return false;
      }

      // 测试获取许可
      await semaphore.acquire();
      if (semaphore.availablePermits() !== 1) {
        console.error('❌ testBasicSemaphore: 获取许可后数量错误');
        this.failed++;
        return false;
      }

      // 测试释放许可
      semaphore.release();
      if (semaphore.availablePermits() !== 2) {
        console.error('❌ testBasicSemaphore: 释放许可后数量错误');
        this.failed++;
        return false;
      }

      console.log('✅ testBasicSemaphore passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testBasicSemaphore: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试信号量阻塞
   */
  async testSemaphoreBlocking(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 1, name: 'test-blocking' });

    try {
      // 获取唯一许可
      await semaphore.acquire();

      // 尝试非阻塞获取（应该失败）
      const acquired: boolean = semaphore.tryAcquire();
      if (acquired) {
        console.error('❌ testSemaphoreBlocking: 应该无法获取许可');
        this.failed++;
        return false;
      }

      // 释放许可
      semaphore.release();

      // 现在应该可以获取
      const acquired2: boolean = semaphore.tryAcquire();
      if (!acquired2) {
        console.error('❌ testSemaphoreBlocking: 应该可以获取许可');
        this.failed++;
        return false;
      }

      semaphore.release();

      console.log('✅ testSemaphoreBlocking passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testSemaphoreBlocking: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试带超时的获取
   */
  async testTryAcquireWithTimeout(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 1, name: 'test-timeout' });

    try {
      // 获取唯一许可
      await semaphore.acquire();

      // 尝试带超时的获取（应该超时）
      const startTime: number = Date.now();
      const acquired: boolean = await semaphore.tryAcquireWithTimeout(100);
      const endTime: number = Date.now();

      if (acquired) {
        console.error('❌ testTryAcquireWithTimeout: 应该超时');
        this.failed++;
        return false;
      }

      if (endTime - startTime < 90 || endTime - startTime > 200) {
        console.error(`❌ testTryAcquireWithTimeout: 超时时间不准确 (${endTime - startTime}ms)`);
        this.failed++;
        return false;
      }

      // 释放并重新获取
      semaphore.release();
      const acquired2: boolean = await semaphore.tryAcquireWithTimeout(100);
      if (!acquired2) {
        console.error('❌ testTryAcquireWithTimeout: 应该成功获取');
        this.failed++;
        return false;
      }

      semaphore.release();

      console.log('✅ testTryAcquireWithTimeout passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testTryAcquireWithTimeout: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试execute方法
   */
  async testExecute(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 1, name: 'test-execute' });
    let executed: boolean = false;

    try {
      const result: string = await semaphore.execute(async () => {
        executed = true;
        return 'success';
      });

      if (!executed) {
        console.error('❌ testExecute: 函数未执行');
        this.failed++;
        return false;
      }

      if (result !== 'success') {
        console.error('❌ testExecute: 返回值错误');
        this.failed++;
        return false;
      }

      // 验证许可已释放
      if (semaphore.availablePermits() !== 1) {
        console.error('❌ testExecute: 许可未释放');
        this.failed++;
        return false;
      }

      console.log('✅ testExecute passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testExecute: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试批量操作
   */
  async testBatchOperations(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 3, name: 'test-batch' });

    try {
      // 批量获取
      await semaphore.acquireMany(2);
      if (semaphore.availablePermits() !== 1) {
        console.error('❌ testBatchOperations: 批量获取后数量错误');
        this.failed++;
        return false;
      }

      // 批量释放
      semaphore.releaseMany(2);
      if (semaphore.availablePermits() !== 3) {
        console.error('❌ testBatchOperations: 批量释放后数量错误');
        this.failed++;
        return false;
      }

      console.log('✅ testBatchOperations passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testBatchOperations: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试动态调整许可数
   */
  async testDynamicPermits(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 2, name: 'test-dynamic' });

    try {
      // 减少许可
      semaphore.reducePermits(1);
      if (semaphore.availablePermits() !== 1) {
        console.error('❌ testDynamicPermits: 减少许可后数量错误');
        this.failed++;
        return false;
      }

      // 增加许可
      semaphore.increasePermits(1);
      if (semaphore.availablePermits() !== 2) {
        console.error('❌ testDynamicPermits: 增加许可后数量错误');
        this.failed++;
        return false;
      }

      console.log('✅ testDynamicPermits passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testDynamicPermits: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试读写锁
   */
  async testReadWriteLock(): Promise<boolean> {
    const rwLock: ReadWriteLock = new ReadWriteLock('test-rw');

    try {
      // 测试读锁（应该允许多个）
      await rwLock.acquireRead();
      await rwLock.acquireRead(); // 第二个读锁应该成功

      // 释放读锁
      rwLock.releaseRead();
      rwLock.releaseRead();

      // 测试写锁
      await rwLock.acquireWrite();

      // 尝试获取读锁（应该阻塞）
      const readAcquired: boolean = await Promise.race([
        rwLock.tryAcquireWithTimeout(50),
        new Promise<boolean>((resolve: (value: boolean) => void) => setTimeout(() => resolve(false), 100))
      ]);

      if (readAcquired) {
        console.error('❌ testReadWriteLock: 写锁持有时不应获取读锁');
        this.failed++;
        return false;
      }

      rwLock.releaseWrite();

      console.log('✅ testReadWriteLock passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testReadWriteLock: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试并发控制器
   */
  async testConcurrencyController(): Promise<boolean> {
    const controller: ConcurrencyController = new ConcurrencyController(2);

    try {
      // 获取信号量
      await controller.acquire('resource1');

      // 执行操作
      const result: string = await controller.execute('resource2', async () => {
        return 'executed';
      });

      if (result !== 'executed') {
        console.error('❌ testConcurrencyController: 执行结果错误');
        this.failed++;
        return false;
      }

      // 释放资源
      controller.release('resource1');

      // 获取统计
      const stats: SemaphoreStats[] = controller.getAllStats();
      if (stats.length !== 2) {
        console.error('❌ testConcurrencyController: 统计数量错误');
        this.failed++;
        return false;
      }

      console.log('✅ testConcurrencyController passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testConcurrencyController: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 测试统计信息
   */
  async testStatistics(): Promise<boolean> {
    const semaphore: Semaphore = new Semaphore({ permits: 2, name: 'test-stats' });

    try {
      // 获取并释放几次
      await semaphore.acquire();
      semaphore.release();
      await semaphore.acquire();
      semaphore.release();

      const stats: SemaphoreStats = semaphore.getStats();

      if (stats.name !== 'Semaphore:test-stats') {
        console.error('❌ testStatistics: 名称错误');
        this.failed++;
        return false;
      }

      if (stats.totalPermits !== 2) {
        console.error('❌ testStatistics: 总许可数错误');
        this.failed++;
        return false;
      }

      if (stats.acquiredCount !== 2) {
        console.error('❌ testStatistics: 获取次数错误');
        this.failed++;
        return false;
      }

      if (stats.releasedCount !== 2) {
        console.error('❌ testStatistics: 释放次数错误');
        this.failed++;
        return false;
      }

      console.log('✅ testStatistics passed');
      this.passed++;
      return true;
    } catch (err) {
      const errorMessage: string = err instanceof Error ? err.message : String(err);
      console.error(`❌ testStatistics: 异常 ${errorMessage}`);
      this.failed++;
      return false;
    }
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting Semaphore tests...\n');

    await this.testBasicSemaphore();
    await this.testSemaphoreBlocking();
    await this.testTryAcquireWithTimeout();
    await this.testExecute();
    await this.testBatchOperations();
    await this.testDynamicPermits();
    await this.testReadWriteLock();
    await this.testConcurrencyController();
    await this.testStatistics();

    const total: number = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);

    if (this.failed > 0) {
      console.log(`❌ ${this.failed} tests failed`);
    } else {
      console.log('✅ All tests passed!');
    }

    return this.failed === 0;
  }
}

// 导出测试实例
const semaphoreTest: SemaphoreTest = new SemaphoreTest();
export default semaphoreTest;
