import { Logger } from "../performance/Logger";
import { util } from '@kit.ArkTS';
import { SafeRegex } from "../security/SafeRegex";
import { JSSecurityConfig } from "../security/JSSecurityConfig";

export interface ScriptContext {
  key?: string;
  page?: number;
  baseUrl?: string;
  result?: string;
  extra?: Map<string, string | number | boolean | object | null | undefined>;
}

type ScriptValue = string | number | boolean | object | null | undefined;

interface Token {
  type: 'keyword' | 'identifier' | 'number' | 'string' | 'operator' | 'punctuation' | 'boolean' | 'null';
  value: string | number | boolean | null;
  line?: number;
  column?: number;
}

interface ASTNode {
  type: string;
  // Literal values
  value?: string | number | boolean | ASTNode | null;
  // Identifier
  name?: string;
  // Program/BlockStatement/Block
  body?: ASTNode | ASTNode[];
  // Function params
  params?: ASTNode[] | string[];
  // Binary/Logical expressions
  left?: ASTNode;
  right?: ASTNode;
  operator?: string;
  // Call expression
  arguments?: ASTNode[];
  callee?: ASTNode;
  // Object expression
  properties?: ASTNode[];
  // Property
  key?: ASTNode | string;
  // VariableDeclaration
  kind?: string;
  declarations?: ASTNode[];
  // VariableDeclarator/ForStatement
  id?: ASTNode;
  init?: ASTNode;
  // IfStatement/ConditionalExpression
  test?: ASTNode;
  consequent?: ASTNode;
  alternate?: ASTNode;
  // ForStatement
  update?: ASTNode;
  // MemberExpression
  object?: ASTNode;
  property?: ASTNode;
  computed?: boolean;
  // ReturnStatement
  argument?: ASTNode;
  // UnaryExpression/UpdateExpression
  prefix?: boolean;
  // ArrayExpression
  elements?: (ASTNode | null)[];
  // TryStatement
  block?: ASTNode;
  handler?: ASTNode;
  finalizer?: ASTNode;
  // CatchClause
  param?: ASTNode;
  // ExpressionStatement
  expression?: ASTNode;
}

class ScriptControlFlow extends Error {
  controlType: 'Return' | 'Break' | 'Continue';
  controlValue: ScriptValue;

  constructor(type: 'Return' | 'Break' | 'Continue', value: ScriptValue = undefined) {
    super(type);
    this.controlType = type;
    this.controlValue = value;
  }
}

export class ScriptEngine {
  private static instance: ScriptEngine | null = null;
  private readonly TAG = 'ScriptEngine';
  private variables: Map<string, ScriptValue> = new Map();
  private functions: Map<string, (args: ScriptValue[]) => ScriptValue> = new Map();
  private builtInFunctions: Map<string, (args: ScriptValue[]) => ScriptValue> = new Map();
  private executionTimedOut: boolean = false;
  private executionStartTime: number = 0;
  private maxLoopIterations: number = 1000;
  private securityConfig: JSSecurityConfig;

  private constructor() {
    this.securityConfig = JSSecurityConfig.getInstance();
    this.initializeBuiltInFunctions();
  }

  static getInstance(): ScriptEngine {
    if (!ScriptEngine.instance) {
      ScriptEngine.instance = new ScriptEngine();
    }
    return ScriptEngine.instance;
  }

  private initializeBuiltInFunctions(): void {
    this.builtInFunctions.set('log', (args) => {
      Logger.info(this.TAG, args.map(arg => String(arg)).join(' '));
      return undefined;
    });

    this.builtInFunctions.set('print', (args) => {
      return args.map(arg => String(arg)).join(' ');
    });

    this.builtInFunctions.set('concat', (args) => {
      return args.map(arg => String(arg)).join('');
    });

    this.builtInFunctions.set('match', (args) => {
      const str = String(args[0] ?? '');
      const pattern = String(args[1] ?? '');
      try {
        const regex = SafeRegex.create(pattern, 'g');
        const matches = regex.execute(str);
        return matches.length > 0 ? matches : null;
      } catch {
        return null;
      }
    });

    this.builtInFunctions.set('matchGroup', (args) => {
      const str = String(args[0] ?? '');
      const pattern = String(args[1] ?? '');
      const groupIndex = Number(args[2] ?? 0);
      try {
        const regex = SafeRegex.create(pattern);
        const match = regex.exec(str);
        return match && match[groupIndex] ? match[groupIndex] : '';
      } catch {
        return '';
      }
    });

    this.builtInFunctions.set('replace', (args) => {
      const str = String(args[0] ?? '');
      const pattern = String(args[1] ?? '');
      const replacement = String(args[2] ?? '');
      try {
        const regex = SafeRegex.create(pattern, 'g');
        return str.replace(regex.getPattern(), replacement);
      } catch {
        return str;
      }
    });

    this.builtInFunctions.set('split', (args) => {
      const str = String(args[0] ?? '');
      const separator = String(args[1] ?? ',');
      return str.split(separator);
    });

    this.builtInFunctions.set('join', (args: ScriptValue[]) => {
      const firstArg = args[0];
      const arr = Array.isArray(firstArg) ? firstArg as string[] : [];
      const separator = String(args[1] ?? ',');
      return arr.join(separator);
    });

    this.builtInFunctions.set('substring', (args) => {
      const str = String(args[0] ?? '');
      const start = Number(args[1] ?? 0);
      const end = Number(args[2] ?? str.length);
      return str.substring(start, end);
    });

    this.builtInFunctions.set('indexOf', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      return str.indexOf(search);
    });

    this.builtInFunctions.set('length', (args) => {
      const val = args[0];
      if (typeof val === 'string') return val.length;
      if (Array.isArray(val)) return val.length;
      return 0;
    });

    this.builtInFunctions.set('parseInt', (args) => {
      return parseInt(String(args[0] ?? '0'), Number(args[1] ?? 10));
    });

    this.builtInFunctions.set('parseFloat', (args) => {
      return parseFloat(String(args[0] ?? '0'));
    });

    this.builtInFunctions.set('JSON_stringify', (args) => {
      try {
        return JSON.stringify(args[0]);
      } catch {
        return '';
      }
    });

    this.builtInFunctions.set('JSON_parse', (args): ScriptValue => {
      try {
        return JSON.parse(String(args[0] ?? '{}'));
      } catch {
        return null;
      }
    });

