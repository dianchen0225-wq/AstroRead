import { DesignSystem } from '../../common/DesignSystem';
import { isApiVersionAtLeast } from '../SystemVersionUtils';
import { performanceMonitor } from '../performance/PerformanceMonitor';
import { Logger } from '../performance/Logger';
import { ElasticPushParams } from './VelocityAwareController';

export enum GPUDegradeLevel {
  HIGH = 'high',
  MEDIUM = 'medium',
  LOW = 'low'
}

export class CapsulePerformanceAdapter {
  private readonly TAG = 'CapsulePerformanceAdapter';
  private currentFPS: number = 60;
  private gpuLevel: GPUDegradeLevel = GPUDegradeLevel.HIGH;
  private apiVersion: number = 12;

  constructor() {
    this.apiVersion = isApiVersionAtLeast(12) ? 12 : 11;
  }

  updateFPS(fps: number): void {
    this.currentFPS = fps;
  }

  getInkMaxRadius(): number {
    if (this.gpuLevel === GPUDegradeLevel.LOW || this.currentFPS < 30) {
      return 0;
    }
    if (this.currentFPS < 45) {
      return DesignSystem.CapsuleInk.lowGPUMaxRadius;
    }
    return DesignSystem.CapsuleInk.maxRadius;
  }

  shouldUseInkEffect(): boolean {
    return this.gpuLevel !== GPUDegradeLevel.LOW && this.currentFPS >= 30;
  }

  shouldUseNightGlow(): boolean {
    return this.gpuLevel !== GPUDegradeLevel.LOW;
  }

  shouldUseSpringCurve(): boolean {
    return this.apiVersion >= 12;
  }

  getAnimationCurve(): string {
    if (this.shouldUseSpringCurve()) {
      return DesignSystem.AnimationCurve.spring;
    }
    return DesignSystem.AnimationCurve.easeOut;
  }

  shouldUseSystemSymbols(): boolean {
    return this.apiVersion >= 12;
  }

  getAirGap(): number {
    return DesignSystem.CapsuleGesture.airGapFromSystemBar;
  }

  setGPULevel(level: GPUDegradeLevel): void {
    this.gpuLevel = level;
    Logger.info(this.TAG, `GPU降级等级: ${level}`);
  }

  getGPULevel(): GPUDegradeLevel {
    return this.gpuLevel;
  }

  getElasticPushParams(): ElasticPushParams {
    if (this.currentFPS < 55) {
      const params: ElasticPushParams = {
        overshoot: 0,
        returnDuration: DesignSystem.CapsuleAnimation.elasticReturnDuration
      };
      return params;
    }
    const params: ElasticPushParams = {
      overshoot: DesignSystem.CapsuleAnimation.elasticOvershoot,
      returnDuration: DesignSystem.CapsuleAnimation.elasticReturnDuration
    };
    return params;
  }

  reset(): void {
    this.currentFPS = 60;
    this.gpuLevel = GPUDegradeLevel.HIGH;
  }
}

export const capsulePerformanceAdapter = new CapsulePerformanceAdapter();
