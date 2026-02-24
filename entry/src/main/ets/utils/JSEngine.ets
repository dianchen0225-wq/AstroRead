/**
 * JavaScript引擎封装类
 * 使用HarmonyOS内置WebView执行JavaScript代码
 * 用于解析阅读APP格式的书源
 * 
 * 安全增强：使用统一的 JSSecurityConfig 进行安全验证
 */

import { webview } from '@kit.ArkWeb';
import { Logger } from './Logger';
import { HTMLParser } from './HTMLParser';
import { JSSecurityConfig, SecurityValidationResult, SAFE_GLOBALS, FORBIDDEN_GLOBALS } from './JSSecurityConfig';

export interface JSExecutionResult {
  success: boolean;
  result: string;
  error?: string;
}

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

interface SecurityConfig {
  maxScriptLength: number;
  maxExecutionTime: number;
  maxNestedDepth: number;
}

interface ValidationResult {
  valid: boolean;
  error?: string;
}

export class JSEngine {
  private static instance: JSEngine | null = null;
  private webController: webview.WebviewController | null = null;
  private isInitialized: boolean = false;
  private readonly TAG = 'JSEngine';
  private securityConfig: JSSecurityConfig;
  private pendingOperations: Set<Promise<JSExecutionResult>> = new Set();
  private isDestroying: boolean = false;

  private constructor() {
    this.securityConfig = JSSecurityConfig.getInstance();
  }

  static getInstance(): JSEngine {
    if (JSEngine.instance === null) {
      JSEngine.instance = new JSEngine();
    }
    return JSEngine.instance;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    if (this.isDestroying) {
      Logger.warn(this.TAG, '引擎正在销毁中，无法初始化');
      return false;
    }

    try {
      Logger.info(this.TAG, '初始化JavaScript引擎...');
      this.webController = new webview.WebviewController();
      this.isInitialized = true;
      Logger.info(this.TAG, 'JavaScript引擎初始化成功');
      return true;
    } catch (error) {
      Logger.error(this.TAG, `初始化JavaScript引擎失败: ${error}`);
      return false;
    }
  }

  validateScript(script: string): ValidationResult {
    // 使用统一的安全配置进行验证
    const result = this.securityConfig.validateScript(script);
    
    if (!result.valid) {
      return { valid: false, error: result.error };
    }
    
    return { valid: true };
  }

  sanitizeInput(input: string): string {
    return this.securityConfig.sanitizeInput(input);
  }

  async execute(script: string, timeout?: number): Promise<JSExecutionResult> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    if (this.isDestroying) {
      return {
        success: false,
        result: '',
        error: '引擎正在销毁中'
      };
    }

    const validation = this.validateScript(script);
    if (!validation.valid) {
      return {
        success: false,
        result: '',
        error: validation.error
      };
    }

    const config = this.securityConfig.getConfig();
    const actualTimeout = Math.min(timeout ?? config.maxExecutionTime, config.maxExecutionTime);

