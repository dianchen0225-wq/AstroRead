/**
 * XMLParserAdapter - XML 解析器适配器
 * 支持标准 XML、带命名空间 XML
 */

import {
  ParserType,
  ParseOptions,
  ParseResult,
  FormatOptions,
  ParseErrorInfo,
  ParseWarningInfo,
  XmlNode,
  ParseStatus,
    ValidationResult as IValidationResult
} from '../../interfaces/IParser';
import { CachingParserAdapter } from '../ParserAdapter';
import { ParserError, ParserWarning, ParserErrorCode, ParseResultBuilder } from '../ParserError';
import { EntityDecoder } from '../utils/EntityDecoder';
import { PositionTracker } from '../utils/PositionTracker';

class XMLWarningInfo {
  code: string = '';
  message: string = '';
  severity: 'warning' | 'info' = 'warning';

  constructor(code: string, message: string, severity: 'warning' | 'info' = 'warning') {
    this.code = code;
    this.message = message;
    this.severity = severity;
  }
}

class XMLParseResult {
  node: XmlNode | null = null;
  warnings: XMLWarningInfo[] = [];

  constructor(node: XmlNode, warnings: XMLWarningInfo[]) {
    this.node = node;
    this.warnings = warnings;
  }
}

// 定义错误信息接口
class ValidationErrorInfo implements ParseErrorInfo {
  code: string = '';
  message: string = '';
  line?: number;
  column?: number;
  context?: string;
  severity: 'error' | 'critical' = 'error';

  constructor(code: string, message: string, severity: 'error' | 'critical' = 'error') {
    this.code = code;
    this.message = message;
    this.severity = severity;
  }
}

class ValidationResult {
  errors: ParseErrorInfo[] = [];
  warnings: ParseWarningInfo[] = [];

  constructor(errors: ParseErrorInfo[], warnings: ParseWarningInfo[]) {
    this.errors = errors;
    this.warnings = warnings;
  }
}

export class XMLParserAdapter extends CachingParserAdapter<XmlNode> {
  readonly type = ParserType.XML;
  readonly name = 'XMLParser';
  readonly version = '1.0.0';
  readonly supportedExtensions = ['xml', 'xhtml', 'xsl', 'svg'];
  readonly priority = 90;

  protected async doParse(content: string, options: ParseOptions): Promise<ParseResult<XmlNode>> {
    return this.parseXML(content, options);
  }

  protected doParseSync(content: string, options: ParseOptions): ParseResult<XmlNode> {
    return this.parseXML(content, options);
  }

  private parseXML(content: string, options: ParseOptions): ParseResult<XmlNode> {
    const defaultNode: XmlNode = { type: 'text', value: '' } as XmlNode;
    const builder = new ParseResultBuilder<XmlNode>(defaultNode);
    builder.setMetadata({
      parserType: this.type,
      version: this.version,
      parseTime: 0,
      dataSize: 0,
      cached: false,
      timestamp: Date.now()
    });

    try {
      let processedContent = content.trim();
      processedContent = this.stripXMLDeclaration(processedContent);

      const parseResult: XMLParseResult = this.parseXMLContent(processedContent, options);

      if (parseResult.node !== null) {
        builder.setData(parseResult.node);
      }
      builder.setStatus(ParseStatus.SUCCESS);

      for (const warningInfo of parseResult.warnings) {
        builder.addWarning(new ParserWarning(warningInfo.code, warningInfo.message));
      }
    } catch (error) {
      const parseError = this.handleParseError(error as Error, content);
      builder.addError(parseError);
      builder.setStatus(ParseStatus.FAILED);
    }

    return builder.build();
  }

  private parseXMLContent(content: string, options: ParseOptions): XMLParseResult {
    const warnings: XMLWarningInfo[] = [];
    const pos = new PositionTracker();

    this.skipWhitespace(content, pos);

    const node = this.parseNode(content, pos, options.maxDepth ?? 100, 0, warnings);

    const result = new XMLParseResult(node, warnings);
    return result;
  }

