import { router } from '@kit.ArkUI';
import { logCollector, LogEntry } from '../utils/LogCollector';
import { Logger } from '../utils/Logger';

@Entry
@Component
struct DebugLogPage {
  @State logs: LogEntry[] = [];
  @State filterTag: string = '';
  @State filterLevel: string = 'all';
  @State isAutoRefresh: boolean = true;
  private refreshTimer: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.loadLogs();
    // 启动自动刷新
    this.startAutoRefresh();
  }

  aboutToDisappear() {
    this.stopAutoRefresh();
  }

  startAutoRefresh() {
    if (this.refreshTimer === 0) {
      this.refreshTimer = setInterval(() => {
        if (this.isAutoRefresh) {
          this.loadLogs();
        }
      }, 1000);
    }
  }

  stopAutoRefresh() {
    if (this.refreshTimer !== 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = 0;
    }
  }

  loadLogs() {
    let logs = logCollector.getAllLogs();

    // 按标签过滤
    if (this.filterTag.trim().length > 0) {
      logs = logs.filter(log => log.tag.toLowerCase().includes(this.filterTag.toLowerCase()));
    }

    // 按级别过滤
    if (this.filterLevel !== 'all') {
      logs = logs.filter(log => log.level === this.filterLevel);
    }

    this.logs = logs;
  }

  getLevelColor(level: string): ResourceColor {
    switch (level) {
      case 'error':
        return '#f44336';
      case 'warn':
        return '#ff9800';
      case 'info':
        return '#2196f3';
      case 'debug':
        return '#9e9e9e';
      default:
        return '#666';
    }
  }

  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}:${date.getSeconds().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })

        Text('调试日志')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row() {
          Text('自动刷新')
            .fontSize(12)
            .margin({ right: 8 })

          Toggle({ type: ToggleType.Switch, isOn: this.isAutoRefresh })
            .selectedColor('#4CAF50')
            .onChange((isOn: boolean) => {
              this.isAutoRefresh = isOn;
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#f5f5f5')

      // 过滤栏
      Column() {
        Row() {
          TextInput({ placeholder: '过滤标签...', text: this.filterTag })
            .layoutWeight(1)
            .height(40)
            .onChange((value: string) => {
              this.filterTag = value;
              this.loadLogs();
            })

          Button('清除')
            .fontSize(12)
            .height(32)
            .margin({ left: 8 })
            .onClick(() => {
              this.filterTag = '';
              this.loadLogs();
            })
        }
        .width('100%')

        Row() {
          Text('级别:')
            .fontSize(14)
            .margin({ right: 8 })

          Select([
            { value: 'all', icon: $r('app.media.ic_default') },
            { value: 'error', icon: $r('app.media.ic_error') },
            { value: 'warn', icon: $r('app.media.ic_warning') },
            { value: 'info', icon: $r('app.media.ic_info') },
            { value: 'debug', icon: $r('app.media.ic_debug') }
          ])
            .selected(this.filterLevel === 'all' ? 0 :
              this.filterLevel === 'error' ? 1 :
                this.filterLevel === 'warn' ? 2 :
                  this.filterLevel === 'info' ? 3 : 4)
            .value(this.filterLevel === 'all' ? '全部' :
              this.filterLevel === 'error' ? '错误' :
                this.filterLevel === 'warn' ? '警告' :
                  this.filterLevel === 'info' ? '信息' : '调试')
            .onSelect((index: number) => {
              const levels = ['all', 'error', 'warn', 'info', 'debug'];
              this.filterLevel = levels[index];
              this.loadLogs();
            })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#fafafa')

      // 日志统计
      Row() {
        Text(`共 ${this.logs.length} 条日志`)
          .fontSize(12)
          .fontColor('#666')

        Blank()

        Button('导出')
          .fontSize(12)
          .height(32)
          .onClick(() => {
            const exported = logCollector.exportLogs();
            Logger.info('DebugLogPage', '日志已导出到控制台');
            console.log('========== 导出的日志 ==========');
            console.log(exported);
            console.log('================================');
          })

        Button('清空')
          .fontSize(12)
          .height(32)
          .fontColor('#f44336')
          .backgroundColor('transparent')
          .onClick(() => {
            logCollector.clearLogs();
            this.loadLogs();
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#f0f0f0')

      // 日志列表
      List({ scroller: this.scroller }) {
        ForEach(this.logs, (log: LogEntry, index: number) => {
          ListItem() {
            Column() {
              Row() {
                Text(`[${this.formatTime(log.timestamp)}]`)
                  .fontSize(10)
                  .fontColor('#999')
                  .width(70)

                Text(`[${log.level.toUpperCase()}]`)
                  .fontSize(10)
                  .fontColor(this.getLevelColor(log.level))
                  .width(50)

                Text(`[${log.tag}]`)
                  .fontSize(10)
                  .fontColor('#666')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')

              Text(log.message)
                .fontSize(12)
                .fontColor('#333')
                .margin({ top: 4 })
                .width('100%')
            }
            .width('100%')
            .padding(8)
            .backgroundColor(index % 2 === 0 ? '#fff' : '#fafafa')
            .alignItems(HorizontalAlign.Start)
          }
        }, (log: LogEntry, index: number) => index.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
