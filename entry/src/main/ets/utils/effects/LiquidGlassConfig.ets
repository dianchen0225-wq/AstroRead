import { themeManager } from '../../common/ThemeManager';
import { Logger } from '../performance/Logger';
import {
  requestAnimationFrame,
  cancelAnimationFrame,
  performanceNow
} from './HarmonyOSCompat';

export interface LiquidGlassConfig {
  fluidity: number;
  viscosity: number;
  surfaceTension: number;
  transparency: number;
  refractionIndex: number;
  blurIntensity: number;
  colorTint: string;
  rippleEnabled: boolean;
  rippleIntensity: number;
  rippleDecay: number;
  morphEnabled: boolean;
  morphSpeed: number;
  morphAmplitude: number;
  glowEnabled: boolean;
  glowIntensity: number;
  glowColor: string;
  shadowSoftness: number;
  animationFrameRate: number;
  reducedMotion: boolean;
}

export interface RipplePoint {
  x: number;
  y: number;
  startTime: number;
  intensity: number;
  radius: number;
  maxRadius: number;
}

export interface MorphState {
  scale: number;
  rotation: number;
  skewX: number;
  skewY: number;
  translateX: number;
  translateY: number;
}

export interface PhysicsState {
  velocity: number;
  acceleration: number;
  damping: number;
  springConstant: number;
  targetValue: number;
  currentValue: number;
}

export interface PerformanceStats {
  averageFPS: number;
  minFPS: number;
  maxFPS: number;
  droppedFrameRate: number;
  recommendedQuality: 'high' | 'medium' | 'low';
}

export interface SpringAnimationResult {
  value: number;
  velocity: number;
}

export class LiquidGlassPreset {
  static readonly DEFAULT: LiquidGlassConfig = {
    fluidity: 0.5,
    viscosity: 0.3,
    surfaceTension: 0.4,
    transparency: 0.85,
    refractionIndex: 1.33,
    blurIntensity: 20,
    colorTint: 'rgba(255, 255, 255, 0.1)',
    rippleEnabled: true,
    rippleIntensity: 0.6,
    rippleDecay: 0.95,
    morphEnabled: true,
    morphSpeed: 0.02,
    morphAmplitude: 0.05,
    glowEnabled: true,
    glowIntensity: 0.3,
    glowColor: 'rgba(255, 255, 255, 0.5)',
    shadowSoftness: 0.8,
    animationFrameRate: 60,
    reducedMotion: false
  };

  static readonly SILK: LiquidGlassConfig = {
    fluidity: 0.8,
    viscosity: 0.2,
    surfaceTension: 0.3,
    transparency: 0.9,
    refractionIndex: 1.45,
    blurIntensity: 25,
    colorTint: 'rgba(240, 248, 255, 0.15)',
    rippleEnabled: true,
    rippleIntensity: 0.4,
    rippleDecay: 0.92,
    morphEnabled: true,
    morphSpeed: 0.015,
    morphAmplitude: 0.03,
    glowEnabled: true,
    glowIntensity: 0.4,
    glowColor: 'rgba(200, 220, 255, 0.4)',
    shadowSoftness: 0.9,
    animationFrameRate: 60,
    reducedMotion: false
  };

  static readonly CRYSTAL: LiquidGlassConfig = {
    fluidity: 0.3,
    viscosity: 0.5,
    surfaceTension: 0.6,
    transparency: 0.75,
    refractionIndex: 1.52,
    blurIntensity: 15,
    colorTint: 'rgba(200, 230, 255, 0.2)',
    rippleEnabled: true,
    rippleIntensity: 0.8,
    rippleDecay: 0.88,
    morphEnabled: false,
    morphSpeed: 0.01,
    morphAmplitude: 0.02,
    glowEnabled: true,
    glowIntensity: 0.5,
    glowColor: 'rgba(180, 200, 255, 0.6)',
    shadowSoftness: 0.6,
    animationFrameRate: 60,
    reducedMotion: false
  };

