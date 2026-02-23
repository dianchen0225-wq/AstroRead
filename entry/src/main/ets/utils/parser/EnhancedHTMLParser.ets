/**
 * EnhancedHTMLParser - 增强版 HTML 解析器
 * 支持完整的 DOM 树构建和高级 CSS 选择器
 */

import { DOMNode } from './DOMNode';

export interface ParseOptions {
  ignoreWhitespace?: boolean;
  decodeEntities?: boolean;
}

export class EnhancedHTMLParser {
  private html: string = '';
  private pos: number = 0;
  private options: ParseOptions;

  constructor(options: ParseOptions = {}) {
    this.options = {
      ignoreWhitespace: options.ignoreWhitespace !== undefined ? options.ignoreWhitespace : true,
      decodeEntities: options.decodeEntities !== undefined ? options.decodeEntities : true
    };
  }

  /**
   * 解析 HTML 字符串为 DOM 树
   */
  parse(html: string): DOMNode {
    this.html = html;
    this.pos = 0;

    const root = new DOMNode({ tagName: 'root' });
    
    while (this.pos < this.html.length) {
      const node = this.parseNode();
      if (node) {
        root.appendChild(node);
      }
    }

    return root;
  }

  /**
   * 解析单个节点
   */
  private parseNode(): DOMNode | null {
    this.skipWhitespace();

    if (this.pos >= this.html.length) {
      return null;
    }

    // 处理注释节点
    if (this.peek(4) === '<!--') {
      return this.parseComment();
    }

    // 处理文本节点
    if (this.peek(1) !== '<') {
      return this.parseText();
    }

    // 处理元素节点
    if (this.peek(1) === '<') {
      return this.parseElement();
    }

    return null;
  }

  /**
   * 解析注释节点
   */
  private parseComment(): DOMNode | null {
    if (this.peek(4) !== '<!--') {
      return null;
    }

    this.pos += 4; // 跳过 <!--
    const start = this.pos;

    const endIndex = this.html.indexOf('-->', this.pos);
    if (endIndex === -1) {
      // 未找到结束标记，视为文本
      this.pos = start;
      return this.parseText();
    }

    const content = this.html.substring(this.pos, endIndex);
    this.pos = endIndex + 3; // 跳过 -->

    return DOMNode.createComment(content);
  }

  /**
   * 解析文本节点
   */
  private parseText(): DOMNode | null {
    const start = this.pos;

    while (this.pos < this.html.length && this.peek(1) !== '<') {
      this.pos++;
    }

    if (this.pos === start) {
      return null;
    }

    let content = this.html.substring(start, this.pos);

    // 解码 HTML 实体
    if (this.options.decodeEntities) {
      content = this.decodeEntities(content);
    }

    // 如果忽略空白且内容全是空白，返回 null
    if (this.options.ignoreWhitespace && !content.trim()) {
      return null;
    }

    return DOMNode.createText(content);
  }

  /**
   * 解析元素节点
   */
  private parseElement(): DOMNode | null {
    if (this.peek(1) !== '<') {
      return null;
    }

    this.pos++; // 跳过 <

    // 解析标签名
    const tagName = this.parseTagName();
    if (!tagName) {
      return null;
    }

    // 解析属性
    const attributes = this.parseAttributes();

    this.skipWhitespace();

    // 检查是否是自闭合标签
    const isSelfClosing = this.peek(1) === '/' || this.isVoidElement(tagName);
    
    if (this.peek(1) === '/') {
      this.pos++; // 跳过 /
    }

    if (this.peek(1) === '>') {
      this.pos++; // 跳过 >
    }

    const node = new DOMNode({
      tagName,
      attributes
    });

    // 如果不是自闭合标签，解析子节点
    if (!isSelfClosing) {
      this.parseChildren(node, tagName);
    }

    return node;
  }

  /**
   * 解析标签名
   */
  private parseTagName(): string {
    const start = this.pos;

    // 标签名必须以字母开头
    if (!/[a-zA-Z]/.test(this.peek(1))) {
      return '';
    }

    while (this.pos < this.html.length) {
      const c = this.peek(1);
      if (/[a-zA-Z0-9-]/.test(c)) {
        this.pos++;
      } else {
        break;
      }
    }

    return this.html.substring(start, this.pos).toLowerCase();
  }

