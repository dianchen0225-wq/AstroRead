import { Logger } from '../Logger';
import { Result, ErrorCode } from '../../core/Result';
import { BaseParser, IParser, ParserResult, ParserType, ParseOptions } from '../IParser';

interface CssNode {
  type: string;
  tagName?: string;
  attributes?: Map<string, string>;
  children?: CssNode[];
  content?: string;
  index?: number;
}

export class CssParser extends BaseParser {
  readonly type: ParserType = ParserType.CSS;
  readonly name: string = 'CssParser';
  private static readonly TAG = 'CssParser';

  canHandle(rule: string): boolean {
    if (!rule) return false;
    const trimmed = rule.trim();
    return trimmed.startsWith('@css:') || 
           trimmed.startsWith('css:') ||
           this.looksLikeCssSelector(trimmed);
  }

  private looksLikeCssSelector(rule: string): boolean {
    if (rule.startsWith('//') || rule.startsWith('@') || rule.startsWith('<')) {
      return false;
    }
    const cssPattern = /^[.#]?[a-zA-Z_][a-zA-Z0-9_-]*(\s*[>+~]?\s*[.#]?[a-zA-Z_][a-zA-Z0-9_-]*)*(\[[^\]]+\])*(?::[a-zA-Z-]+(\([^)]*\))?)?(\s*,\s*[.#]?[a-zA-Z_][a-zA-Z0-9_-]*)*$/;
    return cssPattern.test(rule);
  }

  parse(html: string, rule: string, _options?: ParseOptions): Result<ParserResult> {
    if (!this.validateInput(html, rule)) {
      return this.createErrorResult('CSS parse: empty input');
    }

    try {
      let selector = rule.trim();
      if (selector.startsWith('@css:')) {
        selector = selector.substring(5).trim();
      } else if (selector.startsWith('css:')) {
        selector = selector.substring(4).trim();
      }

      const nodes = this.parseHtmlToNodes(html);
      const matchedNodes = this.selectNodes(nodes, selector);
      const values = matchedNodes.map(node => this.getNodeContent(node));

      return Result.ok(ParserResult.fromValues(values));
    } catch (error) {
      Logger.error(CssParser.TAG, `CSS解析失败: ${error}`);
      return this.createErrorResult(
        `CSS parse failed: ${error}`,
        ErrorCode.PARSE_CSS_SELECTOR_ERROR,
        error instanceof Error ? error.stack : String(error)
      );
    }
  }

  private parseHtmlToNodes(html: string): CssNode[] {
    const nodes: CssNode[] = [];
    let pos = 0;

    while (pos < html.length) {
      const openMatch = html.substring(pos).match(/<([a-zA-Z][a-zA-Z0-9]*)/);
      if (!openMatch) break;

      const tagName = openMatch[1].toLowerCase();
      const tagStart = pos + openMatch.index!;

      const closeBracket = html.indexOf('>', tagStart + openMatch[0].length);
      if (closeBracket === -1) break;

      const attrString = html.substring(tagStart + openMatch[0].length, closeBracket);
      const attributes = this.parseAttributes(attrString);

      const isSelfClosing = html[closeBracket - 1] === '/' || this.isVoidElement(tagName);

      let content = '';
      let children: CssNode[] = [];
      let tagEnd = closeBracket + 1;

      if (!isSelfClosing) {
        const closeTag = `</${tagName}>`;
        const closeIndex = this.findCloseTag(html, tagName, closeBracket + 1);
        if (closeIndex !== -1) {
          const innerHtml = html.substring(closeBracket + 1, closeIndex);
          children = this.parseHtmlToNodes(innerHtml);
          content = this.extractTextContent(innerHtml);
          tagEnd = closeIndex + closeTag.length;
        }
      }

      nodes.push({
        type: 'element',
        tagName,
        attributes,
        children,
        content,
        index: nodes.length
      });

      pos = tagEnd;
    }

    return nodes;
  }

  private findCloseTag(html: string, tagName: string, start: number): number {
    const openTag = `<${tagName}`;
    const closeTag = `</${tagName}>`;
    let depth = 1;
    let pos = start;

    while (pos < html.length && depth > 0) {
      const nextOpen = html.indexOf(openTag, pos);
      const nextClose = html.indexOf(closeTag, pos);

      if (nextClose === -1) return -1;

      if (nextOpen !== -1 && nextOpen < nextClose) {
        const afterOpen = html.indexOf('>', nextOpen);
        if (afterOpen !== -1 && html[afterOpen - 1] !== '/') {
          depth++;
        }
        pos = afterOpen + 1;
      } else {
        depth--;
        if (depth === 0) {
          return nextClose;
        }
        pos = nextClose + closeTag.length;
      }
    }

    return -1;
  }

  private parseAttributes(attrString: string): Map<string, string> {
    const attributes = new Map<string, string>();
    const attrPattern = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*["']([^"']*)["']/g;
    let match: RegExpExecArray | null;

    while ((match = attrPattern.exec(attrString)) !== null) {
      attributes.set(match[1].toLowerCase(), match[2]);
    }

    return attributes;
  }

  private isVoidElement(tagName: string): boolean {
    const voidElements = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'];
    return voidElements.includes(tagName);
  }

  private extractTextContent(html: string): string {
    return html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<[^>]+>/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private selectNodes(nodes: CssNode[], selector: string): CssNode[] {
    const selectors = selector.split(',').map(s => s.trim());
    const results: CssNode[] = [];

    for (const sel of selectors) {
      const matched = this.selectWithSingleSelector(nodes, sel);
      for (const node of matched) {
        if (!results.includes(node)) {
          results.push(node);
        }
      }
    }

    return results;
  }

  private selectWithSingleSelector(nodes: CssNode[], selector: string): CssNode[] {
    const parts = this.parseSelectorParts(selector);
    if (parts.length === 0) return [];

    let currentNodes = this.flattenNodes(nodes);

    for (const part of parts) {
      currentNodes = this.filterNodes(currentNodes, part);
      if (currentNodes.length === 0) break;
    }

    return currentNodes;
  }

  private parseSelectorParts(selector: string): string[] {
    const parts: string[] = [];
    let current = '';
    let i = 0;

    while (i < selector.length) {
      const char = selector[i];

      if (char === '>' || char === '+' || char === '~') {
        if (current.trim()) {
          parts.push(current.trim());
        }
        parts.push(char);
        current = '';
        i++;
        while (i < selector.length && selector[i] === ' ') i++;
      } else if (char === ' ') {
        if (current.trim()) {
          parts.push(current.trim());
          current = '';
        }
        i++;
      } else {
        current += char;
        i++;
      }
    }

    if (current.trim()) {
      parts.push(current.trim());
    }

    return parts;
  }

  private flattenNodes(nodes: CssNode[]): CssNode[] {
    const result: CssNode[] = [];
    for (const node of nodes) {
      result.push(node);
      if (node.children) {
        result.push(...this.flattenNodes(node.children));
      }
    }
    return result;
  }

  private filterNodes(nodes: CssNode[], selector: string): CssNode[] {
    if (selector === '>' || selector === '+' || selector === '~') {
      return nodes;
    }

    return nodes.filter(node => this.matchesSelector(node, selector));
  }

  private matchesSelector(node: CssNode, selector: string): boolean {
    if (!node.tagName) return false;

    let currentSelector = selector;

    const pseudoMatch = currentSelector.match(/:([a-zA-Z-]+)(?:\(([^)]*)\))?$/);
    let pseudo: string | null = null;
    let pseudoArg: string | null = null;

    if (pseudoMatch) {
      pseudo = pseudoMatch[1];
      pseudoArg = pseudoMatch[2] ?? null;
      currentSelector = currentSelector.substring(0, currentSelector.length - pseudoMatch[0].length);
    }

    const attrMatch = currentSelector.match(/\[([^\]=]+)(?:=([^\]]+))?\]$/);
    let attrName: string | null = null;
    let attrValue: string | null = null;

