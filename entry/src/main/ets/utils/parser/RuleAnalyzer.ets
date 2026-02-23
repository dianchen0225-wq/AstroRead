/**
 * RuleAnalyzer - 规则分析器
 * 完全复刻 Legado Android 的 RuleAnalyzer 核心逻辑
 * 
 * 功能：
 * 1. 复杂规则切分（支持 && || %% 操作符）
 * 2. 规则平衡组处理（处理嵌套规则）
 * 3. 代码平衡组处理（处理 [] 嵌套）
 * 4. 内嵌规则替换（处理 {$...} 内嵌）
 */

import { Logger } from '../performance/Logger';

export class RuleAnalyzer {
  private static readonly TAG = 'RuleAnalyzer';
  private static readonly ESC = '\\';

  // 被处理的字符串
  private queue: string;
  // 当前处理位置
  private pos: number = 0;
  // 当前处理字段的开始
  private start: number = 0;
  // 当前规则的开始
  private startX: number = 0;

  // 分割字符的长度
  step: number = 0;
  // 当前分割字符串类型（&& || %%）
  elementsType: string = '';

  constructor(data: string) {
    this.queue = data;
  }

  /**
   * 重置位置，方便复用解析器
   */
  reSetPos(): void {
    this.pos = 0;
    this.startX = 0;
    this.start = 0;
  }

  /**
   * 设置新的数据源
   */
  setData(data: string): void {
    this.queue = data;
    this.reSetPos();
  }

  /**
   * 修剪当前规则之前的"@"或者空白符
   */
  trim(): void {
    if (this.pos >= this.queue.length) return;
    
    if (this.queue[this.pos] === '@' || this.queue[this.pos] < '!') {
      this.pos++;
      while (this.pos < this.queue.length && 
             (this.queue[this.pos] === '@' || this.queue[this.pos] < '!')) {
        this.pos++;
      }
      this.start = this.pos;
      this.startX = this.pos;
    }
  }

  /**
   * 从剩余字串中拉出一个字符串，直到但不包括匹配序列
   * @param seq 查找的字符串，区分大小写
   * @returns 是否找到相应字段
   */
  private consumeTo(seq: string): boolean {
    this.start = this.pos;
    const offset = this.queue.indexOf(seq, this.pos);
    if (offset !== -1) {
      this.pos = offset;
      return true;
    }
    return false;
  }

  /**
   * 从剩余字串中拉出一个字符串，直到但不包括匹配序列（匹配参数列表中一项即为匹配）
   * @param seq 匹配字符串序列
   * @returns 成功返回true并设置间隔，失败返回false
   */
  private consumeToAny(...seq: string[]): boolean {
    let pos = this.pos;

    while (pos < this.queue.length) {
      for (const s of seq) {
        if (this.queue.substring(pos, pos + s.length) === s) {
          // 检查是否在引号内
          if (!this.isInQuotes(pos)) {
            this.step = s.length;
            this.pos = pos;
            return true;
          }
        }
      }
      pos++;
    }
    return false;
  }

  /**
   * 检查指定位置是否在引号内
   */
  private isInQuotes(pos: number): boolean {
    let inSingleQuote = false;
    let inDoubleQuote = false;

    for (let i = 0; i < pos; i++) {
      const c = this.queue[i];
      if (c === '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      } else if (c === "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (c === '\\' && (inSingleQuote || inDoubleQuote) && i + 1 < pos) {
        i++; // 跳过转义字符
      }
    }

    return inSingleQuote || inDoubleQuote;
  }

  /**
   * 切分规则 - 核心方法
   * 支持 &&（与）、||（或）、%%（交叉）三种操作符
   * 
   * @param seq 分隔符列表，如 ['&&', '||', '%%']
   * @returns 切分后的规则列表
   */
  splitRule(...seq: string[]): string[] {
    const rules: string[] = [];
    this.elementsType = '';

    // 记录当前规则的起始位置
    this.start = this.pos;
    this.startX = this.pos;

    while (this.consumeToAny(...seq)) {
      const rule = this.queue.substring(this.start, this.pos).trim();
      if (rule.length > 0) {
        rules.push(rule);
      }

      // 记录操作符类型
      if (this.pos < this.queue.length) {
        this.elementsType = this.queue.substring(this.pos, this.pos + this.step);
      }

      // 移动位置，跳过操作符
      this.pos += this.step;
      this.start = this.pos;
      this.startX = this.pos;
    }

    // 处理最后一个规则
    const lastRule = this.queue.substring(this.start).trim();
    if (lastRule.length > 0) {
      rules.push(lastRule);
    }

    return rules;
  }