  static readonly WATER: LiquidGlassConfig = {
    fluidity: 0.9,
    viscosity: 0.1,
    surfaceTension: 0.2,
    transparency: 0.95,
    refractionIndex: 1.33,
    blurIntensity: 30,
    colorTint: 'rgba(100, 180, 255, 0.08)',
    rippleEnabled: true,
    rippleIntensity: 1.0,
    rippleDecay: 0.9,
    morphEnabled: true,
    morphSpeed: 0.025,
    morphAmplitude: 0.08,
    glowEnabled: false,
    glowIntensity: 0.2,
    glowColor: 'rgba(100, 200, 255, 0.3)',
    shadowSoftness: 1.0,
    animationFrameRate: 60,
    reducedMotion: false
  };

  static readonly FROSTED: LiquidGlassConfig = {
    fluidity: 0.2,
    viscosity: 0.6,
    surfaceTension: 0.5,
    transparency: 0.7,
    refractionIndex: 1.4,
    blurIntensity: 35,
    colorTint: 'rgba(255, 255, 255, 0.25)',
    rippleEnabled: false,
    rippleIntensity: 0.3,
    rippleDecay: 0.85,
    morphEnabled: false,
    morphSpeed: 0.005,
    morphAmplitude: 0.01,
    glowEnabled: true,
    glowIntensity: 0.6,
    glowColor: 'rgba(255, 255, 255, 0.7)',
    shadowSoftness: 0.7,
    animationFrameRate: 60,
    reducedMotion: false
  };

  static readonly AMBER: LiquidGlassConfig = {
    fluidity: 0.4,
    viscosity: 0.4,
    surfaceTension: 0.45,
    transparency: 0.8,
    refractionIndex: 1.55,
    blurIntensity: 22,
    colorTint: 'rgba(184, 134, 11, 0.15)',
    rippleEnabled: true,
    rippleIntensity: 0.5,
    rippleDecay: 0.93,
    morphEnabled: true,
    morphSpeed: 0.018,
    morphAmplitude: 0.04,
    glowEnabled: true,
    glowIntensity: 0.35,
    glowColor: 'rgba(232, 197, 71, 0.5)',
    shadowSoftness: 0.75,
    animationFrameRate: 60,
    reducedMotion: false
  };

  static getReducedMotionConfig(base: LiquidGlassConfig): LiquidGlassConfig {
    return {
      fluidity: base.fluidity,
      viscosity: base.viscosity,
      surfaceTension: base.surfaceTension,
      transparency: base.transparency,
      refractionIndex: base.refractionIndex,
      blurIntensity: base.blurIntensity,
      colorTint: base.colorTint,
      rippleEnabled: false,
      rippleIntensity: base.rippleIntensity,
      rippleDecay: base.rippleDecay,
      morphEnabled: false,
      morphSpeed: base.morphSpeed,
      morphAmplitude: base.morphAmplitude,
      glowEnabled: base.glowEnabled,
      glowIntensity: base.glowIntensity,
      glowColor: base.glowColor,
      shadowSoftness: base.shadowSoftness,
      animationFrameRate: 30,
      reducedMotion: true
    };
  }

  static getThemeAwareConfig(base: LiquidGlassConfig, isLightMode: boolean): LiquidGlassConfig {
    if (isLightMode) {
      return {
        fluidity: base.fluidity,
        viscosity: base.viscosity,
        surfaceTension: base.surfaceTension,
        transparency: base.transparency,
        refractionIndex: base.refractionIndex,
        blurIntensity: base.blurIntensity,
        colorTint: base.colorTint.replace(/[\d.]+\)$/, '0.12)'),
        rippleEnabled: base.rippleEnabled,
        rippleIntensity: base.rippleIntensity,
        rippleDecay: base.rippleDecay,
        morphEnabled: base.morphEnabled,
        morphSpeed: base.morphSpeed,
        morphAmplitude: base.morphAmplitude,
        glowEnabled: base.glowEnabled,
        glowIntensity: base.glowIntensity,
        glowColor: 'rgba(255, 255, 255, 0.4)',
        shadowSoftness: base.shadowSoftness * 0.8,
        animationFrameRate: base.animationFrameRate,
        reducedMotion: base.reducedMotion
      };
    }
    return {
      fluidity: base.fluidity,
      viscosity: base.viscosity,
      surfaceTension: base.surfaceTension,
      transparency: base.transparency,
      refractionIndex: base.refractionIndex,
      blurIntensity: base.blurIntensity,
      colorTint: base.colorTint.replace(/[\d.]+\)$/, '0.08)'),
      rippleEnabled: base.rippleEnabled,
      rippleIntensity: base.rippleIntensity,
      rippleDecay: base.rippleDecay,
      morphEnabled: base.morphEnabled,
      morphSpeed: base.morphSpeed,
      morphAmplitude: base.morphAmplitude,
      glowEnabled: base.glowEnabled,
      glowIntensity: base.glowIntensity,
      glowColor: 'rgba(200, 200, 255, 0.3)',
      shadowSoftness: base.shadowSoftness * 1.2,
      animationFrameRate: base.animationFrameRate,
      reducedMotion: base.reducedMotion
    };
  }
}

