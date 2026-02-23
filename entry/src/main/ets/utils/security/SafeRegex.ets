import { Logger } from "../performance/Logger";

/**
 * RegexMatchResult - 正则匹配结果类
 * 用于替代RegExpExecArray，解决ArkTS不支持结构化类型的问题
 */
export class RegexMatchResult {
  index: number = 0;
  input: string = '';
  private matches: string[] = [];

  constructor(index: number, input: string, matches: string[]) {
    this.index = index;
    this.input = input;
    this.matches = matches;
  }

  /**
   * 获取完整匹配字符串
   */
  getMatch(): string {
    return this.matches.length > 0 ? this.matches[0] : '';
  }

  /**
   * 获取捕获组
   * @param groupIndex 捕获组索引（0为完整匹配，1-9为捕获组）
   */
  getGroup(groupIndex: number): string | undefined {
    return this.matches[groupIndex];
  }

  /**
   * 获取所有匹配结果
   */
  getAllMatches(): string[] {
    return this.matches.slice();
  }

  /**
   * 从RegExpExecArray创建实例（运行时转换）
   * 使用object类型避免ArkTS结构化类型限制
   */
  static fromExecArray(execArray: object): RegexMatchResult {
    const arr = execArray as RegExpExecArray;
    const matches: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      matches.push(arr[i]);
    }
    return new RegexMatchResult(arr.index, arr.input, matches);
  }
}

/**
 * 执行选项接口
 */
interface ExecuteOptions {
  timeout?: number;
}

/**
 * SafeRegex - 安全的正则表达式处理类
 * 提供ReDoS攻击防护、正则表达式安全检测等功能
 */
export class SafeRegex {
  private static readonly TAG = 'SafeRegex';

  // 执行限制
  private static readonly MAX_EXECUTION_TIME = 1000;  // 降低到1秒
  private static readonly MAX_INPUT_LENGTH = 50000;   // 降低到5万字符
  private static readonly MAX_PATTERN_LENGTH = 2000;  // 正则表达式最大长度
  private static readonly MAX_QUANTIFIER_DEPTH = 2;   // 降低到2层
  private static readonly MAX_GROUP_COUNT = 15;       // 降低到15个分组
  private static readonly MAX_CHAR_CLASS_LENGTH = 50; // 降低到50字符
  private static readonly MAX_ALTERNATION_COUNT = 10; // 最大分支数
  private static readonly MAX_MATCH_COUNT = 1000;     // 最大匹配次数

  // 危险模式 - 增强ReDoS检测
  private static readonly DANGEROUS_PATTERNS: string[] = [
    // 嵌套量词
    '\\(\\?\\!.*\\*\\+?\\)',
    '\\(\\?\\<\\!.*\\*\\+?\\)',
    '\\(.*\\*\\+?\\)\\{\\d+,\\}',
    '\\(.*\\*\\+?\\)\\+',
    '\\(.*\\*\\+?\\)\\*',
    '\\(.*\\*\\+?\\)\\?',
    '\\[.*\\]\\{\\d+,\\}',
    '\\[.*\\]\\+',
    '\\[.*\\]\\*',
    '\\(\\?:.*\\*\\+?\\)\\{\\d+,\\}',
    '\\(\\?:.*\\*\\+?\\)\\+',
    '\\(\\?:.*\\*\\+?\\)\\*',
    // 额外的危险模式
    '\\(.*\\+\\)\\+',           // (a+)+ 模式
    '\\(.*\\*\\)\\*',           // (a*)* 模式
    '\\(.*\\?)\\?',           // (a?)? 模式
    '\\(.*\\{\\d+,\\}\\)\\{\\d+,\\}',  // 嵌套重复
    '\\(\\[.*\\]\\+\\)\\+',     // ([a-z]+)+
    '\\(\\[.*\\]\\*)\\*',     // ([a-z]*)*
  ];
  
  // 可疑的重复模式
  private static readonly SUSPICIOUS_REPETITIONS = [
    /(.+)\1{10,}/,  // 10次以上重复
    /(.{2,})\1{5,}/, // 5次以上2字符重复
    /(.{3,})\1{3,}/, // 3次以上3字符重复
  ];

