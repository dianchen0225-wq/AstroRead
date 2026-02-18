/**
 * HTMLParserAdapter - HTML 解析器适配器
 * 支持标准 HTML、XHTML、HTML5
 */

import {
  ParserType,
  ParseOptions,
  ParseResult,
  FormatOptions,
  ParseErrorInfo,
  ParseWarningInfo,
  HtmlNode,
  ParseMetadata
} from '../../interfaces/IParser';
import { CachingParserAdapter } from '../ParserAdapter';
import { ParserError, ParserWarning, ParseResultBuilder } from '../ParserError';
import { EntityDecoder } from '../utils/EntityDecoder';
import { PositionTracker } from '../utils/PositionTracker';

class ParseHTMLContentResult {
  node: HtmlNode;
  warnings: ParseWarningInfo[];

  constructor(node: HtmlNode, warnings: ParseWarningInfo[]) {
    this.node = node;
    this.warnings = warnings;
  }
}

class ValidateResult {
  errors: ParseErrorInfo[] = [];
  warnings: ParseWarningInfo[] = [];

  constructor(errors: ParseErrorInfo[], warnings: ParseWarningInfo[]) {
    this.errors = errors;
    this.warnings = warnings;
  }
}

export class HTMLParserAdapter extends CachingParserAdapter<HtmlNode> {
  readonly type = ParserType.HTML;
  readonly name = 'HTMLParser';
  readonly version = '1.0.0';
  readonly supportedExtensions = ['html', 'htm', 'xhtml'];
  readonly priority = 80;

  private selfClosingTags = new Set([
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr'
  ]);

  protected async doParse(content: string, options: ParseOptions): Promise<ParseResult<HtmlNode>> {
    return this.parseHTML(content, options);
  }

  protected doParseSync(content: string, options: ParseOptions): ParseResult<HtmlNode> {
    return this.parseHTML(content, options);
  }

  private parseHTML(content: string, options: ParseOptions): ParseResult<HtmlNode> {
    const emptyNode: HtmlNode = { type: 'text', value: '' };
    const builder = new ParseResultBuilder<HtmlNode>(emptyNode);
    
    // 显式定义metadata对象
    const metadata: Partial<ParseMetadata> = {
      parserType: this.type,
      version: this.version
    };
    builder.setMetadata(metadata);

    try {
      const parseResult = this.parseHTMLContent(content, options);
      const node = parseResult.node;
      const warnings = parseResult.warnings;

      builder.setData(node);
      builder.setStatus('success' as never);

      for (let i = 0; i < warnings.length; i++) {
        const warning = warnings[i];
        builder.addWarning(new ParserWarning(warning.code, warning.message));
      }
    } catch (error) {
      const parseError = this.handleParseError(error as Error);
      builder.addError(parseError);
      builder.setStatus('failed' as never);
    }

    return builder.build();
  }

  private parseHTMLContent(content: string, options: ParseOptions): ParseHTMLContentResult {
    const warnings: ParseWarningInfo[] = [];
    const pos = new PositionTracker();

    this.skipWhitespace(content, pos);

    const node = this.parseNode(content, pos, options.maxDepth ?? 100, 0, warnings);

    const result = new ParseHTMLContentResult(node, warnings);
    return result;
  }

  private parseNode(
    content: string,
    pos: PositionTracker,
    maxDepth: number,
    currentDepth: number,
    warnings: ParseWarningInfo[]
  ): HtmlNode {
    this.skipWhitespace(content, pos);

    if (pos.index >= content.length) {
      const emptyNode: HtmlNode = { type: 'text', value: '' };
      return emptyNode;
    }

    if (currentDepth > maxDepth) {
      throw ParserError.syntaxError(
        this.type,
        `Maximum depth exceeded: ${maxDepth}`,
        undefined,
        undefined,
        `Current depth: ${currentDepth}`
      );
    }

    if (content[pos.index] === '<') {
      return this.parseElement(content, pos, maxDepth, currentDepth, warnings);
    }

    return this.parseText(content, pos);
  }

