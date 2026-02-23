/**
 * WebReader - 基于 Web 组件的阅读器实现
 * 使用 Web 组件渲染 HTML 内容，支持 CSS 样式和复杂排版
 */

import webview from '@ohos.web.webview';
import { themeManager } from '../common/ThemeManager';
import { ReadConfig } from '../models/ReadConfig';
import { Logger } from '../utils/Logger';

// 阅读器配置接口
export interface WebReaderConfig {
  fontSize: number;
  lineHeight: number;
  letterSpacing: number;
  backgroundColor: string;
  textColor: string;
  theme: 'light' | 'dark' | 'sepia';
}

/**
 * WebReader 组件
 * 使用 Web 组件渲染阅读内容，支持复杂排版和 CSS 样式
 */
@Component
export struct WebReader {
  @State webController: webview.WebviewController = new webview.WebviewController();
  @Prop content: string = '';  // HTML 格式的内容
  @Prop config: WebReaderConfig = {
    fontSize: 18,
    lineHeight: 1.8,
    letterSpacing: 0,
    backgroundColor: '#FFFFFF',
    textColor: '#333333',
    theme: 'light'
  };
  @State isReady: boolean = false;

  // 回调函数
  onPageChange?: (page: number, total: number) => void;
  onChapterEnd?: () => void;
  onReaderClick?: () => void;

  private readonly TAG = 'WebReader';

  aboutToAppear() {
    // WebviewController 需要在 aboutToAppear 中初始化
    Logger.debug(this.TAG, 'WebReader initializing...');
  }

  aboutToDisappear() {
    try {
      // 清理资源
      Logger.debug(this.TAG, 'WebReader destroying...');
      // 释放 WebviewController 资源
      if (this.webController) {
        this.webController.stop();
        this.webController.clearHistory();
        this.webController.clearSslCache();
        Logger.debug(this.TAG, 'WebviewController resources cleared');
      }
    } catch (error) {
      Logger.error(this.TAG, `销毁失败: ${error}`);
    }
  }

  /**
   * 构建阅读器 HTML 模板
   */
  private buildReaderHtml(content: string, isHtml: boolean = true): string {
    const safeContent = this.processContent(content, isHtml);
    const themeStyles = this.getThemeStyles();

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>阅读器</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
      -webkit-user-select: none;
      user-select: none;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: ${this.config.fontSize}px;
      line-height: ${this.config.lineHeight};
      letter-spacing: ${this.config.letterSpacing}px;
      background-color: ${this.config.backgroundColor};
      color: ${this.config.textColor};
      padding: 20px;
      padding-bottom: 60px;
      overflow-x: hidden;
      word-wrap: break-word;
      text-align: justify;
    }

    ${themeStyles}

    p {
      margin: 0.8em 0;
      text-indent: 2em;
    }

    h1, h2, h3, h4, h5, h6 {
      margin: 1.2em 0 0.8em;
      font-weight: 600;
    }

    h1 { font-size: 1.5em; }
    h2 { font-size: 1.3em; }
    h3 { font-size: 1.1em; }

    img {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 1em auto;
    }

    a {
      color: inherit;
      text-decoration: none;
    }

    /* 特殊样式 */
    .chapter-title {
      font-size: 1.4em;
      font-weight: 600;
      text-align: center;
      margin: 1em 0;
      padding-bottom: 0.5em;
      border-bottom: 1px solid rgba(0,0,0,0.1);
    }

    .content-divider {
      text-align: center;
      margin: 2em 0;
      color: #999;
    }

    /* 点击区域 */
    .tap-area {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      z-index: 1;
    }

    /* 滚动条样式 */
    ::-webkit-scrollbar {
      width: 0;
      background: transparent;
    }
  </style>
</head>
<body>
  <div class="chapter-title" id="chapter-title"></div>
  <div id="content">${safeContent}</div>
  <div class="content-divider">* * *</div>

  <script>
    // 防止默认触摸行为
    document.addEventListener('touchmove', function(e) {
      if (e.scale !== 1) {
        e.preventDefault();
      }
    }, { passive: false });

    // 点击事件处理
    document.body.addEventListener('click', function(e) {
      const width = window.innerWidth;
      const x = e.clientX;

      // 左侧 1/3 上一页，中间 1/3 显示菜单，右侧 1/3 下一页
      if (x < width / 3) {
        window.handleClick('prev');
      } else if (x > width * 2 / 3) {
        window.handleClick('next');
      } else {
        window.handleClick('menu');
      }
    });

    // 滚动到指定位置
    window.scrollToPosition = function(ratio) {
      const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
      window.scrollTo(0, scrollHeight * ratio);
    };