    const operationPromise = new Promise<JSExecutionResult>((resolve) => {
      let resolved = false;
      
      try {
        const wrappedScript = `
          (function() {
            'use strict';
            const forbiddenGlobals = ['eval', 'Function', 'constructor', 'prototype', '__proto__', 
              'Proxy', 'Reflect', 'require', 'import', 'process', 'global', 'globalThis', 'module'];
            
            const safeConsole = {
              log: function() {},
              warn: function() {},
              error: function() {},
              info: function() {}
            };
            
            const sandboxGlobals = {
              console: safeConsole,
              JSON: JSON,
              Math: Math,
              Date: Date,
              String: String,
              Number: Number,
              Boolean: Boolean,
              Array: Array,
              Object: Object,
              parseInt: parseInt,
              parseFloat: parseFloat,
              isNaN: isNaN,
              isFinite: isFinite,
              encodeURIComponent: encodeURIComponent,
              decodeURIComponent: decodeURIComponent,
              encodeURI: encodeURI,
              decodeURI: decodeURI,
              btoa: btoa,
              atob: atob
            };
            
            try {
              const result = (function() {
                ${script}
              })();
              if (result === undefined) {
                return JSON.stringify({ success: true, result: '' });
              }
              if (typeof result === 'object') {
                return JSON.stringify({ success: true, result: JSON.stringify(result) });
              }
              return JSON.stringify({ success: true, result: String(result) });
            } catch (e) {
              return JSON.stringify({ success: false, error: e.message || String(e) });
            }
          })();
        `;

        this.webController?.runJavaScript(wrappedScript)
          .then((result: string) => {
            if (!resolved) {
              resolved = true;
              try {
                const parsed = JSON.parse(result) as JSExecutionResult;
                resolve(parsed);
              } catch {
                resolve({
                  success: true,
                  result: result
                });
              }
            }
          })
          .catch((error: Error) => {
            if (!resolved) {
              resolved = true;
              resolve({
                success: false,
                result: '',
                error: error.message
              });
            }
          });

        setTimeout(() => {
          if (!resolved) {
            resolved = true;
            resolve({
              success: false,
              result: '',
              error: '执行超时'
            });
          }
        }, actualTimeout);

      } catch (error) {
        if (!resolved) {
          resolved = true;
          resolve({
            success: false,
            result: '',
            error: error instanceof Error ? error.message : '未知错误'
          });
        }
      }
    });

    this.pendingOperations.add(operationPromise);