    if (attrMatch) {
      attrName = attrMatch[1];
      attrValue = attrMatch[2] ? attrMatch[2].replace(/["']/g, '') : null;
      currentSelector = currentSelector.substring(0, currentSelector.length - attrMatch[0].length);
    }

    let tagName = '';
    let classes: string[] = [];
    let id: string | null = null;

    const parts = currentSelector.split(/([.#])/);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (part === '.') {
        classes.push(parts[++i]);
      } else if (part === '#') {
        id = parts[++i];
      } else if (part) {
        tagName = part.toLowerCase();
      }
    }

    if (tagName && node.tagName !== tagName) {
      return false;
    }

    if (id) {
      const nodeId = node.attributes?.get('id');
      if (nodeId !== id) return false;
    }

    if (classes.length > 0) {
      const nodeClass = node.attributes?.get('class') ?? '';
      const nodeClasses = nodeClass.split(/\s+/);
      for (const cls of classes) {
        if (!nodeClasses.includes(cls)) return false;
      }
    }

    if (attrName) {
      const value = node.attributes?.get(attrName);
      if (value === undefined) return false;
      if (attrValue !== null && value !== attrValue) return false;
    }

    if (pseudo) {
      if (!this.matchesPseudo(node, pseudo, pseudoArg)) return false;
    }

    return true;
  }

  private matchesPseudo(node: CssNode, pseudo: string, arg: string | null): boolean {
    switch (pseudo) {
      case 'first-child':
        return node.index === 0;
      case 'last-child':
        return true;
      case 'nth-child':
        if (arg) {
          const n = parseInt(arg, 10);
          return node.index === n - 1;
        }
        return false;
      case 'not':
        if (arg) {
          return !this.matchesSelector(node, arg);
        }
        return true;
      default:
        return true;
    }
  }

  private getNodeContent(node: CssNode): string {
    if (node.content) {
      return node.content;
    }
    if (node.children && node.children.length > 0) {
      return node.children.map(c => this.getNodeContent(c)).join(' ');
    }
    return '';
  }

  selectAttribute(html: string, selector: string, attrName: string): string {
    const result = this.parse(html, selector);
    if (result.isErr() || !result.data?.hasValue()) {
      return '';
    }

    const nodes = this.parseHtmlToNodes(html);
    const matchedNodes = this.selectNodes(nodes, selector);

    if (matchedNodes.length > 0 && matchedNodes[0].attributes) {
      return matchedNodes[0].attributes.get(attrName) ?? '';
    }

    return '';
  }
}

export default CssParser;
