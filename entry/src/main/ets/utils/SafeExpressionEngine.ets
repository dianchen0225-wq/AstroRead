/**
 * SafeExpressionEngine - 安全表达式引擎
 * 不使用 eval 或 new Function()，通过解析器实现表达式计算
 * 支持 HarmonyOS 安全沙箱环境
 */

import { Logger } from './Logger';
import { util } from '@kit.ArkTS';

export interface ExpressionContext {
  key?: string;
  page?: number;
  baseUrl?: string;
  result?: string;
}

interface Token {
  type: 'string' | 'number' | 'variable' | 'operator' | 'function' | 'paren' | 'dot' | 'comma' | 'bracket';
  value: string | number;
}

type SafeFunction = (args: (string | number | boolean | object | null)[]) => string | number | boolean | object | null;

export class SafeExpressionEngine {
  private static instance: SafeExpressionEngine | null = null;
  private readonly TAG = 'SafeExpressionEngine';

  private functions: Map<string, SafeFunction> = new Map();

  private constructor() {
    this.registerBuiltInFunctions();
  }

  static getInstance(): SafeExpressionEngine {
    if (!SafeExpressionEngine.instance) {
      SafeExpressionEngine.instance = new SafeExpressionEngine();
    }
    return SafeExpressionEngine.instance;
  }

  private registerBuiltInFunctions(): void {
    this.functions.set('encodeURI', (args) => {
      return encodeURI(String(args[0] ?? ''));
    });

    this.functions.set('decodeURI', (args) => {
      return decodeURI(String(args[0] ?? ''));
    });

    this.functions.set('encodeURIComponent', (args) => {
      return encodeURIComponent(String(args[0] ?? ''));
    });

    this.functions.set('decodeURIComponent', (args) => {
      return decodeURIComponent(String(args[0] ?? ''));
    });

    this.functions.set('parseInt', (args) => {
      return parseInt(String(args[0] ?? '0'), (args[1] as number) || 10);
    });

    this.functions.set('parseFloat', (args) => {
      return parseFloat(String(args[0] ?? '0'));
    });

    this.functions.set('String', (args) => {
      return String(args[0] ?? '');
    });

    this.functions.set('Number', (args) => {
      return Number(args[0] ?? 0);
    });

    this.functions.set('Boolean', (args) => {
      return Boolean(args[0]);
    });

    this.functions.set('JSON_stringify', (args) => {
      try {
        return JSON.stringify(args[0]);
      } catch {
        return '';
      }
    });

    this.functions.set('JSON_parse', (args): string | number | boolean | object | null => {
      try {
        const parsed = JSON.parse(String(args[0] ?? '{}')) as string | number | boolean | object | null;
        return parsed;
      } catch {
        return null;
      }
    });

    this.functions.set('String2', (args) => {
      const val = args[0];
      return val === null || val === undefined ? '' : String(val);
    });

    this.functions.set('Number2', (args) => {
      return Number(args[0]) || 0;
    });

    this.functions.set('Boolean2', (args) => {
      return Boolean(args[0]);
    });

    this.functions.set('tzs', (args) => {
      return String(args[0] ?? '');
    });

    this.functions.set('replace', (args) => {
      const str = String(args[0] ?? '');
      const pattern = String(args[1] ?? '');
      const replacement = String(args[2] ?? '');
      try {
        const regex = new RegExp(pattern, 'g');
        return str.replace(regex, replacement);
      } catch {
        return str;
      }
    });

    this.functions.set('match', (args) => {
      const str = String(args[0] ?? '');
      const pattern = String(args[1] ?? '');
      try {
        const regex = new RegExp(pattern);
        const match = str.match(regex);
        return match ? match[0] : '';
      } catch {
        return '';
      }
    });

    this.functions.set('matchAll', (args) => {
      const str = String(args[0] ?? '');
      const pattern = String(args[1] ?? '');
      try {
        const regex = new RegExp(pattern, 'g');
        const matches = str.match(regex);
        return matches || [];
      } catch {
        return [];
      }
    });

    this.functions.set('split', (args) => {
      const str = String(args[0] ?? '');
      const separator = String(args[1] ?? ',');
      return str.split(separator);
    });

    this.functions.set('join', (args) => {
      const arr = args[0];
      const separator = String(args[1] ?? ',');
      if (Array.isArray(arr)) {
        return arr.join(separator);
      }
      return String(arr);
    });

    this.functions.set('trim', (args) => {
      return String(args[0] ?? '').trim();
    });

    this.functions.set('toLowerCase', (args) => {
      return String(args[0] ?? '').toLowerCase();
    });

    this.functions.set('toUpperCase', (args) => {
      return String(args[0] ?? '').toUpperCase();
    });

    this.functions.set('substring', (args) => {
      const str = String(args[0] ?? '');
      const start = Number(args[1]) || 0;
      const end = args[2] !== undefined ? Number(args[2]) : undefined;
      return end !== undefined ? str.substring(start, end) : str.substring(start);
    });

    this.functions.set('substr', (args) => {
      const str = String(args[0] ?? '');
      const start = Number(args[1]) || 0;
      const length = args[2] !== undefined ? Number(args[2]) : undefined;
      return length !== undefined ? str.substr(start, length) : str.substr(start);
    });

    this.functions.set('charAt', (args) => {
      const str = String(args[0] ?? '');
      const index = Number(args[1]) || 0;
      return str.charAt(index);
    });

    this.functions.set('indexOf', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      return str.indexOf(search);
    });

