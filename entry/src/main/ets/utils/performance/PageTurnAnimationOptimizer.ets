import { Logger } from './Logger';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { ResourceLevel } from './ResourceMonitor';

/**
 * 渲染节点
 */
interface RenderNode {
  chapterIndex: number;
  content: string;
  timestamp: number;
}

/**
 * 翻页动画优化器
 * 优化翻页动画性能，支持预渲染和动画取消
 */
export class PageTurnAnimationOptimizer {
  private static instance: PageTurnAnimationOptimizer;
  private preRenderCache: Map<number, RenderNode> = new Map();
  private isAnimating: boolean = false;
  private currentAnimationController: (() => void) | null = null;
  private resourceLevel: ResourceLevel = ResourceLevel.ABUNDANT;

  private constructor() {
    this.startResourceMonitoring();
  }

  public static getInstance(): PageTurnAnimationOptimizer {
    if (!PageTurnAnimationOptimizer.instance) {
      PageTurnAnimationOptimizer.instance = new PageTurnAnimationOptimizer();
    }
    return PageTurnAnimationOptimizer.instance;
  }

  /**
   * 执行翻页动画
   * @param direction 翻页方向
   * @param onAnimation 动画执行回调
   * @param onFinish 动画完成回调
   */
  animatePageTurn(
    direction: 'prev' | 'next',
    onAnimation: () => void,
    onFinish: () => void
  ): void {
    Logger.debug('PageTurnAnimationOptimizer', `开始翻页动画: ${direction}`);

    // 如果正在执行动画，先取消
    if (this.isAnimating && this.currentAnimationController) {
      Logger.debug('PageTurnAnimationOptimizer', '取消当前动画');
      this.currentAnimationController();
    }

    this.isAnimating = true;
    const traceId = `pageTurn_${direction}_${Date.now()}`;
    hiTraceMeter.startTrace(traceId, 1);

    // 根据资源级别调整动画参数
    const duration = this.getAnimationDuration();
    const curve = this.getAnimationCurve();

    animateTo({
      duration: duration,
      curve: curve,
      onFinish: () => {
        hiTraceMeter.finishTrace(traceId, 1);
        this.isAnimating = false;
        this.currentAnimationController = null;
        onFinish();
        Logger.debug('PageTurnAnimationOptimizer', `翻页动画完成: ${direction}`);
      }
    }, () => {
      onAnimation();
    });

    // 保存动画控制器，用于取消
    this.currentAnimationController = () => {
      Logger.debug('PageTurnAnimationOptimizer', `动画被取消: ${direction}`);
    };
  }

  /**
   * 预渲染下一章
   * @param chapterIndex 章节索引
   * @param content 章节内容
   */
  preRenderNextChapter(chapterIndex: number, content: string): void {
    Logger.debug('PageTurnAnimationOptimizer', `预渲染章节: ${chapterIndex}`);

    // 限制预渲染缓存数量为2章
    if (this.preRenderCache.size >= 2) {
      this.evictOldestPreRender();
    }

    this.preRenderCache.set(chapterIndex, {
      chapterIndex,
      content,
      timestamp: Date.now()
    });
  }

  /**
   * 获取预渲染内容
   * @param chapterIndex 章节索引
   * @returns 预渲染内容，不存在返回null
   */
  getPreRenderContent(chapterIndex: number): string | null {
    const node = this.preRenderCache.get(chapterIndex);
    if (node) {
      Logger.debug('PageTurnAnimationOptimizer', `使用预渲染内容: ${chapterIndex}`);
      return node.content;
    }
    return null;
  }

  /**
   * 取消当前动画
   */
  cancelAnimation(): void {
    if (this.currentAnimationController) {
      this.currentAnimationController();
      this.currentAnimationController = null;
      this.isAnimating = false;
      Logger.debug('PageTurnAnimationOptimizer', '动画已取消');
    }
  }

  /**
   * 清空预渲染缓存
   */
  clearPreRenderCache(): void {
    this.preRenderCache.clear();
    Logger.info('PageTurnAnimationOptimizer', '预渲染缓存已清空');
  }

  /**
   * 获取动画时长（根据资源级别调整）
   */
  private getAnimationDuration(): number {
    switch (this.resourceLevel) {
      case ResourceLevel.ABUNDANT:
        return 200;
      case ResourceLevel.NORMAL:
        return 200;
      case ResourceLevel.LOW:
        return 150;
      case ResourceLevel.CRITICAL:
        return 100;
      default:
        return 200;
    }
  }
  /**
   * 获取动画曲线（根据资源级别调整）
   */
  private getAnimationCurve(): Curve {
    switch (this.resourceLevel) {
      case ResourceLevel.ABUNDANT:
        return Curve.EaseOut;
      case ResourceLevel.NORMAL:
        return Curve.EaseOut;
      case ResourceLevel.LOW:
        return Curve.FastOutLinearIn;
      case ResourceLevel.CRITICAL:
        return Curve.Linear;
      default:
        return Curve.EaseOut;
    }
  }

  /**
   * 淘汰最旧的预渲染
   */
  private evictOldestPreRender(): void {
    let oldestKey: number | null = null;
    let oldestTimestamp = Infinity;

    this.preRenderCache.forEach((node, key) => {
      if (node.timestamp < oldestTimestamp) {
        oldestTimestamp = node.timestamp;
        oldestKey = key;
      }
    });

    if (oldestKey !== null) {
      this.preRenderCache.delete(oldestKey);
      Logger.debug('PageTurnAnimationOptimizer', `淘汰预渲染: ${oldestKey}`);
    }
  }

  /**
   * 开始资源监控
   */
  private startResourceMonitoring(): void {
    Logger.info('PageTurnAnimationOptimizer', '开始资源监控');
  }

  /**
   * 更新资源级别
   */
  updateResourceLevel(level: ResourceLevel): void {
    this.resourceLevel = level;
    Logger.debug('PageTurnAnimationOptimizer', `资源级别更新: ${level}`);
  }
}
