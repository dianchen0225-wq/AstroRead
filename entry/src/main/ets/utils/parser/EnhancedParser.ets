/**
 * EnhancedParser - 统一的增强版解析器
 * 整合 DOMNode、EnhancedHTMLParser、EnhancedCssSelector
 * 提供完整的 HTML 解析和 CSS 选择器功能
 */

import { DOMNode } from './DOMNode';
import { EnhancedHTMLParser } from './EnhancedHTMLParser';
import { EnhancedCssSelector } from './EnhancedCssSelector';
import { Logger } from "../performance/Logger";

export interface EnhancedParseResult {
  nodes: DOMNode[];
  html: string[];
  text: string[];
}

export class EnhancedParser {
  private static readonly TAG = 'EnhancedParser';
  private static instance: EnhancedParser;
  private htmlParser: EnhancedHTMLParser;

  private constructor() {
    this.htmlParser = new EnhancedHTMLParser();
  }

  static getInstance(): EnhancedParser {
    if (!EnhancedParser.instance) {
      EnhancedParser.instance = new EnhancedParser();
    }
    return EnhancedParser.instance;
  }

  /**
   * 解析 HTML 并查询选择器
   */
  parseAndSelect(html: string, selector: string): EnhancedParseResult {
    try {
      // 解析 HTML
      const root = this.htmlParser.parse(html);
      
      // 查询选择器
      const nodes = EnhancedCssSelector.querySelectorAll(root, selector);
      
      return {
        nodes,
        html: nodes.map(n => n.outerHTML),
        text: nodes.map(n => n.textContent)
      };
    } catch (error) {
      Logger.error(EnhancedParser.TAG, `解析失败: ${error}`);
      return { nodes: [], html: [], text: [] };
    }
  }

  /**
   * 仅解析 HTML
   */
  parse(html: string): DOMNode {
    return this.htmlParser.parse(html);
  }

  /**
   * 在已解析的 DOM 上查询
   */
  select(root: DOMNode, selector: string): DOMNode[] {
    return EnhancedCssSelector.querySelectorAll(root, selector);
  }

  /**
   * 提取属性值
   */
  extractAttribute(html: string, selector: string, attrName: string): string {
    const result = this.parseAndSelect(html, selector);
    if (result.nodes.length === 0) return '';
    
    return result.nodes[0].getAttribute(attrName) || '';
  }

  /**
   * 提取文本内容
   */
  extractText(html: string, selector: string): string {
    const result = this.parseAndSelect(html, selector);
    if (result.nodes.length === 0) return '';
    
    return result.nodes[0].textContent;
  }

  /**
   * 提取 HTML 内容
   */
  extractHtml(html: string, selector: string): string {
    const result = this.parseAndSelect(html, selector);
    if (result.nodes.length === 0) return '';
    
    return result.nodes[0].innerHTML;
  }

  /**
   * 批量提取
   */
  extractAll(html: string, selector: string): string[] {
    const result = this.parseAndSelect(html, selector);
    return result.text;
  }
}

export default EnhancedParser.getInstance();