    // 获取当前阅读进度
    window.getProgress = function() {
      const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
      const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
      return scrollHeight > 0 ? scrollTop / scrollHeight : 0;
    };

    // 监听滚动
    let scrollTimeout;
    window.addEventListener('scroll', function() {
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(function() {
        const progress = window.getProgress();
        if (window.onProgressChange) {
          window.onProgressChange(progress);
        }
      }, 100);
    });

    // 设置内容
    window.setContent = function(title, content) {
      document.getElementById('chapter-title').textContent = title || '';
      document.getElementById('content').innerHTML = content;
    };

    // 更新样式
    window.updateStyle = function(config) {
      document.body.style.fontSize = config.fontSize + 'px';
      document.body.style.lineHeight = config.lineHeight;
      document.body.style.letterSpacing = config.letterSpacing + 'px';
      document.body.style.backgroundColor = config.backgroundColor;
      document.body.style.color = config.textColor;
    };
  </script>
</body>
</html>`;
  }

  /**
   * 获取主题样式
   */
  private getThemeStyles(): string {
    if (this.config.theme === 'dark') {
      return `
        body { background-color: #1A1A1A; color: #D4D4D4; }
        .chapter-title { border-bottom-color: rgba(255,255,255,0.1); }
      `;
    } else if (this.config.theme === 'sepia') {
      return `
        body { background-color: #F5E6D3; color: #5B4636; }
        .chapter-title { border-bottom-color: rgba(91,70,54,0.2); }
      `;
    } else {
      return `
        body { background-color: #FFFFFF; color: #333333; }
        .chapter-title { border-bottom-color: rgba(0,0,0,0.1); }
      `;
    }
  }

  /**
   * HTML 转义 - 基础版本
   */
  private escapeHtml(text: string): string {
    if (!text) return '';
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  /**
   * 深度清理 HTML 内容，防止 XSS 攻击
   */
  private sanitizeHtml(html: string): string {
    if (!html) return '';

    let sanitized = html;

    const dangerousTags = [
      /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
      /<script\b[^>]*>/gi,
      /<\/script>/gi,
      /<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi,
      /<iframe\b[^>]*>/gi,
      /<\/iframe>/gi,
      /<object\b[^<]*(?:(?!<\/object>)<[^<]*)*<\/object>/gi,
      /<object\b[^>]*>/gi,
      /<\/object>/gi,
      /<embed\b[^>]*>/gi,
      /<applet\b[^<]*(?:(?!<\/applet>)<[^<]*)*<\/applet>/gi,
      /<applet\b[^>]*>/gi,
      /<\/applet>/gi,
      /<form\b[^<]*(?:(?!<\/form>)<[^<]*)*<\/form>/gi,
      /<form\b[^>]*>/gi,
      /<\/form>/gi,
      /<input\b[^>]*>/gi,
      /<button\b[^>]*>/gi,
      /<\/button>/gi,
      /<select\b[^>]*>/gi,
      /<\/select>/gi,
      /<textarea\b[^>]*>/gi,
      /<\/textarea>/gi,
      /<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi,
      /<link\b[^>]*>/gi,
      /<meta\b[^>]*>/gi,
      /<base\b[^>]*>/gi,
    ];

    for (const pattern of dangerousTags) {
      sanitized = sanitized.replace(pattern, '');
    }

    const eventHandlers = [
      'onload', 'onerror', 'onclick', 'onmouseover', 'onmouseout', 'onmouseenter',
      'onmouseleave', 'onmousedown', 'onmouseup', 'onmousemove', 'onkeydown',
      'onkeyup', 'onkeypress', 'onfocus', 'onblur', 'onchange', 'onsubmit',
      'onreset', 'onselect', 'onabort', 'oncanplay', 'oncanplaythrough',
      'ondurationchange', 'onemptied', 'onended', 'oninput', 'oninvalid',
      'onloadstart', 'onloadeddata', 'onloadedmetadata', 'onpause', 'onplay',
      'onplaying', 'onprogress', 'onratechange', 'onseeked', 'onseeking',
      'onstalled', 'onsuspend', 'ontimeupdate', 'onvolumechange', 'onwaiting',
      'oncopy', 'oncut', 'onpaste', 'ondrag', 'ondragend', 'ondragenter',
      'ondragleave', 'ondragover', 'ondragstart', 'ondrop', 'onscroll',
      'onwheel', 'ontouchstart', 'ontouchmove', 'ontouchend', 'ontouchcancel',
      'onanimationstart', 'onanimationend', 'onanimationiteration',
      'ontransitionend', 'oncontextmenu', 'onpointerdown', 'onpointermove',
      'onpointerup', 'onpointercancel', 'onpointerover', 'onpointerout',
      'onpointerenter', 'onpointerleave', 'ongotpointercapture', 'onlostpointercapture'
    ];

    for (const handler of eventHandlers) {
      const patterns = [
        new RegExp(`\\s+${handler}\\s*=\\s*"[^"]*"`, 'gi'),
        new RegExp(`\\s+${handler}\\s*=\\s*'[^']*'`, 'gi'),
        new RegExp(`\\s+${handler}\\s*=\\s*[^\\s>]+`, 'gi'),
      ];
      for (const pattern of patterns) {
        sanitized = sanitized.replace(pattern, '');
      }
    }

