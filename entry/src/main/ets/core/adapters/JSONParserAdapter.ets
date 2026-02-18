/**
 * JSONParserAdapter - JSON 解析器适配器
 * 支持标准 JSON、带注释 JSON、宽松 JSON 格式
 */

import {
  ParserType,
  ParseOptions,
  ParseResult,
  FormatOptions,
  ParseErrorInfo,
  ParseWarningInfo,
  JsonValue,
  JsonObject,
  JsonArray,
  ParseStatus
} from '../../interfaces/IParser';
import { CachingParserAdapter } from '../ParserAdapter';
import { ParserError, ParserWarning, ParserErrorCode, ParseResultBuilder } from '../ParserError';

interface ErrorLocation {
  line: number;
  column: number;
  context: string;
}

interface ValidationResult {
  errors: ParseErrorInfo[];
  warnings: ParseWarningInfo[];
}
export class JSONParserAdapter extends CachingParserAdapter<JsonValue> {
  readonly type = ParserType.JSON;
  readonly name = 'JSONParser';
  readonly version = '1.0.0';
  readonly supportedExtensions = ['json', 'jsonc', 'json5'];
  readonly priority = 100;

  private currentDepth: number = 0;

  protected async doParse(content: string, options: ParseOptions): Promise<ParseResult<JsonValue>> {
    return this.parseJSON(content, options);
  }

  protected doParseSync(content: string, options: ParseOptions): ParseResult<JsonValue> {
    return this.parseJSON(content, options);
  }

  private parseJSON(content: string, options: ParseOptions): ParseResult<JsonValue> {
    const builder: ParseResultBuilder<JsonValue> = new ParseResultBuilder<JsonValue>(null as JsonValue);
    builder.setMetadata({
      parserType: this.type,
      version: this.version
    });

    try {
      let processedContent = content;

      processedContent = this.stripBOM(processedContent);

      if (options.strict !== true) {
        processedContent = this.stripComments(processedContent);
        processedContent = this.stripTrailingCommas(processedContent);
      }

      this.currentDepth = 0;
      const data: JsonValue = this.parseWithDepth(processedContent, options.maxDepth ?? 100);

      builder.setData(data);
      builder.setStatus(ParseStatus.SUCCESS);

      if (processedContent !== content) {
        builder.addWarning(new ParserWarning('CONTENT_MODIFIED', 'JSON content was preprocessed (comments/trailing commas removed)'));
      }
    } catch (error) {
      const parseError = this.handleParseError(error as Error, content);
      builder.addError(parseError);
      builder.setStatus(ParseStatus.FAILED);
    }

    return builder.build();
  }

  private parseWithDepth(content: string, maxDepth: number): JsonValue {
    const result: JsonValue = JSON.parse(content, (key: string, value: JsonValue): JsonValue => {
      this.currentDepth++;
      if (this.currentDepth > maxDepth) {
        throw ParserError.syntaxError(
          this.type,
          `Maximum depth exceeded: ${maxDepth}`,
          undefined,
          undefined,
          `Key: ${key}`
        );
      }
      return value;
    }) as JsonValue;
    return result;
  }

  private handleParseError(error: Error, content: string): ParserError {
    if (error instanceof ParserError) {
      return error;
    }

    const syntaxMatch = error.message.match(/position\s+(\d+)/i);
    if (syntaxMatch) {
      const position = parseInt(syntaxMatch[1], 10);
      const errorLocation = this.getErrorLocation(content, position);
      return ParserError.syntaxError(this.type, error.message, errorLocation.line, errorLocation.column, errorLocation.context);
    }

    return ParserError.fromError(error, this.type);
  }

  private getErrorLocation(content: string, position: number): ErrorLocation {
    let line = 1;
    let column = 1;
    let lastLineStart = 0;

    for (let i = 0; i < position && i < content.length; i++) {
      if (content[i] === '\n') {
        line++;
        column = 1;
        lastLineStart = i + 1;
      } else {
        column++;
      }
    }

    const lineEnd = content.indexOf('\n', lastLineStart);
    const context = content.substring(lastLineStart, lineEnd === -1 ? content.length : lineEnd);

    return { line, column, context };
  }

  protected doValidate(content: string, _options?: ParseOptions): ValidationResult {
    const errors: ParseErrorInfo[] = [];
    const warnings: ParseWarningInfo[] = [];

    const trimmed = content.trim();

    if (!this.isValidJSONStart(trimmed)) {
      const error: ParseErrorInfo = {
        code: ParserErrorCode.INVALID_FORMAT,
        message: 'Content does not start with valid JSON character ({ or [)',
        severity: 'error'
      };
      errors.push(error);
      return { errors, warnings };
    }

    const bracketStack: string[] = [];
    let inString = false;
    let escapeNext = false;

    for (let i = 0; i < trimmed.length; i++) {
      const char = trimmed[i];

      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (char === '\\' && inString) {
        escapeNext = true;
        continue;
      }

      if (char === '"') {
        inString = !inString;
        continue;
      }

      if (inString) {
        continue;
      }

      if (char === '{' || char === '[') {
        bracketStack.push(char);
      } else if (char === '}') {
        if (bracketStack.pop() !== '{') {
          const error: ParseErrorInfo = {
            code: ParserErrorCode.SYNTAX_ERROR,
            message: 'Unexpected closing brace }',
            severity: 'error'
          };
          errors.push(error);
        }
      } else if (char === ']') {
        if (bracketStack.pop() !== '[') {
          const error: ParseErrorInfo = {
            code: ParserErrorCode.SYNTAX_ERROR,
            message: 'Unexpected closing bracket ]',
            severity: 'error'
          };
          errors.push(error);
        }
      }
    }

    if (bracketStack.length > 0) {
      const error: ParseErrorInfo = {
        code: ParserErrorCode.SYNTAX_ERROR,
        message: `Unclosed brackets: ${bracketStack.join(', ')}`,
        severity: 'error'
      };
      errors.push(error);
    }

    return { errors, warnings };
  }