export class LiquidGlassAnimator {
  private config: LiquidGlassConfig;
  private ripples: RipplePoint[] = [];
  private morphState: MorphState;
  private physicsState: PhysicsState;
  private animationId: number = -1;
  private lastFrameTime: number = 0;
  private frameCount: number = 0;
  private isRunning: boolean = false;
  private frameInterval: number = 1000 / 60;
  private targetMorphState: MorphState = {
    scale: 1,
    rotation: 0,
    skewX: 0,
    skewY: 0,
    translateX: 0,
    translateY: 0
  };

  constructor(config: LiquidGlassConfig = LiquidGlassPreset.DEFAULT) {
    this.config = {
      fluidity: config.fluidity,
      viscosity: config.viscosity,
      surfaceTension: config.surfaceTension,
      transparency: config.transparency,
      refractionIndex: config.refractionIndex,
      blurIntensity: config.blurIntensity,
      colorTint: config.colorTint,
      rippleEnabled: config.rippleEnabled,
      rippleIntensity: config.rippleIntensity,
      rippleDecay: config.rippleDecay,
      morphEnabled: config.morphEnabled,
      morphSpeed: config.morphSpeed,
      morphAmplitude: config.morphAmplitude,
      glowEnabled: config.glowEnabled,
      glowIntensity: config.glowIntensity,
      glowColor: config.glowColor,
      shadowSoftness: config.shadowSoftness,
      animationFrameRate: config.animationFrameRate,
      reducedMotion: config.reducedMotion
    };
    this.morphState = {
      scale: 1,
      rotation: 0,
      skewX: 0,
      skewY: 0,
      translateX: 0,
      translateY: 0
    };
    this.physicsState = {
      velocity: 0,
      acceleration: 0,
      damping: 0.95,
      springConstant: 0.1,
      targetValue: 1,
      currentValue: 1
    };
    this.updateFrameInterval();
  }

  private updateFrameInterval(): void {
    const targetFps = Math.min(this.config.animationFrameRate, 60);
    this.frameInterval = 1000 / targetFps;
  }

  updateConfig(newConfig: Partial<LiquidGlassConfig>): void {
    if (newConfig.fluidity !== undefined) this.config.fluidity = newConfig.fluidity;
    if (newConfig.viscosity !== undefined) this.config.viscosity = newConfig.viscosity;
    if (newConfig.surfaceTension !== undefined) this.config.surfaceTension = newConfig.surfaceTension;
    if (newConfig.transparency !== undefined) this.config.transparency = newConfig.transparency;
    if (newConfig.refractionIndex !== undefined) this.config.refractionIndex = newConfig.refractionIndex;
    if (newConfig.blurIntensity !== undefined) this.config.blurIntensity = newConfig.blurIntensity;
    if (newConfig.colorTint !== undefined) this.config.colorTint = newConfig.colorTint;
    if (newConfig.rippleEnabled !== undefined) this.config.rippleEnabled = newConfig.rippleEnabled;
    if (newConfig.rippleIntensity !== undefined) this.config.rippleIntensity = newConfig.rippleIntensity;
    if (newConfig.rippleDecay !== undefined) this.config.rippleDecay = newConfig.rippleDecay;
    if (newConfig.morphEnabled !== undefined) this.config.morphEnabled = newConfig.morphEnabled;
    if (newConfig.morphSpeed !== undefined) this.config.morphSpeed = newConfig.morphSpeed;
    if (newConfig.morphAmplitude !== undefined) this.config.morphAmplitude = newConfig.morphAmplitude;
    if (newConfig.glowEnabled !== undefined) this.config.glowEnabled = newConfig.glowEnabled;
    if (newConfig.glowIntensity !== undefined) this.config.glowIntensity = newConfig.glowIntensity;
    if (newConfig.glowColor !== undefined) this.config.glowColor = newConfig.glowColor;
    if (newConfig.shadowSoftness !== undefined) this.config.shadowSoftness = newConfig.shadowSoftness;
    if (newConfig.animationFrameRate !== undefined) this.config.animationFrameRate = newConfig.animationFrameRate;
    if (newConfig.reducedMotion !== undefined) this.config.reducedMotion = newConfig.reducedMotion;
    this.updateFrameInterval();
  }

