/**
 * JSSecurityConfig - JavaScript 执行安全配置模块
 * 提供统一的沙箱隔离、代码注入检测和安全验证机制
 */

import { Logger } from "../performance/Logger";

/**
 * 安全配置接口
 */
export interface SecurityConfig {
  maxScriptLength: number;
  maxExecutionTime: number;
  maxNestedDepth: number;
  maxLoopIterations: number;
  enableSandbox: boolean;
  enableInjectionDetection: boolean;
  enableTimeoutControl: boolean;
}

/**
 * 验证结果接口
 */
export interface SecurityValidationResult {
  valid: boolean;
  error?: string;
  errors?: string[];
  threat?: string;
  severity?: 'low' | 'medium' | 'high' | 'critical';
}

/**
 * 安全的全局对象白名单
 * 只允许这些安全的 API 在沙箱中使用
 */
export const SAFE_GLOBALS: Record<string, boolean> = {
  // 标准内置对象
  'JSON': true,
  'Math': true,
  'Date': true,
  'Array': true,
  'Object': true,
  'String': true,
  'Number': true,
  'Boolean': true,
  'Error': true,
  'RegExp': true,

  // 安全的全局函数
  'parseInt': true,
  'parseFloat': true,
  'isNaN': true,
  'isFinite': true,
  'encodeURIComponent': true,
  'decodeURIComponent': true,
  'encodeURI': true,
  'decodeURI': true,

  // 允许的上下文变量
  'key': true,
  'page': true,
  'baseUrl': true,
  'result': true,
  'java': true,
  'src': true,
};

/**
 * 禁止访问的敏感全局对象
 */
export const FORBIDDEN_GLOBALS: string[] = [
  // Node.js 环境
  'process',
  'require',
  'module',
  'exports',
  '__dirname',
  '__filename',
  'global',
  'Buffer',

  // 浏览器环境
  'window',
  'document',
  'navigator',
  'location',
  'history',
  'localStorage',
  'sessionStorage',
  'indexedDB',
  'openDatabase',
  'cookieStore',

  // 网络相关
  'fetch',
  'XMLHttpRequest',
  'WebSocket',
  'EventSource',

  // Web Workers
  'Worker',
  'SharedWorker',
  'ServiceWorker',

  // 危险对象
  'eval',
  'Function',
  'Proxy',
  'Reflect',
  'globalThis',
  'Atomics',
  'SharedArrayBuffer',
  'WebAssembly',

  // 系统访问
  'alert',
  'confirm',
  'prompt',
  'print',
  'open',
  'close',

  // 原型链操作
  '__proto__',
  'constructor',
  'prototype',
];

/**
 * 禁止的代码模式（正则表达式）
 * 用于检测潜在的代码注入攻击
 */