  protected detectContent(content: string): boolean {
    const trimmed = content.trim();
    return this.isValidJSONStart(trimmed);
  }

  private isValidJSONStart(content: string): boolean {
    return content.startsWith('{') || content.startsWith('[');
  }

  format(data: JsonValue, options?: FormatOptions): string {
    if (options?.compact) {
      return JSON.stringify(data);
    }

    const indent = options?.indent ?? 2;
    return JSON.stringify(data, null, indent);
  }

  private stripBOM(content: string): string {
    if (content.charCodeAt(0) === 0xFEFF) {
      return content.slice(1);
    }
    return content;
  }

  private stripComments(content: string): string {
    let result = '';
    let inString = false;
    let escapeNext = false;
    let i = 0;

    while (i < content.length) {
      const char = content[i];
      const nextChar = content[i + 1];

      if (escapeNext) {
        result += char;
        escapeNext = false;
        i++;
        continue;
      }

      if (char === '\\' && inString) {
        result += char;
        escapeNext = true;
        i++;
        continue;
      }

      if (char === '"') {
        inString = !inString;
        result += char;
        i++;
        continue;
      }

      if (inString) {
        result += char;
        i++;
        continue;
      }

      if (char === '/' && nextChar === '/') {
        while (i < content.length && content[i] !== '\n') {
          i++;
        }
        continue;
      }

      if (char === '/' && nextChar === '*') {
        i += 2;
        while (i < content.length - 1 && !(content[i] === '*' && content[i + 1] === '/')) {
          i++;
        }
        i += 2;
        continue;
      }

      result += char;
      i++;
    }

    return result;
  }

  private stripTrailingCommas(content: string): string {
    return content.replace(/,(\s*[}\]])/g, '$1');
  }

  query(data: JsonValue, path: string): JsonValue | undefined {
    if (!path || path === '$' || path === '.') {
      return data;
    }

    let processedPath = path;
    if (processedPath.startsWith('$')) {
      processedPath = processedPath.substring(1);
    }
    if (processedPath.startsWith('.')) {
      processedPath = processedPath.substring(1);
    }

    const parts = processedPath.split(/[.\[\]]+/).filter(p => p.length > 0);
    let current: JsonValue = data;

    for (const part of parts) {
      if (current === null || current === undefined) {
        return undefined;
      }

      const index = parseInt(part, 10);
      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index];
        } else {
          return undefined;
        }
      } else if (typeof current === 'object' && current !== null && !Array.isArray(current)) {
        const obj: JsonObject = current as JsonObject;
        current = obj[part];
      } else {
        return undefined;
      }
    }

    return current;
  }

  set(data: JsonObject | JsonArray, path: string, value: JsonValue): JsonObject | JsonArray {
    if (!path || path === '$' || path === '.') {
      if (Array.isArray(value)) {
        return value as JsonArray;
      }
      if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
        return value as JsonObject;
      }
      return data;
    }

    let processedPath = path;
    if (processedPath.startsWith('$')) {
      processedPath = processedPath.substring(1);
    }
    if (processedPath.startsWith('.')) {
      processedPath = processedPath.substring(1);
    }

    const parts = processedPath.split(/[.\[\]]+/).filter(p => p.length > 0);
    const result: JsonObject | JsonArray = JSON.parse(JSON.stringify(data)) as JsonObject | JsonArray;
    let current: JsonValue = result;

    for (let i = 0; i < parts.length - 1; i++) {
      const part = parts[i];
      const index = parseInt(part, 10);
      const nextPart = parts[i + 1];
      const nextIndex = parseInt(nextPart, 10);

      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index];
        }
      } else if (typeof current === 'object' && current !== null && !Array.isArray(current)) {
        const obj: JsonObject = current as JsonObject;
        if (!obj.hasOwnProperty(part)) {
          const newValue: JsonValue = !isNaN(nextIndex) ? [] : {};
          obj[part] = newValue;
          current = newValue;
        } else {
          current = obj[part];
        }
      }
    }

    const lastPart = parts[parts.length - 1];
    const lastIndex = parseInt(lastPart, 10);

    if (!isNaN(lastIndex) && Array.isArray(current)) {
      current[lastIndex] = value;
    } else if (typeof current === 'object' && current !== null && !Array.isArray(current)) {
      const obj: JsonObject = current as JsonObject;
      obj[lastPart] = value;
    }

    return result;
  }
}


export default new JSONParserAdapter();