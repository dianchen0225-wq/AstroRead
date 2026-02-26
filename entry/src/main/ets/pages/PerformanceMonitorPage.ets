/**
 * PerformanceMonitorPage - 性能监控页面
 * 显示应用性能指标和警告信息
 */

import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { performanceMonitor, PerformanceMetrics, PerformanceWarning } from '../utils/performance/PerformanceMonitor';
import { smartSourceSelector } from '../utils/search/SmartSourceSelector';
import { GCOptimizer } from '../utils/cache/ObjectPool';
import { Logger } from '../utils/performance/Logger';

@ComponentV2
export struct PerformanceMonitorPage {
  @Local isLightMode: boolean = true;
  @Local currentMetrics: PerformanceMetrics | null = null;
  @Local warnings: PerformanceWarning[] = [];
  @Local isMonitoring: boolean = false;
  @Local autoRefresh: boolean = true;
  @Local refreshInterval: number = 2000;

  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);

    this.loadMetrics();
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
    this.stopAutoRefresh();
  }

  private loadMetrics(): void {
    this.currentMetrics = performanceMonitor.getCurrentMetrics();
    this.warnings = performanceMonitor.getRecentWarnings(20);
    this.isMonitoring = true;
  }

  private startAutoRefresh(): void {
    if (this.autoRefresh) {
      this.refreshTimer = setInterval(() => {
        this.loadMetrics();
      }, this.refreshInterval);
    }
  }

  private stopAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private toggleAutoRefresh(): void {
    this.autoRefresh = !this.autoRefresh;
    if (this.autoRefresh) {
      this.startAutoRefresh();
    } else {
      this.stopAutoRefresh();
    }
  }

  private clearWarnings(): void {
    performanceMonitor.clearWarnings();
    this.warnings = [];
  }

  private getSeverityColor(severity: string): string {
    switch (severity) {
      case 'critical':
        return '#FF0000';
      case 'high':
        return '#FF6600';
      case 'medium':
        return '#FFCC00';
      case 'low':
        return '#00CC00';
      default:
        return DesignSystem.getSecondaryTextColor(this.isLightMode);
    }
  }

  private formatBytes(bytes: number): string {
    if (bytes < 1024) return `${bytes}B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)}KB`;
    return `${(bytes / 1024 / 1024).toFixed(2)}MB`;
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}:${date.getSeconds().toString().padStart(2, '0')}`;
  }

  @Builder
  headerBuilder() {
    Row() {
      Text('性能监控')
        .fontSize(20)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(600)
        .layoutWeight(1)

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.autoRefresh })
          .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .onChange(() => {
            this.toggleAutoRefresh();
          })

        Text('自动刷新')
          .fontSize(12)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ left: 8 })
      }
      .margin({ right: 16 })

      Button('刷新')
        .fontSize(14)
        .fontColor(DesignSystem.Colors.text.primary.light)
        .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .borderRadius(8)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .onClick(() => {
          this.loadMetrics();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 15, bottom: 15 })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: { bottom: 1 },
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }

  @Builder
  metricsCardBuilder(title: string, metrics: Record<string, string | number>) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(600)
        .margin({ bottom: 12 })

      ForEach(Object.keys(metrics), (key: string) => {
        Row() {
          Text(key)
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .layoutWeight(1)

          Text(`${metrics[key]}`)
            .fontSize(14)
            .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
            .fontWeight(500)
        }
        .width('100%')
        .margin({ bottom: 8 })
      })
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .margin({ bottom: 12 })
  }

  @Builder
  warningsBuilder() {
    Column() {
      Row() {
        Text('性能警告')
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)

        if (this.warnings.length > 0) {
          Button('清除')
            .fontSize(12)
            .fontColor(DesignSystem.Colors.text.primary.light)
            .backgroundColor('#FF6600')
            .borderRadius(6)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .onClick(() => {
              this.clearWarnings();
            })
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.warnings.length === 0) {
        Column() {
          Text('✓')
            .fontSize(32)
            .fontColor('#00CC00')
            .margin({ bottom: 8 })

          Text('暂无性能警告')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        }
        .width('100%')
        .height(100)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.warnings, (warning: PerformanceWarning) => {
            ListItem() {
              Row() {
                Column() {
                  Row() {
                    Text(`[${warning.severity.toUpperCase()}]`)
                      .fontSize(12)
                      .fontColor(this.getSeverityColor(warning.severity))
                      .fontWeight(600)

                    Text(warning.message)
                      .fontSize(14)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                      .layoutWeight(1)
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .margin({ bottom: 4 })

                  Text(this.formatTime(warning.timestamp))
                    .fontSize(11)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor(DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
            }
            .margin({ bottom: 8 })
          })
        }
        .width('100%')
        .height(200)
        .cachedCount(5)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .margin({ bottom: 12 })
  }

  @Builder
  actionsBuilder() {
    Column() {
      Text('操作')
        .fontSize(16)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
        .fontWeight(600)
        .margin({ bottom: 12 })

      Row() {
        Button('生成报告')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            const report = performanceMonitor.generateReport();
            Logger.info('PerformanceMonitorPage', report);
          })

        Button('GC优化统计')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            const stats = GCOptimizer.getStats();
            Logger.info('PerformanceMonitorPage', JSON.stringify(stats));
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      Row() {
        Button('书源报告')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            const report = smartSourceSelector.getReport();
            Logger.info('PerformanceMonitorPage', report);
          })

        Button('重置指标')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor('#FF6600')
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            performanceMonitor.reset();
            this.loadMetrics();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  build() {
    Column() {
      this.headerBuilder()

      if (this.currentMetrics) {
        Scroll() {
          Column() {
            // 系统指标
            this.metricsCardBuilder('系统指标', {
              '内存使用': this.formatBytes(this.currentMetrics.memoryUsage),
              '内存峰值': this.formatBytes(this.currentMetrics.memoryPeak),
              'GC次数': this.currentMetrics.gcCount,
              'CPU使用率': `${this.currentMetrics.cpuUsage.toFixed(1)}%`
            })

            // 渲染指标
            this.metricsCardBuilder('渲染指标', {
              'FPS': this.currentMetrics.fps.toFixed(1),
              '帧时间': `${this.currentMetrics.frameTime.toFixed(2)}ms`,
              '丢帧数': this.currentMetrics.droppedFrames
            })

            // 网络指标
            this.metricsCardBuilder('网络指标', {
              '总请求数': this.currentMetrics.networkRequests,
              '成功率': `${(this.currentMetrics.networkSuccessRate * 100).toFixed(1)}%`,
              '平均响应时间': `${this.currentMetrics.avgResponseTime.toFixed(0)}ms`,
              '活跃连接': this.currentMetrics.activeConnections
            })

            // 书源指标
            this.metricsCardBuilder('书源指标', {
              '活跃书源': this.currentMetrics.activeSources,
              '健康书源': this.currentMetrics.healthySources,
              '黑名单书源': this.currentMetrics.blacklistedSources
            })

            // 缓存指标
            this.metricsCardBuilder('缓存指标', {
              '缓存命中率': `${(this.currentMetrics.cacheHitRate * 100).toFixed(1)}%`,
              '缓存大小': this.formatBytes(this.currentMetrics.cacheSize)
            })

            // 警告
            this.warningsBuilder()

            // 操作按钮
            this.actionsBuilder()
          }
          .width('100%')
          .padding(20)
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(DesignSystem.getPrimaryColor(this.isLightMode))

          Text('加载中...')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}
