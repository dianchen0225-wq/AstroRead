/**
 * BookSourceDebuggerComponent - 书源调试组件
 * 提供可视化界面测试书源规则
 */

import { BookSource } from '../models/BookSource';
import { BookSourceDebugger, DebugStep, DebugResult, BookInfo, ChapterInfo } from '../utils/BookSourceDebugger';
import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';

@Component
export struct BookSourceDebuggerComponent {
  @Prop source: BookSource;
  @State activeTab: number = 0;
  @State keyword: string = '斗破苍穹';
  @State bookUrl: string = '';
  @State chapterUrl: string = '';
  @State isRunning: boolean = false;
  @State steps: DebugStep[] = [];
  @State result: DebugResult | null = null;
  @State errorMessage: string = '';
  @State isLightMode: boolean = true;

  private debugger = BookSourceDebugger.getInstance();

  aboutToAppear() {
    this.isLightMode = themeManager.isLightTheme();
  }

  private async runSearchTest() {
    if (!this.keyword) {
      this.errorMessage = '请输入搜索关键词';
      return;
    }

    this.isRunning = true;
    this.steps = [];
    this.result = null;
    this.errorMessage = '';

    const result = await this.debugger.testSearch(
      this.source,
      this.keyword,
      (step: DebugStep) => {
        this.steps.push(step);
        this.steps = [...this.steps]; // 触发更新
      }
    );

    this.result = result;
    this.isRunning = false;
  }

  private async runChapterTest() {
    if (!this.bookUrl) {
      this.errorMessage = '请输入书籍 URL';
      return;
    }

    this.isRunning = true;
    this.steps = [];
    this.result = null;
    this.errorMessage = '';

    const result = await this.debugger.testChapterList(
      this.source,
      this.bookUrl,
      (step: DebugStep) => {
        this.steps.push(step);
        this.steps = [...this.steps];
      }
    );

    this.result = result;
    this.isRunning = false;
  }

  private async runContentTest() {
    if (!this.chapterUrl) {
      this.errorMessage = '请输入章节 URL';
      return;
    }

    this.isRunning = true;
    this.steps = [];
    this.result = null;
    this.errorMessage = '';

    const result = await this.debugger.testContent(
      this.source,
      this.chapterUrl,
      (step: DebugStep) => {
        this.steps.push(step);
        this.steps = [...this.steps];
      }
    );

    this.result = result;
    this.isRunning = false;
  }

  private getStatusIcon(status: string): string {
    switch (status) {
      case 'running': return '⏳';
      case 'success': return '✅';
      case 'error': return '❌';
      default: return '⏸️';
    }
  }

  private getStatusColor(status: string): ResourceColor {
    switch (status) {
      case 'running': return '#FFA500';
      case 'success': return '#52C41A';
      case 'error': return '#FF4D4F';
      default: return '#999999';
    }
  }

  build() {
    Column() {
      // 标题
      Text('书源调试工具')
        .fontSize(20)
        .fontWeight(600)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 16, bottom: 16 })
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

      // 标签页切换
      Row() {
        this.buildTab('搜索测试', 0)
        this.buildTab('章节测试', 1)
        this.buildTab('正文测试', 2)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .margin({ bottom: 16 })

      // 输入区域
      this.buildInputArea()

      // 执行按钮
      Button(this.isRunning ? '执行中...' : '开始测试')
        .width('100%')
        .margin({ top: 16, bottom: 16 })
        .enabled(!this.isRunning)
        .onClick(() => {
          switch (this.activeTab) {
            case 0: this.runSearchTest(); break;
            case 1: this.runChapterTest(); break;
            case 2: this.runContentTest(); break;
          }
        })

      // 错误提示
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontColor('#FF4D4F')
          .fontSize(14)
          .margin({ bottom: 8 })
      }