    this.builtInFunctions.set('base64Encode', (args) => {
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

    this.builtInFunctions.set('base64Decode', (args) => {
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

    this.builtInFunctions.set('String2', (args) => {
      const val = args[0];
      return val === null || val === undefined ? '' : String(val);
    });

    this.builtInFunctions.set('tzs', (args) => {
      return String(args[0] ?? '');
    });

    this.builtInFunctions.set('replace', (args) => {
      const str = String(args[0] ?? '');
      const search = String(args[1] ?? '');
      const replacement = String(args[2] ?? '');
      return str.split(search).join(replacement);
    });

    this.builtInFunctions.set('trim', (args) => {
      return String(args[0] ?? '').trim();
    });

    this.builtInFunctions.set('toLowerCase', (args) => {
      return String(args[0] ?? '').toLowerCase();
    });

    this.builtInFunctions.set('toUpperCase', (args) => {
      return String(args[0] ?? '').toUpperCase();
    });

    this.builtInFunctions.set('get', (args) => {
      const obj = args[0];
      const key = String(args[1] ?? '');
      if (obj && typeof obj === 'object') {
        return (obj as Record<string, ScriptValue>)[key];
      }
      return undefined;
    });

    this.builtInFunctions.set('set', (args) => {
      const obj = args[0];
      const key = String(args[1] ?? '');
      const value = args[2];
      if (obj && typeof obj === 'object') {
        (obj as Record<string, ScriptValue>)[key] = value;
      }
      return obj;
    });

    this.builtInFunctions.set('keys', (args) => {
      const obj = args[0];
      if (obj && typeof obj === 'object') {
        return Object.keys(obj);
      }
      return [];
    });

    this.builtInFunctions.set('values', (args) => {
      const obj = args[0];
      if (obj && typeof obj === 'object') {
        return Object.values(obj);
      }
      return [];
    });

    this.builtInFunctions.set('entries', (args) => {
      const obj = args[0];
      if (obj && typeof obj === 'object') {
        return Object.entries(obj);
      }
      return [];
    });

    this.builtInFunctions.set('push', (args: ScriptValue[]): ScriptValue => {
      const firstArg = args[0];
      const arr = Array.isArray(firstArg) ? firstArg as ScriptValue[] : [];
      const item = args[1];
      arr.push(item);
      return arr;
    });

    this.builtInFunctions.set('pop', (args: ScriptValue[]): ScriptValue => {
      const firstArg = args[0];
      const arr = Array.isArray(firstArg) ? firstArg as ScriptValue[] : [];
      return arr.pop();
    });

    this.builtInFunctions.set('shift', (args: ScriptValue[]): ScriptValue => {
      const firstArg = args[0];
      const arr = Array.isArray(firstArg) ? firstArg as ScriptValue[] : [];
      return arr.shift();
    });

    this.builtInFunctions.set('unshift', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const item = args[1];
      arr.unshift(item);
      return arr;
    });

    this.builtInFunctions.set('slice', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const start = Number(args[1] ?? 0);
      const end = Number(args[2] ?? arr.length);
      return arr.slice(start, end);
    });

    this.builtInFunctions.set('splice', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const start = Number(args[1] ?? 0);
      const deleteCount = Number(args[2] ?? 0);
      const items = args.slice(3);
      return arr.splice(start, deleteCount, ...items);
    });

    this.builtInFunctions.set('filter', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => boolean;
        const result: ScriptValue[] = [];
        for (let i = 0; i < arr.length; i++) {
          if (fn([arr[i], i, arr])) {
            result.push(arr[i]);
          }
        }
        return result;
      }
      return arr;
    });

    this.builtInFunctions.set('map', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => ScriptValue;
        const result: ScriptValue[] = [];
        for (let i = 0; i < arr.length; i++) {
          result.push(fn([arr[i], i, arr]));
        }
        return result;
      }
      return arr;
    });

    this.builtInFunctions.set('reduce', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      const initialValue = args[2];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => ScriptValue;
        let acc: ScriptValue = initialValue;
        for (let i = 0; i < arr.length; i++) {
          acc = fn([acc, arr[i], i, arr]);
        }
        return acc;
      }
      return initialValue;
    });

    this.builtInFunctions.set('find', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => boolean;
        for (let i = 0; i < arr.length; i++) {
          if (fn([arr[i], i, arr])) {
            return arr[i];
          }
        }
      }
      return undefined;
    });

    this.builtInFunctions.set('findIndex', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => boolean;
        for (let i = 0; i < arr.length; i++) {
          if (fn([arr[i], i, arr])) {
            return i;
          }
        }
      }
      return -1;
    });

    this.builtInFunctions.set('some', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => boolean;
        for (let i = 0; i < arr.length; i++) {
          if (fn([arr[i], i, arr])) {
            return true;
          }
        }
      }
      return false;
    });

    this.builtInFunctions.set('every', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const fn = callback as (a: ScriptValue[]) => boolean;
        for (let i = 0; i < arr.length; i++) {
          if (!fn([arr[i], i, arr])) {
            return false;
          }
        }
      }
      return true;
    });

    this.builtInFunctions.set('includes', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const item = args[1];
      return arr.includes(item);
    });

    this.builtInFunctions.set('indexOf', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const item = args[1];
      return arr.indexOf(item);
    });

    this.builtInFunctions.set('lastIndexOf', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const item = args[1];
      return arr.lastIndexOf(item);
    });

    this.builtInFunctions.set('reverse', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      return arr.reverse();
    });

    this.builtInFunctions.set('sort', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const compareFn = args[1];
      if (typeof compareFn === 'function') {
        const fn = compareFn as (a: ScriptValue[]) => number;
        return arr.sort((a: ScriptValue, b: ScriptValue): number => {
          return fn([a, b]);
        });
      }
      return arr.sort();
    });

    this.builtInFunctions.set('flat', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const depth = Number(args[1] ?? 1);
      return arr.flat(depth);
    });

    this.builtInFunctions.set('flatMap', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const callback = args[1];
      if (typeof callback === 'function') {
        const result: ScriptValue[] = [];
        for (let i = 0; i < arr.length; i++) {
          const item: ScriptValue = arr[i];
          const mapped = (callback as (a: ScriptValue[]) => ScriptValue | ScriptValue[])([item, i, arr]);
          if (Array.isArray(mapped)) {
            const mappedArr = mapped as ScriptValue[];
            for (let j = 0; j < mappedArr.length; j++) {
              result.push(mappedArr[j]);
            }
          } else {
            result.push(mapped);
          }
        }
        return result;
      }
      return arr;
    });

    this.builtInFunctions.set('fill', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const value = args[1];
      const start = Number(args[2] ?? 0);
      const end = Number(args[3] ?? arr.length);
      return arr.fill(value, start, end);
    });

    this.builtInFunctions.set('copyWithin', (args) => {
      const arr: ScriptValue[] = Array.isArray(args[0]) ? args[0] as ScriptValue[] : [];
      const target = Number(args[1] ?? 0);
      const start = Number(args[2] ?? 0);
      const end = Number(args[3] ?? arr.length);
      return arr.copyWithin(target, start, end);
    });

    this.builtInFunctions.set('from', (args) => {
      const iterable = args[0];
      const mapFn = args[1];
      if (Array.isArray(iterable)) {
        const arr = iterable as ScriptValue[];
        if (typeof mapFn === 'function') {
          const result: ScriptValue[] = [];
          for (let i = 0; i < arr.length; i++) {
            const item: ScriptValue = arr[i];
            const mappedValue: ScriptValue = (mapFn as (a: ScriptValue[]) => ScriptValue)([item, i]);
            result.push(mappedValue);
          }
          return result;
        }
        return [...arr];
      }
      return [];
    });

    this.builtInFunctions.set('of', (args) => {
      return args;
    });

    this.builtInFunctions.set('isArray', (args) => {
      return Array.isArray(args[0]);
    });

    this.builtInFunctions.set('abs', (args) => {
      return Math.abs(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('ceil', (args) => {
      return Math.ceil(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('floor', (args) => {
      return Math.floor(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('round', (args) => {
      return Math.round(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('max', (args) => {
      return Math.max(...args.map(arg => Number(arg ?? 0)));
    });

    this.builtInFunctions.set('min', (args) => {
      return Math.min(...args.map(arg => Number(arg ?? 0)));
    });

    this.builtInFunctions.set('pow', (args) => {
      return Math.pow(Number(args[0] ?? 0), Number(args[1] ?? 0));
    });

    this.builtInFunctions.set('sqrt', (args) => {
      return Math.sqrt(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('cbrt', (args) => {
      return Math.cbrt(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('random', (args) => {
      return Math.random();
    });

    this.builtInFunctions.set('sign', (args) => {
      return Math.sign(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('trunc', (args) => {
      return Math.trunc(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('sin', (args) => {
      return Math.sin(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('cos', (args) => {
      return Math.cos(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('tan', (args) => {
      return Math.tan(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('asin', (args) => {
      return Math.asin(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('acos', (args) => {
      return Math.acos(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('atan', (args) => {
      return Math.atan(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('atan2', (args) => {
      return Math.atan2(Number(args[0] ?? 0), Number(args[1] ?? 0));
    });

    this.builtInFunctions.set('exp', (args) => {
      return Math.exp(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('log', (args) => {
      return Math.log(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('log10', (args) => {
      return Math.log10(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('log2', (args) => {
      return Math.log2(Number(args[0] ?? 0));
    });

    this.builtInFunctions.set('PI', () => {
      return Math.PI;
    });

    this.builtInFunctions.set('E', () => {
      return Math.E;
    });

    this.builtInFunctions.set('LN2', () => {
      return Math.LN2;
    });

    this.builtInFunctions.set('LN10', () => {
      return Math.LN10;
    });

    this.builtInFunctions.set('LOG2E', () => {
      return Math.LOG2E;
    });

    this.builtInFunctions.set('LOG10E', () => {
      return Math.LOG10E;
    });

    this.builtInFunctions.set('SQRT1_2', () => {
      return Math.SQRT1_2;
    });

    this.builtInFunctions.set('SQRT2', () => {
      return Math.SQRT2;
    });
  }

  execute(script: string, context: ScriptContext = {}): ScriptValue {
    try {
      // 使用统一的安全配置检查脚本
      const validationResult = this.securityConfig.validateScript(script);
      if (!validationResult.valid) {
        const errorMsg = validationResult.error ?? 'Unknown validation error';
        Logger.error(this.TAG, `Script validation failed: ${errorMsg}`);
        return '';
      }

      this.variables.clear();
      this.executionTimedOut = false;
      this.executionStartTime = Date.now();
      
      // 安全地注入上下文变量
      const contextKeys = Object.keys(context);
      for (let i = 0; i < contextKeys.length; i++) {
        const key = contextKeys[i];
        const value = (context as Record<string, ScriptValue>)[key];
        // 使用统一的安全配置检查禁止的标识符
        if (this.securityConfig.isIdentifierForbidden(key)) {
          Logger.warn(this.TAG, `禁止注入的危险变量名: ${key}`);
          continue;
        }
        this.variables.set(key, value);
      }

      const tokens = this.tokenize(script);
      const ast = this.parse(tokens);
      
      return this.evaluate(ast);
    } catch (error) {
      if (this.executionTimedOut) {
        const config = this.securityConfig.getConfig();
        Logger.error(this.TAG, `Script execution timed out after ${config.maxExecutionTime}ms`);
        return '';
      }
      Logger.error(this.TAG, `Script execution failed: ${error}`);
      return '';
    }
  }

  executeWithTimeout(script: string, context: ScriptContext = {}, timeoutMs?: number): Promise<ScriptValue> {
    const config = this.securityConfig.getConfig();
    const actualTimeout = timeoutMs ?? config.maxExecutionTime;
    
    return new Promise((resolve) => {
      const timeoutId = setTimeout(() => {
        this.executionTimedOut = true;
        Logger.warn(this.TAG, `Script execution timed out after ${actualTimeout}ms`);
        resolve('');
      }, actualTimeout);
      
      try {
        const result = this.execute(script, context);
        clearTimeout(timeoutId);
        resolve(result);
      } catch (e) {
        clearTimeout(timeoutId);
        resolve('');
      }
    });
  }

  executeAsString(script: string, context: ScriptContext = {}): string {
    const result = this.execute(script, context);
    if (result === null || result === undefined) {
      return '';
    }
    if (typeof result === 'string') {
      return result;
    }
    if (typeof result === 'number' || typeof result === 'boolean') {
      return String(result);
    }
    try {
      return JSON.stringify(result);
    } catch {
      return String(result);
    }
  }

  private checkTimeout(): void {
    const config = this.securityConfig.getConfig();
    if (Date.now() - this.executionStartTime > config.maxExecutionTime) {
      this.executionTimedOut = true;
      throw new Error('Script execution timeout');
    }
  }

  private tokenize(script: string): Token[] {
    const tokens: Token[] = [];
    let i = 0;
    let line = 1;
    let column = 1;

    while (i < script.length) {
      this.checkTimeout();

      const char = script[i];

      // Skip whitespace
      if (/\s/.test(char)) {
        if (char === '\n') {
          line++;
          column = 1;
        } else {
          column++;
        }
        i++;
        continue;
      }

      // Comments
      if (char === '/' && script[i + 1] === '/') {
        while (i < script.length && script[i] !== '\n') {
          i++;
          column++;
        }
        continue;
      }

      if (char === '/' && script[i + 1] === '*') {
        i += 2;
        column += 2;
        while (i < script.length && !(script[i] === '*' && script[i + 1] === '/')) {
          if (script[i] === '\n') {
            line++;
            column = 1;
          } else {
            column++;
          }
          i++;
        }
        i += 2;
        column += 2;
        continue;
      }

      // Strings
      if (char === '"' || char === "'" || char === '`') {
        const quote = char;
        let str = '';
        i++;
        column++;
        while (i < script.length && script[i] !== quote) {
          if (script[i] === '\\') {
            i++;
            column++;
            const escapeChar = script[i];
            switch (escapeChar) {
              case 'n': str += '\n'; break;
              case 't': str += '\t'; break;
              case 'r': str += '\r'; break;
              case '\\': str += '\\'; break;
              case '"': str += '"'; break;
              case "'": str += "'"; break;
              case '`': str += '`'; break;
              default: str += escapeChar;
            }
          } else {
            str += script[i];
          }
          i++;
          column++;
        }
        i++;
        column++;
        tokens.push({ type: 'string', value: str, line, column });
        continue;
      }

      // Numbers
      if (/\d/.test(char) || (char === '.' && /\d/.test(script[i + 1]))) {
        let num = '';
        while (i < script.length && (/\d/.test(script[i]) || script[i] === '.')) {
          num += script[i];
          i++;
          column++;
        }
        tokens.push({ type: 'number', value: parseFloat(num), line, column });
        continue;
      }

      // Identifiers and keywords
      if (/[a-zA-Z_$]/.test(char)) {
        let identifier = '';
        while (i < script.length && /[a-zA-Z0-9_$]/.test(script[i])) {
          identifier += script[i];
          i++;
          column++;
        }

        // Check for keywords
        const keywords = ['if', 'else', 'while', 'for', 'return', 'function', 'var', 'let', 'const', 'true', 'false', 'null', 'undefined', 'break', 'continue', 'try', 'catch', 'finally', 'throw', 'new', 'this', 'typeof', 'instanceof', 'in', 'of'];
        if (keywords.includes(identifier)) {
          if (identifier === 'true') {
            tokens.push({ type: 'boolean', value: true, line, column });
          } else if (identifier === 'false') {
            tokens.push({ type: 'boolean', value: false, line, column });
          } else if (identifier === 'null') {
            tokens.push({ type: 'null', value: null, line, column });
          } else if (identifier === 'undefined') {
            tokens.push({ type: 'null', value: null, line, column });
          } else {
            tokens.push({ type: 'keyword', value: identifier, line, column });
          }
        } else {
          tokens.push({ type: 'identifier', value: identifier, line, column });
        }
        continue;
      }

      const operators = ['===', '!==', '==', '!=', '<=', '>=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '=>'];
      let foundOperator = false;
      for (const op of operators) {
        if (script.substring(i, i + op.length) === op) {
          tokens.push({ type: 'operator', value: op, line, column });
          i += op.length;
          column += op.length;
          foundOperator = true;
          break;
        }
      }
      if (foundOperator) continue;

      // Single character operators and punctuation
      if (/[+\-*/%=<>!&|]/.test(char)) {
        tokens.push({ type: 'operator', value: char, line, column });
        i++;
        column++;
        continue;
      }

      if (/[(){}\[\];:,.]/.test(char)) {
        tokens.push({ type: 'punctuation', value: char, line, column });
        i++;
        column++;
        continue;
      }

      // Unknown character
      i++;
      column++;
    }

    return tokens;
  }

  private parse(tokens: Token[]): ASTNode {
    let pos = 0;

    const peek = (): Token | undefined => tokens[pos];
    const consume = (): Token => tokens[pos++];
    const expect = (type: string, value?: string): Token => {
      const token = peek();
      if (!token || token.type !== type || (value !== undefined && token.value !== value)) {
        throw new Error(`Expected ${type}${value ? ` '${value}'` : ''} but got ${token?.type}${token?.value ? ` '${token.value}'` : ''}`);
      }
      return consume();
    };

    const parseExpression = (): ASTNode => {
      return parseAssignmentExpression();
    };

    const parseAssignmentExpression = (): ASTNode => {
      const left = parseConditionalExpression();
      const token = peek();
      if (token && token.type === 'operator' && ['=', '+=', '-=', '*=', '/='].includes(token.value as string)) {
        const operator = consume().value as string;
        const right = parseAssignmentExpression();
        return { type: 'AssignmentExpression', operator, left, right };
      }
      return left;
    };

    const parseConditionalExpression = (): ASTNode => {
      const test = parseLogicalOrExpression();
      const token = peek();
      if (token && token.type === 'operator' && token.value === '?') {
        consume();
        const consequent = parseExpression();
        expect('punctuation', ':');
        const alternate = parseExpression();
        return { type: 'ConditionalExpression', test, consequent, alternate };
      }
      return test;
    };

    const parseLogicalOrExpression = (): ASTNode => {
      let left = parseLogicalAndExpression();
      while (peek()?.type === 'operator' && peek()?.value === '||') {
        const operator = consume().value as string;
        const right = parseLogicalAndExpression();
        left = { type: 'LogicalExpression', operator, left, right };
      }
      return left;
    };

    const parseLogicalAndExpression = (): ASTNode => {
      let left = parseEqualityExpression();
      while (peek()?.type === 'operator' && peek()?.value === '&&') {
        const operator = consume().value as string;
        const right = parseEqualityExpression();
        left = { type: 'LogicalExpression', operator, left, right };
      }
      return left;
    };

    const parseEqualityExpression = (): ASTNode => {
      let left = parseRelationalExpression();
      while (peek()?.type === 'operator' && ['==', '!=', '===', '!=='].includes(peek()?.value as string)) {
        const operator = consume().value as string;
        const right = parseRelationalExpression();
        left = { type: 'BinaryExpression', operator, left, right };
      }
      return left;
    };

    const parseRelationalExpression = (): ASTNode => {
      let left = parseAdditiveExpression();
      while (peek()?.type === 'operator' && ['<', '>', '<=', '>=', 'in', 'instanceof'].includes(peek()?.value as string)) {
        const operator = consume().value as string;
        const right = parseAdditiveExpression();
        left = { type: 'BinaryExpression', operator, left, right };
      }
      return left;
    };

    const parseAdditiveExpression = (): ASTNode => {
      let left = parseMultiplicativeExpression();
      while (peek()?.type === 'operator' && ['+', '-'].includes(peek()?.value as string)) {
        const operator = consume().value as string;
        const right = parseMultiplicativeExpression();
        left = { type: 'BinaryExpression', operator, left, right };
      }
      return left;
    };

    const parseMultiplicativeExpression = (): ASTNode => {
      let left = parseUnaryExpression();
      while (peek()?.type === 'operator' && ['*', '/', '%'].includes(peek()?.value as string)) {
        const operator = consume().value as string;
        const right = parseUnaryExpression();
        left = { type: 'BinaryExpression', operator, left, right };
      }
      return left;
    };

    const parseUnaryExpression = (): ASTNode => {
      const token = peek();
      if (token && token.type === 'operator' && ['+', '-', '!', '~', 'typeof', 'void', 'delete'].includes(token.value as string)) {
        const operator = consume().value as string;
        const argument = parseUnaryExpression();
        return { type: 'UnaryExpression', operator, argument, prefix: true };
      }
      return parseUpdateExpression();
    };

    const parseUpdateExpression = (): ASTNode => {
      const token = peek();
      if (token && token.type === 'operator' && ['++', '--'].includes(token.value as string)) {
        const operator = consume().value as string;
        const argument = parseMemberExpression();
        return { type: 'UpdateExpression', operator, argument, prefix: true };
      }
      const argument = parseMemberExpression();
      const nextToken = peek();
      if (nextToken && nextToken.type === 'operator' && ['++', '--'].includes(nextToken.value as string)) {
        const operator = consume().value as string;
        return { type: 'UpdateExpression', operator, argument, prefix: false };
      }
      return argument;
    };

    const parseMemberExpression = (): ASTNode => {
      let object = parsePrimaryExpression();
      while (true) {
        const token = peek();
        if (token && token.type === 'punctuation' && token.value === '.') {
          consume();
          const property = parsePrimaryExpression();
          object = { type: 'MemberExpression', object, property, computed: false };
        } else if (token && token.type === 'punctuation' && token.value === '[') {
          consume();
          const property = parseExpression();
          expect('punctuation', ']');
          object = { type: 'MemberExpression', object, property, computed: true };
        } else if (token && token.type === 'punctuation' && token.value === '(') {
          consume();
          const args: ASTNode[] = [];
          while (peek() && !(peek()?.type === 'punctuation' && peek()?.value === ')')) {
            args.push(parseExpression());
            if (peek()?.type === 'punctuation' && peek()?.value === ',') {
              consume();
            }
          }
          expect('punctuation', ')');
          object = { type: 'CallExpression', callee: object, arguments: args };
        } else {
          break;
        }
      }
      return object;
    };

    const parsePrimaryExpression = (): ASTNode => {
      const token = peek();
      if (!token) {
        throw new Error('Unexpected end of input');
      }

      if (token.type === 'number') {
        consume();
        return { type: 'Literal', value: token.value };
      }

      if (token.type === 'string') {
        consume();
        return { type: 'Literal', value: token.value };
      }

      if (token.type === 'boolean') {
        consume();
        return { type: 'Literal', value: token.value };
      }

      if (token.type === 'null') {
        consume();
        return { type: 'Literal', value: token.value };
      }

      if (token.type === 'identifier') {
        consume();
        return { type: 'Identifier', name: token.value as string };
      }

      if (token.type === 'punctuation' && token.value === '(') {
        consume();
        const expr = parseExpression();
        expect('punctuation', ')');
        return expr;
      }

      if (token.type === 'punctuation' && token.value === '[') {
        consume();
        const elements: (ASTNode | null)[] = [];
        while (peek() && !(peek()?.type === 'punctuation' && peek()?.value === ']')) {
          if (peek()?.type === 'punctuation' && peek()?.value === ',') {
            consume();
            elements.push(null);
          } else {
            elements.push(parseExpression());
            if (peek()?.type === 'punctuation' && peek()?.value === ',') {
              consume();
            }
          }
        }
        expect('punctuation', ']');
        return { type: 'ArrayExpression', elements };
      }

      if (token.type === 'punctuation' && token.value === '{') {
        consume();
        const properties: ASTNode[] = [];
        while (peek() && !(peek()?.type === 'punctuation' && peek()?.value === '}')) {
          const key = parseExpression();
          expect('punctuation', ':');
          const value = parseExpression();
          properties.push({ type: 'Property', key, value });
          if (peek()?.type === 'punctuation' && peek()?.value === ',') {
            consume();
          }
        }
        expect('punctuation', '}');
        return { type: 'ObjectExpression', properties };
      }

      throw new Error(`Unexpected token: ${token.type} '${token.value}'`);
    };

    const parseStatement = (): ASTNode => {
      const token = peek();
      if (!token) {
        throw new Error('Unexpected end of input');
      }

      if (token.type === 'punctuation' && token.value === '{') {
        return parseBlockStatement();
      }

      if (token.type === 'keyword') {
        switch (token.value) {
          case 'if':
            return parseIfStatement();
          case 'while':
            return parseWhileStatement();
          case 'for':
            return parseForStatement();
          case 'return':
            return parseReturnStatement();
          case 'break':
            consume();
            if (peek()?.type === 'punctuation' && peek()?.value === ';') {
              consume();
            }
            return { type: 'BreakStatement' };
          case 'continue':
            consume();
            if (peek()?.type === 'punctuation' && peek()?.value === ';') {
              consume();
            }
            return { type: 'ContinueStatement' };
          case 'try':
            return parseTryStatement();
          case 'throw':
            return parseThrowStatement();
          case 'var':
          case 'let':
          case 'const':
            return parseVariableDeclaration();
          case 'function':
            return parseFunctionDeclaration();
        }
      }

      const expr = parseExpression();
      if (peek()?.type === 'punctuation' && peek()?.value === ';') {
        consume();
      }
      return { type: 'ExpressionStatement', expression: expr };
    };

    const parseBlockStatement = (): ASTNode => {
      expect('punctuation', '{');
      const body: ASTNode[] = [];
      while (peek() && !(peek()?.type === 'punctuation' && peek()?.value === '}')) {
        body.push(parseStatement());
      }
      expect('punctuation', '}');
      return { type: 'BlockStatement', body };
    };

    const parseIfStatement = (): ASTNode => {
      expect('keyword', 'if');
      expect('punctuation', '(');
      const test = parseExpression();
      expect('punctuation', ')');
      const consequent = parseStatement();
      let alternate: ASTNode | undefined;
      if (peek()?.value === 'else') {
        consume();
        alternate = parseStatement();
      }
      const result: ASTNode = { type: 'IfStatement', test: test, consequent: consequent, alternate: alternate };
      return result;
    };

    const parseForStatement = (): ASTNode => {
      expect('keyword', 'for');
      expect('punctuation', '(');

      let init: ASTNode | undefined;
      if (peek()?.type === 'keyword' && ['let', 'const', 'var'].includes(peek()!.value as string)) {
        init = parseVariableDeclaration();
      } else if (peek()?.value !== ';') {
        init = parseExpression();
        if (peek()?.value === ';') consume();
      } else {
        consume();
      }

      let test: ASTNode | undefined;
      if (peek()?.value !== ';') {
        test = parseExpression();
      }
      expect('punctuation', ';');

      let update: ASTNode | undefined;
      if (peek()?.value !== ')') {
        update = parseExpression();
      }
      expect('punctuation', ')');

      const body = parseStatement();

      return { type: 'ForStatement', init, test, update, body };
    };

    const parseWhileStatement = (): ASTNode => {
      expect('keyword', 'while');
      expect('punctuation', '(');
      const test = parseExpression();
      expect('punctuation', ')');
      const body = parseStatement();
      return { type: 'WhileStatement', test, body };
    };

    const parseReturnStatement = (): ASTNode => {
      expect('keyword', 'return');
      let argument: ASTNode | undefined;
      if (peek()?.value !== ';' && peek()?.value !== '}') {
        argument = parseExpression();
      }
      if (peek()?.value === ';') consume();
      return { type: 'ReturnStatement', argument };
    };

    const parseFunctionDeclaration = (): ASTNode => {
      expect('keyword', 'function');
      const name = expect('identifier').value as string;
      expect('punctuation', '(');
      const params: ASTNode[] = [];
      while (peek() && !(peek()?.type === 'punctuation' && peek()?.value === ')')) {
        params.push(parsePrimaryExpression());
        if (peek()?.type === 'punctuation' && peek()?.value === ',') {
          consume();
        }
      }
      expect('punctuation', ')');
      const body = parseBlockStatement();
      return { type: 'FunctionDeclaration', name, params, body };
    };

    const parseVariableDeclaration = (): ASTNode => {
      const kind = consume().value as string;
      const declarations: ASTNode[] = [];
      do {
        const id = parsePrimaryExpression();
        let init: ASTNode | undefined;
        if (peek()?.type === 'operator' && peek()?.value === '=') {
          consume();
          init = parseExpression();
        }
        declarations.push({ type: 'VariableDeclarator', id, init });
        if (peek()?.type === 'punctuation' && peek()?.value === ',') {
          consume();
        }
      } while (peek() && peek()?.type !== 'punctuation' && peek()?.value !== ';');
      if (peek()?.type === 'punctuation' && peek()?.value === ';') {
        consume();
      }
      return { type: 'VariableDeclaration', kind, declarations };
    };

    const parseTryStatement = (): ASTNode => {
      expect('keyword', 'try');
      const block = parseBlockStatement();
      let handler: ASTNode | undefined;
      if (peek()?.value === 'catch') {
        consume();
        expect('punctuation', '(');
        const param = parsePrimaryExpression();
        expect('punctuation', ')');
        const body = parseBlockStatement();
        handler = { type: 'CatchClause', param, body };
      }
      let finalizer: ASTNode | undefined;
      if (peek()?.value === 'finally') {
        consume();
        finalizer = parseBlockStatement();
      }
      return { type: 'TryStatement', block, handler, finalizer };
    };

    const parseThrowStatement = (): ASTNode => {
      expect('keyword', 'throw');
      const argument = parseExpression();
      if (peek()?.type === 'punctuation' && peek()?.value === ';') {
        consume();
      }
      return { type: 'ThrowStatement', argument };
    };

    const body: ASTNode[] = [];
    while (pos < tokens.length) {
      body.push(parseStatement());
    }

    return { type: 'Program', body };
  }

  private evaluate(node: ASTNode): ScriptValue {
    this.checkTimeout();

    switch (node.type) {
      case 'Program':
        return this.evaluateProgram(node);
      case 'BlockStatement':
        return this.evaluateBlockStatement(node);
      case 'ExpressionStatement':
        return this.evaluate(node.expression as ASTNode);
      case 'Literal':
        return node.value as ScriptValue;
      case 'Identifier':
        return this.evaluateIdentifier(node);
      case 'BinaryExpression':
        return this.evaluateBinaryExpression(node);
      case 'LogicalExpression':
        return this.evaluateLogicalExpression(node);
      case 'UnaryExpression':
        return this.evaluateUnaryExpression(node);
      case 'UpdateExpression':
        return this.evaluateUpdateExpression(node);
      case 'AssignmentExpression':
        return this.evaluateAssignmentExpression(node);
      case 'ConditionalExpression':
        return this.evaluateConditionalExpression(node);
      case 'CallExpression':
        return this.evaluateCallExpression(node);
      case 'MemberExpression':
        return this.evaluateMemberExpression(node);
      case 'ArrayExpression':
        return this.evaluateArrayExpression(node);
      case 'ObjectExpression':
        return this.evaluateObjectExpression(node);
      case 'VariableDeclaration':
        return this.evaluateVariableDeclaration(node);
      case 'FunctionDeclaration':
        return this.evaluateFunctionDeclaration(node);
      case 'IfStatement':
        return this.evaluateIfStatement(node);
      case 'ForStatement':
        return this.evaluateForStatement(node);
      case 'WhileStatement':
        return this.evaluateWhileStatement(node);
      case 'ReturnStatement':
        return this.evaluateReturnStatement(node);
      case 'BreakStatement':
        throw new ScriptControlFlow('Break');
      case 'ContinueStatement':
        throw new ScriptControlFlow('Continue');
      case 'TryStatement':
        return this.evaluateTryStatement(node);
      case 'ThrowStatement':
        return this.evaluateThrowStatement(node);
      default:
        return undefined;
    }
  }

  private evaluateProgram(node: ASTNode): ScriptValue {
    let result: ScriptValue = undefined;
    const bodyContent = node.body;
    if (Array.isArray(bodyContent)) {
      for (let i = 0; i < bodyContent.length; i++) {
        const stmt = bodyContent[i];
        try {
          result = this.evaluate(stmt);
        } catch (e) {
          if (e instanceof ScriptControlFlow && e.controlType === 'Return') {
            return e.controlValue;
          }
          if (e instanceof Error) {
            throw e;
          }
          throw new Error(String(e));
        }
      }
    } else if (bodyContent) {
      result = this.evaluate(bodyContent as ASTNode);
    }
    return result;
  }

  private evaluateIdentifier(node: ASTNode): ScriptValue {
    const name = node.name as string;
    
    // 使用统一的安全配置检查禁止的标识符
    if (this.securityConfig.isIdentifierForbidden(name)) {
      Logger.warn(this.TAG, `禁止访问的标识符: ${name}`);
      return undefined;
    }
    
    if (this.variables.has(name)) {
      return this.variables.get(name);
    }
    if (this.functions.has(name)) {
      return this.functions.get(name) as ScriptValue;
    }
    if (this.builtInFunctions.has(name)) {
      return this.builtInFunctions.get(name) as ScriptValue;
    }
    return undefined;
  }

  private evaluateBinaryExpression(node: ASTNode): ScriptValue {
    const left = this.evaluate(node.left as ASTNode);
    const right = this.evaluate(node.right as ASTNode);
    const operator = node.operator as string;

    switch (operator) {
      case '+':
        if (typeof left === 'string' || typeof right === 'string') {
          return String(left ?? '') + String(right ?? '');
        }
        return Number(left ?? 0) + Number(right ?? 0);
      case '-':
        return Number(left ?? 0) - Number(right ?? 0);
      case '*':
        return Number(left ?? 0) * Number(right ?? 0);
      case '/':
        return Number(right ?? 0) === 0 ? Infinity : Number(left ?? 0) / Number(right ?? 0);
      case '%':
        return Number(left ?? 0) % Number(right ?? 0);
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '===':
        return left === right;
      case '!==':
        return left !== right;
      case '<':
        return Number(left ?? 0) < Number(right ?? 0);
      case '>':
        return Number(left ?? 0) > Number(right ?? 0);
      case '<=':
        return Number(left ?? 0) <= Number(right ?? 0);
      case '>=':
        return Number(left ?? 0) >= Number(right ?? 0);
      case '&':
        return Number(left ?? 0) & Number(right ?? 0);
      case '|':
        return Number(left ?? 0) | Number(right ?? 0);
      case '^':
        return Number(left ?? 0) ^ Number(right ?? 0);
      case '<<':
        return Number(left ?? 0) << Number(right ?? 0);
      case '>>':
        return Number(left ?? 0) >> Number(right ?? 0);
      case '>>>':
        return Number(left ?? 0) >>> Number(right ?? 0);
      case 'in':
        if (typeof right === 'object' && right !== null) {
          const key = String(left ?? '');
          const keys = Object.keys(right);
          for (let i = 0; i < keys.length; i++) {
            if (keys[i] === key) {
              return true;
            }
          }
          return false;
        }
        return false;
      case 'instanceof':
        return false;
      default:
        return undefined;
    }
  }

  private evaluateLogicalExpression(node: ASTNode): ScriptValue {
    const left = this.evaluate(node.left as ASTNode);
    const operator = node.operator as string;

    if (operator === '&&') {
      return left ? this.evaluate(node.right as ASTNode) : left;
    } else if (operator === '||') {
      return left ? left : this.evaluate(node.right as ASTNode);
    }
    return undefined;
  }

  private evaluateUnaryExpression(node: ASTNode): ScriptValue {
    const argument = this.evaluate(node.argument as ASTNode);
    const operator = node.operator as string;

    switch (operator) {
      case '+':
        return +Number(argument ?? 0);
      case '-':
        return -Number(argument ?? 0);
      case '!':
        return !argument;
      case '~':
        return ~Number(argument ?? 0);
      case 'typeof':
        return typeof argument;
      case 'void':
        return undefined;
      case 'delete':
        return true;
      default:
        return undefined;
    }
  }

  private evaluateUpdateExpression(node: ASTNode): ScriptValue {
    const argument = node.argument as ASTNode;
    const operator = node.operator as string;
    const prefix = node.prefix ?? false;

    if (argument.type === 'Identifier') {
      const name = argument.name as string;
      const currentValue = Number(this.variables.get(name) ?? 0);
      let newValue: number;

      if (operator === '++') {
        newValue = currentValue + 1;
      } else if (operator === '--') {
        newValue = currentValue - 1;
      } else {
        return undefined;
      }

      this.variables.set(name, newValue);
      return prefix ? newValue : currentValue;
    }

    return undefined;
  }

  private evaluateAssignmentExpression(node: ASTNode): ScriptValue {
    const left = node.left as ASTNode;
    const right = this.evaluate(node.right as ASTNode);
    const operator = node.operator as string;

    if (left.type === 'Identifier') {
      const name = left.name as string;
      const currentValue = this.variables.get(name);
      let newValue: ScriptValue;

      switch (operator) {
        case '=':
          newValue = right;
          break;
        case '+=':
          if (typeof currentValue === 'string' || typeof right === 'string') {
            newValue = String(currentValue ?? '') + String(right ?? '');
          } else {
            newValue = Number(currentValue ?? 0) + Number(right ?? 0);
          }
          break;
        case '-=':
          newValue = Number(currentValue ?? 0) - Number(right ?? 0);
          break;
        case '*=':
          newValue = Number(currentValue ?? 0) * Number(right ?? 0);
          break;
        case '/=':
          newValue = Number(right ?? 0) === 0 ? Infinity : Number(currentValue ?? 0) / Number(right ?? 0);
          break;
        default:
          return undefined;
      }

      this.variables.set(name, newValue);
      return newValue;
    }

    return undefined;
  }

  private evaluateConditionalExpression(node: ASTNode): ScriptValue {
    const test = this.evaluate(node.test as ASTNode);
    return test ? this.evaluate(node.consequent as ASTNode) : this.evaluate(node.alternate as ASTNode);
  }

  private evaluateCallExpression(node: ASTNode): ScriptValue {
    const callee = this.evaluate(node.callee as ASTNode);
    const args = (node.arguments ?? []).map(arg => this.evaluate(arg));

    if (typeof callee === 'function') {
      return callee(args);
    }

    return undefined;
  }

  private evaluateMemberExpression(node: ASTNode): ScriptValue {
    const obj = this.evaluate(node.object as ASTNode);
    const prop = node.computed ? 
      this.evaluate(node.property as ASTNode) : 
      (node.property as ASTNode).name;

    if (obj === null || obj === undefined) {
      return undefined;
    }

    if (Array.isArray(obj)) {
      if (prop === 'length') {
        return obj.length;
      }
      const index = Number(prop);
      if (!isNaN(index)) {
        return obj[index];
      }
    }

    if (typeof obj === 'object') {
      return (obj as Record<string, ScriptValue>)[String(prop)];
    }

    if (typeof obj === 'string') {
      if (prop === 'length') {
        return obj.length;
      }
      const index = Number(prop);
      if (!isNaN(index)) {
        return obj[index];
      }
    }

    return undefined;
  }

  private evaluateArrayExpression(node: ASTNode): ScriptValue {
    return (node.elements ?? []).map(element => 
      element === null ? undefined : this.evaluate(element)
    );
  }

  private evaluateObjectExpression(node: ASTNode): ScriptValue {
    const obj: Record<string, ScriptValue> = {};
    const properties = node.properties ?? [];
    for (let i = 0; i < properties.length; i++) {
      const prop = properties[i];
      const key = prop.key;
      let keyName: string;
      if (typeof key === 'string') {
        keyName = key;
      } else if (key?.type === 'Identifier') {
        keyName = key.name ?? '';
      } else if (key) {
        keyName = String(this.evaluate(key));
      } else {
        keyName = '';
      }
      obj[keyName] = this.evaluate(prop.value as ASTNode);
    }
    return obj;
  }

  private evaluateVariableDeclaration(node: ASTNode): ScriptValue {
    const declarations = node.declarations ?? [];
    for (let i = 0; i < declarations.length; i++) {
      const declaration = declarations[i];
      const id = declaration.id as ASTNode;
      if (id.type === 'Identifier') {
        const name = id.name as string;
        const init = declaration.init;
        const value = init ? this.evaluate(init) : undefined;
        this.variables.set(name, value);
      }
    }
    return undefined;
  }

  private evaluateFunctionDeclaration(node: ASTNode): ScriptValue {
    const name = node.name as string;
    const params = (node.params ?? []) as ASTNode[];
    const body = node.body as ASTNode;

    const func = (args: ScriptValue[]): ScriptValue => {
      const savedVars = new Map(this.variables);

      for (let i = 0; i < params.length; i++) {
        const param = params[i];
        if (param.type === 'Identifier') {
          this.variables.set(param.name as string, args[i]);
        }
      }

      try {
        const bodyContent = body.body;
        if (Array.isArray(bodyContent)) {
          for (let i = 0; i < bodyContent.length; i++) {
            const stmt = bodyContent[i];
            this.evaluate(stmt);
          }
        } else if (bodyContent) {
          this.evaluate(bodyContent as ASTNode);
        }
      } catch (e) {
        if (e instanceof ScriptControlFlow && e.controlType === 'Return') {
          this.variables = savedVars;
          return e.controlValue;
        }
        if (e instanceof Error) {
          throw e;
        }
        throw new Error(String(e));
      }

      this.variables = savedVars;
      return undefined;
    };

    this.functions.set(name, func);
    return undefined;
  }

  private evaluateIfStatement(node: ASTNode): ScriptValue {
    const test = this.evaluate(node.test as ASTNode);
    if (test) {
      return this.evaluate(node.consequent as ASTNode);
    } else if (node.alternate) {
      return this.evaluate(node.alternate as ASTNode);
    }
    return undefined;
  }

  private evaluateForStatement(node: ASTNode): ScriptValue {
    const savedVars = new Map(this.variables);
    let result: ScriptValue = undefined;
    let iterations = 0;

    if (node.init) {
      this.evaluate(node.init);
    }

    while (iterations < this.maxLoopIterations) {
      this.checkTimeout();

      if (node.test) {
        const test = this.evaluate(node.test);
        if (!test) break;
      }

      try {
        const bodyNode = node.body;
        if (bodyNode) {
          if (Array.isArray(bodyNode)) {
            for (let i = 0; i < bodyNode.length; i++) {
              result = this.evaluate(bodyNode[i]);
            }
          } else {
            result = this.evaluate(bodyNode);
          }
        }
      } catch (e) {
        if (e instanceof ScriptControlFlow) {
          if (e.controlType === 'Break') break;
          if (e.controlType === 'Continue') {
            if (node.update) this.evaluate(node.update);
            iterations++;
            continue;
          }
        }
        if (e instanceof Error) {
          throw e;
        }
        throw new Error(String(e));
      }

      if (node.update) {
        this.evaluate(node.update);
      }
      iterations++;
    }

    if (iterations >= this.maxLoopIterations) {
      Logger.warn(this.TAG, `For循环达到最大迭代次数限制: ${this.maxLoopIterations}`);
    }

    this.variables = savedVars;
    return result;
  }

  private evaluateWhileStatement(node: ASTNode): ScriptValue {
    let result: ScriptValue = undefined;
    let iterations = 0;

    while (iterations < this.maxLoopIterations) {
      const testNode = node.test;
      if (!testNode) break;
      const test = this.evaluate(testNode);
      if (!test) break;

      try {
        const bodyNode = node.body;
        if (bodyNode) {
          if (Array.isArray(bodyNode)) {
            for (let i = 0; i < bodyNode.length; i++) {
              result = this.evaluate(bodyNode[i]);
            }
          } else {
            result = this.evaluate(bodyNode);
          }
        }
      } catch (e) {
        if (e instanceof ScriptControlFlow) {
          if (e.controlType === 'Break') break;
          if (e.controlType === 'Continue') {
            iterations++;
            continue;
          }
        }
        if (e instanceof Error) {
          throw e;
        }
        throw new Error(String(e));
      }
      iterations++;
    }

    if (iterations >= this.maxLoopIterations) {
      Logger.warn(this.TAG, `While循环达到最大迭代次数限制: ${this.maxLoopIterations}`);
    }

    return result;
  }

  private evaluateReturnStatement(node: ASTNode): ScriptValue {
    const value = node.argument ? this.evaluate(node.argument) : undefined;
    throw new ScriptControlFlow('Return', value);
  }

  private evaluateTryStatement(node: ASTNode): ScriptValue {
    try {
      const blockNode = node.block;
      if (blockNode) {
        return this.evaluate(blockNode);
      }
    } catch (e) {
      const handlerNode = node.handler;
      if (handlerNode) {
        const paramNode = handlerNode.param as ASTNode;
        if (paramNode && paramNode.type === 'Identifier') {
          const errorMessage = e instanceof Error ? e.message : String(e);
          this.variables.set(paramNode.name as string, errorMessage);
        }
        const bodyNode = handlerNode.body as ASTNode;
        if (bodyNode) {
          return this.evaluate(bodyNode);
        }
      }
    } finally {
      const finalizerNode = node.finalizer;
      if (finalizerNode) {
        this.evaluate(finalizerNode);
      }
    }
    return undefined;
  }

  private evaluateThrowStatement(node: ASTNode): ScriptValue {
    const argument = node.argument;
    const value = argument ? this.evaluate(argument) : undefined;
    const errorMessage = value instanceof Error ? value.message : String(value ?? 'Error');
    throw new Error(errorMessage);
  }

  private evaluateBlockStatement(node: ASTNode): ScriptValue {
    let result: ScriptValue = undefined;
    const bodyContent = node.body;
    if (Array.isArray(bodyContent)) {
      for (let i = 0; i < bodyContent.length; i++) {
        const stmt = bodyContent[i];
        try {
          result = this.evaluate(stmt);
        } catch (e) {
          if (e instanceof ScriptControlFlow) {
            throw e;
          }
          if (e instanceof Error) {
            throw e;
          }
          throw new Error(String(e));
        }
      }
    } else if (bodyContent) {
      result = this.evaluate(bodyContent as ASTNode);
    }
    return result;
  }

  clearState(): void {
    this.variables.clear();
    this.functions.clear();
  }
}
