import { DesignSystem } from '../../common/DesignSystem';

export enum CapsuleMorphState {
  FULL = 'full',
  THIN_LINE = 'thin_line',
  HIDDEN = 'hidden'
}

export enum ScrollDirection {
  UP = 'up',
  DOWN = 'down',
  NONE = 'none'
}

export enum DeviceLayoutMode {
  PORTRAIT_PHONE = 'portrait_phone',
  LANDSCAPE_TABLET = 'landscape_tablet',
  FOLDABLE_EXPANDED = 'foldable_expanded'
}

export interface CapsuleState {
  morphState: CapsuleMorphState;
  isDeepReading: boolean;
  consecutivePagesScrolled: number;
  currentOpacity: number;
  currentVelocity: number;
  scrollDirection: ScrollDirection;
  isReadingPage: boolean;
  chapterProgress: number;
  brightnessValue: number;
  fontSizeValue: number;
  showBookmarkDot: boolean;
  isLandscape: boolean;
  isLightMode: boolean;
  screenWidth: number;
  screenHeight: number;
  deviceLayoutMode: DeviceLayoutMode;
  swipeUpDistance: number;
  isSystemGestureActive: boolean;
  isPetalMenuOpen: boolean;
  isBookmarkLineDragging: boolean;
  bookmarkLineLength: number;
  isBreathTransitioning: boolean;
  breathBrightness: number;
  isInkEffectActive: boolean;
}

export class CapsuleStateStore {
  private static instance: CapsuleStateStore;

  morphState: CapsuleMorphState = CapsuleMorphState.FULL;
  isDeepReading: boolean = false;
  consecutivePagesScrolled: number = 0;
  currentOpacity: number = 1.0;
  currentVelocity: number = 0;
  scrollDirection: ScrollDirection = ScrollDirection.NONE;
  isReadingPage: boolean = false;
  chapterProgress: number = 0;
  brightnessValue: number = 50;
  fontSizeValue: number = 16;
  showBookmarkDot: boolean = false;
  isLandscape: boolean = false;
  isLightMode: boolean = true;
  screenWidth: number = 360;
  screenHeight: number = 780;
  deviceLayoutMode: DeviceLayoutMode = DeviceLayoutMode.PORTRAIT_PHONE;
  swipeUpDistance: number = 0;
  isSystemGestureActive: boolean = false;
  isPetalMenuOpen: boolean = false;
  isBookmarkLineDragging: boolean = false;
  bookmarkLineLength: number = 0;
  isBreathTransitioning: boolean = false;
  breathBrightness: number = 1.0;
  isInkEffectActive: boolean = true;

  private throttleTimers: Map<string, number> = new Map();
  private readonly THROTTLE_INTERVAL = 16;

  private constructor() {}

  static getInstance(): CapsuleStateStore {
    if (!CapsuleStateStore.instance) {
      CapsuleStateStore.instance = new CapsuleStateStore();
    }
    return CapsuleStateStore.instance;
  }

  getState(): CapsuleState {
    return {
      morphState: this.morphState,
      isDeepReading: this.isDeepReading,
      consecutivePagesScrolled: this.consecutivePagesScrolled,
      currentOpacity: this.currentOpacity,
      currentVelocity: this.currentVelocity,
      scrollDirection: this.scrollDirection,
      isReadingPage: this.isReadingPage,
      chapterProgress: this.chapterProgress,
      brightnessValue: this.brightnessValue,
      fontSizeValue: this.fontSizeValue,
      showBookmarkDot: this.showBookmarkDot,
      isLandscape: this.isLandscape,
      isLightMode: this.isLightMode,
      screenWidth: this.screenWidth,
      screenHeight: this.screenHeight,
      deviceLayoutMode: this.deviceLayoutMode,
      swipeUpDistance: this.swipeUpDistance,
      isSystemGestureActive: this.isSystemGestureActive,
      isPetalMenuOpen: this.isPetalMenuOpen,
      isBookmarkLineDragging: this.isBookmarkLineDragging,
      bookmarkLineLength: this.bookmarkLineLength,
      isBreathTransitioning: this.isBreathTransitioning,
      breathBrightness: this.breathBrightness,
      isInkEffectActive: this.isInkEffectActive
    };
  }

  updateOpacityThrottled(opacity: number): void {
    const key = 'opacity';
    const now = Date.now();
    const lastTime = this.throttleTimers.get(key) || 0;
    if (now - lastTime >= this.THROTTLE_INTERVAL) {
      this.currentOpacity = Math.max(0, Math.min(1, opacity));
      this.throttleTimers.set(key, now);
    }
  }

  updateVelocityThrottled(velocity: number): void {
    const key = 'velocity';
    const now = Date.now();
    const lastTime = this.throttleTimers.get(key) || 0;
    if (now - lastTime >= this.THROTTLE_INTERVAL) {
      this.currentVelocity = Math.max(0, velocity);
      this.throttleTimers.set(key, now);
    }
  }

  incrementConsecutivePages(): void {
    this.consecutivePagesScrolled++;
    if (this.consecutivePagesScrolled >= 3 && !this.isDeepReading) {
      this.isDeepReading = true;
    }
  }

  resetDeepReading(): void {
    this.isDeepReading = false;
    this.consecutivePagesScrolled = 0;
  }

  updateDeviceLayout(width: number, height: number): void {
    this.screenWidth = width;
    this.screenHeight = height;
    this.isLandscape = width > height;

    if (this.isLandscape && width >= DesignSystem.CapsuleSideLying.minScreenWidth) {
      this.deviceLayoutMode = DeviceLayoutMode.LANDSCAPE_TABLET;
    } else if (width >= DesignSystem.CapsuleSideLying.minScreenWidth) {
      this.deviceLayoutMode = DeviceLayoutMode.FOLDABLE_EXPANDED;
    } else {
      this.deviceLayoutMode = DeviceLayoutMode.PORTRAIT_PHONE;
    }
  }

  clampBrightness(value: number): number {
    return Math.max(0, Math.min(100, value));
  }

  clampFontSize(value: number): number {
    return Math.max(12, Math.min(36, value));
  }

  reset(): void {
    this.morphState = CapsuleMorphState.FULL;
    this.isDeepReading = false;
    this.consecutivePagesScrolled = 0;
    this.currentOpacity = 1.0;
    this.currentVelocity = 0;
    this.scrollDirection = ScrollDirection.NONE;
    this.isPetalMenuOpen = false;
    this.isBookmarkLineDragging = false;
    this.bookmarkLineLength = 0;
    this.isBreathTransitioning = false;
    this.breathBrightness = 1.0;
    this.throttleTimers.clear();
  }
}

export const capsuleStateStore = CapsuleStateStore.getInstance();