    this.functions.set('lastIndexOf', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      return str.lastIndexOf(search);
    });

    this.functions.set('startsWith', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      return str.startsWith(search);
    });

    this.functions.set('endsWith', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      return str.endsWith(search);
    });

    this.functions.set('includes', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      return str.includes(search);
    });

    this.functions.set('length', (args) => {
      const val = args[0];
      if (typeof val === 'string') return val.length;
      if (Array.isArray(val)) return val.length;
      return 0;
    });

    this.functions.set('Math_floor', (args) => {
      return Math.floor(Number(args[0]) || 0);
    });

    this.functions.set('Math_ceil', (args) => {
      return Math.ceil(Number(args[0]) || 0);
    });

    this.functions.set('Math_round', (args) => {
      return Math.round(Number(args[0]) || 0);
    });

    this.functions.set('Math_abs', (args) => {
      return Math.abs(Number(args[0]) || 0);
    });

    this.functions.set('Math_min', (args) => {
      return Math.min(...args.map(a => Number(a) || 0));
    });

    this.functions.set('Math_max', (args) => {
      return Math.max(...args.map(a => Number(a) || 0));
    });

    this.functions.set('Math_random', () => {
      return Math.random();
    });

    this.functions.set('Math_pow', (args) => {
      return Math.pow(Number(args[0]) || 0, Number(args[1]) || 0);
    });

    this.functions.set('Math_sqrt', (args) => {
      return Math.sqrt(Number(args[0]) || 0);
    });

    this.functions.set('base64Encode', (args) => {
      try {
        const str = String(args[0] ?? '');
        const encoder = new util.TextEncoder();
        const uint8Array = encoder.encodeInto(str);
        const base64 = new util.Base64Helper();
        return base64.encodeToStringSync(uint8Array);
      } catch {
        return String(args[0] ?? '');
      }
    });

    this.functions.set('base64Decode', (args) => {
      try {
        const str = String(args[0] ?? '');
        const base64 = new util.Base64Helper();
        const uint8Array = base64.decodeSync(str);
        const decoder = new util.TextDecoder('utf-8');
        return decoder.decodeToString(uint8Array);
      } catch {
        return String(args[0] ?? '');
      }
    });
  }

  evaluate(expression: string, context: ExpressionContext = {}): string | number | boolean | object | null {
    try {
      const trimmed = expression.trim();
      
      if (trimmed === '') {
        return '';
      }

      if (this.isSimpleString(trimmed)) {
        return this.replaceVariables(trimmed, context);
      }

      if (this.isSimpleNumber(trimmed)) {
        return Number(trimmed);
      }

      if (this.isSimpleVariable(trimmed)) {
        return this.getVariable(trimmed, context);
      }

      if (this.isTemplateString(trimmed)) {
        return this.evaluateTemplateString(trimmed, context);
      }

      if (this.isSimpleExpression(trimmed)) {
        return this.evaluateSimpleExpression(trimmed, context);
      }

      return this.evaluateComplexExpression(trimmed, context);
    } catch (error) {
      Logger.error(this.TAG, `表达式求值失败: ${expression}, 错误: ${error}`);
      return '';
    }
  }

  evaluateAsString(expression: string, context: ExpressionContext = {}): string {
    const result = this.evaluate(expression, context);
    if (result === null) return '';
    if (typeof result === 'string') return result;
    if (typeof result === 'number' || typeof result === 'boolean') return String(result);
    if (Array.isArray(result)) return result.join('');
    try {
      return JSON.stringify(result);
    } catch {
      return '';
    }
  }

  private isSimpleString(expr: string): boolean {
    return (expr.startsWith("'") && expr.endsWith("'")) ||
           (expr.startsWith('"') && expr.endsWith('"'));
  }

  private isSimpleNumber(expr: string): boolean {
    return /^-?\d+(\.\d+)?$/.test(expr);
  }

  private isSimpleVariable(expr: string): boolean {
    return /^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(expr);
  }

  private isTemplateString(expr: string): boolean {
    return expr.includes('{{') && expr.includes('}}');
  }

  private isSimpleExpression(expr: string): boolean {
    const simplePattern = /^[a-zA-Z_$][a-zA-Z0-9_$]*\s*[+\-*/]\s*('[^']*'|"[^"]*"|\d+|[a-zA-Z_$][a-zA-Z0-9_$]*)$/;
    return simplePattern.test(expr) || /^[a-zA-Z_$][a-zA-Z0-9_$]*\([^)]*\)$/.test(expr);
  }

  private replaceVariables(str: string, context: ExpressionContext): string {
    let result = str;
    
    if (context.key !== undefined) {
      result = result.replace(/\{\{key\}\}/g, context.key);
      result = result.replace(/\bkey\b/g, context.key);
    }
    
    if (context.page !== undefined) {
      result = result.replace(/\{\{page\}\}/g, String(context.page));
      result = result.replace(/\bpage\b/g, String(context.page));
    }
    
    if (context.baseUrl !== undefined) {
      result = result.replace(/\{\{baseUrl\}\}/g, context.baseUrl);
      result = result.replace(/\bbaseUrl\b/g, context.baseUrl);
    }
    
    if (context.result !== undefined) {
      result = result.replace(/\{\{result\}\}/g, context.result);
      result = result.replace(/\bresult\b/g, context.result);
    }

    return result;
  }

  private getVariable(name: string, context: ExpressionContext): string | number | boolean | object | null {
    switch (name) {
      case 'key':
        return context.key ?? '';
      case 'page':
        return context.page ?? 1;
      case 'baseUrl':
        return context.baseUrl ?? '';
      case 'result':
        return context.result ?? '';
      default:
        return '';
    }
  }

  private evaluateTemplateString(expr: string, context: ExpressionContext): string {
    return expr.replace(/\{\{([^}]+)\}\}/g, (match: string, inner: string) => {
      const value = this.evaluate(inner.trim(), context);
      return String(value ?? '');
    });
  }

  private evaluateSimpleExpression(expr: string, context: ExpressionContext): string | number | boolean | object | null {
    const funcMatch = expr.match(/^([a-zA-Z_$][a-zA-Z0-9_$]*)\(([^)]*)\)$/);
    if (funcMatch) {
      const funcName = funcMatch[1];
      const argsStr = funcMatch[2];
      return this.callFunction(funcName, argsStr, context);
    }

    const binaryMatch = expr.match(/^([a-zA-Z_$][a-zA-Z0-9_$]*)\s*([+\-*/])\s*(.+)$/);
    if (binaryMatch) {
      const left = this.getVariable(binaryMatch[1], context);
      const op = binaryMatch[2];
      const rightStr = binaryMatch[3].trim();
      const right = this.isSimpleNumber(rightStr) ? Number(rightStr) :
                    this.isSimpleString(rightStr) ? this.replaceVariables(rightStr, context) :
                    this.getVariable(rightStr, context);
      
      return this.applyBinaryOp(Number(left) || 0, op, Number(right) || 0);
    }

    return '';
  }

  private evaluateComplexExpression(expr: string, context: ExpressionContext): string | number | boolean | object | null {
    const tokens = this.tokenize(expr);
    return this.evaluateTokens(tokens, context);
  }

  private tokenize(expr: string): Token[] {
    const tokens: Token[] = [];
    let i = 0;

    while (i < expr.length) {
      const char = expr[i];

      if (/\s/.test(char)) {
        i++;
        continue;
      }

      if (char === "'" || char === '"') {
        const quote = char;
        let str = '';
        i++;
        while (i < expr.length && expr[i] !== quote) {
          if (expr[i] === '\\' && i + 1 < expr.length) {
            str += expr[i + 1];
            i += 2;
          } else {
            str += expr[i];
            i++;
          }
        }
        i++;
        tokens.push({ type: 'string', value: str });
        continue;
      }

      if (/\d/.test(char) || (char === '-' && i + 1 < expr.length && /\d/.test(expr[i + 1]))) {
        let num = '';
        if (char === '-') {
          num += char;
          i++;
        }
        while (i < expr.length && /[\d.]/.test(expr[i])) {
          num += expr[i];
          i++;
        }
        tokens.push({ type: 'number', value: Number(num) });
        continue;
      }

      if (/[a-zA-Z_$]/.test(char)) {
        let name = '';
        while (i < expr.length && /[a-zA-Z0-9_$]/.test(expr[i])) {
          name += expr[i];
          i++;
        }
        
        if (expr[i] === '(') {
          tokens.push({ type: 'function', value: name });
        } else {
          tokens.push({ type: 'variable', value: name });
        }
        continue;
      }

      if (char === '(' || char === ')') {
        tokens.push({ type: 'paren', value: char });
        i++;
        continue;
      }

      if (char === '[' || char === ']') {
        tokens.push({ type: 'bracket', value: char });
        i++;
        continue;
      }

      if (char === '.') {
        tokens.push({ type: 'dot', value: '.' });
        i++;
        continue;
      }

      if (char === ',') {
        tokens.push({ type: 'comma', value: ',' });
        i++;
        continue;
      }

      if (/[+\-*/%]/.test(char)) {
        tokens.push({ type: 'operator', value: char });
        i++;
        continue;
      }

      i++;
    }

    return tokens;
  }

  private evaluateTokens(tokens: Token[], context: ExpressionContext): string | number | boolean | object | null {
    if (tokens.length === 0) return '';

    let pos = 0;

    const parseValue = (): string | number | boolean | object | null => {
      const token = tokens[pos];
      
      if (!token) return null;

      if (token.type === 'string') {
        pos++;
        return this.replaceVariables(String(token.value), context);
      }

      if (token.type === 'number') {
        pos++;
        return token.value as number;
      }

      if (token.type === 'variable') {
        pos++;
        return this.getVariable(String(token.value), context);
      }

      if (token.type === 'function') {
        return parseFunctionCall();
      }

      if (token.type === 'paren' && token.value === '(') {
        pos++;
        const value = parseExpression();
        if (tokens[pos]?.type === 'paren' && tokens[pos].value === ')') {
          pos++;
        }
        return value;
      }

      return null;
    };

    const parseFunctionCall = (): string | number | boolean | object | null => {
      const funcToken = tokens[pos];
      pos++;

      if (tokens[pos]?.type === 'paren' && tokens[pos].value === '(') {
        pos++;
      }

      const args: (string | number | boolean | object | null)[] = [];
      
      while (pos < tokens.length && !(tokens[pos].type === 'paren' && tokens[pos].value === ')')) {
        if (tokens[pos].type === 'comma') {
          pos++;
          continue;
        }
        args.push(parseValue());
      }

      if (tokens[pos]?.type === 'paren' && tokens[pos].value === ')') {
        pos++;
      }

      return this.executeFunction(String(funcToken.value), args);
    };

    const parseExpression = (): string | number | boolean | object | null => {
      let left = parseValue();

      while (pos < tokens.length && tokens[pos].type === 'operator') {
        const op = String(tokens[pos].value);
        pos++;
        const right = parseValue();
        left = this.applyBinaryOp(Number(left) || 0, op, Number(right) || 0);
      }

      return left;
    };

    return parseExpression();
  }

  private callFunction(funcName: string, argsStr: string, context: ExpressionContext): string | number | boolean | object | null {
    const args: (string | number | boolean | object | null)[] = [];
    
    if (argsStr.trim()) {
      const argParts = this.splitArgs(argsStr);
      for (const part of argParts) {
        const trimmed = part.trim();
        if (this.isSimpleString(trimmed)) {
          args.push(this.replaceVariables(trimmed.slice(1, -1), context));
        } else if (this.isSimpleNumber(trimmed)) {
          args.push(Number(trimmed));
        } else if (this.isSimpleVariable(trimmed)) {
          args.push(this.getVariable(trimmed, context));
        } else {
          args.push(this.evaluate(trimmed, context));
        }
      }
    }

    return this.executeFunction(funcName, args);
  }

  private splitArgs(argsStr: string): string[] {
    const args: string[] = [];
    let current = '';
    let depth = 0;
    let inString = false;
    let stringChar = '';

    for (let i = 0; i < argsStr.length; i++) {
      const char = argsStr[i];

      if (!inString && (char === "'" || char === '"')) {
        inString = true;
        stringChar = char;
        current += char;
      } else if (inString && char === stringChar) {
        inString = false;
        current += char;
      } else if (!inString && char === '(') {
        depth++;
        current += char;
      } else if (!inString && char === ')') {
        depth--;
        current += char;
      } else if (!inString && char === ',' && depth === 0) {
        args.push(current);
        current = '';
      } else {
        current += char;
      }
    }

    if (current) {
      args.push(current);
    }

    return args;
  }

  private executeFunction(funcName: string, args: (string | number | boolean | object | null)[]): string | number | boolean | object | null {
    const normalizedName = funcName.replace(/\./g, '_');
    
    const func = this.functions.get(normalizedName);
    if (func) {
      return func(args);
    }

    Logger.warn(this.TAG, `未知函数: ${funcName}`);
    return '';
  }

  private applyBinaryOp(left: number, op: string, right: number): number {
    switch (op) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        return right !== 0 ? left / right : 0;
      case '%':
        return right !== 0 ? left % right : 0;
      default:
        return left;
    }
  }

  registerFunction(name: string, func: SafeFunction): void {
    this.functions.set(name.replace(/\./g, '_'), func);
  }

  hasFunction(name: string): boolean {
    return this.functions.has(name.replace(/\./g, '_'));
  }
}

export default SafeExpressionEngine.getInstance();
