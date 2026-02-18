/**
 * AbortController - 请求取消控制器
 * 支持请求取消和超时控制
 */
import { HttpErrorImpl } from './HttpError';

// 定义自定义事件接口，替代标准 Event
interface CustomEvent {
  readonly type: string;
}

// 定义信号对象接口，避免对象字面量问题
interface AbortSignalImpl extends AbortSignal {
  getAborted(): boolean;
  getReason(): string | null;
}

export interface AbortSignal {
  readonly aborted: boolean;
  readonly reason?: string | null;
  onabort: ((ev: CustomEvent) => void) | null;
  addEventListener(type: 'abort', listener: (ev: CustomEvent) => void): void;
  removeEventListener(type: 'abort', listener: (ev: CustomEvent) => void): void;
  throwIfAborted(): void;
}

export class AbortControllerImpl {
  private _aborted: boolean = false;
  private _reason: string | null = null;
  private _listeners: Set<(ev: CustomEvent) => void> = new Set();
  private _timeoutId: number | null = null;

  get signal(): AbortSignal {
    const self = this;
    
    // 使用类来实现信号对象，避免对象字面量问题
    class SignalImpl implements AbortSignal {
      get aborted(): boolean { return self._aborted; }
      get reason(): string | null { return self._reason; }
      onabort: ((ev: CustomEvent) => void) | null = null;
      addEventListener(type: 'abort', listener: (ev: CustomEvent) => void): void {
        if (type === 'abort') {
          self._listeners.add(listener);
        }
      }
      
      removeEventListener(type: 'abort', listener: (ev: CustomEvent) => void): void {
        if (type === 'abort') {
          self._listeners.delete(listener);
        }
      }
      
      throwIfAborted(): void {
        if (self._aborted) {
          throw HttpErrorImpl.aborted('The operation was aborted');
        }
      }
    }
    
    return new SignalImpl();
  }

  abort(reason?: string | null): void {
    if (this._aborted) {
      return;
    }

    this._aborted = true;
    this._reason = reason || null;

    if (this._timeoutId !== null) {
      clearTimeout(this._timeoutId);
      this._timeoutId = null;
    }

    const event: CustomEvent = { type: 'abort' };
    this._listeners.forEach(listener => {
      try {
        listener(event);
      } catch (e) {
        console.error('Error in abort listener:', e);
      }
    });
  }

  setTimeout(timeout: number): void {
    if (this._timeoutId !== null) {
      clearTimeout(this._timeoutId);
    }

    this._timeoutId = setTimeout(() => {
      if (!this._aborted) {
        this.abort(`Request timeout after ${timeout}ms`);
      }
    }, timeout);
  }

  clearTimeout(): void {
    if (this._timeoutId !== null) {
      clearTimeout(this._timeoutId);
      this._timeoutId = null;
    }
  }

  get aborted(): boolean {
    return this._aborted;
  }

  get reason(): string | null {
    return this._reason;
  }
}

export class AbortManager {
  private static instance: AbortManager | null = null;

  private controllers: Map<string, AbortControllerImpl> = new Map();
  private requestTags: Map<string, Set<string>> = new Map();

  private constructor() {}

  static getInstance(): AbortManager {
    if (!AbortManager.instance) {
      AbortManager.instance = new AbortManager();
    }
    return AbortManager.instance;
  }

  createController(requestId: string, timeout?: number): AbortControllerImpl {
    const controller = new AbortControllerImpl();

    if (timeout && timeout > 0) {
      controller.setTimeout(timeout);
    }

    this.controllers.set(requestId, controller);
    return controller;
  }

  getController(requestId: string): AbortControllerImpl | undefined {
    return this.controllers.get(requestId);
  }

  abort(requestId: string, reason?: string | null): boolean {
    const controller = this.controllers.get(requestId);
    if (controller && !controller.aborted) {
      controller.abort(reason);
      this.controllers.delete(requestId);
      return true;
    }
    return false;
  }

  abortAll(reason?: string | null): void {
    this.controllers.forEach((controller, id) => {
      if (!controller.aborted) {
        controller.abort(reason);
      }
    });
    this.controllers.clear();
  }

  tagRequest(requestId: string, tag: string): void {
    if (!this.requestTags.has(tag)) {
      this.requestTags.set(tag, new Set());
    }
    const tagSet = this.requestTags.get(tag);
    if (tagSet) {
      tagSet.add(requestId);
    }
  }

  abortByTag(tag: string, reason?: string | null): number {
    const requestIds = this.requestTags.get(tag);
    if (!requestIds) {
      return 0;
    }

    let count = 0;
    requestIds.forEach(requestId => {
      if (this.abort(requestId, reason)) {
        count++;
      }
    });

    this.requestTags.delete(tag);
    return count;
  }

  removeController(requestId: string): void {
    const controller = this.controllers.get(requestId);
    if (controller) {
      controller.clearTimeout();
      this.controllers.delete(requestId);
    }
  }

  cleanup(): void {
    this.controllers.forEach((controller, id) => {
      if (controller.aborted) {
        controller.clearTimeout();
        this.controllers.delete(id);
      }
    });
  }

  getActiveCount(): number {
    let count = 0;
    this.controllers.forEach(controller => {
      if (!controller.aborted) {
        count++;
      }
    });
    return count;
  }

  getActiveRequestIds(): string[] {
    const ids: string[] = [];
    this.controllers.forEach((controller, id) => {
      if (!controller.aborted) {
        ids.push(id);
      }
    });
    return ids;
  }
}

export default AbortManager.getInstance();