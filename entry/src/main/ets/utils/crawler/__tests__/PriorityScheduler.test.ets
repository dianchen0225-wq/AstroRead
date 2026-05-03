import { PriorityScheduler } from '../PriorityScheduler';
import { TaskPriority, CrawlTask } from '../interfaces/IConcurrency';
import { Result } from '../../../core/Result';

export class PrioritySchedulerTest {
  private passed: number = 0;
  private failed: number = 0;

  runAll(): void {
    console.log('=== PriorityScheduler Tests ===');

    this.testPriorityOrder();
    this.testQueueFull();
    this.testEmptyDequeue();
    this.testFifoSamePriority();

    console.log(`\nResults: ${this.passed} passed, ${this.failed} failed`);
  }

  private testPriorityOrder(): void {
    const scheduler = new PriorityScheduler(100);

    const lowTask: CrawlTask = { id: 'low', url: '', rule: '', priority: TaskPriority.LOW, createdAt: Date.now(), retryCount: 0 };
    const highTask: CrawlTask = { id: 'high', url: '', rule: '', priority: TaskPriority.HIGH, createdAt: Date.now(), retryCount: 0 };
    const normalTask: CrawlTask = { id: 'normal', url: '', rule: '', priority: TaskPriority.NORMAL, createdAt: Date.now(), retryCount: 0 };

    scheduler.enqueue(lowTask);
    scheduler.enqueue(highTask);
    scheduler.enqueue(normalTask);

    const first = scheduler.dequeue();
    const second = scheduler.dequeue();
    const third = scheduler.dequeue();

    this.assertString('HIGH priority dequeued first', first !== null ? first.id : undefined, 'high');
    this.assertString('NORMAL priority dequeued second', second !== null ? second.id : undefined, 'normal');
    this.assertString('LOW priority dequeued third', third !== null ? third.id : undefined, 'low');
  }

  private testQueueFull(): void {
    const scheduler = new PriorityScheduler(2);
    const task: CrawlTask = { id: 't', url: '', rule: '', priority: TaskPriority.NORMAL, createdAt: Date.now(), retryCount: 0 };

    scheduler.enqueue(task);
    scheduler.enqueue(task);

    const result = scheduler.enqueue(task);
    this.assertBoolean('Queue full returns error', result.isErr(), true);
  }

  private testEmptyDequeue(): void {
    const scheduler = new PriorityScheduler(100);
    const result = scheduler.dequeue();
    this.assertNull('Empty queue returns null', result);
  }

  private testFifoSamePriority(): void {
    const scheduler = new PriorityScheduler(100);

    const t1: CrawlTask = { id: 'first', url: '', rule: '', priority: TaskPriority.NORMAL, createdAt: Date.now(), retryCount: 0 };
    const t2: CrawlTask = { id: 'second', url: '', rule: '', priority: TaskPriority.NORMAL, createdAt: Date.now(), retryCount: 0 };

    scheduler.enqueue(t1);
    scheduler.enqueue(t2);

    const first = scheduler.dequeue();
    const second = scheduler.dequeue();
    this.assertString('FIFO order for same priority', first !== null ? first.id : undefined, 'first');
    this.assertString('FIFO second item', second !== null ? second.id : undefined, 'second');
  }

  private assertString(name: string, actual: string | undefined, expected: string | undefined): void {
    if (actual === expected) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected ${expected}, got ${actual}`);
    }
  }

  private assertBoolean(name: string, actual: boolean, expected: boolean): void {
    if (actual === expected) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected ${expected}, got ${actual}`);
    }
  }

  private assertNull(name: string, actual: CrawlTask | null): void {
    if (actual === null) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected null, got non-null`);
    }
  }
}