    sanitized = sanitized.replace(/javascript\s*:/gi, 'blocked:');
    sanitized = sanitized.replace(/vbscript\s*:/gi, 'blocked:');
    sanitized = sanitized.replace(/data\s*:\s*text\/html/gi, 'blocked:');
    sanitized = sanitized.replace(/expression\s*\(/gi, 'blocked(');

    sanitized = sanitized.replace(/src\s*=\s*["']?\s*javascript:/gi, 'src="blocked:"');
    sanitized = sanitized.replace(/href\s*=\s*["']?\s*javascript:/gi, 'href="blocked:"');
    sanitized = sanitized.replace(/action\s*=\s*["']?\s*javascript:/gi, 'action="blocked:"');
    sanitized = sanitized.replace(/formaction\s*=\s*["']?\s*javascript:/gi, 'formaction="blocked:"');

    sanitized = sanitized.replace(/<\s*!--[\s\S]*?--\s*>/g, '');

    return sanitized;
  }

  /**
   * 安全处理内容 - 根据内容类型选择处理方式
   */
  private processContent(content: string, isHtml: boolean = false): string {
    if (!content) return '';

    if (isHtml) {
      return this.sanitizeHtml(content);
    } else {
      return this.escapeHtml(content);
    }
  }

  /**
   * 加载内容
   */
  public loadContent(title: string, content: string, isHtml: boolean = true): void {
    try {
      const html = this.buildReaderHtml(content, isHtml);
      this.webController.loadData(
        html,
        'text/html',
        'UTF-8'
      );
    } catch (error) {
      Logger.error(this.TAG, `加载内容失败: ${error}`);
    }
  }

  /**
   * 更新配置
   */
  public updateConfig(newConfig: Partial<WebReaderConfig>): void {
    if (newConfig.fontSize !== undefined) {
      this.config.fontSize = newConfig.fontSize;
    }
    if (newConfig.lineHeight !== undefined) {
      this.config.lineHeight = newConfig.lineHeight;
    }
    if (newConfig.letterSpacing !== undefined) {
      this.config.letterSpacing = newConfig.letterSpacing;
    }
    if (newConfig.backgroundColor !== undefined) {
      this.config.backgroundColor = newConfig.backgroundColor;
    }
    if (newConfig.textColor !== undefined) {
      this.config.textColor = newConfig.textColor;
    }
    if (newConfig.theme !== undefined) {
      this.config.theme = newConfig.theme;
    }
    try {
      const script = `updateStyle(${JSON.stringify(this.config)})`;
      this.webController.runJavaScript(script);
    } catch (error) {
      Logger.error(this.TAG, `更新配置失败: ${error}`);
    }
  }

  /**
   * 获取当前阅读进度
   */
  public getProgress(): Promise<number> {
    return new Promise<number>((resolve: (value: number) => void) => {
      try {
        this.webController.runJavaScript('getProgress()')
          .then((result: string) => {
            resolve(parseFloat(result) || 0);
          })
          .catch(() => resolve(0));
      } catch (error) {
        resolve(0);
      }
    });
  }

  /**
   * 滚动到指定进度
   */
  public scrollToProgress(ratio: number): void {
    try {
      this.webController.runJavaScript(`scrollToPosition(${ratio})`);
    } catch (error) {
      Logger.error(this.TAG, `滚动失败: ${error}`);
    }
  }

  build() {
    Column() {
      Web({
        src: '',
        controller: this.webController
      })
        .width('100%')
        .height('100%')
        .backgroundColor(this.config.backgroundColor)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .onPageBegin(() => {
          this.isReady = true;
          Logger.debug(this.TAG, 'WebView ready');
        })
        .onErrorReceive((event) => {
          if (event && event.error) {
            Logger.error(this.TAG, `WebView error: ${event.error.getErrorInfo()}`);
          }
        })
        .onHttpErrorReceive((event) => {
          if (event && event.response) {
            Logger.error(this.TAG, `WebView HTTP error: ${event.response.getResponseCode()}`);
          }
        })
    }
    .width('100%')
    .height('100%')
  }
}

export default WebReader;
