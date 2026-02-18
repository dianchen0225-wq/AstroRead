/**
 * HttpClient 测试页面
 * 提供 UI 界面来运行 HttpClient 单元测试
 */

import HttpClientTestRunner from '../network/__tests__/HttpClientTestRunner';

@Entry
@Component
struct HttpClientTestPage {
  @State testRunning: boolean = false;
  @State testResults: string[] = [];
  @State successCount: number = 0;
  @State totalCount: number = 0;
  @State testDuration: number = 0;

  build() {
    Column({ space: 20 }) {
      Text('HttpClient 单元测试')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)

      if (this.testRunning) {
        LoadingProgress()
          .width(40)
          .height(40)
        
        Text('测试运行中...')
          .fontSize(16)
      } else {
        Button('运行测试')
          .width('80%')
          .height(50)
          .fontSize(18)
          .fontColor(Color.White)
          .backgroundColor('#007DFF')
          .onClick(() => {
            this.runTests();
          })
      }

      if (this.testResults.length > 0) {
        Text(`测试结果: ${this.successCount}/${this.totalCount} 通过`)
          .fontSize(18)
          .fontColor(this.successCount === this.totalCount ? '#00C853' : '#FF3B30')

        Text(`耗时: ${this.testDuration}ms`)
          .fontSize(14)
          .fontColor('#666666')

        List({ space: 10 }) {
          ForEach(this.testResults, (result: string, index: number) => {
            ListItem() {
              Text(result)
                .fontSize(14)
                .fontColor(result.includes('✅') ? '#00C853' : '#FF3B30')
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
  }

  async runTests() {
    this.testRunning = true;
    this.testResults = [];
    this.successCount = 0;
    this.totalCount = 0;
    this.testDuration = 0;

    const startTime = Date.now();
    
    try {
      const success = await HttpClientTestRunner.runTests();
      this.successCount = success ? 7 : 0;
      this.totalCount = 7;
    } catch (error) {
      const errorMsg = '❌ 测试运行失败: ' + String(error);
      this.testResults.push(errorMsg);
      this.successCount = 0;
      this.totalCount = 7;
    }

    this.testDuration = Date.now() - startTime;
    
    this.testRunning = false;
  }
}