/**
 * EPUBReader - EPUB 电子书阅读器组件
 * 基于 WebReader 实现 EPUB 内容渲染
 */

import { EPUBParser, EPUBBook, EPUBChapter } from '../utils/parser/EPUBParser';
import { WebReader, WebReaderConfig } from './WebReader';
import { themeManager } from '../common/ThemeManager';
import { Logger } from '../utils/performance/Logger';

@Component
export struct EPUBReader {
  @State book: EPUBBook | null = null;
  @State currentChapterIndex: number = 0;
  @State isLoading: boolean = false;
  @State showMenu: boolean = false;
  @State webConfig: WebReaderConfig = {
    fontSize: 18,
    lineHeight: 1.8,
    letterSpacing: 0,
    backgroundColor: '#FFFFFF',
    textColor: '#333333',
    theme: 'light'
  };

  @Prop epubPath: string = '';

  private parser = EPUBParser.getInstance();
  private readonly TAG = 'EPUBReader';

  aboutToAppear() {
    this.syncThemeToWebReader();
    if (this.epubPath) {
      this.loadEPUB(this.epubPath);
    }
  }

  async loadEPUB(path: string): Promise<void> {
    this.isLoading = true;
    try {
      const extractPath = `${path}_extracted`;
      this.book = await this.parser.parse(path, extractPath);
      this.currentChapterIndex = 0;
      Logger.info(this.TAG, `EPUB 加载成功: ${this.book.metadata.title}`);
    } catch (error) {
      Logger.error(this.TAG, `加载 EPUB 失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  private syncThemeToWebReader(): void {
    const isLight = themeManager.isLightTheme();
    this.webConfig = {
      fontSize: this.webConfig.fontSize,
      lineHeight: this.webConfig.lineHeight,
      letterSpacing: this.webConfig.letterSpacing,
      backgroundColor: isLight ? '#FFFFFF' : '#1A1A1A',
      textColor: isLight ? '#333333' : '#D4D4D4',
      theme: isLight ? 'light' : 'dark'
    };
  }

  private getCurrentChapterContent(): string {
    if (!this.book) return '';
    const chapter = this.book.chapters[this.currentChapterIndex];
    if (!chapter) return '';

    return this.convertEPUBHtmlToWebHtml(chapter.content || '');
  }

  private convertEPUBHtmlToWebHtml(html: string): string {
    if (!html) return '';

    let cleanHtml = html
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');

    const textContent = this.extractText(cleanHtml);
    const paragraphs = textContent.split(/\n\s*\n/);

    const result: string[] = [];
    for (let i = 0; i < paragraphs.length; i++) {
      const p = paragraphs[i].trim();
      if (p.length > 0) {
        result.push(`<p>${this.escapeHtml(p)}</p>`);
      }
    }

    return result.join('\n');
  }

  private extractText(html: string): string {
    return html
      .replace(/<[^>]+>/g, '\n')
      .replace(/\n\s*\n/g, '\n')
      .trim();
  }

  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  private nextChapter(): void {
    if (this.book && this.currentChapterIndex < this.book.chapters.length - 1) {
      this.currentChapterIndex++;
    }
  }

  private prevChapter(): void {
    if (this.currentChapterIndex > 0) {
      this.currentChapterIndex--;
    }
  }

  private getCurrentChapterTitle(): string {
    if (!this.book || this.book.chapters.length === 0) return '';
    const chapter = this.book.chapters[this.currentChapterIndex];
    return chapter ? chapter.title : '';
  }

  build() {
    Stack() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .margin({ top: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.book && this.book.chapters.length > 0) {
        Column() {
          Text(this.getCurrentChapterTitle())
            .fontSize(18)
            .fontWeight(600)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 20, bottom: 20 })

          WebReader({
            content: this.getCurrentChapterContent(),
            config: this.webConfig,
            onChapterEnd: () => {
              this.nextChapter();
            }
          })
            .width('100%')
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      } else {
        Column() {
          Text('无法加载 EPUB')
            .fontSize(16)
            .fontColor('#999')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      if (this.showMenu) {
        Column() {
          Row() {
            Button('上一章')
              .enabled(this.currentChapterIndex > 0)
              .onClick(() => this.prevChapter())

            Text(`${this.currentChapterIndex + 1} / ${this.book?.chapters.length || 0}`)
              .fontSize(14)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            Button('下一章')
              .enabled(this.book ? this.currentChapterIndex < this.book.chapters.length - 1 : false)
              .onClick(() => this.nextChapter())
          }
          .width('100%')
          .padding(15)
          .backgroundColor('#F5F5F5')
        }
        .width('100%')
        .position({ x: 0, y: '100%' })
        .translate({ y: '-100%' })
      }
    }
    .width('100%')
    .height('100%')
  }
}

export default EPUBReader;