  /**
   * 拉出一个规则平衡组
   * 处理引号、转义、嵌套
   * 
   * @param open 开始字符，如 '{' 或 '['
   * @param close 结束字符，如 '}' 或 ']'
   * @returns 是否成功匹配
   */
  chompRuleBalanced(open: string, close: string): boolean {
    let pos = this.pos;
    let depth = 0;
    let inSingleQuote = false;
    let inDoubleQuote = false;

    do {
      if (pos >= this.queue.length) break;
      const c = this.queue[pos++];

      if (c !== RuleAnalyzer.ESC) {
        // 处理引号
        if (c === "'" && !inDoubleQuote) {
          inSingleQuote = !inSingleQuote;
        } else if (c === '"' && !inSingleQuote) {
          inDoubleQuote = !inDoubleQuote;
        }

        // 在引号内，跳过
        if (inSingleQuote || inDoubleQuote) continue;

        // 处理嵌套
        if (c === open[0]) {
          depth++;
        } else if (c === close[0]) {
          depth--;
        }
      } else {
        // 转义字符，跳过下一个字符
        if (pos < this.queue.length) {
          pos++;
        }
      }
    } while (depth > 0);

    // 检查是否成功匹配
    if (depth === 0) {
      this.pos = pos;
      return true;
    }

    return false;
  }

  /**
   * 拉出一个代码平衡组
   * 处理 [] 嵌套，用于 XPath 和 JSONPath
   * 
   * @param open 开始字符，如 '[' 或 '{'
   * @param close 结束字符，如 ']' 或 '}'
   * @returns 是否成功匹配
   */
  chompCodeBalanced(open: string, close: string): boolean {
    let pos = this.pos;
    let depth = 0;
    let otherDepth = 0; // 其他对称符号嵌套深度
    let inSingleQuote = false;
    let inDoubleQuote = false;

    do {
      if (pos >= this.queue.length) break;
      const c = this.queue[pos++];

      if (c !== RuleAnalyzer.ESC) {
        // 处理引号
        if (c === "'" && !inDoubleQuote) {
          inSingleQuote = !inSingleQuote;
        } else if (c === '"' && !inSingleQuote) {
          inDoubleQuote = !inDoubleQuote;
        }

        // 在引号内，跳过
        if (inSingleQuote || inDoubleQuote) continue;

        // 处理 [] 嵌套
        if (c === '[') {
          depth++;
        } else if (c === ']') {
          depth--;
        } else if (depth === 0) {
          // 处于默认嵌套中的非默认字符
          if (c === open[0]) {
            otherDepth++;
          } else if (c === close[0]) {
            otherDepth--;
          }
        }
      } else {
        // 转义字符
        if (pos < this.queue.length) {
          pos++;
        }
      }
    } while (depth > 0 || otherDepth > 0);

    if (depth === 0 && otherDepth === 0) {
      this.pos = pos;
      return true;
    }

    return false;
  }

  /**
   * 内嵌规则替换
   * 处理 {$...} 形式的内嵌规则
   * 
   * @param start 开始标记，如 '{$.'
   * @param callback 替换回调函数
   * @returns 替换后的字符串
   */
  innerRule(start: string, callback: (rule: string) => string): string {
    let result = '';
    let lastPos = 0;

    while (true) {
      const startIndex = this.queue.indexOf(start, lastPos);
      if (startIndex === -1) break;

      // 添加开始标记之前的内容
      result += this.queue.substring(lastPos, startIndex);

      // 设置位置到开始标记之后
      this.pos = startIndex + start.length;

      // 查找结束标记 '}
      const savedPos = this.pos;
      if (this.chompRuleBalanced('{', '}')) {
        // 提取内嵌规则（去掉外层的大括号）
        const innerRule = this.queue.substring(savedPos, this.pos - 1);
        // 执行回调替换
        const replacement = callback(innerRule);
        result += replacement;
        lastPos = this.pos;
      } else {
        // 未找到匹配的结束标记，保留原样
        result += this.queue.substring(startIndex, savedPos);
        lastPos = savedPos;
      }
    }

    // 添加剩余内容
    result += this.queue.substring(lastPos);

    return result;
  }

  /**
   * 提取字符串，直到遇到指定字符
   * @param chars 停止字符列表
   * @returns 提取的字符串
   */
  consumeToAnyChar(...chars: string[]): string {
    const start = this.pos;
    while (this.pos < this.queue.length) {
      if (chars.includes(this.queue[this.pos])) {
        break;
      }
      this.pos++;
    }
    return this.queue.substring(start, this.pos);
  }

  /**
   * 获取剩余字符串
   */
  remaining(): string {
    return this.queue.substring(this.pos);
  }

  /**
   * 获取当前位置
   */
  getPos(): number {
    return this.pos;
  }

  /**
   * 设置当前位置
   */
  setPos(pos: number): void {
    this.pos = pos;
    this.start = pos;
    this.startX = pos;
  }

  /**
   * 获取原始字符串
   */
  getQueue(): string {
    return this.queue;
  }
}

export default RuleAnalyzer;
