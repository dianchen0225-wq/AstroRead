export interface DebounceHandle {
  call: () => void;
  cancel: () => void;
}

export interface DebounceWithArgHandle<T> {
  call: (arg: T) => void;
  cancel: () => void;
}

export interface ThrottleHandle {
  call: () => void;
  cancel: () => void;
}

export class DebounceThrottleUtil {
  static debounce(fn: () => void, delay: number): DebounceHandle {
    let timerId: number | null = null;

    const handle: DebounceHandle = {
      call: () => {
        if (timerId !== null) {
          clearTimeout(timerId);
        }
        timerId = setTimeout(() => {
          fn();
          timerId = null;
        }, delay);
      },
      cancel: () => {
        if (timerId !== null) {
          clearTimeout(timerId);
          timerId = null;
        }
      }
    };
    return handle;
  }

  static debounceWithArg<T>(fn: (arg: T) => void, delay: number): DebounceWithArgHandle<T> {
    let timerId: number | null = null;
    let lastArg: T | null = null;

    const handle: DebounceWithArgHandle<T> = {
      call: (arg: T) => {
        lastArg = arg;
        if (timerId !== null) {
          clearTimeout(timerId);
        }
        timerId = setTimeout(() => {
          if (lastArg !== null) {
            fn(lastArg);
          }
          timerId = null;
          lastArg = null;
        }, delay);
      },
      cancel: () => {
        if (timerId !== null) {
          clearTimeout(timerId);
          timerId = null;
        }
        lastArg = null;
      }
    };
    return handle;
  }

  static throttle(fn: () => void, interval: number): ThrottleHandle {
    let lastExecTime: number = 0;
    let timerId: number | null = null;

    const handle: ThrottleHandle = {
      call: () => {
        const now = Date.now();
        const elapsed = now - lastExecTime;

        if (elapsed >= interval) {
          lastExecTime = now;
          fn();
        } else {
          if (timerId !== null) {
            clearTimeout(timerId);
          }
          timerId = setTimeout(() => {
            lastExecTime = Date.now();
            fn();
            timerId = null;
          }, interval - elapsed);
        }
      },
      cancel: () => {
        if (timerId !== null) {
          clearTimeout(timerId);
          timerId = null;
        }
      }
    };
    return handle;
  }
}
