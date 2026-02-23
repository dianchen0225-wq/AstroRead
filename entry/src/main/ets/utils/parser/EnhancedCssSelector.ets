/**
 * EnhancedCssSelector - 增强版 CSS 选择器引擎
 * 支持完整的 CSS3 选择器，包括 :nth-child, :first-child, :last-child 等
 */

import { DOMNode } from './DOMNode';

export interface SelectorPart {
  type: 'tag' | 'id' | 'class' | 'attribute' | 'pseudo' | 'combinator';
  value: string;
  argument?: string;
}

export class EnhancedCssSelector {
  /**
   * 查询匹配选择器的所有元素
   */
  static querySelectorAll(root: DOMNode, selector: string): DOMNode[] {
    if (!selector.trim()) {
      return [];
    }

    try {
      // 分割复合选择器（逗号分隔）
      const selectors = EnhancedCssSelector.splitSelectors(selector);
      const results: DOMNode[] = [];

      for (const sel of selectors) {
        const matched = EnhancedCssSelector.queryWithSingleSelector(root, sel.trim());
        for (const node of matched) {
          if (!results.includes(node)) {
            results.push(node);
          }
        }
      }

      return results;
    } catch (error) {
      return [];
    }
  }

  /**
   * 查询单个选择器
   */
  private static queryWithSingleSelector(root: DOMNode, selector: string): DOMNode[] {
    // 解析选择器链
    const parts = EnhancedCssSelector.parseSelectorChain(selector);

    if (parts.length === 0) {
      return [];
    }

    // 获取所有候选元素
    let candidates = EnhancedCssSelector.getAllElements(root);

    // 逐步过滤
    for (const part of parts) {
      if (part.type === 'combinator') {
        // 处理组合器 > + ~ 空格
        candidates = EnhancedCssSelector.applyCombinator(candidates, part.value, root);
      } else {
        // 过滤匹配当前部分的元素
        candidates = candidates.filter(node => EnhancedCssSelector.matchesPart(node, part));
      }
    }

    return candidates;
  }

  /**
   * 分割复合选择器
   */
  private static splitSelectors(selector: string): string[] {
    const selectors: string[] = [];
    let current = '';
    let depth = 0;

    for (let i = 0; i < selector.length; i++) {
      const char = selector[i];

      if (char === '(' || char === '[') {
        depth++;
        current += char;
      } else if (char === ')' || char === ']') {
        depth--;
        current += char;
      } else if (char === ',' && depth === 0) {
        if (current.trim()) {
          selectors.push(current.trim());
        }
        current = '';
      } else {
        current += char;
      }
    }

    if (current.trim()) {
      selectors.push(current.trim());
    }

    return selectors;
  }

  /**
   * 解析选择器链
   */
  private static parseSelectorChain(selector: string): SelectorPart[] {
    const parts: SelectorPart[] = [];
    let i = 0;

    while (i < selector.length) {
      // 跳过空白
      while (i < selector.length && /\s/.test(selector[i])) {
        i++;
      }

      if (i >= selector.length) break;

      // 检查组合器
      if (/[>+~]/.test(selector[i])) {
        parts.push({ type: 'combinator', value: selector[i] });
        i++;
        continue;
      }

      // 解析简单选择器
      const part = EnhancedCssSelector.parseSimpleSelector(selector, i);
      if (part) {
        parts.push(part);
        i += EnhancedCssSelector.getSelectorLength(part, selector, i);
      } else {
        i++;
      }
    }

    return parts;
  }

  /**
   * 解析简单选择器
   */
  private static parseSimpleSelector(selector: string, start: number): SelectorPart | null {
    let i = start;
    const char = selector[i];

    // ID 选择器
    if (char === '#') {
      i++;
      const value = EnhancedCssSelector.parseIdentifier(selector, i);
      return { type: 'id', value };
    }

    // Class 选择器
    if (char === '.') {
      i++;
      const value = EnhancedCssSelector.parseIdentifier(selector, i);
      return { type: 'class', value };
    }

    // 属性选择器
    if (char === '[') {
      return EnhancedCssSelector.parseAttributeSelector(selector, i);
    }

    // 伪类选择器
    if (char === ':') {
      return EnhancedCssSelector.parsePseudoSelector(selector, i);
    }

    // 标签选择器
    if (/[a-zA-Z]/.test(char)) {
      const value = EnhancedCssSelector.parseIdentifier(selector, i);
      return { type: 'tag', value: value.toLowerCase() };
    }

    return null;
  }

