import { Logger } from './Logger';
import { ParseTaskQueue, ParseTaskType, ParseTaskPriority, ParseTaskResult } from './ParseTaskQueue';

export interface AsyncTaskOptions {
  timeout: number;
  priority: ParseTaskPriority;
  retryCount: number;
  retryDelay: number;
  onCancelled?: () => void;
}

const DEFAULT_OPTIONS: AsyncTaskOptions = {
  timeout: 30000,
  priority: ParseTaskPriority.NORMAL,
  retryCount: 3,
  retryDelay: 1000
};

export class MainThreadGuard {
  private static instance: MainThreadGuard | null = null;
  private parseTaskQueue: ParseTaskQueue = ParseTaskQueue.getInstance();

  private constructor() {}

  static getInstance(): MainThreadGuard {
    if (!MainThreadGuard.instance) {
      MainThreadGuard.instance = new MainThreadGuard();
    }
    return MainThreadGuard.instance;
  }

  async executeAsync<T>(
    task: () => Promise<T>,
    options?: Partial<AsyncTaskOptions>
  ): Promise<T> {
    const opts: AsyncTaskOptions = { ...DEFAULT_OPTIONS, ...options };

    return new Promise<T>((resolve, reject) => {
      let completed = false;
      let retryCount = 0;

      const timeoutId = setTimeout(() => {
        if (!completed) {
          completed = true;
          opts.onCancelled?.();
          reject(new Error(`任务超时: ${opts.timeout}ms`));
        }
      }, opts.timeout);

      const attemptExecution = (): void => {
        task()
          .then((result: T) => {
            if (!completed) {
              completed = true;
              clearTimeout(timeoutId);
              resolve(result);
            }
          })
          .catch((error: Error) => {
            if (completed) return;

            retryCount++;
            if (retryCount < opts.retryCount) {
              const delay = opts.retryDelay * Math.pow(2, retryCount - 1);
              Logger.warn('MainThreadGuard', `任务失败，${delay}ms后重试 (${retryCount}/${opts.retryCount})`);
              setTimeout(attemptExecution, delay);
            } else {
              completed = true;
              clearTimeout(timeoutId);
              reject(error);
            }
          });
      };

      attemptExecution();
    });
  }

  wrapViewModelMethod<T extends (...args: ESObject[]) => Promise<ESObject>>(
    method: T,
    options?: Partial<AsyncTaskOptions>
  ): (...args: ESObject[]) => Promise<ESObject> {
    return (...args: ESObject[]): Promise<ESObject> => {
      return this.executeAsync(() => method(...args), options);
    };
  }
}