  getConfig(): LiquidGlassConfig {
    return {
      fluidity: this.config.fluidity,
      viscosity: this.config.viscosity,
      surfaceTension: this.config.surfaceTension,
      transparency: this.config.transparency,
      refractionIndex: this.config.refractionIndex,
      blurIntensity: this.config.blurIntensity,
      colorTint: this.config.colorTint,
      rippleEnabled: this.config.rippleEnabled,
      rippleIntensity: this.config.rippleIntensity,
      rippleDecay: this.config.rippleDecay,
      morphEnabled: this.config.morphEnabled,
      morphSpeed: this.config.morphSpeed,
      morphAmplitude: this.config.morphAmplitude,
      glowEnabled: this.config.glowEnabled,
      glowIntensity: this.config.glowIntensity,
      glowColor: this.config.glowColor,
      shadowSoftness: this.config.shadowSoftness,
      animationFrameRate: this.config.animationFrameRate,
      reducedMotion: this.config.reducedMotion
    };
  }

  addRipple(x: number, y: number, intensity?: number): void {
    if (!this.config.rippleEnabled || this.config.reducedMotion) {
      return;
    }

    const now = Date.now();
    const rippleIntensity = intensity ?? this.config.rippleIntensity;
    
    this.ripples.push({
      x,
      y,
      startTime: now,
      intensity: rippleIntensity,
      radius: 0,
      maxRadius: 150
    });

    if (this.ripples.length > 5) {
      this.ripples.shift();
    }
  }

  updateRipples(): RipplePoint[] {
    const now = Date.now();
    const activeRipples: RipplePoint[] = [];

    for (const ripple of this.ripples) {
      const elapsed = now - ripple.startTime;
      const progress = elapsed / 1000;
      
      ripple.radius = progress * 100 * (1 + this.config.fluidity);
      ripple.intensity *= this.config.rippleDecay;

      if (ripple.intensity > 0.01 && ripple.radius < ripple.maxRadius) {
        activeRipples.push(ripple);
      }
    }

    this.ripples = activeRipples;
    return this.ripples;
  }

  updateMorph(deltaTime: number): MorphState {
    if (!this.config.morphEnabled || this.config.reducedMotion) {
      return this.morphState;
    }

    const speed = this.config.morphSpeed;
    const amplitude = this.config.morphAmplitude;
    const time = Date.now() / 1000;

    const springForce = (this.targetMorphState.scale - this.morphState.scale) * this.physicsState.springConstant;
    this.physicsState.velocity += springForce;
    this.physicsState.velocity *= this.physicsState.damping;
    this.morphState.scale += this.physicsState.velocity * deltaTime;

    this.morphState.rotation = Math.sin(time * speed * 2) * amplitude * 5;
    this.morphState.skewX = Math.sin(time * speed * 1.5) * amplitude * 2;
    this.morphState.skewY = Math.cos(time * speed * 1.5) * amplitude * 2;
    this.morphState.translateX = Math.sin(time * speed * 3) * amplitude * 3;
    this.morphState.translateY = Math.cos(time * speed * 2.5) * amplitude * 3;

    return this.morphState;
  }

  applyPhysicsForce(force: number): void {
    this.physicsState.acceleration = force * (1 - this.config.viscosity);
    this.physicsState.velocity += this.physicsState.acceleration;
  }

  getPhysicsState(): PhysicsState {
    return {
      velocity: this.physicsState.velocity,
      acceleration: this.physicsState.acceleration,
      damping: this.physicsState.damping,
      springConstant: this.physicsState.springConstant,
      targetValue: this.physicsState.targetValue,
      currentValue: this.physicsState.currentValue
    };
  }

