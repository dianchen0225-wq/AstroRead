import { Result, ErrorCode } from "../../core/Result";
import { CrawlTask, TaskPriority, IPriorityScheduler } from "./interfaces/IConcurrency";
import { CrawlErrorCode } from "./models/CrawlError";
import { Logger } from "../performance/Logger";

interface HeapEntry {
  task: CrawlTask;
  insertOrder: number;
}

export class PriorityScheduler implements IPriorityScheduler {
  private static readonly TAG = 'PriorityScheduler';

  private heap: HeapEntry[] = [];
  private capacity: number;
  private insertCounter: number = 0;

  constructor(capacity: number = 10000) {
    this.capacity = capacity;
  }

  enqueue(task: CrawlTask): Result<void> {
    if (this.heap.length >= this.capacity) {
      return Result.err(ErrorCode.VALIDATION_OUT_OF_RANGE,
        CrawlErrorCode.QUEUE_FULL.toString());
    }

    const entry: HeapEntry = {
      task: task,
      insertOrder: this.insertCounter++,
    };

    this.heap.push(entry);
    this.siftUp(this.heap.length - 1);
    Logger.debug(PriorityScheduler.TAG, `Enqueued task ${task.id} with priority ${task.priority}`);
    return Result.ok(undefined);
  }

  dequeue(): CrawlTask | null {
    if (this.heap.length === 0) {
      return null;
    }

    const top = this.heap[0];
    const last = this.heap.pop()!;

    if (this.heap.length > 0) {
      this.heap[0] = last;
      this.siftDown(0);
    }

    Logger.debug(PriorityScheduler.TAG, `Dequeued task ${top.task.id}`);
    return top.task;
  }

  peek(): CrawlTask | null {
    return this.heap.length > 0 ? this.heap[0].task : null;
  }

  size(): number {
    return this.heap.length;
  }

  clear(): void {
    this.heap = [];
    this.insertCounter = 0;
  }

  isFull(): boolean {
    return this.heap.length >= this.capacity;
  }

  private siftUp(index: number): void {
    while (index > 0) {
      const parentIndex = Math.floor((index - 1) / 2);
      if (this.compare(this.heap[index], this.heap[parentIndex]) < 0) {
        this.swap(index, parentIndex);
        index = parentIndex;
      } else {
        break;
      }
    }
  }

  private siftDown(index: number): void {
    const length = this.heap.length;
    while (true) {
      let smallest = index;
      const left = 2 * index + 1;
      const right = 2 * index + 2;

      if (left < length && this.compare(this.heap[left], this.heap[smallest]) < 0) {
        smallest = left;
      }
      if (right < length && this.compare(this.heap[right], this.heap[smallest]) < 0) {
        smallest = right;
      }

      if (smallest !== index) {
        this.swap(index, smallest);
        index = smallest;
      } else {
        break;
      }
    }
  }

  private compare(a: HeapEntry, b: HeapEntry): number {
    if (a.task.priority !== b.task.priority) {
      return a.task.priority - b.task.priority;
    }
    return a.insertOrder - b.insertOrder;
  }

  private swap(i: number, j: number): void {
    const temp = this.heap[i];
    this.heap[i] = this.heap[j];
    this.heap[j] = temp;
  }
}
