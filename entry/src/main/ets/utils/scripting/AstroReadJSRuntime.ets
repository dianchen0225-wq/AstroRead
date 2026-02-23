import { Logger } from "../performance/Logger";
import { RuleEngine } from "../parser/RuleEngine";

export interface SearchContext {
  key: string;
  page: number;
  baseUrl: string;
  result?: string;
}

type JSVariable = string | number | boolean | object | null | undefined;
type JSVariables = Record<string, JSVariable>;

export interface ScriptParam extends JSVariables {
  key: string;
  page: number;
  baseUrl: string;
}

export interface RuleParam extends JSVariables {
  result: string;
  baseUrl: string;
}

export class AstroReadJSRuntime {
  private static instance: AstroReadJSRuntime | null = null;
  private readonly TAG = 'AstroReadJSRuntime';
  private cache: Map<string, string | number | boolean> = new Map();
  private jsRuntime: JSVariables | null = null;

  private constructor() {
  }

  static getInstance(): AstroReadJSRuntime {
    if (AstroReadJSRuntime.instance === null) {
      AstroReadJSRuntime.instance = new AstroReadJSRuntime();
    }
    return AstroReadJSRuntime.instance;
  }

  async executeSearchUrl(script: string, context: SearchContext): Promise<string> {
    try {
      let jsCode = script.replace(/^@js:\s*/i, '').trim();

      if (jsCode.startsWith('<js>')) {
        jsCode = jsCode.replace(/<js>/, '').replace(/<\/js>/, '').trim();
      }

      Logger.debug(this.TAG, `执行搜索URL脚本`);

      const param: ScriptParam = {
        key: context.key,
        page: context.page,
        baseUrl: context.baseUrl
      };
      const result = await this.executeScript(jsCode, param);

      if (result) {
        let url = result;
        if ((url.startsWith('"') && url.endsWith('"')) ||
            (url.startsWith("'") && url.endsWith("'"))) {
          url = url.slice(1, -1);
        }
        Logger.info(this.TAG, `生成搜索URL: ${url}`);
        return url;
      }

      return '';
    } catch (error) {
      Logger.error(this.TAG, `执行搜索URL脚本异常: ${error}`);
      return '';
    }
  }

  async executeRule(html: string, rule: string): Promise<string> {
    try {
      if (!this.isJSRule(rule)) {
        return rule;
      }

      let jsCode = rule;
      if (jsCode.includes('<js>')) {
        const match = jsCode.match(/<js>([\s\S]*?)<\/js>/);
        if (match) {
          jsCode = match[1];
        }
      } else {
        jsCode = jsCode.replace(/^@js:\s*/i, '').trim();
      }

      const param: RuleParam = {
        result: html,
        baseUrl: RuleEngine.getContext().baseUrl
      };
      const result = await this.executeScript(jsCode, param);

      return result || '';
    } catch (error) {
      Logger.error(this.TAG, `执行规则脚本异常: ${error}`);
      return '';
    }
  }

  private async executeScript(jsCode: string, variables: JSVariables): Promise<string> {
    const wrappedCode = this.buildScriptEnvironment(jsCode, variables);

    try {
      if (this.jsRuntime && typeof this.jsRuntime.runJavaScript === 'function') {
        const result = await this.jsRuntime.runJavaScript(wrappedCode) as JSVariable;
        return String(result || '');
      }

      Logger.warn(this.TAG, 'JS运行时未初始化，使用简化执行');
      return this.executeSimple(jsCode, variables);
    } catch (error) {
      Logger.error(this.TAG, `脚本执行失败: ${error}`);
      return '';
    }
  }

  private executeSimple(jsCode: string, variables: JSVariables): string {
    try {
      const key = (variables.key as string) || '';
      const page = (variables.page as number) || 1;
      const baseUrl = (variables.baseUrl as string) || '';

      let result = jsCode;

      result = result.replace(/\bkey\b/g, `"${key}"`);
      result = result.replace(/\bpage\b/g, String(page));
      result = result.replace(/\bbaseUrl\b/g, `"${baseUrl}"`);

      if (result.includes('encodeURIComponent')) {
        const match = result.match(/encodeURIComponent\s*\(\s*["']?([^"')]+)["']?\s*\)/);
        if (match) {
          return encodeURIComponent(match[1]);
        }
      }

      return result;
    } catch (error) {
      Logger.error(this.TAG, `简化执行失败: ${error}`);
      return '';
    }
  }

