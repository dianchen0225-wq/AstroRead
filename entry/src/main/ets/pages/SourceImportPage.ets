/**
 * 书源导入页面
 * 提供多种方式导入书源：手动输入、文件导入、网络导入
 */

import { BookSourceViewModel, ImportResult } from '../viewmodel/BookSourceViewModel';
import { BookSource } from '../models/BookSource';
import { Logger } from '../utils/Logger';

@Entry
@Component
struct SourceImportPage {
  @State message: string = '';
  @State isImporting: boolean = false;
  @State importResult: ImportResult | null = null;
  @State importContent: string = '';
  @State selectedFormat: string = 'auto';
  @State showFormatOptions: boolean = false;
  
  private bookSourceViewModel: BookSourceViewModel = new BookSourceViewModel();
  
  aboutToAppear() {
    Logger.info('SourceImportPage', '页面加载完成');
  }
  
  build() {
    Column({ space: 20 }) {
      // 标题
      Text('书源导入')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 30, bottom: 20 })
      
      // 导入方式选择
      this.buildImportMethodSelector()
      
      // 内容输入区域
      this.buildContentInputArea()
      
      // 格式选择
      this.buildFormatSelector()
      
      // 操作按钮
      this.buildActionButtons()
      
      // 结果显示
      this.buildResultDisplay()
      
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F5F5')
  }
  
  // 构建导入方式选择器
  @Builder
  buildImportMethodSelector() {
    Column({ space: 10 }) {
      Text('导入方式')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .align(Alignment.Start)
        .width('100%')
      
      Row({ space: 15 }) {
        Button('手动输入')
          .borderRadius(8)
          .backgroundColor(this.importContent.length === 0 ? '#007DFF' : '#CCCCCC')
          .onClick(() => {
            this.importContent = '';
            this.message = '请在下方输入书源内容';
          })
        
        Button('粘贴内容')
          .borderRadius(8)
          .backgroundColor('#007DFF')
          .onClick(() => {
            // TODO: 实现粘贴板功能
            this.message = '请长按输入框选择粘贴';
          })
        
        Button('文件导入')
          .borderRadius(8)
          .backgroundColor('#007DFF')
          .onClick(() => {
            // TODO: 实现文件选择功能
            this.message = '文件导入功能开发中';
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('100%')
  }
  
  // 构建内容输入区域
  @Builder
  buildContentInputArea() {
    Column({ space: 10 }) {
      Text('书源内容')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .align(Alignment.Start)
        .width('100%')
      
      TextArea({
        placeholder: '请输入书源JSON内容、XML内容或TXT格式内容...',
        text: this.importContent
      })
      .onChange((value: string) => {
        this.importContent = value;
        // 自动检测格式
        if (this.selectedFormat === 'auto') {
          const detectedFormat = this.bookSourceViewModel.detectSourceFormat(value);
          if (detectedFormat !== 'unknown') {
            this.message = `检测到格式：${detectedFormat.toUpperCase()}`;
          }
        }
      })
      .height(200)
      .width('100%')
      .borderRadius(8)
      .padding(10)
      .backgroundColor(Color.White)
      
      // 输入提示
      if (this.message) {
        Text(this.message)
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
  }
  
  // 构建格式选择器
  @Builder
  buildFormatSelector() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('格式选择')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        
        Button(this.getFormatDisplayName())
          .borderRadius(6)
          .fontSize(14)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.showFormatOptions = !this.showFormatOptions;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      
      // 格式选项
      if (this.showFormatOptions) {
        Column({ space: 5 }) {
          RadioGroup({ group: 'formatGroup' }) {
            Radio({ value: 'auto', group: 'formatGroup' })
              .checked(this.selectedFormat === 'auto')
              .onChange((value: string) => {
                this.selectedFormat = value;
                this.showFormatOptions = false;
              })
            Text('自动检测')
              .fontSize(14)
              .margin({ left: 10 })
            
            Radio({ value: 'json', group: 'formatGroup' })
              .checked(this.selectedFormat === 'json')
              .onChange((value: string) => {
                this.selectedFormat = value;
                this.showFormatOptions = false;
              })
            Text('JSON格式')
              .fontSize(14)
              .margin({ left: 10 })
            
            Radio({ value: 'xml', group: 'formatGroup' })
              .checked(this.selectedFormat === 'xml')
              .onChange((value: string) => {
                this.selectedFormat = value;
                this.showFormatOptions = false;
              })
            Text('XML格式')
              .fontSize(14)
              .margin({ left: 10 })
            
            Radio({ value: 'txt', group: 'formatGroup' })
              .checked(this.selectedFormat === 'txt')
              .onChange((value: string) => {
                this.selectedFormat = value;
                this.showFormatOptions = false;
              })
            Text('TXT格式')
              .fontSize(14)
              .margin({ left: 10 })
          }
          .width('100%')
        }
        .width('100%')
        .padding(10)
        .backgroundColor(Color.White)
        .borderRadius(8)
      }
    }
    .width('100%')
  }
  
  // 构建操作按钮
  @Builder
  buildActionButtons() {
    Row({ space: 15 }) {
      Button('开始导入')
        .borderRadius(8)
        .backgroundColor(this.isImporting || !this.importContent ? '#CCCCCC' : '#007DFF')
        .fontColor(Color.White)
        .width('45%')
        .height(50)
        .enabled(!this.isImporting && this.importContent.length > 0)
        .onClick(() => {
          this.startImport();
        })
      
      Button('清空内容')
        .borderRadius(8)
        .backgroundColor('#FF6B35')
        .fontColor(Color.White)
        .width('45%')
        .height(50)
        .onClick(() => {
          this.clearContent();
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
  }
  
  // 构建结果显示
  @Builder
  buildResultDisplay() {
    if (this.importResult) {
      Column({ space: 10 }) {
        Text('导入结果')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .textAlign(TextAlign.Start)
        
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Text('状态：')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text(this.importResult.success ? '成功' : '失败')
              .fontSize(14)
              .fontColor(this.importResult.success ? '#52C41A' : '#FF4D4F')
          }
          
          Row({ space: 10 }) {
            Text('消息：')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text(this.importResult.message)
              .fontSize(14)
              .fontColor('#666666')
          }
          
          if (this.importResult.count !== undefined) {
            Row({ space: 10 }) {
              Text('数量：')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Text(this.importResult.count.toString())
                .fontSize(14)
                .fontColor('#666666')
            }
          }
        }
        .width('100%')
        .padding(15)
        .backgroundColor(Color.White)
        .borderRadius(8)
        
        // 操作按钮
        if (this.importResult.success) {
          Button('查看书源列表')
            .borderRadius(8)
            .backgroundColor('#007DFF')
            .fontColor(Color.White)
            .width('100%')
            .height(45)
            .margin({ top: 10 })
            .onClick(() => {
              // TODO: 跳转到书源列表页面
              this.message = '跳转到书源列表';
            })
        }
      }
      .width('100%')
    }
  }
  
  // 获取格式显示名称
  private getFormatDisplayName(): string {
    switch (this.selectedFormat) {
      case 'auto': return '自动检测';
      case 'json': return 'JSON格式';
      case 'xml': return 'XML格式';
      case 'txt': return 'TXT格式';
      default: return '自动检测';
    }
  }
  
  // 开始导入
  private async startImport() {
    if (this.isImporting || !this.importContent) {
      return;
    }
    
    this.isImporting = true;
    this.importResult = null;
    this.message = '正在导入书源，请稍候...';
    
    try {
      const format = this.selectedFormat === 'auto' ? undefined : this.selectedFormat;
      const result = await this.bookSourceViewModel.importBookSource(this.importContent, format);
      
      this.importResult = result;
      
      if (result.success) {
        this.message = `导入成功！共导入${result.count}个书源`;
        Logger.info('SourceImportPage', `书源导入成功：${result.count}个`);
      } else {
        this.message = `导入失败：${result.message}`;
        Logger.error('SourceImportPage', `书源导入失败：${result.message}`);
      }
      
    } catch (error) {
      this.importResult = {
        success: false,
        message: error instanceof Error ? error.message : '导入过程中发生异常'
      };
      this.message = '导入过程出现异常';
      Logger.error('SourceImportPage', `书源导入异常：${error}`);
    } finally {
      this.isImporting = false;
    }
  }
  
  // 清空内容
  private clearContent() {
    this.importContent = '';
    this.importResult = null;
    this.message = '内容已清空';
  }
}