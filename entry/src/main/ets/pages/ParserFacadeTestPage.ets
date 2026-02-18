/**
 * ParserFacade 测试页面
 * 用于在 UI 中运行和查看测试结果
 */

import { ParserFacadeTestRunner } from '../core/__tests__/ParserFacadeTestRunner';

@Entry
@Component
struct ParserFacadeTestPage {
  @State testResults: string = '测试未运行';
  @State isRunning: boolean = false;
  @State successCount: number = 0;
  @State totalCount: number = 0;

  build() {
    Column() {
      Text('ParserFacade 单元测试')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })

      Text(this.testResults)
        .fontSize(16)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })
        .maxLines(10)

      Text(`测试结果: ${this.successCount}/${this.totalCount} 通过`)
        .fontSize(18)
        .fontColor(this.successCount === this.totalCount ? Color.Green : Color.Red)
        .margin({ bottom: 20 })

      Button(this.isRunning ? '测试运行中...' : '运行测试')
        .enabled(!this.isRunning)
        .onClick(() => {
          this.runTests();
        })
        .margin({ bottom: 10 })

      Button('清除结果')
        .enabled(!this.isRunning)
        .onClick(() => {
          this.clearResults();
        })
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  async runTests() {
    this.isRunning = true;
    this.testResults = '测试运行中...';
    
    try {
      const success = await ParserFacadeTestRunner.runTests();
      this.successCount = success ? 12 : 0; // 假设有12个测试
      this.totalCount = 12;
      this.testResults = success ? '✅ 所有测试通过!' : '❌ 部分测试失败';
    } catch (error) {
      this.testResults = `❌ 测试运行出错: ${error}`;
      this.successCount = 0;
      this.totalCount = 12;
    }
    
    this.isRunning = false;
  }

  clearResults() {
    this.testResults = '测试未运行';
    this.successCount = 0;
    this.totalCount = 0;
  }
}