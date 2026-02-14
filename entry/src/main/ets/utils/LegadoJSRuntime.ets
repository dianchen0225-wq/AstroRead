/**
 * 阅读APP书源JavaScript运行环境
 * 模拟阅读APP的完整JavaScript API
 */

import http from '@ohos.net.http';
import { Logger } from './Logger';
import { JSEngine, JSExecutionResult } from './JSEngine';

/**
 * 搜索上下文
 */
export interface SearchContext {
  key: string;           // 搜索关键词
  page: number;          // 当前页码
  baseUrl: string;       // 基础URL
  result?: string;       // 当前结果（用于链式处理）
}

/**
 * 书源JavaScript运行环境
 * 提供阅读APP书源所需的完整JavaScript环境
 */
export class LegadoJSRuntime {
  private static instance: LegadoJSRuntime | null = null;
  private jsEngine: JSEngine;
  private readonly TAG = 'LegadoJSRuntime';
  
  // 缓存数据
  private cache: Map<string, string | number | boolean> = new Map();
  
  // HTTP请求头
  private defaultHeaders: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
  };

  private constructor() {
    this.jsEngine = JSEngine.getInstance();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): LegadoJSRuntime {
    if (LegadoJSRuntime.instance === null) {
      LegadoJSRuntime.instance = new LegadoJSRuntime();
    }
    return LegadoJSRuntime.instance;
  }

  /**
   * 执行搜索URL生成脚本
   * @param script @js脚本内容
   * @param context 搜索上下文
   * @returns 生成的搜索URL
   */
  async executeSearchUrl(script: string, context: SearchContext): Promise<string> {
    try {
      // 移除@js前缀
      let jsCode = script.replace(/^@js:\s*/i, '').trim();
      
      // 构建完整的执行环境
      const wrappedCode = this.buildSearchUrlEnvironment(jsCode, context);
      
      Logger.debug(this.TAG, `执行搜索URL脚本: ${jsCode.substring(0, 100)}...`);
      
      const result = await this.jsEngine.execute(wrappedCode, 5000);
      
      if (result.success && result.result) {
        // 处理结果
        let url = result.result;
        // 移除可能的引号
        if ((url.startsWith('"') && url.endsWith('"')) || 
            (url.startsWith("'") && url.endsWith("'"))) {
          url = url.slice(1, -1);
        }
        Logger.info(this.TAG, `生成搜索URL: ${url}`);
        return url;
      } else {
        Logger.error(this.TAG, `执行搜索URL脚本失败: ${result.error}`);
        return '';
      }
    } catch (error) {
      Logger.error(this.TAG, `执行搜索URL脚本异常: ${error}`);
      return '';
    }
  }

  /**
   * 构建搜索URL执行环境
   */
  private buildSearchUrlEnvironment(jsCode: string, context: SearchContext): string {
    return `
// ========== 阅读APP书源环境模拟 ==========
(function() {
  // 缓存对象
  const _cache = {};
  
  // java对象模拟
  const java = {
    // 缓存操作
    put: function(key, value) {
      _cache[key] = value;
      return value;
    },
    get: function(key) {
      return _cache[key];
    },
    
    // 日志
    log: function(msg) {
      console.log('[Legado] ' + msg);
    },
    longToast: function(msg) {
      console.log('[Legado Toast] ' + msg);
    },
    
    // 编码函数
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
    
    // 繁简转换（简化实现）
    t2s: function(str) {
      return String(str);
    },
    s2t: function(str) {
      return String(str);
    },
    
    // 网络请求（返回URL，实际请求在外部处理）
    ajax: function(url) {
      return url;
    },
    
    // 浏览器操作
    startBrowser: function(url, title) {
      return url;
    },
    startBrowserAwait: function(url, title) {
      return url;
    },
    openUrl: function(url) {
      return url;
    },
    
    // WebView UA
    getWebViewUA: function() {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    },
    
    // JSON操作
    JSON: {
      parse: function(str) {
        return JSON.parse(str);
      },
      stringify: function(obj) {
        return JSON.stringify(obj);
      }
    },
    
    // 字符串操作
    String: function(obj) {
      return String(obj);
    },
    Number: function(obj) {
      return Number(obj);
    },
    
    // 数学函数
    Math: Math,
    
    // 正则表达式
    RegExp: RegExp,
    
    // 数组操作
    Array: {
      isArray: function(obj) {
        return Array.isArray(obj);
      }
    }
  };
  
  // 全局变量
  const key = "${this.escapeString(context.key)}";
  const page = ${context.page};
  const baseUrl = "${this.escapeString(context.baseUrl || '')}";
  let result = "${this.escapeString(context.result || '')}";
  
  // 常用函数
  const tzs = function(str) { return String(str); };
  const String = function(obj) { return String(obj); };
  const Number = function(obj) { return Number(obj); };
  
  // ========== 用户脚本 ==========
  ${jsCode}
  
  // ========== 返回结果 ==========
  // 如果脚本没有显式返回，尝试返回最后一个表达式
})();
`;
  }

  /**
   * 执行规则脚本
   * @param html HTML内容
   * @param rule 规则脚本
   * @returns 解析结果
   */
  async executeRule(html: string, rule: string): Promise<string> {
    try {
      // 检查是否是JS规则
      if (!this.isJSRule(rule)) {
        return rule; // 不是JS规则，直接返回
      }

      // 提取JS代码
      let jsCode = rule;
      if (jsCode.includes('<js>')) {
        const match = jsCode.match(/<js>([\s\S]*?)<\/js>/);
        if (match) {
          jsCode = match[1];
        }
      } else {
        jsCode = jsCode.replace(/^@js:\s*/i, '').trim();
      }

      // 构建执行环境
      const wrappedCode = this.buildRuleEnvironment(jsCode, html);
      
      const result = await this.jsEngine.execute(wrappedCode, 5000);
      
      if (result.success) {
        return result.result;
      } else {
        Logger.error(this.TAG, `执行规则脚本失败: ${result.error}`);
        return '';
      }
    } catch (error) {
      Logger.error(this.TAG, `执行规则脚本异常: ${error}`);
      return '';
    }
  }

  /**
   * 构建规则执行环境
   */
  private buildRuleEnvironment(jsCode: string, html: string): string {
    const escapedHtml = this.escapeString(html);
    
    return `
// ========== 规则执行环境 ==========
(function() {
  const result = "${escapedHtml}";
  
  // java对象（简化版）
  const java = {
    log: function(msg) { console.log(msg); },
    getElements: function(html, rule) { return []; },
    t2s: function(str) { return str; },
    s2t: function(str) { return str; }
  };
  
  // ========== 用户规则 ==========
  ${jsCode}
})();
`;
  }

  /**
   * 检查是否是JavaScript规则
   */
  isJSRule(rule: string): boolean {
    if (!rule) return false;
    return rule.startsWith('@js:') || rule.includes('<js>');
  }

  /**
   * 转义字符串
   */
  private escapeString(str: string): string {
    if (!str) return '';
    return str
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t');
  }

  /**
   * 清理缓存
   */
  clearCache(): void {
    this.cache.clear();
  }

  /**
   * 销毁资源
   */
  destroy(): void {
    this.clearCache();
    this.jsEngine.destroy();
  }
}

// 导出单例
export default LegadoJSRuntime.getInstance();
