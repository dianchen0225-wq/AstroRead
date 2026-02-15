/**
 * JavaScript引擎封装类
 * 使用HarmonyOS内置WebView执行JavaScript代码
 * 用于解析阅读APP格式的书源
 */

import webview from '@ohos.web.webview';
import { Logger } from './Logger';

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

const DEFAULT_SECURITY_CONFIG: SecurityConfig = {
  maxScriptLength: 50000,
  maxExecutionTime: 5000,
  maxNestedDepth: 10
};

const FORBIDDEN_PATTERNS: RegExp[] = [
  /eval\s*\(/gi,
  /Function\s*\(/gi,
  /new\s+Function\s*\(/gi,
  /document\.\s*/gi,
  /window\.\s*/gi,
  /globalThis\.\s*/gi,
  /process\.\s*/gi,
  /require\s*\(/gi,
  /import\s+/gi,
  /WebSocket\s*\(/gi,
  /XMLHttpRequest\s*\(/gi,
  /fetch\s*\(/gi,
  /localStorage/gi,
  /sessionStorage/gi,
  /indexedDB/gi,
  /openDatabase/gi,
  /Worker\s*\(/gi,
  /SharedArrayBuffer/gi,
  /Atomics\./gi,
  /__proto__/gi,
  /prototype\s*\[/gi,
  /constructor\s*\(/gi,
  /Object\.defineProperty/gi,
  /Object\.setPrototypeOf/gi,
  /Reflect\./gi,
  /Proxy\s*\(/gi,
  /\.innerHTML\s*=/gi,
  /\.outerHTML\s*=/gi,
  /alert\s*\(/gi,
  /confirm\s*\(/gi,
  /prompt\s*\(/gi
];

export class JSEngine {
  private static instance: JSEngine | null = null;
  private webController: webview.WebviewController | null = null;
  private isInitialized: boolean = false;
  private readonly TAG = 'JSEngine';
  private securityConfig: SecurityConfig;

  private constructor(config: Partial<SecurityConfig> = {}) {
    this.securityConfig = {
      maxScriptLength: config.maxScriptLength ?? DEFAULT_SECURITY_CONFIG.maxScriptLength,
      maxExecutionTime: config.maxExecutionTime ?? DEFAULT_SECURITY_CONFIG.maxExecutionTime,
      maxNestedDepth: config.maxNestedDepth ?? DEFAULT_SECURITY_CONFIG.maxNestedDepth
    };
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
    if (!script || script.trim().length === 0) {
      const result: ValidationResult = { valid: false, error: '脚本为空' };
      return result;
    }

    if (script.length > this.securityConfig.maxScriptLength) {
      const result: ValidationResult = { valid: false, error: `脚本长度超过限制 (${this.securityConfig.maxScriptLength}字符)` };
      return result;
    }

    for (const pattern of FORBIDDEN_PATTERNS) {
      if (pattern.test(script)) {
        Logger.warn(this.TAG, `脚本包含禁止的模式: ${pattern.source}`);
        const result: ValidationResult = { valid: false, error: `脚本包含不安全的代码模式` };
        return result;
      }
    }

    const bracketCount = (script.match(/\(/g) || []).length;
    const closeBracketCount = (script.match(/\)/g) || []).length;
    if (Math.abs(bracketCount - closeBracketCount) > this.securityConfig.maxNestedDepth) {
      const result: ValidationResult = { valid: false, error: '脚本嵌套深度超过限制' };
      return result;
    }

    const result: ValidationResult = { valid: true };
    return result;
  }

  sanitizeInput(input: string): string {
    return input
      .replace(/\\/g, '\\\\')
      .replace(/`/g, '\\`')
      .replace(/\$/g, '\\$')
      .replace(/"/g, '\\"')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t');
  }

  async execute(script: string, timeout: number = 5000): Promise<JSExecutionResult> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const validation = this.validateScript(script);
    if (!validation.valid) {
      return {
        success: false,
        result: '',
        error: validation.error
      };
    }

    const actualTimeout = Math.min(timeout, this.securityConfig.maxExecutionTime);

    return new Promise<JSExecutionResult>((resolve) => {
      let resolved = false;
      
      try {
        const wrappedScript = `
          (function() {
            'use strict';
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
  }

  async executeSearchUrlScript(script: string, keyword: string, page: number = 1): Promise<string> {
    const sanitizedKeyword = this.sanitizeInput(keyword);
    
    const envScript = `
      (function() {
        'use strict';
        const java = {
          ajax: function(url) { return String(url); },
          get: function(url) { return String(url); },
          post: function(url, body) { return String(url); },
          log: function(msg) { },
          longToast: function(msg) { },
          encodeURI: function(str) { return encodeURI(str); },
          decodeURI: function(str) { return decodeURI(str); },
          encodeURIComponent: function(str) { return encodeURIComponent(str); },
          decodeURIComponent: function(str) { return decodeURIComponent(str); },
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
          _cache: {}
        };

        const key = "${sanitizedKeyword}";
        const page = ${page};

        ${script.replace('@js:', '')}
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
    const sanitizedHtml = this.sanitizeInput(html);
    const sanitizedRule = this.sanitizeInput(rule);

    const envScript = `
      (function() {
        'use strict';
        const java = {
          ajax: function(url) { return ''; },
          getElements: function(html, rule) { return []; },
          parseHtml: function(html) { return {}; },
          log: function(msg) { },
          t2s: function(str) { return String(str); },
          s2t: function(str) { return String(str); }
        };

        const result = "${sanitizedHtml}";

        ${sanitizedRule.replace('@js:', '').replace('<js>', '').replace('</js>', '')}
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

  destroy(): void {
    this.webController = null;
    this.isInitialized = false;
    Logger.info(this.TAG, 'JavaScript引擎已销毁');
  }
}
