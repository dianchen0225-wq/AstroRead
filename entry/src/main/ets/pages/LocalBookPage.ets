import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { LocalBook, LocalChapter } from '../models/LocalBook';
import { LocalFileParser } from '../utils/parser/LocalFileParser';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Logger } from '../utils/performance/Logger';
import { NavigationManager } from '../common/NavigationManager';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';

@Entry
@ComponentV2
struct LocalBookPage {
  @Local isLightMode: boolean = true;
  @Local localBooks: LocalBook[] = [];
  @Local isLoading: boolean = false;
  @Local isScanning: boolean = false;
  @Local scanResults: string[] = [];
  
  private readonly TAG = 'LocalBookPage';

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    viewModelManager.setContext(context);
    this.loadLocalBooks();
  }

  async loadLocalBooks(): Promise<void> {
    this.isLoading = true;
    try {
      const bookViewModel = viewModelManager.getBookViewModel();
      const allBooks = await bookViewModel.loadAllBooks();
      this.localBooks = allBooks.filter(book => book.bookSourceId === 'local') as LocalBook[];
    } catch (error) {
      Logger.error(this.TAG, `加载本地书籍失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  async pickFile(): Promise<void> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 10;
      documentSelectOptions.fileSuffixFilters = ['.txt', '.epub'];
      
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.select(documentSelectOptions);
      
      if (uris && uris.length > 0) {
        for (const uri of uris) {
          await this.importFile(uri);
        }
        await this.loadLocalBooks();
      }
    } catch (error) {
      Logger.error(this.TAG, `选择文件失败: ${error}`);
    }
  }

  async importFile(filePath: string): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      
      if (filePath.toLowerCase().endsWith('.txt')) {
        const result = await LocalFileParser.parseTxtFile(filePath, context);
        
        const bookViewModel = viewModelManager.getBookViewModel();
        await bookViewModel.addBook(result.book);
        
        Logger.info(this.TAG, `成功导入: ${result.book.name}`);
      } else if (filePath.toLowerCase().endsWith('.epub')) {
        Logger.warn(this.TAG, 'EPUB格式暂不支持');
      }
    } catch (error) {
      Logger.error(this.TAG, `导入文件失败: ${error}`);
    }
  }

  async scanLocalFiles(): Promise<void> {
    this.isScanning = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.scanResults = await LocalFileParser.scanLocalBooks(context);
      Logger.info(this.TAG, `扫描到 ${this.scanResults.length} 个本地文件`);
    } catch (error) {
      Logger.error(this.TAG, `扫描失败: ${error}`);
    } finally {
      this.isScanning = false;
    }
  }

  async importAllScanned(): Promise<void> {
    for (const filePath of this.scanResults) {
      await this.importFile(filePath);
    }
    this.scanResults = [];
    await this.loadLocalBooks();
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('‹')
            .fontSize(20)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 15 })
        .onClick(() => {
          NavigationManager.getInstance().navigateBack();
        })

        Text('本地书籍')
          .fontSize(18)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 15, right: 20, top: 15, bottom: 15 })
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
      .border({
        width: { bottom: 1 },
        color: DesignSystem.getBorderColor(this.isLightMode)
      })

      Row() {
        Button('选择文件')
          .fontSize(14)
          .fontColor(DesignSystem.Colors.text.primary.light)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .borderRadius(8)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.pickFile();
          })

        Button(this.isScanning ? '扫描中...' : '智能扫描')
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .borderRadius(8)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ left: 12 })
          .enabled(!this.isScanning)
          .onClick(() => {
            this.scanLocalFiles();
          })
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)

      if (this.scanResults.length > 0) {
        Column() {
          Row() {
            Text(`发现 ${this.scanResults.length} 个文件`)
              .fontSize(14)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .layoutWeight(1)

            Button('全部导入')
              .fontSize(12)
              .fontColor(DesignSystem.Colors.text.primary.light)
              .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
              .borderRadius(6)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .onClick(() => {
                this.importAllScanned();
              })
          }
          .width('100%')
          .padding(12)

          List() {
            ForEach(this.scanResults, (filePath: string) => {
              ListItem() {
                Row() {
                  Text('📄')
                    .fontSize(20)
                    .margin({ right: 12 })

                  Column() {
                    Text(filePath.split('/').pop() || filePath)
                      .fontSize(14)
                      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(filePath)
                      .fontSize(11)
                      .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Button('导入')
                    .fontSize(12)
                    .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
                    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                    .borderRadius(6)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .onClick(() => {
                      this.importFile(filePath);
                    })
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              }
              .margin({ bottom: 8 })
            }, (filePath: string) => filePath)
          }
          .width('100%')
          .height(200)
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
        .borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 16 })
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
          Text('加载中...')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.localBooks.length === 0) {
        Column() {
          Text('📁')
            .fontSize(48)
            .margin({ bottom: 16 })
          Text('暂无本地书籍')
            .fontSize(16)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ bottom: 8 })
          Text('点击上方按钮导入TXT或EPUB文件')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.localBooks, (book: LocalBook) => {
            ListItem() {
              Row() {
                Column() {
                  Text('📄')
                    .fontSize(32)
                }
                .width(60)
                .height(80)
                .borderRadius(6)
                .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
                .justifyContent(FlexAlign.Center)

                Column() {
                  Text(book.name)
                    .fontSize(16)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .fontWeight(600)
                    .margin({ bottom: 4 })

                  Text(book.fileType.toUpperCase())
                    .fontSize(12)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .margin({ bottom: 4 })

                  Text(this.formatFileSize(book.fileSize))
                    .fontSize(11)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
              }
              .width('100%')
              .padding(15)
              .borderRadius(12)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .onClick(() => {
                NavigationManager.getInstance().navigateTo('BookDetailPage', {
                  bookId: book.id
                });
              })
            }
          }, (book: LocalBook) => book.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
  }
}

export { LocalBookPage };