  private buildScriptEnvironment(jsCode: string, variables: JSVariables): string {
    const key = this.escapeString((variables.key as string) || '');
    const page = (variables.page as number) || 1;
    const baseUrl = this.escapeString((variables.baseUrl as string) || '');
    const result = this.escapeString((variables.result as string) || '');

    return `
  (function() {
    'use strict';

    const _cache = {};
    const _variables = {};

    const java = {
      put: function(key, value) {
        _cache[key] = value;
        return value;
      },
      get: function(key) {
        return _cache[key] !== undefined ? _cache[key] : '';
      },

      log: function(msg) {
        console.log('[AstroRead] ' + msg);
      },
      longToast: function(msg) {
        console.log('[Toast] ' + msg);
      },

      encodeURI: function(str) {
        return encodeURI(String(str));
      },
      decodeURI: function(str) {
        return decodeURI(String(str));
      },
      encodeURIComponent: function(str) {
        return encodeURIComponent(String(str));
      },
      decodeURIComponent: function(str) {
        return decodeURIComponent(String(str));
      },

      base64Encode: function(str) {
        try {
          return btoa(unescape(encodeURIComponent(String(str))));
        } catch (e) {
          return btoa(String(str));
        }
      },
      base64Decode: function(str) {
        try {
          return decodeURIComponent(escape(atob(String(str))));
        } catch (e) {
          return atob(String(str));
        }
      },
      base64DecodeToByteArray: function(str) {
        const binary = atob(String(str));
        const arr = new Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
          arr[i] = binary.charCodeAt(i);
        }
        return arr;
      },

      md5Encode: function(str) {
        return String(str);
      },

      t2s: function(str) {
        return String(str);
      },
      s2t: function(str) {
        return String(str);
      },

      ajax: function(url) {
        return String(url);
      },
      get: function(url) {
        return String(url);
      },
      post: function(url, body) {
        return String(url);
      },

      connect: function(url) {
        return {
          url: url,
          method: 'GET',
          header: {},
          body: '',
          get: function() { return this; },
          post: function() { return this; },
          header: function(h) { Object.assign(this.header, h); return this; },
          body: function(b) { this.body = b; return this; },
          toString: function() { return this.url; }
        };
      },

      getString: function(rule) {
        return '';
      },
      getStringList: function(rule) {
        return [];
      },

      startBrowser: function(url, title) {
        return String(url);
      },
      startBrowserAwait: function(url, title) {
        return String(url);
      },
      openUrl: function(url) {
        return String(url);
      },

      getWebViewUA: function() {
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      },

      timeFormat: function(format, timestamp) {
        const date = timestamp ? new Date(timestamp) : new Date();
        return date.toLocaleString();
      },
      time: function() {
        return Date.now();
      },

      random: function(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
      },

      uuid: function() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
          const r = Math.random() * 16 | 0;
          const v = c === 'x' ? r : (r & 0x3 | 0x8);
          return v.toString(16);
        });
      },

      JSON: {
        parse: function(str) {
          return JSON.parse(str);
        },
        stringify: function(obj) {
          return JSON.stringify(obj);
        }
      },

      String: function(obj) {
        return String(obj);
      },
      Number: function(obj) {
        return Number(obj);
      },

      Math: Math,
      RegExp: RegExp,
      Date: Date,
      Array: {
        isArray: function(obj) {
          return Array.isArray(obj);
        }
      },

      importClass: function(className) {
        return {};
      },
      importPackage: function(pkg) {
        return {};
      }
    };

    const key = "${key}";
    const page = ${page};
    const baseUrl = "${baseUrl}";
    let result = "${result}";

    const tzs = function(str) { return String(str); };
    const String2 = function(obj) { return String(obj); };
    const Number2 = function(obj) { return Number(obj); };

    const JavaImporter = function() {
      return {
        importPackage: function() {},
        importClass: function() {}
      };
    };

    const Packages = {};
    const Packages2 = {};

    with (java) {
      try {
        ${jsCode}
      } catch (e) {
        console.log('[AstroRead Error] ' + e.message);
      }
    }
  })();
  `;
  }

  isJSRule(rule: string): boolean {
    if (!rule) return false;
    return rule.startsWith('@js:') || rule.includes('<js>');
  }

  private escapeString(str: string): string {
    if (!str) return '';
    return str
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t');
  }

  setJSRuntime(runtime: JSVariables): void {
    this.jsRuntime = runtime;
  }

  putCache(key: string, value: string | number | boolean): void {
    this.cache.set(key, value);
  }

  getCache(key: string): string | number | boolean | undefined {
    return this.cache.get(key);
  }

  clearCache(): void {
    this.cache.clear();
  }

  destroy(): void {
    this.clearCache();
    this.jsRuntime = null;
  }
}

export default AstroReadJSRuntime.getInstance();