  private parseNode(
    content: string,
    pos: PositionTracker,
    maxDepth: number,
    currentDepth: number,
    warnings: XMLWarningInfo[]
  ): XmlNode {
    this.skipWhitespace(content, pos);

    if (pos.index >= content.length) {
      const textNode: XmlNode = { type: 'text', value: '' } as XmlNode;
      return textNode;
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
    warnings: XMLWarningInfo[]
  ): XmlNode {
    pos.advance(1);

    if (content.substring(pos.index, pos.index + 3) === '!--') {
      return this.parseComment(content, pos);
    }

    if (content.substring(pos.index, pos.index + 8) === '![CDATA[') {
      return this.parseCDATA(content, pos);
    }

    if (content.substring(pos.index, pos.index + 2) === '?') {
      return this.parseProcessingInstruction(content, pos);
    }

    const name = this.parseName(content, pos);
    const attributes = this.parseAttributes(content, pos);

    this.skipWhitespace(content, pos);

    if (content[pos.index] === '/' && content[pos.index + 1] === '>') {
      pos.advance(2);
      const elementNode: XmlNode = {
        type: 'element',
        name: name,
        attributes: attributes,
        children: []
      } as XmlNode;
      return elementNode;
    }

    if (content[pos.index] !== '>') {
      throw ParserError.syntaxError(
        this.type,
        'Expected > at end of opening tag',
        undefined,
        undefined,
        `Tag: ${name}`
      );
    }
    pos.advance(1);

    const children: XmlNode[] = [];

    while (pos.index < content.length) {
      this.skipWhitespace(content, pos);

      if (content.substring(pos.index, pos.index + 2) === '</') {
        pos.advance(2);
        const closingName = this.parseName(content, pos);
        this.skipWhitespace(content, pos);

        if (closingName !== name) {
          const warningInfo = new XMLWarningInfo(
            'MISMATCHED_TAG',
            `Mismatched closing tag: expected </${name}>, found </${closingName}>`,
            'warning'
          );
          warnings.push(warningInfo);
        }

        if (content[pos.index] !== '>') {
          throw ParserError.syntaxError(
            this.type,
            'Expected > at end of closing tag',
            undefined,
            undefined,
            `Tag: ${closingName}`
          );
        }
        pos.advance(1);
        break;
      }

      const child = this.parseNode(content, pos, maxDepth, currentDepth + 1, warnings);
      if (child.type === 'text' && (!child.value || !child.value.trim())) {
        continue;
      }
      children.push(child);
    }

    const elementNode: XmlNode = {
      type: 'element',
      name: name,
      attributes: attributes,
      children: children
    } as XmlNode;
    return elementNode;
  }

  private parseName(content: string, pos: PositionTracker): string {
    const start = pos.index;
    while (pos.index < content.length) {
      const char = content[pos.index];
      if (/[a-zA-Z0-9_:.-]/.test(char)) {
        pos.advance(1);
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

      const name = this.parseName(content, pos);
      if (!name) break;

      this.skipWhitespace(content, pos);

      if (content[pos.index] !== '=') {
        break;
      }
      pos.advance(1);

      this.skipWhitespace(content, pos);

      const quote = content[pos.index];
      if (quote !== '"' && quote !== "'") {
        throw ParserError.syntaxError(
          this.type,
          'Expected quote character for attribute value',
          undefined,
          undefined,
          `Attribute: ${name}`
        );
      }
      pos.advance(1);

      const valueStart = pos.index;
      while (pos.index < content.length && content[pos.index] !== quote) {
        pos.advance(1);
      }
      const value = content.substring(valueStart, pos.index);
      pos.advance(1);

      attributes.set(name, EntityDecoder.decode(value));
    }

    return attributes;
  }

  private parseText(content: string, pos: PositionTracker): XmlNode {
    const start = pos.index;
    while (pos.index < content.length && content[pos.index] !== '<') {
      pos.advance(1);
    }
    const value = EntityDecoder.decode(content.substring(start, pos.index));
    const textNode: XmlNode = { type: 'text', value: value } as XmlNode;
    return textNode;
  }

  private parseComment(content: string, pos: PositionTracker): XmlNode {
    pos.advance(3);
    const start = pos.index;
    while (pos.index < content.length - 2) {
      if (content.substring(pos.index, pos.index + 3) === '-->') {
        break;
      }
      pos.advance(1);
    }
    const value = content.substring(start, pos.index);
    pos.advance(3);
    const commentNode: XmlNode = { type: 'comment', value: value };
    return commentNode;
  }

  private parseCDATA(content: string, pos: PositionTracker): XmlNode {
    pos.advance(8);
    const start = pos.index;
    while (pos.index < content.length - 2) {
      if (content.substring(pos.index, pos.index + 3) === ']]>') {
        break;
      }
      pos.advance(1);
    }
    const value = content.substring(start, pos.index);
    pos.advance(3);
    const cdataNode: XmlNode = { type: 'cdata', value: value };
    return cdataNode;
  }

  private parseProcessingInstruction(content: string, pos: PositionTracker): XmlNode {
    pos.advance(1);
    const start = pos.index;
    while (pos.index < content.length - 1) {
      if (content.substring(pos.index, pos.index + 2) === '?>') {
        break;
      }
      pos.advance(1);
    }
    const value = content.substring(start, pos.index);
    pos.advance(2);
    const piNode: XmlNode = { type: 'processing-instruction', value: value };
    return piNode;
  }

  private skipWhitespace(content: string, pos: PositionTracker): void {
    while (pos.index < content.length && /\s/.test(content[pos.index])) {
      pos.advance(1);
    }
  }

  private stripXMLDeclaration(content: string): string {
    return content.replace(/<\?xml[^?]*\?>/i, '').trim();
  }

  private handleParseError(error: Error, _content: string): ParserError {
    if (error instanceof ParserError) {
      return error;
    }
    return ParserError.fromError(error, this.type);
  }

  protected doValidate(content: string, _options?: ParseOptions): ValidationResult {
    const errors: ParseErrorInfo[] = [];
    const warnings: ParseWarningInfo[] = [];

    const tagStack: string[] = [];
    let inComment = false;
    let inCDATA = false;

    for (let i = 0; i < content.length; i++) {
      const char = content[i];
      const nextChars = content.substring(i, i + 3);
      const cdataStart = content.substring(i, i + 9);

      if (inComment) {
        if (nextChars === '-->') {
          inComment = false;
          i += 2;
        }
        continue;
      }

      if (inCDATA) {
        if (content.substring(i, i + 3) === ']]>') {
          inCDATA = false;
          i += 2;
        }
        continue;
      }

      if (char === '<') {
        if (nextChars === '!--') {
          inComment = true;
          i += 3;
          continue;
        }

        if (cdataStart === '<![CDATA[') {
          inCDATA = true;
          i += 8;
          continue;
        }

        if (content[i + 1] === '/') {
          const match = content.substring(i + 2).match(/^([a-zA-Z][a-zA-Z0-9_-]*)/);
          if (match) {
            const tagName = match[1];
            if (tagStack.length === 0) {
              const errorInfo = new ValidationErrorInfo(
                ParserErrorCode.SYNTAX_ERROR,
                `Unexpected closing tag: </${tagName}>`,
                'error'
              );
              errors.push(errorInfo);
            } else {
              const expected = tagStack.pop();
              if (expected !== tagName) {
                const errorInfo = new ValidationErrorInfo(
                  ParserErrorCode.SYNTAX_ERROR,
                  `Mismatched tag: expected </${expected}>, found </${tagName}>`,
                  'error'
                );
                errors.push(errorInfo);
              }
            }
          }
        } else if (content[i + 1] !== '?' && content[i + 1] !== '!') {
          const match = content.substring(i + 1).match(/^([a-zA-Z][a-zA-Z0-9_-]*)/);
          if (match) {
            const tagName = match[1];
            const selfClosing = /\/\s*>/.test(content.substring(i, content.indexOf('>', i)));
            if (!selfClosing) {
              tagStack.push(tagName);
            }
          }
        }
      }
    }

    if (tagStack.length > 0) {
      const errorInfo = new ValidationErrorInfo(
        ParserErrorCode.SYNTAX_ERROR,
        `Unclosed tags: ${tagStack.join(', ')}`,
        'error'
      );
      errors.push(errorInfo);
    }

    const validationResult = new ValidationResult(errors, warnings);
    return validationResult;
  }

  protected detectContent(content: string): boolean {
    const trimmed = content.trim();
    return trimmed.startsWith('<') && !trimmed.startsWith('<!DOCTYPE html');
  }

  format(data: XmlNode, options?: FormatOptions): string {
    const indent = options?.indent ?? 2;
    return this.formatNode(data, 0, indent);
  }

  private formatNode(node: XmlNode, depth: number, indent: number): string {
    const spaces = ' '.repeat(depth * indent);

    switch (node.type) {
      case 'element':
        return this.formatElement(node, depth, indent);
      case 'text':
        return node.value || '';
      case 'comment':
        return `${spaces}<!--${node.value}-->`;
      case 'cdata':
        return `${spaces}<![CDATA[${node.value}]]>`;
      case 'processing-instruction':
        return `${spaces}<?${node.value}?>`;
      default:
        return '';
    }
  }

  private formatElement(node: XmlNode, depth: number, indent: number): string {
    const spaces = ' '.repeat(depth * indent);
    let result = `${spaces}<${node.name}`;

    if (node.attributes) {
      node.attributes.forEach((value: string, name: string) => {
        result += ` ${name}="${EntityDecoder.encode(value)}"`;
      });
    }

    if (!node.children || node.children.length === 0) {
      return result + ' />';
    }

    result += '>';

    const hasElementChildren = node.children.some(child => child.type === 'element');

    for (const child of node.children) {
      if (hasElementChildren && child.type !== 'text') {
        result += '\n';
      }
      result += this.formatNode(child, depth + 1, indent);
    }

    if (hasElementChildren) {
      result += `\n${spaces}`;
    }

    return result + `</${node.name}>`;
  }

  query(node: XmlNode, path: string): XmlNode[] {
    if (!path || path === '/') {
      return [node];
    }

    const results: XmlNode[] = [];
    const segments = path.split('/').filter(segment => segment);
    this.queryInternal(node, segments, results);
    return results;
  }

  private queryInternal(node: XmlNode, segments: string[], results: XmlNode[]): void {
    if (segments.length === 0) {
      results.push(node);
      return;
    }

    const segment = segments[0];
    const remaining = segments.slice(1);

    if (node.type === 'element' && node.children) {
      for (const child of node.children) {
        if (child.type === 'element') {
          if (segment === '*' || child.name === segment) {
            this.queryInternal(child, remaining, results);
          }
        }
      }
    }
  }

  getTextContent(node: XmlNode): string {
    if (node.type === 'text') {
      return node.value || '';
    }

    if (node.type === 'element' && node.children) {
      let textContent = '';
      for (const child of node.children) {
        textContent += this.getTextContent(child);
      }
      return textContent;
    }

    return '';
  }
}

export default new XMLParserAdapter();