  /**
   * 解析属性
   */
  private parseAttributes(): Map<string, string> {
    const attributes = new Map<string, string>();

    while (this.pos < this.html.length) {
      this.skipWhitespace();

      const c = this.peek(1);
      
      // 遇到 / 或 > 结束属性解析
      if (c === '/' || c === '>') {
        break;
      }

      // 解析属性名
      const attrName = this.parseAttributeName();
      if (!attrName) {
        break;
      }

      this.skipWhitespace();

      let attrValue = '';
      
      // 检查是否有属性值
      if (this.peek(1) === '=') {
        this.pos++; // 跳过 =
        this.skipWhitespace();
        attrValue = this.parseAttributeValue();
      }

      attributes.set(attrName.toLowerCase(), attrValue);
    }

    return attributes;
  }

  /**
   * 解析属性名
   */
  private parseAttributeName(): string {
    const start = this.pos;

    while (this.pos < this.html.length) {
      const c = this.peek(1);
      if (/[a-zA-Z0-9-_:]/.test(c)) {
        this.pos++;
      } else {
        break;
      }
    }

    return this.html.substring(start, this.pos);
  }

  /**
   * 解析属性值
   */
  private parseAttributeValue(): string {
    this.skipWhitespace();

    const quote = this.peek(1);
    
    if (quote === '"' || quote === "'") {
      this.pos++; // 跳过引号
      const start = this.pos;

      while (this.pos < this.html.length && this.peek(1) !== quote) {
        this.pos++;
      }

      const value = this.html.substring(start, this.pos);
      
      if (this.peek(1) === quote) {
        this.pos++; // 跳过结束引号
      }

      return this.decodeEntities(value);
    }

    // 无引号属性值
    const start = this.pos;
    while (this.pos < this.html.length) {
      const c = this.peek(1);
      if (/[^\s>/]/.test(c)) {
        this.pos++;
      } else {
        break;
      }
    }

    return this.html.substring(start, this.pos);
  }

  /**
   * 解析子节点
   */
  private parseChildren(parent: DOMNode, tagName: string): void {
    while (this.pos < this.html.length) {
      // 检查是否是结束标签
      if (this.peek(2) === '</') {
        this.pos += 2; // 跳过 </
        
        const endTagName = this.parseTagName();
        
        // 跳过到 >
        while (this.pos < this.html.length && this.peek(1) !== '>') {
          this.pos++;
        }
        
        if (this.peek(1) === '>') {
          this.pos++; // 跳过 >
        }

        // 如果结束标签匹配，结束当前元素
        if (endTagName === tagName) {
          return;
        }

        // 标签不匹配，继续解析（容错处理）
        continue;
      }

      const node = this.parseNode();
      if (node) {
        parent.appendChild(node);
      }
    }
  }

  /**
   * 查看接下来的 n 个字符
   */
  private peek(n: number): string {
    return this.html.substring(this.pos, this.pos + n);
  }

  /**
   * 跳过空白字符
   */
  private skipWhitespace(): void {
    while (this.pos < this.html.length && /\s/.test(this.peek(1))) {
      this.pos++;
    }
  }

  /**
   * 判断是否是空元素
   */
  private isVoidElement(tagName: string): boolean {
    const voidElements = [
      'area', 'base', 'br', 'col', 'embed', 'hr', 'img',
      'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'
    ];
    return voidElements.includes(tagName.toLowerCase());
  }

  /**
   * 解码 HTML 实体
   */
  private decodeEntities(text: string): string {
    const entities: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
      '&copy;': '©',
      '&reg;': '®',
      '&trade;': '™',
      '&hellip;': '…',
      '&mdash;': '—',
      '&ndash;': '–',
      '&ldquo;': '"',
      '&rdquo;': '"',
      '&lsquo;': '\'',
      '&rsquo;': '\'',
      '&laquo;': '«',
      '&raquo;': '»'
    };

    // 处理命名实体
    let result = text;
    const entries = Object.entries(entities);
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const entity = entry[0];
      const char = entry[1];
      result = result.replace(new RegExp(entity, 'g'), char);
    }

    // 处理数字实体 &#123;
    result = result.replace(/&#(\d+);/g, (match: string, code: string) => {
      return String.fromCharCode(parseInt(code, 10));
    });

    // 处理十六进制实体 &#x7B;
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (match: string, code: string) => {
      return String.fromCharCode(parseInt(code, 16));
    });

    return result;
  }

  /**
   * 静态方法：快速解析 HTML
   */
  static parse(html: string, options?: ParseOptions): DOMNode {
    const parser = new EnhancedHTMLParser(options);
    return parser.parse(html);
  }

  /**
   * 静态方法：解析并查询
   */
  static parseAndQuery(html: string, selector: string): DOMNode[] {
    const parser = new EnhancedHTMLParser();
    const root = parser.parse(html);
    return root.querySelectorAll(selector);
  }
}

export default EnhancedHTMLParser;
