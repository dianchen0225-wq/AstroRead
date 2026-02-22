/**
 * ImportPage - 本地文件导入页面
 * 支持导入 TXT、EPUB 等格式的本地书籍
 */

import { themeManager } from '../common/ThemeManager';
import { DesignSystem } from '../common/DesignSystem';
import { FileManager, FileInfo } from '../utils/FileManager';
import { TXTParser } from '../utils/TXTParser';
import { EPUBParser } from '../utils/EPUBParser';
import { AsyncTXTParser, asyncTXTParser } from '../utils/AsyncTXTParser';
import { viewModelManager } from '../viewmodel/ViewModelManager';
import { Book, Chapter } from '../models/Book';
import { Logger } from '../utils/Logger';
import { NavigationManager } from '../common/NavigationManager';
import common from '@ohos.app.ability.common';

@Entry
@ComponentV2
struct ImportPage {
  @Param path: string = '';
  @Local isLightMode: boolean = true;
  @Local importedFiles: FileInfo[] = [];
  @Local isImporting: boolean = false;
  @Local importProgress: string = '';
  @Local showDeleteDialog: boolean = false;
  @Local selectedFile: FileInfo | null = null;

  private fileManager = FileManager.getInstance();
  private txtParser = TXTParser.getInstance();
  private asyncTXTParser = asyncTXTParser;
  private epubParser = EPUBParser.getInstance();

  aboutToAppear() {
    this.isLightMode = themeManager.isLightTheme();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.fileManager.setContext(context);
    this.loadImportedFiles();
  }

  // 加载已导入的文件列表
  loadImportedFiles() {
    this.importedFiles = this.fileManager.getBookFiles();
  }

  // 选择并导入文件
  async handleImport() {
    if (this.isImporting) return;

    this.isImporting = true;
    this.importProgress = '正在选择文件...';

    try {
      const result = await this.fileManager.pickFile();

      if (result.success && result.path) {
        this.importProgress = '正在解析文件...';

        // 根据文件类型解析
        const extension = result.path.split('.').pop()?.toLowerCase();

        if (extension === 'txt') {
          await this.parseAndSaveTXT(result.path);
        } else if (extension === 'epub') {
          await this.parseAndSaveEPUB(result.path);
        } else {
          // 其他格式暂不处理
          this.importProgress = '暂不支持此格式';
        }

        // 刷新列表
        this.loadImportedFiles();
      } else if (result.error) {
        this.importProgress = result.error;
      }
    } catch (error) {
      Logger.error('ImportPage', `导入失败: ${error}`);
      this.importProgress = '导入失败';
    } finally {
      this.isImporting = false;
      // 3秒后清除进度提示
      setTimeout(() => {
        this.importProgress = '';
      }, 3000);
    }
  }

  // 解析并保存TXT（使用异步解析器）
  async parseAndSaveTXT(filePath: string) {
    // 使用异步解析器，避免主线程阻塞
    const parseResult = await this.asyncTXTParser.parse(
      filePath,
      undefined,
      (progress: number) => {
        this.importProgress = `解析进度: ${progress}%`;
      }
    );

    if (parseResult.success && parseResult.book && parseResult.chapters) {
      // 保存到数据库
      const bookViewModel = viewModelManager.getBookViewModel();
      const chapterViewModel = viewModelManager.getChapterViewModel();

      // 添加书籍
      const bookId = await bookViewModel.addBook(parseResult.book);

      // 更新章节的 bookId
      const chapters: Chapter[] = [];
      let chapterIndex = 0;
      for (const ch of parseResult.chapters) {
        const chapter: Chapter = {
          id: ch.id,
          bookId: bookId,
          title: ch.title,
          url: ch.url,
          order: chapterIndex++,
          isVip: ch.isVip
        };
        chapters.push(chapter);
      }

      // 保存章节
      await chapterViewModel.saveChapters(bookId, chapters);

      this.importProgress = `成功导入: ${parseResult.book.name}`;
    } else {
      this.importProgress = parseResult.error || '解析失败';
    }
  }

