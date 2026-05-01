import { Logger } from '../performance/Logger';
import { DesignSystem } from '../../common/DesignSystem';
import { themeManager } from '../../common/ThemeManager';

export interface GestureConfig {
  swipeUpHoldEnabled: boolean;
  swipeUpHoldThreshold: number;
  swipeUpHoldTimeout: number;
  edgeSwipeHoldEnabled: boolean;
  edgeSwipeThreshold: number;
  edgeSwipeHoldTimeout: number;
  edgeSwipeZoneWidth: number;
  kioskMode: boolean;
  gestureDetectionAccuracy: number;
}

export type GestureDirection = 'up' | 'down' | 'left' | 'right';

export interface GestureEvent {
  type: 'swipe_up_hold' | 'edge_swipe_hold' | 'pan' | 'long_press';
  direction: GestureDirection;
  startX: number;
  startY: number;
  currentX: number;
  currentY: number;
  velocityX: number;
  velocityY: number;
  duration: number;
  isComplete: boolean;
}

export type GestureCallback = (event: GestureEvent) => void;

const DEFAULT_GESTURE_CONFIG: GestureConfig = {
  swipeUpHoldEnabled: true,
  swipeUpHoldThreshold: 80,
  swipeUpHoldTimeout: 500,
  edgeSwipeHoldEnabled: true,
  edgeSwipeThreshold: 60,
  edgeSwipeHoldTimeout: 400,
  edgeSwipeZoneWidth: 24,
  kioskMode: false,
  gestureDetectionAccuracy: 0.95
};

export class GestureController {
  private static instance: GestureController;
  private config: GestureConfig = DEFAULT_GESTURE_CONFIG;
  private callbacks: GestureCallback[] = [];
  private activeGestures: Map<string, GestureEvent> = new Map();
  private gestureTimers: Map<string, number> = new Map();
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private touchStartTime: number = 0;
  private isPanning: boolean = false;
  private panDirection: GestureDirection | null = null;
  private screenWidth: number = 360;
  private screenHeight: number = 780;

  private readonly TAG = 'GestureController';

  private constructor() {}

  static getInstance(): GestureController {
    if (!GestureController.instance) {
      GestureController.instance = new GestureController();
    }
    return GestureController.instance;
  }

  setConfig(config: Partial<GestureConfig>): void {
    if (config.swipeUpHoldEnabled !== undefined) this.config.swipeUpHoldEnabled = config.swipeUpHoldEnabled;
    if (config.swipeUpHoldThreshold !== undefined) this.config.swipeUpHoldThreshold = config.swipeUpHoldThreshold;
    if (config.swipeUpHoldTimeout !== undefined) this.config.swipeUpHoldTimeout = config.swipeUpHoldTimeout;
    if (config.edgeSwipeHoldEnabled !== undefined) this.config.edgeSwipeHoldEnabled = config.edgeSwipeHoldEnabled;
    if (config.edgeSwipeThreshold !== undefined) this.config.edgeSwipeThreshold = config.edgeSwipeThreshold;
    if (config.edgeSwipeHoldTimeout !== undefined) this.config.edgeSwipeHoldTimeout = config.edgeSwipeHoldTimeout;
    if (config.edgeSwipeZoneWidth !== undefined) this.config.edgeSwipeZoneWidth = config.edgeSwipeZoneWidth;
    if (config.kioskMode !== undefined) this.config.kioskMode = config.kioskMode;
    if (config.gestureDetectionAccuracy !== undefined) this.config.gestureDetectionAccuracy = config.gestureDetectionAccuracy;
    Logger.info(this.TAG, `手势配置更新: kiosk=${this.config.kioskMode}`);
  }

  getConfig(): GestureConfig {
    return {
      swipeUpHoldEnabled: this.config.swipeUpHoldEnabled,
      swipeUpHoldThreshold: this.config.swipeUpHoldThreshold,
      swipeUpHoldTimeout: this.config.swipeUpHoldTimeout,
      edgeSwipeHoldEnabled: this.config.edgeSwipeHoldEnabled,
      edgeSwipeThreshold: this.config.edgeSwipeThreshold,
      edgeSwipeHoldTimeout: this.config.edgeSwipeHoldTimeout,
      edgeSwipeZoneWidth: this.config.edgeSwipeZoneWidth,
      kioskMode: this.config.kioskMode,
      gestureDetectionAccuracy: this.config.gestureDetectionAccuracy
    };
  }

  setScreenSize(width: number, height: number): void {
    this.screenWidth = width;
    this.screenHeight = height;
  }

  addCallback(callback: GestureCallback): void {
    this.callbacks.push(callback);
  }

  removeCallback(callback: GestureCallback): void {
    const index = this.callbacks.indexOf(callback);
    if (index > -1) {
      this.callbacks.splice(index, 1);
    }
  }

  handleTouchStart(x: number, y: number): void {
    this.lastTouchX = x;
    this.lastTouchY = y;
    this.touchStartTime = Date.now();
    this.isPanning = false;
    this.panDirection = null;
  }