  /**
   * 检查正则表达式是否安全
   * @param pattern 正则表达式模式
   * @returns 是否安全
   */
  static isSafe(pattern: string): boolean {
    if (!pattern || typeof pattern !== 'string') {
      return false;
    }

    // 长度检查
    if (pattern.length > SafeRegex.MAX_PATTERN_LENGTH) {
      Logger.warn(SafeRegex.TAG, `正则表达式过长: ${pattern.length} 字符，限制: ${SafeRegex.MAX_PATTERN_LENGTH}`);
      return false;
    }

    // 检查危险模式
    for (const dangerousPattern of SafeRegex.DANGEROUS_PATTERNS) {
      try {
        const regex = new RegExp(dangerousPattern);
        if (regex.test(pattern)) {
          Logger.warn(SafeRegex.TAG, `检测到危险正则模式: ${dangerousPattern}`);
          return false;
        }
      } catch (e) {
        continue;
      }
    }

    // 检查量词嵌套深度
    const quantifierDepth = SafeRegex.calculateQuantifierDepth(pattern);
    if (quantifierDepth > SafeRegex.MAX_QUANTIFIER_DEPTH) {
      Logger.warn(SafeRegex.TAG, `嵌套量词深度过大: ${quantifierDepth}，限制: ${SafeRegex.MAX_QUANTIFIER_DEPTH}`);
      return false;
    }

    // 检查分组数量
    const groupCount = (pattern.match(/\(/g) || []).length;
    if (groupCount > SafeRegex.MAX_GROUP_COUNT) {
      Logger.warn(SafeRegex.TAG, `分组数量过多: ${groupCount}，限制: ${SafeRegex.MAX_GROUP_COUNT}`);
      return false;
    }

    // 检查字符类长度
    const charClasses = pattern.match(/\[[^\]]*\]/g) || [];
    for (const charClass of charClasses) {
      if (charClass.length > SafeRegex.MAX_CHAR_CLASS_LENGTH) {
        Logger.warn(SafeRegex.TAG, `字符类过长: ${charClass.length}，限制: ${SafeRegex.MAX_CHAR_CLASS_LENGTH}`);
        return false;
      }
    }

    // 检查分支数量
    const alternationCount = (pattern.match(/\|/g) || []).length;
    if (alternationCount > SafeRegex.MAX_ALTERNATION_COUNT) {
      Logger.warn(SafeRegex.TAG, `分支数量过多: ${alternationCount}，限制: ${SafeRegex.MAX_ALTERNATION_COUNT}`);
      return false;
    }

    // 验证正则表达式语法
    try {
      new RegExp(pattern);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.warn(SafeRegex.TAG, `无效的正则表达式: ${errorMsg}`);
      return false;
    }

    return true;
  }
  private static calculateQuantifierDepth(pattern: string): number {
    let maxDepth = 0;
    let currentDepth = 0;
    let inGroup = false;

    for (let i = 0; i < pattern.length; i++) {
      const char = pattern[i];

      if (char === '(') {
        inGroup = true;
      } else if (char === ')') {
        inGroup = false;
        currentDepth = 0;
      } else if (inGroup && /[*+?{\]]/.test(char)) {
        currentDepth++;
        maxDepth = Math.max(maxDepth, currentDepth);
      }
    }

    return maxDepth;
  }

