/**
 * DOMNode - 增强版 DOM 节点类
 * 支持完整的 DOM 树操作和遍历
 */

export interface DOMNodeOptions {
  tagName?: string;
  attributes?: Map<string, string>;
  content?: string;
  parent?: DOMNode;
  index?: number;
}

export class DOMNode {
  type: 'element' | 'text' | 'comment' = 'element';
  tagName: string = '';
  attributes: Map<string, string> = new Map();
  children: DOMNode[] = [];
  content: string = '';
  parent: DOMNode | null = null;
  index: number = 0;
  
  // 缓存相关
  private _textContent: string | null = null;
  private _innerHTML: string | null = null;

  constructor(options: DOMNodeOptions = {}) {
    if (options.tagName) this.tagName = options.tagName.toLowerCase();
    if (options.attributes) this.attributes = new Map(options.attributes);
    if (options.content !== undefined) this.content = options.content;
    if (options.parent !== undefined) this.parent = options.parent || null;
    if (options.index !== undefined) this.index = options.index;
  }

  /**
   * 创建文本节点
   */
  static createText(content: string): DOMNode {
    const node = new DOMNode();
    node.type = 'text';
    node.content = content;
    return node;
  }

  /**
   * 创建注释节点
   */
  static createComment(content: string): DOMNode {
    const node = new DOMNode();
    node.type = 'comment';
    node.content = content;
    return node;
  }

  /**
   * 添加子节点
   */
  appendChild(child: DOMNode): void {
    child.parent = this;
    child.index = this.children.length;
    this.children.push(child);
    this._invalidateCache();
  }

  /**
   * 获取文本内容
   */
  get textContent(): string {
    if (this._textContent !== null) {
      return this._textContent;
    }

    if (this.type === 'text') {
      this._textContent = this.content;
    } else if (this.type === 'element') {
      this._textContent = this.children
        .map(child => child.textContent)
        .join('');
    } else {
      this._textContent = '';
    }

    return this._textContent;
  }

  /**
   * 获取 innerHTML
   */
  get innerHTML(): string {
    if (this._innerHTML !== null) {
      return this._innerHTML;
    }

    this._innerHTML = this.children
      .map(child => child.outerHTML)
      .join('');

    return this._innerHTML;
  }

  /**
   * 获取 outerHTML
   */
  get outerHTML(): string {
    if (this.type === 'text') {
      return this.escapeHtml(this.content);
    }
    
    if (this.type === 'comment') {
      return `<!--${this.content}-->`;
    }

    const attrs = Array.from(this.attributes.entries())
      .map(([key, value]) => `${key}="${this.escapeHtml(value)}"`)
      .join(' ');

    const attrStr = attrs ? ' ' + attrs : '';
    
    if (this.isVoidElement) {
      return `<${this.tagName}${attrStr}>`;
    }

    return `<${this.tagName}${attrStr}>${this.innerHTML}</${this.tagName}>`;
  }

  /**
   * 获取父元素（元素类型的父节点）
   */
  get parentElement(): DOMNode | null {
    let p = this.parent;
    while (p && p.type !== 'element') {
      p = p.parent;
    }
    return p;
  }

  /**
   * 获取所有子元素（过滤文本节点）
   */
  get childElements(): DOMNode[] {
    return this.children.filter(child => child.type === 'element');
  }

  /**
   * 获取第一个子元素
   */
  get firstElementChild(): DOMNode | null {
    return this.childElements[0] || null;
  }

  /**
   * 获取最后一个子元素
   */
  get lastElementChild(): DOMNode | null {
    const elements = this.childElements;
    return elements[elements.length - 1] || null;
  }

  /**
   * 获取下一个兄弟元素
   */
  get nextElementSibling(): DOMNode | null {
    if (!this.parent) return null;
    
    const siblings = this.parent.childElements;
    const index = siblings.findIndex(s => s === this);
    return siblings[index + 1] || null;
  }

  /**
   * 获取上一个兄弟元素
   */
  get previousElementSibling(): DOMNode | null {
    if (!this.parent) return null;
    
    const siblings = this.parent.childElements;
    const index = siblings.findIndex(s => s === this);
    return siblings[index - 1] || null;
  }

  /**
   * 获取兄弟元素列表
   */
  get siblings(): DOMNode[] {
    if (!this.parent) return [];
    return this.parent.childElements.filter(s => s !== this);
  }

  /**
   * 判断是否是空元素（void element）
   */
  get isVoidElement(): boolean {
    const voidElements = [
      'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 
      'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'
    ];
    return voidElements.includes(this.tagName);
  }

  /**
   * 获取指定属性值
   */
  getAttribute(name: string): string | null {
    return this.attributes.get(name.toLowerCase()) || null;
  }

  /**
   * 设置属性值
   */
  setAttribute(name: string, value: string): void {
    this.attributes.set(name.toLowerCase(), value);
    this._invalidateCache();
  }

  /**
   * 判断是否包含指定 class
   */
  hasClass(className: string): boolean {
    const classes = this.classList;
    return classes.includes(className);
  }