  // 解析并保存EPUB
  async parseAndSaveEPUB(filePath: string) {
    try {
      const extractPath = filePath + '_extracted';
      const book = await this.epubParser.parse(filePath, extractPath);

      if (book && book.metadata) {
        const bookViewModel = viewModelManager.getBookViewModel();
        const chapterViewModel = viewModelManager.getChapterViewModel();

        // 创建书籍对象
        const newBook: Book = {
          id: '',
          name: book.metadata.title || '未知书名',
          author: book.metadata.author || '未知作者',
          cover: book.metadata.cover || undefined,
          intro: book.metadata.description || undefined,
          kind: undefined,
          wordCount: undefined,
          latestChapter: undefined,
          bookUrl: filePath,
          bookSourceId: 'local_epub',
          bookSourceName: '本地导入',
          lastUpdateTime: Date.now(),
          addTime: Date.now(),
          readProgress: 0,
          lastReadChapter: undefined,
          lastReadChapterIndex: undefined,
          lastReadTime: Date.now(),
          totalChapters: book.chapters.length,
          currentChapterIndex: 0,
          currentChapterTitle: book.chapters[0]?.title || '',
          isInShelf: false
        };

        // 保存到数据库
        const bookId = await bookViewModel.addBook(newBook);

        // 保存章节
        const chapters: Chapter[] = [];
        for (let index = 0; index < book.chapters.length; index++) {
          const ch = book.chapters[index];
          const chapter: Chapter = {
            id: ch.id || index.toString(),
            bookId: bookId,
            title: ch.title,
            url: ch.href,
            order: ch.order !== undefined ? ch.order : index,
            isVip: false
          };
          chapters.push(chapter);
        }

        await chapterViewModel.saveChapters(bookId, chapters);

        this.importProgress = `成功导入: ${newBook.name}`;
      }
    } catch (error) {
      Logger.error('ImportPage', `EPUB导入失败: ${error}`);
      this.importProgress = 'EPUB解析失败';
    }
  }

  // 删除文件
  handleDelete(file: FileInfo) {
    this.selectedFile = file;
    this.showDeleteDialog = true;
  }

  confirmDelete() {
    if (this.selectedFile) {
      this.fileManager.deleteFile(this.selectedFile.path);
      this.loadImportedFiles();
    }
    this.showDeleteDialog = false;
    this.selectedFile = null;
  }

  // 打开书籍
  async openBook(file: FileInfo) {
    // 查找对应的数据库记录并打开
    const bookViewModel = viewModelManager.getBookViewModel();
    const books = await bookViewModel.getAllBooks();
    const book = books.find((b: Book) => b.bookUrl === file.path);

    if (book) {
      try {
        NavigationManager.getInstance().navigateToBookDetail({ bookId: book.id });
      } catch (error) {
        Logger.error('ImportPage', `打开书籍失败: ${error}`);
      }
    }
  }

  // 获取文件图标
  getFileIcon(extension: string): Resource {
    switch (extension.toLowerCase()) {
      case '.txt':
        return $r('app.media.startIcon');
      case '.epub':
        return $r('app.media.startIcon');
      case '.pdf':
        return $r('app.media.startIcon');
      default:
        return $r('app.media.startIcon');
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('本地导入')
          .fontSize(20)
          .fontWeight(600)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

        Blank()

        Button('导入文件')
          .fontSize(14)
          .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .enabled(!this.isImporting)
          .onClick(() => this.handleImport())
      }
      .width('100%')
      .padding(16)
      .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))

      // 进度提示
      if (this.importProgress) {
        Text(this.importProgress)
          .fontSize(14)
          .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
          .width('100%')
          .padding(12)
          .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
          .textAlign(TextAlign.Center)
      }

      // 文件列表
      if (this.importedFiles.length === 0) {
        Column() {
          Text('暂无导入的书籍')
            .fontSize(16)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .margin({ bottom: 8 })

          Text('点击右上角"导入文件"按钮添加书籍')
            .fontSize(14)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.importedFiles, (file: FileInfo) => {
            ListItem() {
              Row() {
                Image(this.getFileIcon(file.extension))
                  .width(48)
                  .height(48)
                  .margin({ right: 12 })

                Column() {
                  Text(file.name)
                    .fontSize(16)
                    .fontWeight(500)
                    .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Text(`${this.fileManager.getFileSizeString(file.size)}`)
                    .fontSize(12)
                    .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Row() {
                  Button('打开')
                    .fontSize(12)
                    .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
                    .onClick(() => this.openBook(file))

                  Button('删除')
                    .fontSize(12)
                    .backgroundColor('#FF4D4F')
                    .margin({ left: 8 })
                    .onClick(() => this.handleDelete(file))
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
              .borderRadius(8)
            }
          }, (file: FileInfo) => file.path)
        }
        .width('100%')
        .height('100%')
        .padding(16)
        .layoutWeight(1)
        .divider({ strokeWidth: 8, color: 'transparent' })
      }

      // 删除确认对话框
      if (this.showDeleteDialog) {
        Column() {
          Column() {
            Text('确认删除')
              .fontSize(18)
              .fontWeight(600)
              .margin({ bottom: 16 })

            Text(`确定要删除 "${this.selectedFile?.name}" 吗？`)
              .fontSize(14)
              .margin({ bottom: 24 })

            Row() {
              Button('取消')
                .fontSize(14)
                .backgroundColor('#999999')
                .onClick(() => {
                  this.showDeleteDialog = false;
                  this.selectedFile = null;
                })

              Button('删除')
                .fontSize(14)
                .backgroundColor('#FF4D4F')
                .margin({ left: 16 })
                .onClick(() => this.confirmDelete())
            }
          }
          .width('80%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(12)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }
}

export default ImportPage;