  resetMorphState(): void {
    this.morphState = {
      scale: 1,
      rotation: 0,
      skewX: 0,
      skewY: 0,
      translateX: 0,
      translateY: 0
    };
    this.physicsState.velocity = 0;
    this.physicsState.acceleration = 0;
  }

  calculateBlurEffect(baseBlur: number): number {
    const morphBlur = Math.abs(this.morphState.scale - 1) * 20;
    const rippleBlur = this.ripples.length > 0 
      ? this.ripples.reduce((sum, r) => sum + r.intensity * 5, 0) / this.ripples.length 
      : 0;
    
    return baseBlur + morphBlur + rippleBlur;
  }

  calculateOpacity(baseOpacity: number): number {
    const morphOpacity = 1 - Math.abs(this.morphState.scale - 1) * 0.2;
    return Math.max(0.5, Math.min(1, baseOpacity * morphOpacity));
  }

  calculateGlowIntensity(): number {
    if (!this.config.glowEnabled) {
      return 0;
    }

    const baseGlow = this.config.glowIntensity;
    const rippleGlow = this.ripples.length > 0
      ? this.ripples.reduce((sum, r) => sum + r.intensity, 0) / this.ripples.length
      : 0;
    const morphGlow = Math.abs(this.morphState.scale - 1) * 2;

    return Math.min(1, baseGlow + rippleGlow * 0.3 + morphGlow);
  }

  getRippleCount(): number {
    return this.ripples.length;
  }

  clearRipples(): void {
    this.ripples = [];
  }

  startAnimation(callback: (deltaTime: number) => void): void {
    if (this.isRunning) {
      return;
    }

    this.isRunning = true;
    this.lastFrameTime = performanceNow();
    this.frameCount = 0;

    const animate = (): void => {
      if (!this.isRunning) {
        return;
      }

      const currentTime = performanceNow();
      const deltaTime = currentTime - this.lastFrameTime;

      if (deltaTime >= this.frameInterval) {
        this.frameCount++;
        this.lastFrameTime = currentTime - (deltaTime % this.frameInterval);
        callback(deltaTime / 1000);
      }

      this.animationId = requestAnimationFrame(animate);
    };

    this.animationId = requestAnimationFrame(animate);
  }

  stopAnimation(): void {
    this.isRunning = false;
    if (this.animationId !== -1) {
      cancelAnimationFrame(this.animationId);
      this.animationId = -1;
    }
  }

  isAnimating(): boolean {
    return this.isRunning;
  }

  getFrameCount(): number {
    return this.frameCount;
  }

  getAverageFrameTime(): number {
    if (this.frameCount === 0) {
      return 0;
    }
    const elapsed = performanceNow() - this.lastFrameTime;
    return elapsed / this.frameCount;
  }

  dispose(): void {
    this.stopAnimation();
    this.ripples = [];
    this.resetMorphState();
  }
}

export class LiquidGlassPerformanceMonitor {
  private frameTimes: number[] = [];
  private maxSamples: number = 60;
  private lastFrameTime: number = 0;
  private droppedFrames: number = 0;
  private totalFrames: number = 0;

  startFrame(): void {
    this.lastFrameTime = performanceNow();
  }

  endFrame(): void {
    const frameTime = performanceNow() - this.lastFrameTime;
    this.frameTimes.push(frameTime);
    this.totalFrames++;

    if (this.frameTimes.length > this.maxSamples) {
      this.frameTimes.shift();
    }

    if (frameTime > 16.67 * 1.5) {
      this.droppedFrames++;
    }
  }

  getAverageFPS(): number {
    if (this.frameTimes.length === 0) {
      return 0;
    }

    const avgFrameTime = this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length;
    return Math.min(60, 1000 / avgFrameTime);
  }

  getMinFPS(): number {
    if (this.frameTimes.length === 0) {
      return 0;
    }

    const maxFrameTime = Math.max(...this.frameTimes);
    return 1000 / maxFrameTime;
  }

  getMaxFPS(): number {
    if (this.frameTimes.length === 0) {
      return 0;
    }

    const minFrameTime = Math.min(...this.frameTimes);
    return Math.min(60, 1000 / minFrameTime);
  }

