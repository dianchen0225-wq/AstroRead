/**
 * JavaScript引擎封装类
 * 使用HarmonyOS内置WebView执行JavaScript代码
 * 用于解析阅读APP格式的书源
 */

import webview from '@ohos.web.webview';
import { Logger } from './Logger';

/**
 * JavaScript执行结果
 */
export interface JSExecutionResult {
  success: boolean;
  result: string;
  error?: string;
}

/**
 * 书源Java对象模拟
 * 提供阅读APP书源中常用的java对象方法
 */
export interface AstroReadJavaObject {
  ajax: (url: string) => string;
  get: (url: string) => string;
  post: (url: string, body: string) => string;
  log: (message: string) => void;
  longToast: (message: string) => void;
  encodeURI: (str: string) => string;
  decodeURI: (str: string) => string;
  encodeURIComponent: (str: string) => string;
  decodeURIComponent: (str: string) => string;
  t2s: (str: string) => string;
  s2t: (str: string) => string;
  getElements: (html: string, rule: string) => string[];
  parseHtml: (html: string) => object;
}

/**
 * JavaScript引擎管理器
 * 使用WebView执行JavaScript代码
 */
export class JSEngine {
  private static instance: JSEngine | null = null;
  private webController: webview.WebviewController | null = null;
  private isInitialized: boolean = false;
  private readonly TAG = 'JSEngine';

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): JSEngine {
    if (JSEngine.instance === null) {
      JSEngine.instance = new JSEngine();
    }
    return JSEngine.instance;
  }

  /**
   * 初始化JavaScript引擎
   */
  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    try {
      Logger.info(this.TAG, '初始化JavaScript引擎...');
      
      // 创建WebView控制器
      this.webController = new webview.WebviewController();
      
      this.isInitialized = true;
      Logger.info(this.TAG, 'JavaScript引擎初始化成功');
      return true;
    } catch (error) {
      Logger.error(this.TAG, `初始化JavaScript引擎失败: ${error}`);
      return false;
    }
  }

  /**
   * 执行JavaScript代码
   * @param script JavaScript代码
   * @param timeout 超时时间（毫秒）
   * @returns 执行结果
   */
  async execute(script: string, timeout: number = 5000): Promise<JSExecutionResult> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    return new Promise<JSExecutionResult>((resolve) => {
      try {
        // 包装脚本，捕获结果和错误
        const wrappedScript = `
          (function() {
            try {
              const result = (function() {
                ${script}
              })();
              return JSON.stringify({ success: true, result: result });
            } catch (e) {
              return JSON.stringify({ success: false, error: e.message || String(e) });
            }
          })();
        `;

        // 使用runJavaScript执行
        this.webController?.runJavaScript(wrappedScript)
          .then((result: string) => {
            try {
              const parsed = JSON.parse(result) as JSExecutionResult;
              resolve(parsed);
            } catch {
              resolve({
                success: true,
                result: result
              });
            }
          })
          .catch((error: Error) => {
            resolve({
              success: false,
              result: '',
              error: error.message
            });
          });

        // 设置超时
        setTimeout(() => {
          resolve({
            success: false,
            result: '',
            error: '执行超时'
          });
        }, timeout);

      } catch (error) {
        resolve({
          success: false,
          result: '',
          error: error instanceof Error ? error.message : '未知错误'
        });
      }
    });
  }

  /**
   * 执行书源搜索URL生成脚本
   * @param script 书源中的@js脚本
   * @param keyword 搜索关键词
   * @param page 页码
   * @returns 生成的搜索URL
   */
  async executeSearchUrlScript(script: string, keyword: string, page: number = 1): Promise<string> {
    // 构建执行环境
    const envScript = `
      // 模拟阅读APP的java对象
      const java = {
        ajax: function(url) { return url; },
        get: function(url) { return url; },
        post: function(url, body) { return url; },
        log: function(msg) { console.log(msg); },
        longToast: function(msg) { console.log(msg); },
        encodeURI: function(str) { return encodeURI(str); },
        decodeURI: function(str) { return decodeURI(str); },
        encodeURIComponent: function(str) { return encodeURIComponent(str); },
        decodeURIComponent: function(str) { return decodeURIComponent(str); },
        t2s: function(str) { return str; },
        s2t: function(str) { return str; },
        put: function(key, value) { 
          java._cache = java._cache || {};
          java._cache[key] = value;
          return value;
        },
        get: function(key) {
          return java._cache ? java._cache[key] : null;
        },
        _cache: {}
      };

      // 搜索参数
      const key = "${keyword.replace(/"/g, '\\"')}";
      const page = ${page};

      // 执行脚本
      ${script.replace('@js:', '')}
    `;

    const result = await this.execute(envScript, 3000);
    
    if (result.success) {
      return result.result;
    } else {
      Logger.error(this.TAG, `执行搜索URL脚本失败: ${result.error}`);
      return '';
    }
  }

  /**
   * 执行书源规则脚本
   * @param html HTML内容
   * @param rule 规则脚本
   * @returns 解析结果
   */
  async executeRuleScript(html: string, rule: string): Promise<string> {
    // 转义HTML内容
    const escapedHtml = html
      .replace(/\\/g, '\\\\')
      .replace(/`/g, '\\`')
      .replace(/\$/g, '\\$');

    const envScript = `
      // 模拟阅读APP的java对象
      const java = {
        ajax: function(url) { return ''; },
        getElements: function(html, rule) { return []; },
        parseHtml: function(html) { return {}; },
        log: function(msg) { console.log(msg); },
        t2s: function(str) { return str; },
        s2t: function(str) { return str; }
      };

      // HTML内容
      const result = \`${escapedHtml}\`;

      // 执行规则
      ${rule.replace('@js:', '').replace('<js>', '').replace('</js>', '')}
    `;

    const execResult = await this.execute(envScript, 3000);
    
    if (execResult.success) {
      return execResult.result;
    } else {
      Logger.error(this.TAG, `执行规则脚本失败: ${execResult.error}`);
      return '';
    }
  }

  /**
   * 检查是否为JavaScript脚本
   */
  static isJavaScript(script: string): boolean {
    if (!script) return false;
    return script.startsWith('@js:') || 
           script.includes('<js>') || 
           script.startsWith('javascript:');
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.webController = null;
    this.isInitialized = false;
    Logger.info(this.TAG, 'JavaScript引擎已销毁');
  }
}

// 导出单例
export default JSEngine.getInstance();