  /**
   * 获取 class 列表
   */
  get classList(): string[] {
    const classAttr = this.attributes.get('class') || '';
    return classAttr.split(/\s+/).filter(c => c.length > 0);
  }

  /**
   * 获取 id
   */
  get id(): string {
    return this.attributes.get('id') || '';
  }

  /**
   * 查找最近的匹配选择器的祖先元素
   */
  closest(selector: string): DOMNode | null {
    let current: DOMNode | null = this;
    while (current) {
      if (current.matches(selector)) {
        return current;
      }
      current = current.parentElement;
    }
    return null;
  }

  /**
   * 判断是否匹配选择器（简化版）
   */
  matches(selector: string): boolean {
    // 简化实现，只支持基础选择器
    if (selector.startsWith('#')) {
      return this.id === selector.substring(1);
    }
    if (selector.startsWith('.')) {
      return this.hasClass(selector.substring(1));
    }
    return this.tagName === selector.toLowerCase();
  }

  /**
   * 查找所有后代元素
   */
  querySelectorAll(selector: string): DOMNode[] {
    const results: DOMNode[] = [];
    
    for (const child of this.children) {
      if (child.type === 'element') {
        if (child.matches(selector)) {
          results.push(child);
        }
        results.push(...child.querySelectorAll(selector));
      }
    }
    
    return results;
  }

  /**
   * 查找第一个匹配的后代元素
   */
  querySelector(selector: string): DOMNode | null {
    for (const child of this.children) {
      if (child.type === 'element') {
        if (child.matches(selector)) {
          return child;
        }
        const found = child.querySelector(selector);
        if (found) return found;
      }
    }
    return null;
  }

  /**
   * 获取第 n 个子元素（支持负数，从后往前）
   */
  nthChild(n: number): DOMNode | null {
    const elements = this.childElements;
    if (n < 0) {
      return elements[elements.length + n] || null;
    }
    return elements[n] || null;
  }

  /**
   * 获取在所有兄弟元素中的位置（从1开始）
   */
  get elementIndex(): number {
    if (!this.parent) return 0;
    const siblings = this.parent.childElements;
    return siblings.findIndex(s => s === this) + 1;
  }

  /**
   * 获取同类型兄弟元素中的位置（从1开始）
   */
  get elementIndexOfType(): number {
    if (!this.parent) return 0;
    const siblings = this.parent.childElements.filter(
      s => s.tagName === this.tagName
    );
    return siblings.findIndex(s => s === this) + 1;
  }

  /**
   * 判断是否是第一个子元素
   */
  get isFirstChild(): boolean {
    if (!this.parent) return false;
    return this.parent.childElements[0] === this;
  }

  /**
   * 判断是否是最后一个子元素
   */
  get isLastChild(): boolean {
    if (!this.parent) return false;
    const elements = this.parent.childElements;
    return elements[elements.length - 1] === this;
  }

  /**
   * 判断是否是唯一的子元素
   */
  get isOnlyChild(): boolean {
    if (!this.parent) return false;
    return this.parent.childElements.length === 1;
  }

  /**
   * 判断是否是第一个同类型子元素
   */
  get isFirstOfType(): boolean {
    if (!this.parent) return false;
    const siblings = this.parent.childElements.filter(
      s => s.tagName === this.tagName
    );
    return siblings[0] === this;
  }

  /**
   * 判断是否是最后一个同类型子元素
   */
  get isLastOfType(): boolean {
    if (!this.parent) return false;
    const siblings = this.parent.childElements.filter(
      s => s.tagName === this.tagName
    );
    return siblings[siblings.length - 1] === this;
  }

  /**
   * 判断是否是唯一的同类型子元素
   */
  get isOnlyOfType(): boolean {
    if (!this.parent) return false;
    const siblings = this.parent.childElements.filter(
      s => s.tagName === this.tagName
    );
    return siblings.length === 1;
  }

  /**
   * 使缓存失效
   */
  private _invalidateCache(): void {
    this._textContent = null;
    this._innerHTML = null;
    
    // 向上使父节点缓存失效
    let current = this.parent;
    while (current) {
      current._textContent = null;
      current._innerHTML = null;
      current = current.parent;
    }
  }

  /**
   * HTML 转义
   */
  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /**
   * 克隆节点
   */
  cloneNode(deep: boolean = false): DOMNode {
    const cloned = new DOMNode({
      tagName: this.tagName,
      attributes: new Map(this.attributes),
      content: this.content,
      index: this.index
    });
    cloned.type = this.type;

    if (deep && this.children.length > 0) {
      for (const child of this.children) {
        cloned.appendChild(child.cloneNode(true));
      }
    }

    return cloned;
  }

  /**
   * 转换为 JSON（用于调试）
   */
  toJSON(): object {
    return {
      type: this.type,
      tagName: this.tagName,
      attributes: Object.fromEntries(this.attributes),
      content: this.content,
      index: this.index,
      children: this.children.map(c => c.toJSON())
    };
  }
}

export default DOMNode;