  getDroppedFrameRate(): number {
    if (this.totalFrames === 0) {
      return 0;
    }
    return this.droppedFrames / this.totalFrames;
  }

  isPerformanceGood(): boolean {
    return this.getAverageFPS() >= 55 && this.getDroppedFrameRate() < 0.05;
  }

  getRecommendedQuality(): 'high' | 'medium' | 'low' {
    const avgFPS = this.getAverageFPS();
    const dropRate = this.getDroppedFrameRate();

    if (avgFPS >= 55 && dropRate < 0.03) {
      return 'high';
    } else if (avgFPS >= 45 && dropRate < 0.1) {
      return 'medium';
    }
    return 'low';
  }

  reset(): void {
    this.frameTimes = [];
    this.droppedFrames = 0;
    this.totalFrames = 0;
  }

  getStats(): PerformanceStats {
    return {
      averageFPS: this.getAverageFPS(),
      minFPS: this.getMinFPS(),
      maxFPS: this.getMaxFPS(),
      droppedFrameRate: this.getDroppedFrameRate(),
      recommendedQuality: this.getRecommendedQuality()
    };
  }
}

export class LiquidGlassUtils {
  static lerp(start: number, end: number, t: number): number {
    return start + (end - start) * t;
  }

  static easeOutCubic(t: number): number {
    return 1 - Math.pow(1 - t, 3);
  }

  static easeInOutCubic(t: number): number {
    return t < 0.5 
      ? 4 * t * t * t 
      : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }

  static springAnimation(
    current: number,
    target: number,
    velocity: number,
    stiffness: number,
    damping: number
  ): SpringAnimationResult {
    const spring = stiffness;
    const damper = damping;

    const acceleration = spring * (target - current) - damper * velocity;
    const newVelocity = velocity + acceleration;
    const newValue = current + newVelocity;

    return {
      value: newValue,
      velocity: newVelocity
    };
  }

  static calculateRippleRadius(
    startTime: number,
    currentTime: number,
    maxRadius: number,
    speed: number
  ): number {
    const elapsed = currentTime - startTime;
    const progress = Math.min(1, elapsed / 1000);
    return progress * maxRadius * speed;
  }

  static calculateRippleOpacity(
    startTime: number,
    currentTime: number,
    decay: number
  ): number {
    const elapsed = currentTime - startTime;
    return Math.pow(decay, elapsed / 100);
  }

  static generateNoiseTexture(size: number = 256): string {
    // HarmonyOS 不支持 canvas，返回空字符串
    // 如果需要噪点纹理，可以使用 PixelMap 或其他 HarmonyOS 图形 API
    Logger.warn('LiquidGlassUtils', 'generateNoiseTexture is not supported on HarmonyOS');
    return '';
  }