  private parseElement(
    content: string,
    pos: PositionTracker,
    maxDepth: number,
    currentDepth: number,
    warnings: ParseWarningInfo[]
  ): HtmlNode {
    pos.index++;

    if (content.substring(pos.index, pos.index + 3) === '!--') {
      return this.parseComment(content, pos);
    }

    if (content.substring(pos.index, pos.index + 8).toUpperCase() === '!DOCTYPE') {
      return this.parseDoctype(content, pos);
    }

    const tagName = this.parseTagName(content, pos).toLowerCase();
    const attributes = this.parseAttributes(content, pos);

    this.skipWhitespace(content, pos);

    const isSelfClosing = this.selfClosingTags.has(tagName) ||
      (content[pos.index] === '/' && content[pos.index + 1] === '>');

    if (isSelfClosing) {
      if (content[pos.index] === '/') {
        pos.index++;
      }
      if (content[pos.index] === '>') {
        pos.index++;
      }

      // 显式定义node对象
      const node: HtmlNode = {
        type: 'element',
        name: tagName,
        tagName,
        attributes,
        children: []
      };

      return node;
    }

    if (content[pos.index] !== '>') {
      throw ParserError.syntaxError(
        this.type,
        'Expected > at end of opening tag',
        undefined,
        undefined,
        `Tag: ${tagName}`
      );
    }
    pos.index++;

    const children: HtmlNode[] = [];
    let innerHTML = '';

    while (pos.index < content.length) {
      const textStart = pos.index;

      while (pos.index < content.length && content[pos.index] !== '<') {
        pos.index++;
      }

      if (pos.index > textStart) {
        innerHTML += content.substring(textStart, pos.index);
      }

      if (content.substring(pos.index, pos.index + 2) === '</') {
        pos.index += 2;
        const closingName = this.parseTagName(content, pos).toLowerCase();
        this.skipWhitespace(content, pos);

        if (closingName !== tagName) {
          // 显式定义warning对象
          const warning: ParseWarningInfo = {
            code: 'MISMATCHED_TAG',
            message: `Mismatched closing tag: expected </${tagName}>, found </${closingName}>`,
            severity: 'warning'
          };
          warnings.push(warning);
        }

        while (pos.index < content.length && content[pos.index] !== '>') {
          pos.index++;
        }
        if (content[pos.index] === '>') {
          pos.index++;
        }
        break;
      }

      if (pos.index >= content.length) {
        // 显式定义warning对象
        const warning: ParseWarningInfo = {
          code: 'UNCLOSED_TAG',
          message: `Unclosed tag: <${tagName}>`,
          severity: 'warning'
        };
        warnings.push(warning);
        break;
      }

      const child = this.parseNode(content, pos, maxDepth, currentDepth + 1, warnings);
      if (child.type === 'text' && !child.value?.trim()) {
        continue;
      }
      children.push(child);
    }

    const textContent = children
      .filter(c => c.type === 'text')
      .map(c => c.value || '')
      .join('');

    // 显式定义node对象
    const node: HtmlNode = {
      type: 'element',
      name: tagName,
      tagName,
      attributes,
      children,
      innerHTML,
      outerHTML: '',
      textContent
    };

    return node;
  }

  private parseTagName(content: string, pos: PositionTracker): string {
    const start = pos.index;
    while (pos.index < content.length) {
      const char = content[pos.index];
      if (/[a-zA-Z0-9_:.-]/.test(char)) {
        pos.index++;
      } else {
        break;
      }
    }
    return content.substring(start, pos.index);
  }

  private parseAttributes(content: string, pos: PositionTracker): Map<string, string> {
    const attributes: Map<string, string> = new Map<string, string>();

    while (pos.index < content.length) {
      this.skipWhitespace(content, pos);

      if (content[pos.index] === '>' || content[pos.index] === '/') {
        break;
      }

      const name = this.parseAttributeName(content, pos);
      if (!name) break;

      this.skipWhitespace(content, pos);

      if (content[pos.index] === '=') {
        pos.index++;
        this.skipWhitespace(content, pos);

        const value = this.parseAttributeValue(content, pos);
        attributes.set(name, EntityDecoder.decode(value));
      } else {
        attributes.set(name, '');
      }
    }

    return attributes;
  }

