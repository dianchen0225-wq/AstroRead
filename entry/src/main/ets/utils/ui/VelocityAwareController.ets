import { DesignSystem } from '../../common/DesignSystem';
import { ScrollDirection } from '../../components/capsule/CapsuleStateStore';

export interface VelocityUpdate {
  opacity: number;
  shouldElasticPush: boolean;
  shouldFadeOut: boolean;
}

export interface ElasticPushParams {
  overshoot: number;
  returnDuration: number;
}

export class VelocityAwareController {
  private readonly TAG = 'VelocityAwareController';
  private fastScrollThreshold: number = 800;
  private maxVelocity: number = 2000;
  private maxOpacity: number = 0.8;

  handleScroll(velocity: number, direction: ScrollDirection): VelocityUpdate {
    const absVelocity = Math.abs(velocity);

    if (direction === ScrollDirection.DOWN && absVelocity > this.fastScrollThreshold) {
      const result: VelocityUpdate = {
        opacity: 0,
        shouldElasticPush: true,
        shouldFadeOut: false
      };
      return result;
    }

    if (direction === ScrollDirection.UP) {
      if (absVelocity > this.fastScrollThreshold) {
        const result: VelocityUpdate = {
          opacity: this.maxOpacity,
          shouldElasticPush: false,
          shouldFadeOut: false
        };
        return result;
      }

      const mappedOpacity = this.maxOpacity * Math.min(absVelocity / this.maxVelocity, 1);
      const result: VelocityUpdate = {
        opacity: mappedOpacity,
        shouldElasticPush: false,
        shouldFadeOut: false
      };
      return result;
    }

    if (absVelocity === 0) {
      const result: VelocityUpdate = {
        opacity: 0,
        shouldElasticPush: false,
        shouldFadeOut: true
      };
      return result;
    }

    const result: VelocityUpdate = {
      opacity: 0,
      shouldElasticPush: false,
      shouldFadeOut: false
    };
    return result;
  }

  getElasticPushParams(): ElasticPushParams {
    const params: ElasticPushParams = {
      overshoot: DesignSystem.CapsuleAnimation.elasticOvershoot,
      returnDuration: DesignSystem.CapsuleAnimation.elasticReturnDuration
    };
    return params;
  }

  getFadeOutDuration(): number {
    return DesignSystem.CapsuleAnimation.fadeOutOnStop;
  }

  setFastScrollThreshold(threshold: number): void {
    this.fastScrollThreshold = threshold;
  }

  setMaxVelocity(max: number): void {
    this.maxVelocity = max;
  }
}