  /**
   * 安全执行正则表达式
   * @param pattern 正则表达式
   * @param input 输入字符串
   * @param options 执行选项
   * @returns 匹配结果数组或null
   */
  static safeExecute(pattern: RegExp, input: string, options?: ExecuteOptions): string[] | null {
    if (!input || input.length > SafeRegex.MAX_INPUT_LENGTH) {
      Logger.warn(SafeRegex.TAG, `输入长度超出限制: ${input?.length || 0}，限制: ${SafeRegex.MAX_INPUT_LENGTH}`);
      return null;
    }

    const timeout = options?.timeout || SafeRegex.MAX_EXECUTION_TIME;
    const startTime = Date.now();

    try {
      const results: string[] = [];
      const regex = new RegExp(pattern.source, pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g');
      let match: RegExpExecArray | null;
      let count = 0;

      while ((match = regex.exec(input)) !== null && count < SafeRegex.MAX_MATCH_COUNT) {
        results.push(match[0]);
        count++;

        // 检查执行时间
        if (count % 10 === 0) {
          const elapsed = Date.now() - startTime;
          if (elapsed > timeout) {
            Logger.warn(SafeRegex.TAG, `正则执行超时: ${elapsed}ms，已匹配${count}次`);
            return null;
          }
        }

        if (match.index === regex.lastIndex) {
          regex.lastIndex++;
        }
      }

      // 最终时间检查
      const totalElapsed = Date.now() - startTime;
      if (totalElapsed > timeout) {
        Logger.warn(SafeRegex.TAG, `正则执行超时: ${totalElapsed}ms`);
        return null;
      }

      return results.length > 0 ? results : null;
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(SafeRegex.TAG, `正则执行失败: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 验证正则表达式模式是否安全
   * @param pattern 正则表达式
   * @returns 是否安全
   */
  static validatePattern(pattern: RegExp): boolean {
    return SafeRegex.isSafe(pattern.source);
  }

  /**
   * 转义字符串中的正则表达式特殊字符
   * @param input 输入字符串
   * @returns 转义后的字符串
   */
  static escapeString(input: string): string {
    if (!input) {
      return '';
    }
    // 转义正则表达式特殊字符
    return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 创建安全的正则表达式
   * @param pattern 正则表达式字符串
   * @param flags 标志
   * @returns 安全正则实例或null
   */
  static createSafeRegex(pattern: string, flags?: string): SafeRegexInstance | null {
    if (!SafeRegex.isSafe(pattern)) {
      Logger.warn(SafeRegex.TAG, '不安全的正则表达式被拒绝');
      return null;
    }

    try {
      const regex = new RegExp(pattern, flags);
      return new SafeRegexInstance(regex);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(SafeRegex.TAG, `创建正则表达式失败: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 安全测试正则表达式
   * @param pattern 正则表达式
   * @param input 输入字符串
   * @returns 是否匹配
   */
  static safeTest(pattern: RegExp, input: string): boolean {
    if (!input || input.length > SafeRegex.MAX_INPUT_LENGTH) {
      Logger.warn(SafeRegex.TAG, `输入长度超出限制: ${input?.length || 0}，限制: ${SafeRegex.MAX_INPUT_LENGTH}`);
      return false;
    }

    const startTime = Date.now();

    try {
      const result = pattern.test(input);

      // 检查执行时间
      const elapsed = Date.now() - startTime;
      if (elapsed > SafeRegex.MAX_EXECUTION_TIME) {
        Logger.warn(SafeRegex.TAG, `正则测试执行时间过长: ${elapsed}ms，可能存在ReDoS风险`);
        return false;
      }

      return result;
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(SafeRegex.TAG, `正则测试失败: ${errorMsg}`);
      return false;
    }
  }

  /**
   * 安全匹配 - 带执行时间限制
   * @param pattern 正则表达式
   * @param input 输入字符串
   * @param flags 标志
   * @returns 匹配结果
   */
  static safeMatch(pattern: string, input: string, flags?: string): RegExpMatchArray | null {
    if (!input || input.length > SafeRegex.MAX_INPUT_LENGTH) {
      Logger.warn(SafeRegex.TAG, `输入长度超出限制: ${input?.length || 0}，限制: ${SafeRegex.MAX_INPUT_LENGTH}`);
      return null;
    }

    if (!SafeRegex.isSafe(pattern)) {
      Logger.warn(SafeRegex.TAG, '不安全的正则表达式被拒绝');
      return null;
    }

    // 检查输入是否包含可疑的重复模式
    for (const repPattern of SafeRegex.SUSPICIOUS_REPETITIONS) {
      if (repPattern.test(input)) {
        Logger.warn(SafeRegex.TAG, '输入包含可疑的重复模式，可能导致ReDoS');
        return null;
      }
    }

    const startTime = Date.now();
    
    try {
      const regex = new RegExp(pattern, flags);
      const result = input.match(regex);
      
      // 检查执行时间
      const elapsed = Date.now() - startTime;
      if (elapsed > SafeRegex.MAX_EXECUTION_TIME) {
        Logger.warn(SafeRegex.TAG, `正则匹配执行时间过长: ${elapsed}ms，可能存在ReDoS风险`);
        return null;
      }
      
      return result;
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(SafeRegex.TAG, `正则匹配失败: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 安全全局匹配 - 带执行时间和次数限制
   * @param pattern 正则表达式
   * @param input 输入字符串
   * @param flags 标志
   * @returns 匹配结果数组
   */
  static safeMatchAll(pattern: string, input: string, flags?: string): RegexMatchResult[] {
    if (!input || input.length > SafeRegex.MAX_INPUT_LENGTH) {
      Logger.warn(SafeRegex.TAG, `输入长度超出限制: ${input?.length || 0}，限制: ${SafeRegex.MAX_INPUT_LENGTH}`);
      return [];
    }

    if (!SafeRegex.isSafe(pattern)) {
      Logger.warn(SafeRegex.TAG, '不安全的正则表达式被拒绝');
      return [];
    }

    // 检查输入是否包含可疑的重复模式
    for (const repPattern of SafeRegex.SUSPICIOUS_REPETITIONS) {
      if (repPattern.test(input)) {
        Logger.warn(SafeRegex.TAG, '输入包含可疑的重复模式，可能导致ReDoS');
        return [];
      }
    }

    const startTime = Date.now();

    try {
      const actualFlags = flags !== undefined && flags.includes('g') ? flags : (flags || '') + 'g';
      const regex = new RegExp(pattern, actualFlags);
      const results: RegexMatchResult[] = [];
      let count = 0;
      let match: RegExpExecArray | null = regex.exec(input);
      while (match !== null && count < SafeRegex.MAX_MATCH_COUNT) {
        if (match !== null) {
          results.push(RegexMatchResult.fromExecArray(match as object));
        }
        count++;

        // 每100次匹配检查一次时间
        if (count % 100 === 0) {
          const elapsed = Date.now() - startTime;
          if (elapsed > SafeRegex.MAX_EXECUTION_TIME) {
            Logger.warn(SafeRegex.TAG, `正则匹配执行时间过长: ${elapsed}ms，已匹配${count}次，可能存在ReDoS风险`);
            return results;
          }
        }

        if (match.index === regex.lastIndex) {
          regex.lastIndex++;
        }
        match = regex.exec(input);
      }

      if (count >= SafeRegex.MAX_MATCH_COUNT) {
        Logger.warn(SafeRegex.TAG, `匹配次数达到上限: ${SafeRegex.MAX_MATCH_COUNT}`);
      }

      // 最终时间检查
      const totalElapsed = Date.now() - startTime;
      if (totalElapsed > SafeRegex.MAX_EXECUTION_TIME) {
        Logger.warn(SafeRegex.TAG, `正则匹配执行时间过长: ${totalElapsed}ms，可能存在ReDoS风险`);
      }

      return results;
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(SafeRegex.TAG, `全局匹配失败: ${errorMsg}`);
      return [];
    }
  }

  static safeReplace(input: string, pattern: string, replacement: string): string {
    if (!input || input.length > SafeRegex.MAX_INPUT_LENGTH) {
      Logger.warn(SafeRegex.TAG, `输入长度超出限制: ${input?.length || 0}`);
      return input;
    }

    if (!SafeRegex.isSafe(pattern)) {
      Logger.warn(SafeRegex.TAG, '不安全的正则表达式被拒绝');
      return input;
    }

    try {
      const regex = new RegExp(pattern, 'g');
      return input.replace(regex, replacement);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      Logger.error(SafeRegex.TAG, `替换失败: ${errorMsg}`);
      return input;
    }
  }

  static sanitizePattern(pattern: string): string {
    if (!pattern) {
      return '';
    }

    let sanitized = pattern;

    if (sanitized.length > 5000) {
      sanitized = sanitized.substring(0, 5000);
      Logger.warn(SafeRegex.TAG, '正则表达式被截断至5000字符');
    }

    sanitized = sanitized.replace(/\(\?\!([^)]*)\)\*\+?/g, '(?!$1)');
    sanitized = sanitized.replace(/\(\?\<\!([^)]*)\)\*\+?/g, '(?<!$1)');
    sanitized = sanitized.replace(/\{(\d+),\}/g, '{$1,100}');
    sanitized = sanitized.replace(/\{,\d+\}/g, '{0,$1}');

    return sanitized;
  }

  static isInputSafe(input: string): boolean {
    if (!input) {
      return true;
    }

    if (input.length > SafeRegex.MAX_INPUT_LENGTH) {
      Logger.warn(SafeRegex.TAG, `输入字符串过长: ${input.length}`);
      return false;
    }

    const repeatingPattern = /(.)\1{100,}/;
    if (repeatingPattern.test(input)) {
      Logger.warn(SafeRegex.TAG, '输入包含大量重复字符');
      return false;
    }

    return true;
  }

  static create(pattern: string, flags?: string): SafeRegexInstance {
    if (!SafeRegex.isSafe(pattern)) {
      throw new Error('Unsafe regex pattern');
    }
    const regex = new RegExp(pattern, flags);
    return new SafeRegexInstance(regex);
  }
}

export class SafeRegexInstance {
  private pattern: RegExp;

  constructor(pattern: RegExp) {
    this.pattern = pattern;
  }

  getPattern(): RegExp {
    return this.pattern;
  }

  execute(input: string): string[] {
    if (!SafeRegex.isInputSafe(input)) {
      return [];
    }
    const results: string[] = [];
    let match: RegExpExecArray | null;
    const regex = new RegExp(this.pattern.source, this.pattern.flags.includes('g') ? this.pattern.flags : this.pattern.flags + 'g');
    while ((match = regex.exec(input)) !== null) {
      results.push(match[0]);
      if (!this.pattern.flags.includes('g')) break;
    }
    return results;
  }

  exec(input: string): RegExpMatchArray | null {
    if (!SafeRegex.isInputSafe(input)) {
      return null;
    }
    return this.pattern.exec(input);
  }
}