  /**
   * 解析标识符
   */
  private static parseIdentifier(selector: string, start: number): string {
    let i = start;
    while (i < selector.length && /[a-zA-Z0-9_-]/.test(selector[i])) {
      i++;
    }
    return selector.substring(start, i);
  }

  /**
   * 解析属性选择器
   */
  private static parseAttributeSelector(selector: string, start: number): SelectorPart | null {
    if (selector[start] !== '[') return null;

    let i = start + 1;
    
    // 解析属性名
    const nameStart = i;
    while (i < selector.length && /[a-zA-Z0-9-_:]/.test(selector[i])) {
      i++;
    }
    const attrName = selector.substring(nameStart, i);

    // 跳过空白
    while (i < selector.length && /\s/.test(selector[i])) {
      i++;
    }

    // 检查操作符
    let operator = '';
    if (i < selector.length && /[~|^$*!]?=/.test(selector.substring(i, i + 2))) {
      if (selector.substring(i, i + 2) === '!=' || 
          selector.substring(i, i + 2) === '~=' ||
          selector.substring(i, i + 2) === '|=' ||
          selector.substring(i, i + 2) === '^=' ||
          selector.substring(i, i + 2) === '$=' ||
          selector.substring(i, i + 2) === '*=') {
        operator = selector.substring(i, i + 2);
        i += 2;
      } else if (selector[i] === '=') {
        operator = '=';
        i++;
      }
    }

    // 跳过空白
    while (i < selector.length && /\s/.test(selector[i])) {
      i++;
    }

    // 解析属性值
    let attrValue = '';
    if (i < selector.length && (selector[i] === '"' || selector[i] === "'")) {
      const quote = selector[i];
      i++;
      const valueStart = i;
      while (i < selector.length && selector[i] !== quote) {
        i++;
      }
      attrValue = selector.substring(valueStart, i);
      if (i < selector.length) i++; // 跳过结束引号
    } else if (operator) {
      const valueStart = i;
      while (i < selector.length && /[^\]]/.test(selector[i])) {
        i++;
      }
      attrValue = selector.substring(valueStart, i).trim();
    }

    // 跳过到 ]
    while (i < selector.length && selector[i] !== ']') {
      i++;
    }
    if (i < selector.length) i++; // 跳过 ]