  handleTouchMove(x: number, y: number): GestureEvent | null {
    const deltaX = x - this.lastTouchX;
    const deltaY = y - this.lastTouchY;
    const elapsed = Date.now() - this.touchStartTime;
    const absDx = Math.abs(deltaX);
    const absDy = Math.abs(deltaY);

    if (!this.isPanning && (absDx > 8 || absDy > 8)) {
      this.isPanning = true;

      if (absDx > absDy) {
        this.panDirection = deltaX > 0 ? 'right' : 'left';
      } else {
        this.panDirection = deltaY > 0 ? 'down' : 'up';
      }
    }

    if (this.isPanning && this.panDirection) {
      // 上划停留检测
      if (this.config.swipeUpHoldEnabled && this.panDirection === 'up') {
        const upwardDistance = -deltaY;

        if (upwardDistance >= this.config.swipeUpHoldThreshold) {
          // 从底部区域上划
          const isFromBottom = this.lastTouchY > this.screenHeight * 0.7;

          if (isFromBottom || this.config.kioskMode) {
            const gestureId = 'swipe_up_hold';
            const existing = this.activeGestures.get(gestureId);

            if (!existing || !existing.isComplete) {
              const event: GestureEvent = {
                type: 'swipe_up_hold',
                direction: 'up',
                startX: this.lastTouchX,
                startY: this.lastTouchY,
                currentX: x,
                currentY: y,
                velocityX: absDx / elapsed * 1000,
                velocityY: absDy / elapsed * 1000,
                duration: elapsed,
                isComplete: elapsed >= this.config.swipeUpHoldTimeout
              };

              // 延迟确认（停留检测）
              if (elapsed >= this.config.swipeUpHoldTimeout) {
                event.isComplete = true;
                this.activeGestures.set(gestureId, event);
                this.dispatchGesture(event);
                return event;
              }

              this.activeGestures.set(gestureId, event);
            }
          }
        }
      }

      // 边缘内划停留检测
      if (this.config.edgeSwipeHoldEnabled) {
        const isFromLeftEdge = this.lastTouchX <= this.config.edgeSwipeZoneWidth;
        const isFromRightEdge = this.lastTouchX >= this.screenWidth - this.config.edgeSwipeZoneWidth;

        if (isFromLeftEdge && this.panDirection === 'right') {
          const gestureId = 'edge_swipe_left';
          return this.processEdgeGesture(gestureId, 'left', x, y, absDx, elapsed);
        }

        if (isFromRightEdge && this.panDirection === 'left') {
          const gestureId = 'edge_swipe_right';
          return this.processEdgeGesture(gestureId, 'right', x, y, absDx, elapsed);
        }
      }
    }

    this.lastTouchX = x;
    this.lastTouchY = y;
    return null;
  }

  private processEdgeGesture(
    gestureId: string,
    edge: string,
    x: number,
    y: number,
    distance: number,
    elapsed: number
  ): GestureEvent | null {
    if (distance >= this.config.edgeSwipeThreshold) {
      const event: GestureEvent = {
        type: 'edge_swipe_hold',
        direction: edge === 'left' ? 'right' : 'left',
        startX: this.lastTouchX,
        startY: this.lastTouchY,
        currentX: x,
        currentY: y,
        velocityX: distance / elapsed * 1000,
        velocityY: 0,
        duration: elapsed,
        isComplete: elapsed >= this.config.edgeSwipeHoldTimeout
      };

      if (elapsed >= this.config.edgeSwipeHoldTimeout) {
        event.isComplete = true;
        this.activeGestures.set(gestureId, event);
        this.dispatchGesture(event);
      }

      return event;
    }

    return null;
  }

  handleTouchEnd(): void {
    // 清除所有不完整的手势
    const completedGestures: GestureEvent[] = [];
    this.activeGestures.forEach((gesture, id) => {
      if (gesture.isComplete) {
        completedGestures.push(gesture);
      }
    });
    this.activeGestures.clear();

    this.isPanning = false;
    this.panDirection = null;
  }

  simulateSwipeUpHold(): void {
    if (!this.config.swipeUpHoldEnabled) return;

    const event: GestureEvent = {
      type: 'swipe_up_hold',
      direction: 'up',
      startX: this.screenWidth / 2,
      startY: this.screenHeight * 0.85,
      currentX: this.screenWidth / 2,
      currentY: this.screenHeight * 0.5,
      velocityX: 0,
      velocityY: 300,
      duration: this.config.swipeUpHoldTimeout,
      isComplete: true
    };

    this.dispatchGesture(event);
  }

  simulateEdgeSwipe(side: 'left' | 'right'): void {
    if (!this.config.edgeSwipeHoldEnabled) return;

    const startX = side === 'left' ? 4 : this.screenWidth - 4;
    const event: GestureEvent = {
      type: 'edge_swipe_hold',
      direction: side === 'left' ? 'right' : 'left',
      startX: startX,
      startY: this.screenHeight / 2,
      currentX: side === 'left' ? 180 : this.screenWidth - 180,
      currentY: this.screenHeight / 2,
      velocityX: 400,
      velocityY: 0,
      duration: this.config.edgeSwipeHoldTimeout,
      isComplete: true
    };

    this.dispatchGesture(event);
  }

  private dispatchGesture(event: GestureEvent): void {
    Logger.info(this.TAG,
      `手势触发: ${event.type}, 方向=${event.direction}, ` +
      `耗时=${event.duration}ms`
    );

    for (const callback of this.callbacks) {
      try {
        callback(event);
      } catch (error) {
        Logger.error(this.TAG, `手势回调异常: ${error}`);
      }
    }
  }

  isInKioskMode(): boolean {
    return this.config.kioskMode;
  }

  setKioskMode(enabled: boolean): void {
    this.config.kioskMode = enabled;
    this.config.swipeUpHoldEnabled = true;
    this.config.edgeSwipeHoldEnabled = true;
    Logger.info(this.TAG, `Kiosk模式: ${enabled ? '启用' : '禁用'}`);
  }

  reset(): void {
    this.activeGestures.clear();
    this.callbacks = [];
    this.isPanning = false;
    this.panDirection = null;
  }
}

export const gestureController = GestureController.getInstance();
