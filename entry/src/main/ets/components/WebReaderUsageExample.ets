/**
 * WebReader 使用示例 - 展示如何在 ReadPage 中集成
 */

import { WebReader, WebReaderConfig } from './WebReader';
import { themeManager } from '../common/ThemeManager';
import { ReadConfig } from '../models/ReadConfig';

/**
 * 在 ReadPage 中使用 WebReader 的示例代码
 *
 * 1. 导入 WebReader
 * 2. 使用 @State 创建 WebReaderConfig
 * 3. 在 build() 中使用 WebReader 组件
 */

// ===== 示例 1: 基础使用 =====
@Component
struct ReadPageExample {
  // WebReader 引用
  private webReaderRef: WebReader | null = null;

  // 阅读配置
  @State webConfig: WebReaderConfig = {
    fontSize: 18,
    lineHeight: 1.8,
    letterSpacing: 0,
    backgroundColor: '#FFFFFF',
    textColor: '#333333',
    theme: 'light'
  };

  // 章节内容
  @State chapterTitle: string = '第一章 示例章节';
  @State chapterContent: string = `
    <p>这是第一章的内容。</p>
    <p>WebReader 支持 HTML 格式，可以使用各种标签。</p>
    <p>支持图片：<img src="https://example.com/image.jpg" /></p>
  `;

  aboutToAppear() {
    // 根据主题更新配置
    const isLight = themeManager.isLightTheme();
    this.updateTheme(isLight);
  }

  /**
   * 更新主题
   */
  private updateTheme(isLight: boolean) {
    if (isLight) {
      this.webConfig = {
        fontSize: this.webConfig.fontSize,
        lineHeight: this.webConfig.lineHeight,
        letterSpacing: this.webConfig.letterSpacing,
        backgroundColor: '#FFFFFF',
        textColor: '#333333',
        theme: 'light'
      };
    } else {
      this.webConfig = {
        fontSize: this.webConfig.fontSize,
        lineHeight: this.webConfig.lineHeight,
        letterSpacing: this.webConfig.letterSpacing,
        backgroundColor: '#1A1A1A',
        textColor: '#D4D4D4',
        theme: 'dark'
      };
    }
  }

  /**
   * 加载章节内容
   */
  private loadChapter(title: string, content: string) {
    // 处理纯文本，转换为 HTML
    const htmlContent = this.convertTextToHtml(content);

    // 调用 WebReader 的方法加载内容
    if (this.webReaderRef) {
      this.webReaderRef.loadContent(title, htmlContent);
    }
  }

  /**
   * 将纯文本转换为 HTML
   */
  private convertTextToHtml(text: string): string {
    if (!text) return '';

    // 1. 处理段落（按空行分割）
    const paragraphs = text.split(/\n\s*\n/);

    // 2. 将每个段落包装在 <p> 标签中
    const htmlParagraphs = paragraphs.map(p => {
      // 清理段落
      const cleanP = p.trim().replace(/\n/g, '<br>');
      if (cleanP) {
        return `<p>${cleanP}</p>`;
      }
      return '';
    });

    return htmlParagraphs.join('\n');
  }

  /**
   * 处理 WebReader 点击事件
   */
  private handleWebReaderClick(action: string) {
    switch (action) {
      case 'prev':
        // 上一章
        this.prevChapter();
        break;
      case 'next':
        // 下一章
        this.nextChapter();
        break;
      case 'menu':
        // 显示/隐藏菜单
        this.showMenu = !this.showMenu;
        break;
    }
  }

  // 示例方法（实际项目中实现）
  private prevChapter() { }
  private nextChapter() { }
  @State showMenu: boolean = false;

  build() {
    Column() {
      // 使用 WebReader 组件
      WebReader({
        content: this.chapterContent,
        config: this.webConfig,
        onReaderClick: (): void => this.handleWebReaderClick('menu'),
        onChapterEnd: (): void => this.nextChapter()
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

// ===== 示例 2: 完整配置 =====
@Component
struct ReadPageFullExample {
  private webReaderRef: WebReader | null = null;

  // 更完整的阅读配置
  @State webConfig: WebReaderConfig = {
    fontSize: 18,           // 字体大小（px）
    lineHeight: 1.8,        // 行高（倍数）
    letterSpacing: 0,       // 字间距（px）
    backgroundColor: '#F5E6D3',  // 背景色（护眼模式）
    textColor: '#5B4636',   // 文字颜色
    theme: 'sepia'          // 主题：light、dark、sepia
  };

  // 字体大小调整
  private increaseFontSize() {
    const newSize = Math.min(this.webConfig.fontSize + 2, 32);
    this.webConfig = {
        fontSize: newSize,
        lineHeight: this.webConfig.lineHeight,
        letterSpacing: this.webConfig.letterSpacing,
        backgroundColor: this.webConfig.backgroundColor,
        textColor: this.webConfig.textColor,
        theme: this.webConfig.theme
      };
    this.webReaderRef?.updateConfig({ fontSize: newSize });
  }

  private decreaseFontSize() {
    const newSize = Math.max(this.webConfig.fontSize - 2, 12);
    this.webConfig = {
        fontSize: newSize,
        lineHeight: this.webConfig.lineHeight,
        letterSpacing: this.webConfig.letterSpacing,
        backgroundColor: this.webConfig.backgroundColor,
        textColor: this.webConfig.textColor,
        theme: this.webConfig.theme
      };
    this.webReaderRef?.updateConfig({ fontSize: newSize });
  }

  build() {
    Stack() {
      // WebReader
      WebReader({
        content: '',  // 内容通过 loadContent 方法加载
        config: this.webConfig
      })
        .width('100%')
        .height('100%')

      // 控制栏示例
      Row() {
        Button('A+')
          .onClick(() => this.increaseFontSize())

        Button('A-')
          .onClick(() => this.decreaseFontSize())
      }
      .position({ x: 0, y: '100%' })
      .translate({ y: '-100%' })
    }
    .width('100%')
    .height('100%')
  }
}

// ===== 示例 3: 与 ReadPage 集成 =====
/*
在 ReadPage.ets 中的修改：

1. 导入 WebReader
   import { WebReader, WebReaderConfig } from '../components/WebReader';

2. 添加状态变量
   @State webConfig: WebReaderConfig = {
     fontSize: 18,
     lineHeight: 1.8,
     letterSpacing: 0,
     backgroundColor: '#FFFFFF',
     textColor: '#333333',
     theme: 'light'
   };
   private webReaderRef: WebReader | null = null;

3. 在 loadChapterContent 中加载内容
   if (this.chapterContent) {
     // 将纯文本转为 HTML
     const htmlContent = this.convertTextToHtml(this.chapterContent.content);
     this.webReaderRef?.loadContent(
       this.chapters[this.chapterIndex].title,
       htmlContent
     );
   }

4. 替换 Text 组件为 WebReader
   // 原来：
   Text(this.chapterContent.content)

   // 改为：
   WebReader({
     content: '',
     config: this.webConfig,
     onClick: () => { this.showMenu = !this.showMenu; }
   })
     .width('100%')
     .height('100%')
*/

export { ReadPageExample, ReadPageFullExample };