  private parseAttributeName(content: string, pos: PositionTracker): string {
    const start = pos.index;
    while (pos.index < content.length) {
      const char = content[pos.index];
      if (/[a-zA-Z0-9_:.-]/.test(char)) {
        pos.index++;
      } else {
        break;
      }
    }
    return content.substring(start, pos.index);
  }

  private parseAttributeValue(content: string, pos: PositionTracker): string {
    const quote = content[pos.index];

    if (quote === '"' || quote === "'") {
      pos.index++;
      const start = pos.index;
      while (pos.index < content.length && content[pos.index] !== quote) {
        pos.index++;
      }
      const value = content.substring(start, pos.index);
      if (content[pos.index] === quote) {
        pos.index++;
      }
      return value;
    }

    const start = pos.index;
    while (pos.index < content.length && !/[\s>]/.test(content[pos.index])) {
      pos.index++;
    }
    return content.substring(start, pos.index);
  }

  private parseText(content: string, pos: PositionTracker): HtmlNode {
    const start = pos.index;
    while (pos.index < content.length && content[pos.index] !== '<') {
      pos.index++;
    }
    const value = EntityDecoder.decode(content.substring(start, pos.index));
    const node: HtmlNode = { type: 'text', value: value };
    return node;
  }

  private parseComment(content: string, pos: PositionTracker): HtmlNode {
    pos.index += 3;
    const start = pos.index;
    while (pos.index < content.length - 2) {
      if (content.substring(pos.index, pos.index + 3) === '-->') {
        break;
      }
      pos.index++;
    }
    const value = content.substring(start, pos.index);
    pos.index += 3;
    const node: HtmlNode = { type: 'comment', value: value };
    return node;
  }

  private parseDoctype(content: string, pos: PositionTracker): HtmlNode {
    const start = pos.index;
    while (pos.index < content.length && content[pos.index] !== '>') {
      pos.index++;
    }
    const value = content.substring(start, pos.index);
    if (content[pos.index] === '>') {
      pos.index++;
    }
    const node: HtmlNode = { type: 'comment', value: '!DOCTYPE ' + value };
    return node;
  }

  private skipWhitespace(content: string, pos: PositionTracker): void {
    while (pos.index < content.length && /\s/.test(content[pos.index])) {
      pos.index++;
    }
  }

  private handleParseError(error: Error): ParserError {
    if (error instanceof ParserError) {
      return error;
    }
    return ParserError.fromError(error, this.type);
  }

  protected doValidate(content: string, _options?: ParseOptions): ValidateResult {
    const errors: ParseErrorInfo[] = [];
    const warnings: ParseWarningInfo[] = [];

    const tagStack: string[] = [];
    let inScript = false;
    let inStyle = false;

    for (let i = 0; i < content.length; i++) {
      if (content[i] === '<') {
        if (content.substring(i, i + 4) === '<!--') {
          const end = content.indexOf('-->', i);
          i = end === -1 ? content.length : end + 2;
          continue;
        }

        const isClosing = content[i + 1] === '/';
        const startOffset = isClosing ? 2 : 1;
        const match = content.substring(i + startOffset).match(/^([a-zA-Z][a-zA-Z0-9]*)/);

        if (match) {
          const tagName = match[1].toLowerCase();

          if (tagName === 'script') {
            inScript = !isClosing;
          } else if (tagName === 'style') {
            inStyle = !isClosing;
          }

          if (!inScript && !inStyle) {
            if (isClosing) {
              const expected = tagStack.pop();
              if (expected && expected !== tagName) {
                // 显式定义warning对象
                const warning: ParseWarningInfo = {
                  code: 'MISMATCHED_TAG',
                  message: `Mismatched tag: expected </${expected}>, found </${tagName}>`,
                  severity: 'warning'
                };
                warnings.push(warning);
              }
            } else if (!this.selfClosingTags.has(tagName)) {
              tagStack.push(tagName);
            }
          }
        }
      }
    }

    for (let i = 0; i < tagStack.length; i++) {
      const tag = tagStack[i];
      // 显式定义warning对象
      const warning: ParseWarningInfo = {
        code: 'UNCLOSED_TAG',
        message: 'Unclosed tag: <' + tag + '>',
        severity: 'warning'
      };
      warnings.push(warning);
    }

    const validateResult = new ValidateResult(errors, warnings);
    return validateResult;
  }