  static clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  static mapRange(
    value: number,
    inMin: number,
    inMax: number,
    outMin: number,
    outMax: number
  ): number {
    return ((value - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin;
  }

  static getResponsiveBlur(baseBlur: number, screenWidth: number): number {
    if (screenWidth < 375) {
      return baseBlur * 0.8;
    } else if (screenWidth < 414) {
      return baseBlur * 0.9;
    } else if (screenWidth > 768) {
      return baseBlur * 1.2;
    }
    return baseBlur;
  }

  static getResponsiveAnimationDuration(
    baseDuration: number,
    screenWidth: number
  ): number {
    if (screenWidth < 375) {
      return baseDuration * 0.8;
    } else if (screenWidth > 768) {
      return baseDuration * 1.1;
    }
    return baseDuration;
  }
}

export function createLiquidGlassAnimator(config?: Partial<LiquidGlassConfig>): LiquidGlassAnimator {
  const base = LiquidGlassPreset.DEFAULT;
  const finalConfig: LiquidGlassConfig = {
    fluidity: config?.fluidity ?? base.fluidity,
    viscosity: config?.viscosity ?? base.viscosity,
    surfaceTension: config?.surfaceTension ?? base.surfaceTension,
    transparency: config?.transparency ?? base.transparency,
    refractionIndex: config?.refractionIndex ?? base.refractionIndex,
    blurIntensity: config?.blurIntensity ?? base.blurIntensity,
    colorTint: config?.colorTint ?? base.colorTint,
    rippleEnabled: config?.rippleEnabled ?? base.rippleEnabled,
    rippleIntensity: config?.rippleIntensity ?? base.rippleIntensity,
    rippleDecay: config?.rippleDecay ?? base.rippleDecay,
    morphEnabled: config?.morphEnabled ?? base.morphEnabled,
    morphSpeed: config?.morphSpeed ?? base.morphSpeed,
    morphAmplitude: config?.morphAmplitude ?? base.morphAmplitude,
    glowEnabled: config?.glowEnabled ?? base.glowEnabled,
    glowIntensity: config?.glowIntensity ?? base.glowIntensity,
    glowColor: config?.glowColor ?? base.glowColor,
    shadowSoftness: config?.shadowSoftness ?? base.shadowSoftness,
    animationFrameRate: config?.animationFrameRate ?? base.animationFrameRate,
    reducedMotion: config?.reducedMotion ?? base.reducedMotion
  };

  return new LiquidGlassAnimator(finalConfig);
}

export function getOptimalGlassConfig(
  baseConfig: LiquidGlassConfig,
  performanceLevel: 'high' | 'medium' | 'low'
): LiquidGlassConfig {
  switch (performanceLevel) {
    case 'high':
      return {
        fluidity: baseConfig.fluidity,
        viscosity: baseConfig.viscosity,
        surfaceTension: baseConfig.surfaceTension,
        transparency: baseConfig.transparency,
        refractionIndex: baseConfig.refractionIndex,
        blurIntensity: baseConfig.blurIntensity,
        colorTint: baseConfig.colorTint,
        rippleEnabled: baseConfig.rippleEnabled,
        rippleIntensity: baseConfig.rippleIntensity,
        rippleDecay: baseConfig.rippleDecay,
        morphEnabled: baseConfig.morphEnabled,
        morphSpeed: baseConfig.morphSpeed,
        morphAmplitude: baseConfig.morphAmplitude,
        glowEnabled: baseConfig.glowEnabled,
        glowIntensity: baseConfig.glowIntensity,
        glowColor: baseConfig.glowColor,
        shadowSoftness: baseConfig.shadowSoftness,
        animationFrameRate: baseConfig.animationFrameRate,
        reducedMotion: baseConfig.reducedMotion
      };
    case 'medium':
      return {
        fluidity: baseConfig.fluidity,
        viscosity: baseConfig.viscosity,
        surfaceTension: baseConfig.surfaceTension,
        transparency: baseConfig.transparency,
        refractionIndex: baseConfig.refractionIndex,
        blurIntensity: baseConfig.blurIntensity * 0.8,
        colorTint: baseConfig.colorTint,
        rippleEnabled: baseConfig.rippleEnabled,
        rippleIntensity: baseConfig.rippleIntensity * 0.7,
        rippleDecay: baseConfig.rippleDecay,
        morphEnabled: baseConfig.morphEnabled,
        morphSpeed: baseConfig.morphSpeed,
        morphAmplitude: baseConfig.morphAmplitude * 0.7,
        glowEnabled: baseConfig.glowEnabled,
        glowIntensity: baseConfig.glowIntensity * 0.8,
        glowColor: baseConfig.glowColor,
        shadowSoftness: baseConfig.shadowSoftness,
        animationFrameRate: 45,
        reducedMotion: baseConfig.reducedMotion
      };
    case 'low':
      return {
        fluidity: baseConfig.fluidity,
        viscosity: baseConfig.viscosity,
        surfaceTension: baseConfig.surfaceTension,
        transparency: baseConfig.transparency,
        refractionIndex: baseConfig.refractionIndex,
        blurIntensity: baseConfig.blurIntensity * 0.6,
        colorTint: baseConfig.colorTint,
        rippleEnabled: false,
        rippleIntensity: baseConfig.rippleIntensity,
        rippleDecay: baseConfig.rippleDecay,
        morphEnabled: false,
        morphSpeed: baseConfig.morphSpeed,
        morphAmplitude: baseConfig.morphAmplitude,
        glowEnabled: baseConfig.glowEnabled,
        glowIntensity: baseConfig.glowIntensity * 0.5,
        glowColor: baseConfig.glowColor,
        shadowSoftness: baseConfig.shadowSoftness,
        animationFrameRate: 30,
        reducedMotion: baseConfig.reducedMotion
      };
  }
}
