/**
 * BookSourceRepairPage - 书源修复页面
 * 提供可视化界面来诊断和修复书源问题
 */

import { BookSource } from '../models/BookSource';
import { BookSourceDiagnosticTool, DiagnosticSummary } from '../utils/BookSourceDiagnosticTool';
import { BookSourceManager } from '../utils/BookSourceManager';
import { EnhancedSourceHealthManager } from '../utils/EnhancedSourceHealthManager';
import { Logger } from '../utils/Logger';
import { BookSourceViewModel } from '../viewmodel/BookSourceViewModel';

@Entry
@ComponentV2
export struct BookSourceRepairPage {
  @Local diagnosticSummary: DiagnosticSummary | null = null;
  @Local isDiagnosing: boolean = false;
  @Local repairResults: string[] = [];
  @Local selectedSourceId: string = '';
  @Local repairMessage: string = '';
  @Local showDetails: boolean = false;

  private diagnosticTool: BookSourceDiagnosticTool = BookSourceDiagnosticTool.getInstance();
  private sourceManager: BookSourceManager = BookSourceManager.getInstance();
  private healthManager: EnhancedSourceHealthManager = EnhancedSourceHealthManager.getInstance();
  private viewModel: BookSourceViewModel = BookSourceViewModel.getInstance();

  aboutToAppear(): void {
    // 初始化上下文
  }

  refreshSources(): void {
    // 无需手动刷新，通过方法获取最新数据
  }

  build() {
    Column() {
      Text('书源诊断与修复')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })

      Row() {
        Button('开始诊断')
          .onClick(() => {
            this.runDiagnosis();
          })
          .enabled(!this.isDiagnosing)
          .margin({ right: 10 })

        Button('一键修复')
          .onClick(() => {
            this.runAutoRepair();
          })
          .enabled(this.diagnosticSummary !== null && !this.isDiagnosing)
          .margin({ right: 10 })

        Button('重置所有健康度')
          .onClick(() => {
            this.resetAllHealth();
          })
          .enabled(!this.isDiagnosing)
      }
      .margin({ bottom: 20 })

      if (this.isDiagnosing) {
        Text('正在诊断中...')
          .fontSize(16)
          .fontColor('#666666')
          .margin({ bottom: 20 })
      }

      if (this.diagnosticSummary) {
        Column() {
          Column() {
            Text(`诊断结果`)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)

            Divider()
              .margin({ top: 10, bottom: 10 })

            Row() {
              Text(`总计书源: ${this.diagnosticSummary.totalSources}`)
                .fontSize(14)
                .layoutWeight(1)
              Text(`健康: ${this.diagnosticSummary.healthySources}`)
                .fontSize(14)
                .fontColor('#28a745')
                .layoutWeight(1)
              Text(`异常: ${this.diagnosticSummary.unhealthySources}`)
                .fontSize(14)
                .fontColor('#dc3545')
                .layoutWeight(1)
            }
            .margin({ bottom: 10 })

            if (this.diagnosticSummary.issuesFound.length > 0) {
              Text('发现问题:')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ top: 10, bottom: 5 })

              List({ space: 5 }) {
                ForEach(this.diagnosticSummary.issuesFound, (issue: string) => {
                  ListItem() {
                    Text(`• ${issue}`)
                      .fontSize(14)
                      .maxLines(3)
                      .fontColor('#dc3545')
                  }
                }, (item: string) => item)
              }
              .height(150)
            }

            if (this.diagnosticSummary.repairSuggestions.length > 0) {
              Text('修复建议:')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ top: 10, bottom: 5 })

              List({ space: 5 }) {
                ForEach(this.diagnosticSummary.repairSuggestions, (suggestion: string) => {
                  ListItem() {
                    Text(`• ${suggestion}`)
                      .fontSize(14)
                      .maxLines(3)
                      .fontColor('#007bff')
                  }
                }, (item: string) => item)
              }
              .height(150)
            }
          }
          .padding(15)
        }
        .margin({ bottom: 20 })
      }

      if (this.repairMessage) {
        Text(this.repairMessage)
          .fontSize(16)
          .fontColor('#28a745')
          .margin({ bottom: 20 })
      }

      if (this.repairResults.length > 0) {
        Column() {
          Column() {
            Text('修复详情')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)

            Divider()
              .margin({ top: 10, bottom: 10 })

            List({ space: 5 }) {
              ForEach(this.repairResults, (result: string) => {
                ListItem() {
                  Text(result)
                    .fontSize(14)
                    .fontColor('#28a745')
                }
              }, (item: string) => item)
            }
            .height(200)
          }
          .padding(15)
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
  }

  private async runDiagnosis(): Promise<void> {
    this.isDiagnosing = true;
    this.repairResults = [];
    this.repairMessage = '';

    try {
      // 直接从数据库获取所有启用的书源
      const sources = await this.viewModel.loadEnabledBookSources();
      this.diagnosticSummary = await this.diagnosticTool.diagnoseSources(sources);
      Logger.info('BookSourceRepairPage', `诊断完成: ${JSON.stringify(this.diagnosticSummary)}`);
    } catch (error) {
      Logger.error('BookSourceRepairPage', `诊断失败: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      this.isDiagnosing = false;
    }
  }

  private async runAutoRepair(): Promise<void> {
    this.isDiagnosing = true;
    this.repairResults = [];

    try {
      const sources = await this.viewModel.loadAllBookSources();
      const enabledSources = sources.filter(source => source.enabled);
      const repairedCount = await this.diagnosticTool.repairAll(enabledSources, true);
      
      this.repairMessage = `修复完成: ${repairedCount}/${enabledSources.length} 个书源已修复`;
      
      // 重新诊断以显示修复效果
      this.diagnosticSummary = await this.diagnosticTool.diagnoseSources(enabledSources);
    } catch (error) {
      this.repairMessage = `修复失败: ${error instanceof Error ? error.message : String(error)}`;
      Logger.error('BookSourceRepairPage', `修复失败: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      this.isDiagnosing = false;
    }
  }

  private resetAllHealth(): void {
    this.healthManager.resetAllRecords();
    this.repairMessage = '所有书源健康度已重置';
  }
}