    try {
      const result = await operationPromise;
      return result;
    } finally {
      this.pendingOperations.delete(operationPromise);
    }
  }

  async executeSearchUrlScript(script: string, keyword: string, page: number = 1, baseUrl: string = ''): Promise<string> {
    // 净化输入
    const sanitizedKeyword = this.sanitizeInput(keyword);
    const sanitizedBaseUrl = this.sanitizeInput(baseUrl);
    
    // 提取并验证 JS 代码
    const jsCode = script.replace('@js:', '');
    const validation = this.validateScript(jsCode);
    if (!validation.valid) {
      Logger.error(this.TAG, `搜索URL脚本安全验证失败: ${validation.error}`);
      return '';
    }

    const envScript = `
      (function() {
        'use strict';
        const java = {
          ajax: function(url) {
            return String(url);
          },
          get: function(url) {
            return String(url);
          },
          post: function(url, body) {
            return String(url);
          },
          log: function(msg) {
            console.log('[JS Log] ' + msg);
          },
          longToast: function(msg) {
            console.log('[Toast] ' + msg);
          },
          encodeURI: function(str) { return encodeURI(String(str)); },
          decodeURI: function(str) { return decodeURI(String(str)); },
          encodeURIComponent: function(str) { return encodeURIComponent(String(str)); },
          decodeURIComponent: function(str) { return decodeURIComponent(String(str)); },
          base64Encode: function(str) { return btoa(String(str)); },
          base64Decode: function(str) { return atob(String(str)); },
          md5Encode: function(str) {
            // 简化版 MD5，实际使用需要完整实现
            return String(str);
          },
          t2s: function(str) { return String(str); },
          s2t: function(str) { return String(str); },
          put: function(key, value) {
            java._cache = java._cache || {};
            java._cache[key] = value;
            return value;
          },
          getCache: function(key) {
            return java._cache ? java._cache[key] : null;
          },
          // HTML 解析功能（简化版，仅支持基本选择器）
          getElements: function(htmlContent, selector) {
            // 简化实现：返回空数组，实际解析应在 TypeScript 层完成
            return [];
          },
          parseHtml: function(htmlContent) {
            // 简化版 HTML 解析
            const div = { innerHTML: htmlContent, textContent: htmlContent.replace(/<[^>]+>/g, '') };
            return div;
          },
          _cache: {}
        };

        // 字符串方法扩展
        String.prototype.replaceAll = function(search, replacement) {
          return this.split(search).join(replacement);
        };

        const key = "${sanitizedKeyword}";
        const page = ${page};
        const baseUrl = "${sanitizedBaseUrl}";

        ${jsCode}
      })();
    `;

    const result = await this.execute(envScript, 3000);

    if (result.success) {
      return result.result;
    } else {
      Logger.error(this.TAG, `执行搜索URL脚本失败: ${result.error}`);
      return '';
    }
  }

  async executeRuleScript(html: string, rule: string): Promise<string> {
    // 净化输入
    const sanitizedHtml = this.sanitizeInput(html);
    
    // 提取并验证 JS 代码
    const jsCode = rule.replace('@js:', '').replace('<js>', '').replace('</js>', '');
    const validation = this.validateScript(jsCode);
    if (!validation.valid) {
      Logger.error(this.TAG, `规则脚本安全验证失败: ${validation.error}`);
      return '';
    }

    const envScript = `
      (function() {
        'use strict';
        const java = {
          ajax: function(url) { return url; },
          get: function(url) { return url; },
          post: function(url, body) { return url; },
          getElements: function(htmlContent, selector) {
            // 简化实现：返回空数组
            return [];
          },
          parseHtml: function(htmlContent) {
            return {
              text: htmlContent.replace(/<[^>]+>/g, ''),
              html: htmlContent
            };
          },
          log: function(msg) { console.log('[JS Log] ' + msg); },
          longToast: function(msg) { console.log('[Toast] ' + msg); },
          t2s: function(str) { return String(str); },
          s2t: function(str) { return String(str); },
          base64Encode: function(str) { return btoa(String(str)); },
          base64Decode: function(str) { return atob(String(str)); },
          encodeURI: function(str) { return encodeURI(String(str)); },
          decodeURI: function(str) { return decodeURI(String(str)); },
          encodeURIComponent: function(str) { return encodeURIComponent(String(str)); },
          decodeURIComponent: function(str) { return decodeURIComponent(String(str)); },
          // 结果变量
          result: "${sanitizedHtml}"
        };

        // 原始 HTML
        const result = "${sanitizedHtml}";

        // 用户规则
        ${jsCode}
      })();
    `;

    const execResult = await this.execute(envScript, 3000);

    if (execResult.success) {
      return execResult.result;
    } else {
      Logger.error(this.TAG, `执行规则脚本失败: ${execResult.error}`);
      return '';
    }
  }

  static isJavaScript(script: string): boolean {
    if (!script) return false;
    return script.startsWith('@js:') || 
           script.includes('<js>') || 
           script.includes('</js>');
  }

  async destroy(): Promise<void> {
    if (this.isDestroying) {
      Logger.warn(this.TAG, '引擎正在销毁中，请勿重复调用');
      return;
    }

    this.isDestroying = true;
    Logger.info(this.TAG, '开始销毁JavaScript引擎...');

    try {
      if (this.pendingOperations.size > 0) {
        Logger.info(this.TAG, `等待 ${this.pendingOperations.size} 个操作完成...`);
        
        const timeout = new Promise<void>((resolve) => {
          setTimeout(() => {
            Logger.warn(this.TAG, '等待操作超时，强制销毁');
            resolve();
          }, 3000);
        });

        await Promise.race([
          Promise.allSettled(Array.from(this.pendingOperations)),
          timeout
        ]);
      }

      if (this.webController) {
        try {
          this.webController.stop();
          Logger.debug(this.TAG, 'WebView 已停止');
        } catch (e) {
          Logger.warn(this.TAG, `停止 WebView 失败: ${e}`);
        }
      }

      this.webController = null;
      this.isInitialized = false;
      this.pendingOperations.clear();
      JSEngine.instance = null;

      Logger.info(this.TAG, 'JavaScript引擎已销毁');
    } catch (error) {
      Logger.error(this.TAG, `销毁JavaScript引擎时发生错误: ${error}`);
      this.webController = null;
      this.isInitialized = false;
      JSEngine.instance = null;
    } finally {
      this.isDestroying = false;
    }
  }

  isEngineReady(): boolean {
    return this.isInitialized && !this.isDestroying && this.webController !== null;
  }

  getPendingOperationsCount(): number {
    return this.pendingOperations.size;
  }
}