    return {
      type: 'attribute',
      value: attrName,
      argument: `${operator}${attrValue}`
    };
  }

  /**
   * 解析伪类选择器
   */
  private static parsePseudoSelector(selector: string, start: number): SelectorPart | null {
    if (selector[start] !== ':') return null;

    let i = start + 1;
    
    // 检查是否是双冒号（伪元素）
    if (selector[i] === ':') {
      i++;
    }

    // 解析伪类名
    const nameStart = i;
    while (i < selector.length && /[a-zA-Z-]/.test(selector[i])) {
      i++;
    }
    const pseudoName = selector.substring(nameStart, i);

    // 解析参数
    let argument = '';
    if (i < selector.length && selector[i] === '(') {
      i++; // 跳过 (
      const argStart = i;
      let depth = 1;
      while (i < selector.length && depth > 0) {
        if (selector[i] === '(') depth++;
        if (selector[i] === ')') depth--;
        if (depth > 0) i++;
      }
      argument = selector.substring(argStart, i).trim();
      if (i < selector.length) i++; // 跳过 )
    }

    return {
      type: 'pseudo',
      value: pseudoName,
      argument: argument || undefined
    };
  }

  /**
   * 获取选择器长度
   */
  private static getSelectorLength(part: SelectorPart, selector: string, start: number): number {
    switch (part.type) {
      case 'id':
      case 'class':
        return 1 + part.value.length;
      case 'tag':
        return part.value.length;
      case 'attribute':
        // 需要重新解析以获取准确长度
        let i = start;
        if (selector[i] === '[') {
          i++;
          while (i < selector.length && selector[i] !== ']') {
            i++;
          }
          if (i < selector.length) i++;
        }
        return i - start;
      case 'pseudo':
        // 需要重新解析以获取准确长度
        let j = start;
        if (selector[j] === ':') {
          j++;
          if (selector[j] === ':') j++;
          while (j < selector.length && /[a-zA-Z-]/.test(selector[j])) {
            j++;
          }
          if (j < selector.length && selector[j] === '(') {
            let depth = 1;
            j++;
            while (j < selector.length && depth > 0) {
              if (selector[j] === '(') depth++;
              if (selector[j] === ')') depth--;
              if (depth > 0) j++;
            }
            if (j < selector.length) j++;
          }
        }
        return j - start;
      default:
        return 0;
    }
  }

  /**
   * 获取所有元素
   */
  private static getAllElements(root: DOMNode): DOMNode[] {
    const elements: DOMNode[] = [];
    
    for (const child of root.children) {
      if (child.type === 'element') {
        elements.push(child);
        elements.push(...EnhancedCssSelector.getAllElements(child));
      }
    }

    return elements;
  }

  /**
   * 应用组合器
   */
  private static applyCombinator(
    candidates: DOMNode[], 
    combinator: string, 
    context: DOMNode
  ): DOMNode[] {
    const results: DOMNode[] = [];

    switch (combinator) {
      case '>':
        // 子元素选择器
        for (const node of candidates) {
          results.push(...node.childElements);
        }
        break;
      case '+':
        // 相邻兄弟选择器
        for (const node of candidates) {
          const next = node.nextElementSibling;
          if (next) {
            results.push(next);
          }
        }
        break;
      case '~':
        // 通用兄弟选择器
        for (const node of candidates) {
          results.push(...node.siblings);
        }
        break;
      case ' ':
      default:
        // 后代选择器
        for (const node of candidates) {
          results.push(...EnhancedCssSelector.getAllElements(node));
        }
        break;
    }

    return results;
  }

  /**
   * 判断节点是否匹配选择器部分
   */
  private static matchesPart(node: DOMNode, part: SelectorPart): boolean {
    switch (part.type) {
      case 'tag':
        return node.tagName === part.value;
      case 'id':
        return node.id === part.value;
      case 'class':
        return node.hasClass(part.value);
      case 'attribute':
        return EnhancedCssSelector.matchesAttribute(node, part.value, part.argument);
      case 'pseudo':
        return EnhancedCssSelector.matchesPseudo(node, part.value, part.argument);
      default:
        return false;
    }
  }

  /**
   * 判断属性是否匹配
   */
  private static matchesAttribute(
    node: DOMNode, 
    attrName: string, 
    argument?: string
  ): boolean {
    const value = node.getAttribute(attrName);

    if (!argument) {
      return value !== null;
    }

    if (!value) {
      return false;
    }

    const operator = argument.substring(0, 2);
    const attrValue = argument.substring(2);

    switch (operator) {
      case '=':
        return value === attrValue;
      case '~=':
        return value.split(/\s+/).includes(attrValue);
      case '|=':
        return value === attrValue || value.startsWith(`${attrValue}-`);
      case '^=':
        return value.startsWith(attrValue);
      case '$=':
        return value.endsWith(attrValue);
      case '*=':
        return value.includes(attrValue);
      case '!=':
        return value !== attrValue;
      default:
        // 没有操作符，检查是否相等
        return value === argument;
    }
  }

  /**
   * 判断伪类是否匹配
   */
  private static matchesPseudo(
    node: DOMNode, 
    pseudoName: string, 
    argument?: string
  ): boolean {
    switch (pseudoName) {
      case 'first-child':
        return node.isFirstChild;
      case 'last-child':
        return node.isLastChild;
      case 'only-child':
        return node.isOnlyChild;
      case 'first-of-type':
        return node.isFirstOfType;
      case 'last-of-type':
        return node.isLastOfType;
      case 'only-of-type':
        return node.isOnlyOfType;
      case 'empty':
        return node.childElements.length === 0;
      case 'root':
        return node.parent === null;
      case 'nth-child':
        return EnhancedCssSelector.matchesNthChild(node, argument);
      case 'nth-of-type':
        return EnhancedCssSelector.matchesNthOfType(node, argument);
      case 'nth-last-child':
        return EnhancedCssSelector.matchesNthLastChild(node, argument);
      case 'nth-last-of-type':
        return EnhancedCssSelector.matchesNthLastOfType(node, argument);
      case 'not':
        return argument ? !EnhancedCssSelector.matchesSimpleSelector(node, argument) : true;
      case 'has':
        return argument ? EnhancedCssSelector.hasDescendant(node, argument) : false;
      case 'is':
      case 'matches':
        return argument ? EnhancedCssSelector.matchesSimpleSelector(node, argument) : false;
      case 'contains':
        return argument ? node.textContent.includes(argument) : false;
      default:
        return false;
    }
  }

  /**
   * 判断 :nth-child 是否匹配
   */
  private static matchesNthChild(node: DOMNode, argument?: string): boolean {
    if (!argument || !node.parent) return false;

    const index = node.elementIndex;
    return EnhancedCssSelector.matchesNthFormula(index, argument);
  }

  /**
   * 判断 :nth-of-type 是否匹配
   */
  private static matchesNthOfType(node: DOMNode, argument?: string): boolean {
    if (!argument || !node.parent) return false;

    const index = node.elementIndexOfType;
    return EnhancedCssSelector.matchesNthFormula(index, argument);
  }

  /**
   * 判断 :nth-last-child 是否匹配
   */
  private static matchesNthLastChild(node: DOMNode, argument?: string): boolean {
    if (!argument || !node.parent) return false;

    const siblings = node.parent.childElements;
    const index = siblings.length - siblings.indexOf(node);
    return EnhancedCssSelector.matchesNthFormula(index, argument);
  }

  /**
   * 判断 :nth-last-of-type 是否匹配
   */
  private static matchesNthLastOfType(node: DOMNode, argument?: string): boolean {
    if (!argument || !node.parent) return false;

    const siblings = node.parent.childElements.filter(
      s => s.tagName === node.tagName
    );
    const index = siblings.length - siblings.indexOf(node);
    return EnhancedCssSelector.matchesNthFormula(index, argument);
  }

  /**
   * 判断 nth 公式是否匹配
   * 支持：
   * - even, odd
   * - 2n+1, 3n, -n+5 等 an+b 格式
   * - 具体数字如 5
   */
  private static matchesNthFormula(index: number, formula: string): boolean {
    formula = formula.trim().toLowerCase();

    // even
    if (formula === 'even') {
      return index % 2 === 0;
    }

    // odd
    if (formula === 'odd') {
      return index % 2 === 1;
    }

    // 解析 an+b 格式
    const match = formula.match(/^([+-]?\d*)n([+-]?\d*)$/);
    if (match) {
      const a = match[1] === '' ? 1 : 
                match[1] === '-' ? -1 : 
                parseInt(match[1], 10);
      const b = match[2] === '' ? 0 : parseInt(match[2], 10);

      // an+b 公式：index = a*n + b
      // 解出 n = (index - b) / a
      const n = (index - b) / a;
      return n >= 0 && Number.isInteger(n);
    }

    // 纯数字
    const num = parseInt(formula, 10);
    if (!isNaN(num)) {
      return index === num;
    }

    return false;
  }

  /**
   * 判断节点是否匹配简单选择器
   */
  private static matchesSimpleSelector(node: DOMNode, selector: string): boolean {
    const parts = EnhancedCssSelector.parseSelectorChain(selector);

    for (const part of parts) {
      if (part.type === 'combinator') {
        // 简单选择器不应该包含组合器
        return false;
      }
      if (!EnhancedCssSelector.matchesPart(node, part)) {
        return false;
      }
    }

    return true;
  }

  /**
   * 判断节点是否有匹配选择器的后代
   */
  private static hasDescendant(node: DOMNode, selector: string): boolean {
    const descendants = EnhancedCssSelector.getAllElements(node);

    for (const descendant of descendants) {
      if (EnhancedCssSelector.matchesSimpleSelector(descendant, selector)) {
        return true;
      }
    }

    return false;
  }
}

export default EnhancedCssSelector;
