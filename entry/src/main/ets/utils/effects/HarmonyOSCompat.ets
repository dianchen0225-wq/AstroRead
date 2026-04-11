/**
 * HarmonyOS 兼容层
 * 提供 Web API 的 HarmonyOS 等价实现
 */

/**
 * 动画帧回调类型
 */
export type AnimationFrameCallback = (timestamp: number) => void;

/**
 * 动画帧管理器
 * 替代 requestAnimationFrame 和 cancelAnimationFrame
 */
export class AnimationFrameManager {
  private static instance: AnimationFrameManager | null = null;
  private callbacks: Map<number, AnimationFrameCallback> = new Map();
  private nextId: number = 1;
  private isRunning: boolean = false;
  private lastTimestamp: number = 0;

  private constructor() {}

  static getInstance(): AnimationFrameManager {
    if (!AnimationFrameManager.instance) {
      AnimationFrameManager.instance = new AnimationFrameManager();
    }
    return AnimationFrameManager.instance;
  }

  /**
   * 请求动画帧
   * @param callback 回调函数
   * @returns 动画帧 ID
   */
  requestAnimationFrame(callback: AnimationFrameCallback): number {
    const id = this.nextId++;
    this.callbacks.set(id, callback);

    if (!this.isRunning) {
      this.isRunning = true;
      this.lastTimestamp = Date.now();
      this.runFrameLoop();
    }

    return id;
  }

  /**
   * 取消动画帧
   * @param id 动画帧 ID
   */
  cancelAnimationFrame(id: number): void {
    this.callbacks.delete(id);

    if (this.callbacks.size === 0) {
      this.isRunning = false;
    }
  }

  private runFrameLoop(): void {
    if (!this.isRunning) {
      return;
    }

    const currentTimestamp = Date.now();
    const deltaTime = currentTimestamp - this.lastTimestamp;

    // 目标帧率 60fps，约 16.67ms
    if (deltaTime >= 16) {
      this.lastTimestamp = currentTimestamp;

      // 复制回调列表，避免在迭代过程中修改
      const callbacksCopy = new Map(this.callbacks);
      callbacksCopy.forEach((callback) => {
        try {
          callback(currentTimestamp);
        } catch (error) {
          console.error('Animation frame callback error:', error);
        }
      });
    }

    // 使用 setTimeout 模拟下一帧
    setTimeout(() => {
      this.runFrameLoop();
    }, 0);
  }
}

/**
 * 性能计时器
 * 替代 performance.now()
 */
export class PerformanceTimer {
  private static startTime: number = Date.now();

  /**
   * 获取高精度时间戳（毫秒）
   * @returns 时间戳
   */
  static now(): number {
    return Date.now() - PerformanceTimer.startTime;
  }

  /**
   * 重置计时器
   */
  static reset(): void {
    PerformanceTimer.startTime = Date.now();
  }
}

// 全局实例
const animationFrameManager = AnimationFrameManager.getInstance();

/**
 * 请求动画帧（全局函数）
 */
export function requestAnimationFrame(callback: AnimationFrameCallback): number {
  return animationFrameManager.requestAnimationFrame(callback);
}

/**
 * 取消动画帧（全局函数）
 */
export function cancelAnimationFrame(id: number): void {
  animationFrameManager.cancelAnimationFrame(id);
}

/**
 * 性能计时（全局函数）
 */
export function performanceNow(): number {
  return PerformanceTimer.now();
}