      // 调试步骤
      if (this.steps.length > 0) {
        Text('执行步骤')
          .fontSize(16)
          .fontWeight(600)
          .width('100%')
          .margin({ top: 8, bottom: 8 })
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

        List() {
          ForEach(this.steps, (step: DebugStep, index: number) => {
            ListItem() {
              Column() {
                Row() {
                  Text(this.getStatusIcon(step.status))
                    .fontSize(16)
                    .margin({ right: 8 })

                  Text(step.name)
                    .fontSize(14)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .layoutWeight(1)

                  if (step.duration) {
                    Text(`${step.duration}ms`)
                      .fontSize(12)
                      .fontColor('#999999')
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                // 输入输出信息
                if (step.input || step.output) {
                  Column() {
                    if (step.input) {
                      Text(`输入: ${step.input.substring(0, 100)}${step.input.length > 100 ? '...' : ''}`)
                        .fontSize(11)
                        .fontColor('#666666')
                        .width('100%')
                    }
                    if (step.output) {
                      Text(`输出: ${step.output.substring(0, 100)}${step.output.length > 100 ? '...' : ''}`)
                        .fontSize(11)
                        .fontColor('#666666')
                        .width('100%')
                        .margin({ top: 4 })
                    }
                  }
                  .width('100%')
                  .padding(8)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(4)
                  .margin({ top: 8 })
                }

                // 错误信息
                if (step.error) {
                  Text(`错误: ${step.error}`)
                    .fontSize(11)
                    .fontColor('#FF4D4F')
                    .width('100%')
                    .margin({ top: 4 })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
              .margin({ bottom: 8 })
            }
          }, (step: DebugStep, index: number) => index.toString())
        }
        .width('100%')
        .height(200)
        .scrollBar(BarState.Auto)
      }

      // 结果展示
      if (this.result) {
        this.buildResultArea()
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  @Builder
  buildTab(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(this.activeTab === index ? 600 : 400)
        .fontColor(this.activeTab === index
          ? DesignSystem.getPrimaryColor(this.isLightMode)
          : DesignSystem.getSecondaryTextColor(this.isLightMode))
        .padding({ top: 8, bottom: 8 })
    }
    .width('33%')
    .border({
      width: { bottom: 2 },
      color: this.activeTab === index
        ? DesignSystem.getPrimaryColor(this.isLightMode)
        : 'transparent'
    })
    .onClick(() => {
      this.activeTab = index;
      this.steps = [];
      this.result = null;
    })
  }

  @Builder
  buildInputArea() {
    Column() {
      if (this.activeTab === 0) {
        // 搜索测试输入
        Text('搜索关键词')
          .fontSize(14)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ bottom: 8 })

        TextInput({ text: $$this.keyword })
          .width('100%')
      } else if (this.activeTab === 1) {
        // 章节测试输入
        Text('书籍 URL')
          .fontSize(14)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ bottom: 8 })

        TextInput({ text: $$this.bookUrl })
          .width('100%')
      } else {
        // 正文测试输入
        Text('章节 URL')
          .fontSize(14)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .width('100%')
          .margin({ bottom: 8 })

        TextInput({ text: $$this.chapterUrl })
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  buildResultArea() {
    Column() {
      Text('测试结果')
        .fontSize(16)
        .fontWeight(600)
        .width('100%')
        .margin({ top: 16, bottom: 8 })
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

      // 结果摘要
      Text(this.result?.summary || '')
        .fontSize(14)
        .fontColor(this.result?.success ? '#52C41A' : '#FF4D4F')
        .width('100%')
        .margin({ bottom: 8 })

      // 书籍结果列表
      if (this.result?.books && this.result.books.length > 0) {
        Text(`找到 ${this.result.books.length} 本书`)
          .fontSize(14)
          .fontWeight(600)
          .width('100%')
          .margin({ top: 8, bottom: 8 })
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

        List() {
          ForEach(this.result.books, (book: BookInfo, index: number) => {
            ListItem() {
              Column() {
                Text(book.name)
                  .fontSize(14)
                  .fontWeight(600)
                  .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                  .width('100%')

                if (book.author) {
                  Text(`作者: ${book.author}`)
                    .fontSize(12)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .width('100%')
                    .margin({ top: 4 })
                }

                if (book.bookUrl) {
                  Text(`链接: ${book.bookUrl.substring(0, 50)}...`)
                    .fontSize(11)
                    .fontColor('#666666')
                    .width('100%')
                    .margin({ top: 4 })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
              .margin({ bottom: 8 })
            }
          }, (book: BookInfo, index: number) => index.toString())
        }
        .width('100%')
        .height(150)
      }

      // 章节结果列表
      if (this.result?.chapters && this.result.chapters.length > 0) {
        Text(`找到 ${this.result.chapters.length} 个章节`)
          .fontSize(14)
          .fontWeight(600)
          .width('100%')
          .margin({ top: 8, bottom: 8 })
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

        List() {
          ForEach(this.result.chapters, (chapter: ChapterInfo, index: number) => {
            ListItem() {
              Text(chapter.title || '无标题')
                .fontSize(13)
                .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                .width('100%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding(8)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .borderRadius(4)
            .margin({ bottom: 4 })
          }, (chapter: ChapterInfo, index: number) => index.toString())
        }
        .width('100%')
        .height(120)
      }

      // 正文内容预览
      if (this.result?.content) {
        Text('正文预览')
          .fontSize(14)
          .fontWeight(600)
          .width('100%')
          .margin({ top: 8, bottom: 8 })
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

        Text(this.result.content.substring(0, 500) + '...')
          .fontSize(12)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .width('100%')
          .padding(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(8)
      }
    }
    .width('100%')
  }
}

export default BookSourceDebuggerComponent;