export const FORBIDDEN_PATTERNS: RegExp[] = [
  // 动态代码执行
  /eval\s*\(/gi,
  /Function\s*\(/gi,
  /new\s+Function\s*\(/gi,
  /setTimeout\s*\(\s*['"`]/gi,
  /setInterval\s*\(\s*['"`]/gi,
  /setImmediate\s*\(/gi,

  // 模块系统
  /require\s*\(/gi,
  /import\s+/gi,
  /export\s+(default\s+)?/gi,
  /define\s*\(/gi,

  // 全局对象访问
  /process\.\s*/gi,
  /global\.\s*/gi,
  /globalThis\.\s*/gi,
  /window\.\s*/gi,
  /document\.\s*/gi,
  /globalThis\[/gi,

  // DOM 操作
  /\.innerHTML\s*=/gi,
  /\.outerHTML\s*=/gi,
  /document\.write/gi,
  /document\.writeln/gi,

  // 原型链污染
  /__proto__/gi,
  /prototype\s*\[/gi,
  /constructor\s*\(/gi,
  /Object\.defineProperty/gi,
  /Object\.setPrototypeOf/gi,
  /Object\.getPrototypeOf/gi,
  /Object\.create\s*\(/gi,
  /Object\.assign\s*\(/gi,

  // 反射和代理
  /Reflect\./gi,
  /Proxy\s*\(/gi,
  /new\s+Proxy\s*\(/gi,

  // 网络请求
  /fetch\s*\(/gi,
  /XMLHttpRequest/gi,
  /WebSocket\s*\(/gi,
  /new\s+WebSocket/gi,

  // 存储访问
  /localStorage/gi,
  /sessionStorage/gi,
  /indexedDB/gi,
  /openDatabase/gi,

  // Worker
  /Worker\s*\(/gi,
  /new\s+Worker/gi,
  /SharedArrayBuffer/gi,
  /Atomics\./gi,

  // 危险操作
  /\.constructor\b/gi,
  /\.prototype\b/gi,
  /this\s*\[\s*['"]/gi,
  /with\s*\(/gi,
  /debugger\b/gi,

  // 用户交互
  /alert\s*\(/gi,
  /confirm\s*\(/gi,
  /prompt\s*\(/gi,

  // 编码绕过尝试
  /\\x[0-9a-fA-F]{2}/g,
  /\\u[0-9a-fA-F]{4}/g,
  /fromCharCode/gi,
  /fromCodePoint/gi,

  // 模板字符串注入
  /\$\{[^}]*eval/gi,
  /\$\{[^}]*Function/gi,
  /\$\{[^}]*require/gi,

  // 删除操作
  /delete\s+\w+\s*\.\s*\w+/gi,

  // 异常处理滥用
  /throw\s+new\s+Error/gi,
];

/**
 * 危险关键字列表
 * 用于额外的关键字检测
 */
export const DANGEROUS_KEYWORDS: string[] = [
  'eval',
  'Function',
  'constructor',
  'prototype',
  '__proto__',
  'defineProperty',
  'getOwnPropertyDescriptor',
  'setPrototypeOf',
  'getPrototypeOf',
  'create',
  'Proxy',
  'Reflect',
  'require',
  'import',
  'process',
  'global',
  'globalThis',
  'module',
  'exports',
  'Buffer',
  'fetch',
  'XMLHttpRequest',
  'WebSocket',
  'Worker',
];

/**
 * 默认安全配置
 */
export const DEFAULT_SECURITY_CONFIG: SecurityConfig = {
  maxScriptLength: 50000,
  maxExecutionTime: 5000,
  maxNestedDepth: 10,
  maxLoopIterations: 10000,
  enableSandbox: true,
  enableInjectionDetection: true,
  enableTimeoutControl: true,
};

/**
 * 合并安全配置的辅助函数
 */
function mergeSecurityConfig(base: SecurityConfig, override: Partial<SecurityConfig>): SecurityConfig {
  const result: SecurityConfig = {
    maxScriptLength: override.maxScriptLength !== undefined ? override.maxScriptLength : base.maxScriptLength,
    maxExecutionTime: override.maxExecutionTime !== undefined ? override.maxExecutionTime : base.maxExecutionTime,
    maxNestedDepth: override.maxNestedDepth !== undefined ? override.maxNestedDepth : base.maxNestedDepth,
    maxLoopIterations: override.maxLoopIterations !== undefined ? override.maxLoopIterations : base.maxLoopIterations,
    enableSandbox: override.enableSandbox !== undefined ? override.enableSandbox : base.enableSandbox,
    enableInjectionDetection: override.enableInjectionDetection !== undefined ? override.enableInjectionDetection : base.enableInjectionDetection,
    enableTimeoutControl: override.enableTimeoutControl !== undefined ? override.enableTimeoutControl : base.enableTimeoutControl
  };
  return result;
}

/**
 * 复制安全配置的辅助函数
 */
function cloneSecurityConfig(config: SecurityConfig): SecurityConfig {
  return {
    maxScriptLength: config.maxScriptLength,
    maxExecutionTime: config.maxExecutionTime,
    maxNestedDepth: config.maxNestedDepth,
    maxLoopIterations: config.maxLoopIterations,
    enableSandbox: config.enableSandbox,
    enableInjectionDetection: config.enableInjectionDetection,
    enableTimeoutControl: config.enableTimeoutControl
  };
}

/**
 * 沙箱控制台接口
 */
interface SandboxConsole {
  log: () => void;
  warn: () => void;
  error: () => void;
  info: () => void;
  debug: () => void;
}

/**
 * 超时控制器接口
 */
interface TimeoutController {
  check: () => boolean;
  remaining: () => number;
  startTime: number;
}

/**
 * JavaScript 安全配置类
 * 提供统一的安全验证和沙箱隔离机制
 */
export class JSSecurityConfig {
  private static instance: JSSecurityConfig | null = null;
  private readonly TAG = 'JSSecurityConfig';
  private config: SecurityConfig;
  private customForbiddenPatterns: RegExp[] = [];
  private customSafeGlobals: Set<string> = new Set();

  private constructor(config: Partial<SecurityConfig> = {}) {
    this.config = mergeSecurityConfig(DEFAULT_SECURITY_CONFIG, config);
  }

  /**
   * 获取单例实例
   */
  static getInstance(config: Partial<SecurityConfig> = {}): JSSecurityConfig {
    if (!JSSecurityConfig.instance) {
      JSSecurityConfig.instance = new JSSecurityConfig(config);
    }
    return JSSecurityConfig.instance;
  }

  /**
   * 获取当前安全配置
   */
  getConfig(): SecurityConfig {
    return cloneSecurityConfig(this.config);
  }

  /**
   * 更新安全配置
   */
  updateConfig(newConfig: Partial<SecurityConfig>): void {
    this.config = mergeSecurityConfig(this.config, newConfig);
    Logger.info(this.TAG, '安全配置已更新');
  }

  /**
   * 添加自定义禁止模式
   */
  addForbiddenPattern(pattern: RegExp): void {
    this.customForbiddenPatterns.push(pattern);
  }

  /**
   * 添加自定义安全全局对象
   */
  addSafeGlobal(name: string): void {
    this.customSafeGlobals.add(name);
  }

  /**
   * 验证脚本安全性
   * 执行多层安全检查
   */
  validateScript(script: string): SecurityValidationResult {
    // 1. 基本检查
    if (!script || script.trim().length === 0) {
      return { valid: false, error: '脚本为空', severity: 'low' };
    }

    // 2. 长度检查
    if (script.length > this.config.maxScriptLength) {
      return {
        valid: false,
        error: `脚本长度超过限制 (${this.config.maxScriptLength} 字符)`,
        severity: 'medium'
      };
    }

    // 3. 代码注入检测
    if (this.config.enableInjectionDetection) {
      const injectionResult = this.detectInjection(script);
      if (!injectionResult.valid) {
        return injectionResult;
      }
    }

    // 4. 嵌套深度检查
    const depthResult = this.checkNestedDepth(script);
    if (!depthResult.valid) {
      return depthResult;
    }

    // 5. 危险关键字检查
    const keywordResult = this.checkDangerousKeywords(script);
    if (!keywordResult.valid) {
      return keywordResult;
    }

    // 6. 禁止标识符检查
    const identifierResult = this.checkForbiddenIdentifiers(script);
    if (!identifierResult.valid) {
      return identifierResult;
    }

    return { valid: true };
  }

  /**
   * 检测代码注入攻击
   */
  private detectInjection(script: string): SecurityValidationResult {
    // 检查标准禁止模式
    for (const pattern of FORBIDDEN_PATTERNS) {
      pattern.lastIndex = 0;
      if (pattern.test(script)) {
        Logger.warn(this.TAG, `检测到禁止的代码模式: ${pattern.source}`);
        return {
          valid: false,
          error: '脚本包含不安全的代码模式',
          threat: pattern.source,
          severity: 'high'
        };
      }
    }

    // 检查自定义禁止模式
    for (const pattern of this.customForbiddenPatterns) {
      pattern.lastIndex = 0;
      if (pattern.test(script)) {
        Logger.warn(this.TAG, `检测到自定义禁止模式: ${pattern.source}`);
        return {
          valid: false,
          error: '脚本包含自定义禁止的代码模式',
          threat: pattern.source,
          severity: 'high'
        };
      }
    }

    // 检测编码绕过尝试
    const encodingBypassPatterns = [
      /\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}/g,
      /\\u[0-9a-fA-F]{4}\\u[0-9a-fA-F]{4}/g,
      /String\.fromCharCode/gi,
    ];

    for (const pattern of encodingBypassPatterns) {
      pattern.lastIndex = 0;
      if (pattern.test(script)) {
        Logger.warn(this.TAG, '检测到编码绕过尝试');
        return {
          valid: false,
          error: '检测到编码绕过尝试',
          severity: 'critical'
        };
      }
    }

    return { valid: true };
  }

  /**
   * 检查嵌套深度
   */
  private checkNestedDepth(script: string): SecurityValidationResult {
    const bracketCount = (script.match(/\(/g) || []).length;
    const closeBracketCount = (script.match(/\)/g) || []).length;
    if (Math.abs(bracketCount - closeBracketCount) > this.config.maxNestedDepth) {
      return {
        valid: false,
        error: '脚本嵌套深度超过限制',
        severity: 'medium'
      };
    }

    const braceCount = (script.match(/\{/g) || []).length;
    const closeBraceCount = (script.match(/\}/g) || []).length;
    if (Math.abs(braceCount - closeBraceCount) > this.config.maxNestedDepth) {
      return {
        valid: false,
        error: '脚本括号不匹配',
        severity: 'medium'
      };
    }

    return { valid: true };
  }

  /**
   * 检查危险关键字
   */
  private checkDangerousKeywords(script: string): SecurityValidationResult {
    const normalizedScript = script.replace(/\s+/g, ' ').toLowerCase();

    for (const keyword of DANGEROUS_KEYWORDS) {
      const patterns = [
        new RegExp(`\\b${keyword}\\s*\\(`, 'i'),
        new RegExp(`\\.${keyword}\\b`, 'i'),
        new RegExp(`\\b${keyword}\\s*:`, 'i'),
        new RegExp(`\\b${keyword}\\s*\\[`, 'i'),
      ];

      for (const pattern of patterns) {
        pattern.lastIndex = 0;
        if (pattern.test(normalizedScript)) {
          Logger.warn(this.TAG, `检测到危险关键字: ${keyword}`);
          return {
            valid: false,
            error: `检测到危险关键字: ${keyword}`,
            threat: keyword,
            severity: 'high'
          };
        }
      }
    }

    return { valid: true };
  }

  /**
   * 检查禁止的标识符
   */
  private checkForbiddenIdentifiers(script: string): SecurityValidationResult {
    for (const forbidden of FORBIDDEN_GLOBALS) {
      // 检查直接访问
      const directAccessPattern = new RegExp(`\\b${forbidden}\\b`, 'g');
      if (directAccessPattern.test(script)) {
        Logger.warn(this.TAG, `检测到禁止的标识符: ${forbidden}`);
        return {
          valid: false,
          error: `禁止访问: ${forbidden}`,
          threat: forbidden,
          severity: 'high'
        };
      }
    }

    return { valid: true };
  }

  /**
   * 检查标识符是否在白名单中
   */
  isIdentifierAllowed(name: string): boolean {
    if (SAFE_GLOBALS[name] === true) {
      return true;
    }
    if (this.customSafeGlobals.has(name)) {
      return true;
    }
    return false;
  }

  /**
   * 检查标识符是否被禁止
   */
  isIdentifierForbidden(name: string): boolean {
    return FORBIDDEN_GLOBALS.includes(name);
  }

  /**
   * 获取安全的全局对象列表
   */
  getSafeGlobals(): string[] {
    const result: string[] = Object.keys(SAFE_GLOBALS);
    this.customSafeGlobals.forEach((name: string) => {
      result.push(name);
    });
    return result;
  }

  /**
   * 获取禁止的全局对象列表
   */
  getForbiddenGlobals(): string[] {
    return FORBIDDEN_GLOBALS.slice();
  }

  /**
   * 输入净化
   * 转义特殊字符，防止注入
   */
  sanitizeInput(input: string): string {
    return input
      .replace(/\\/g, '\\\\')
      .replace(/`/g, '\\`')
      .replace(/\$/g, '\\$')
      .replace(/"/g, '\\"')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t')
      .replace(/\0/g, '\\0');
  }

  /**
   * 创建沙箱环境配置
   * 返回用于隔离执行环境的配置对象
   */
  createSandboxConfig(): Record<string, object | Function> {
    const sandbox: Record<string, object | Function> = {};

    // 添加安全的全局对象
    sandbox['JSON'] = JSON;
    sandbox['Math'] = Math;
    sandbox['Date'] = Date;
    sandbox['Array'] = Array;
    sandbox['Object'] = Object;
    sandbox['String'] = String;
    sandbox['Number'] = Number;
    sandbox['Boolean'] = Boolean;
    sandbox['parseInt'] = parseInt;
    sandbox['parseFloat'] = parseFloat;
    sandbox['isNaN'] = isNaN;
    sandbox['isFinite'] = isFinite;
    sandbox['encodeURIComponent'] = encodeURIComponent;
    sandbox['decodeURIComponent'] = decodeURIComponent;
    sandbox['encodeURI'] = encodeURI;
    sandbox['decodeURI'] = decodeURI;

    // 创建安全的 console
    const safeConsole: SandboxConsole = {
      log: () => {},
      warn: () => {},
      error: () => {},
      info: () => {},
      debug: () => {},
    };
    sandbox['console'] = safeConsole;

    return sandbox;
  }

  /**
   * 创建执行超时控制
   */
  createTimeoutController(timeoutMs?: number): TimeoutController {
    const startTime = Date.now();
    const timeout = timeoutMs ?? this.config.maxExecutionTime;

    const controller: TimeoutController = {
      check: () => Date.now() - startTime > timeout,
      remaining: () => Math.max(0, timeout - (Date.now() - startTime)),
      startTime: startTime
    };
    return controller;
  }

  /**
   * 重置实例（用于测试）
   */
  static resetInstance(): void {
    JSSecurityConfig.instance = null;
  }
}

export default JSSecurityConfig.getInstance();