  protected detectContent(content: string): boolean {
    const trimmed = content.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') ||
           trimmed.startsWith('<html') ||
           (trimmed.startsWith('<') && trimmed.includes('</'));
  }

  format(data: HtmlNode, options?: FormatOptions): string {
    const indent = options?.indent ?? 2;
    return this.formatNode(data, 0, indent);
  }

  private formatNode(node: HtmlNode, depth: number, indent: number): string {
    const spaces = ' '.repeat(depth * indent);

    switch (node.type) {
      case 'element':
        return this.formatElement(node, depth, indent);
      case 'text':
        return node.value || '';
      case 'comment':
        return spaces + '<!--' + node.value + '-->';
      default:
        return '';
    }
  }

  private formatElement(node: HtmlNode, depth: number, indent: number): string {
    const spaces = ' '.repeat(depth * indent);
    const tagName = node.tagName || node.name || 'div';
    let result = spaces + '<' + tagName;

    if (node.attributes) {
      node.attributes.forEach((value: string, name: string) => {
        result += value ? ' ' + name + '="' + value + '"' : ' ' + name;
      });
    }

    if (this.selfClosingTags.has(tagName)) {
      return result + ' />';
    }

    if (!node.children || node.children.length === 0) {
      return result + '></' + tagName + '>';
    }

    result += '>';

    const hasElementChildren = this.hasElementChildren(node.children);

    for (const child of node.children) {
      const htmlChild = child as HtmlNode;
      if (hasElementChildren && !this.isTextNode(htmlChild)) {
        result += '\n';
      }
      result += this.formatNode(htmlChild, depth + 1, indent);
    }

    if (hasElementChildren) {
      result += '\n' + spaces;
    }

    return result + '</' + tagName + '>';
  }

  query(node: HtmlNode, selector: string): HtmlNode[] {
    const results: HtmlNode[] = [];
    this.queryInternal(node, selector, results);
    return results;
  }

  private queryInternal(node: HtmlNode, selector: string, results: HtmlNode[]): void {
    if (node.type !== 'element' || !node.children) {
      return;
    }

    for (const child of node.children) {
        const htmlChild = child as HtmlNode;
        if (this.isElementNode(htmlChild)) {
          const matchResult = this.matchesSelector(htmlChild, selector);
          if (matchResult) {
            results.push(htmlChild);
          }
          this.queryInternal(htmlChild, selector, results);
      }
    }
  }

  private matchesSelector(node: HtmlNode, selector: string): boolean {
    const tagName = node.tagName || node.name || '';

    if (selector.startsWith('#')) {
      const id = selector.substring(1);
      return node.attributes?.get('id') === id;
    }

    if (selector.startsWith('.')) {
      const className = selector.substring(1);
      const classAttr = node.attributes?.get('class') || '';
      const classes = classAttr.split(/\s+/);
      return classes.includes(className);
    }

    return tagName.toLowerCase() === selector.toLowerCase();
  }

  getTextContent(node: HtmlNode): string {
    if (node.type === 'text') {
      return node.value || '';
    }

    if (node.textContent) {
      return node.textContent;
    }

    if (node.type === 'element' && node.children) {
      return node.children.map((c: HtmlNode): string => this.getTextContent(c)).join('');
    }

    return '';
  }

  getAttribute(node: HtmlNode, name: string): string | undefined {
    if (node.attributes) {
      return node.attributes.get(name);
    }
    return undefined;
  }

  private hasElementChildren(children: HtmlNode[]): boolean {
    for (let i = 0; i < children.length; i++) {
      if (this.isElementNode(children[i])) {
        return true;
      }
    }
    return false;
  }

  private isElementNode(node: HtmlNode): boolean {
    return node.type === 'element';
  }

  private isTextNode(node: HtmlNode): boolean {
    return node.type === 'text';
  }

  private asHtmlNode(node: HtmlNode): HtmlNode {
    return node as HtmlNode;
  }
}

export default new HTMLParserAdapter();