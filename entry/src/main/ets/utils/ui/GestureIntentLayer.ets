import { DesignSystem } from '../../common/DesignSystem';

export interface GestureIntentResult {
  shouldShowNavBar: boolean;
  shouldYieldToSystem: boolean;
  shouldShake: boolean;
}

export interface YieldParams {
  translateY: number;
  opacity: number;
  duration: number;
}

export interface ShakeParams {
  amplitude: number;
  duration: number;
  repeatCount: number;
}

export class GestureIntentLayer {
  private readonly TAG = 'GestureIntentLayer';
  private isYielding: boolean = false;
  private yieldTimer: number = 0;
  private lastYieldTime: number = 0;

  handleSwipeUp(distance: number): GestureIntentResult {
    const appThreshold = DesignSystem.CapsuleGesture.appSwipeThreshold;
    const systemThreshold = DesignSystem.CapsuleGesture.systemSwipeThreshold;

    if (distance >= systemThreshold) {
      const result: GestureIntentResult = {
        shouldShowNavBar: true,
        shouldYieldToSystem: true,
        shouldShake: true
      };
      return result;
    }

    if (distance >= appThreshold) {
      const result: GestureIntentResult = {
        shouldShowNavBar: true,
        shouldYieldToSystem: false,
        shouldShake: false
      };
      return result;
    }

    const result: GestureIntentResult = {
      shouldShowNavBar: false,
      shouldYieldToSystem: false,
      shouldShake: false
    };
    return result;
  }

  onSystemGestureTrigger(): YieldParams {
    const now = Date.now();
    if (now - this.lastYieldTime < DesignSystem.CapsuleGesture.yieldDuration) {
      this.lastYieldTime = now;
      return this.getYieldParams();
    }

    this.lastYieldTime = now;
    this.isYielding = true;
    return this.getYieldParams();
  }

  private getYieldParams(): YieldParams {
    const params: YieldParams = {
      translateY: DesignSystem.CapsuleGesture.yieldTranslateY,
      opacity: DesignSystem.CapsuleGesture.yieldOpacity,
      duration: DesignSystem.CapsuleGesture.yieldDuration
    };
    return params;
  }

  getShakeParams(): ShakeParams {
    const params: ShakeParams = {
      amplitude: DesignSystem.CapsuleGesture.shakeAmplitude,
      duration: DesignSystem.CapsuleGesture.shakeDuration,
      repeatCount: DesignSystem.CapsuleGesture.shakeRepeatCount
    };
    return params;
  }

  getAirGap(): number {
    return DesignSystem.CapsuleGesture.airGapFromSystemBar;
  }

  isCurrentlyYielding(): boolean {
    return this.isYielding;
  }

  completeYield(): void {
    this.isYielding = false;
  }

  reset(): void {
    this.isYielding = false;
    this.lastYieldTime = 0;
  }
}
