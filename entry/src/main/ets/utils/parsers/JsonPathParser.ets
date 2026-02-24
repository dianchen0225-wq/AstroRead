import { Logger } from '../Logger';
import { Result, ErrorCode } from '../../core/Result';
import { BaseParser, IParser, ParserResult, ParserType, ParseOptions, JsonValue, JsonData } from '../IParser';

export class JsonPathParser extends BaseParser {
  readonly type: ParserType = ParserType.JSON;
  readonly name: string = 'JsonPathParser';
  private static readonly TAG = 'JsonPathParser';

  canHandle(rule: string): boolean {
    if (!rule) return false;
    const trimmed = rule.trim();
    return trimmed.startsWith('@json:') || 
           trimmed.startsWith('$.') || 
           trimmed.startsWith('from(') ||
           this.looksLikeJsonPath(trimmed);
  }

  private looksLikeJsonPath(rule: string): boolean {
    const jsonPathPattern = /^[a-zA-Z_$][a-zA-Z0-9_$]*(\.[a-zA-Z_$][a-zA-Z0-9_$]*|\[\d+\]|\['[^']+'\]|\["[^"]+"\])*$/;
    return jsonPathPattern.test(rule);
  }

  parse(jsonStr: string, rule: string, _options?: ParseOptions): Result<ParserResult> {
    if (!this.validateInput(jsonStr, rule)) {
      return this.createErrorResult('JSON path parse: empty input');
    }

    try {
      let jsonData: JsonValue;
      try {
        jsonData = JSON.parse(jsonStr) as JsonValue;
      } catch (e) {
        const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          jsonData = JSON.parse(jsonMatch[0]) as JsonValue;
        } else {
          return this.createErrorResult('Invalid JSON format', ErrorCode.PARSE_JSON_ERROR);
        }
      }

      let processedPath = rule.trim();
      if (processedPath.startsWith('@json:')) {
        processedPath = processedPath.substring(6).trim();
      }

      const result = this.resolvePath(jsonData, processedPath);
      return Result.ok(ParserResult.fromRaw(result));
    } catch (error) {
      Logger.error(JsonPathParser.TAG, `JSONPath解析失败: ${error}`);
      return this.createErrorResult(
        `JSONPath parse failed: ${error}`,
        ErrorCode.PARSE_JSON_ERROR,
        error instanceof Error ? error.stack : String(error)
      );
    }
  }

  resolvePath(data: JsonValue, path: string): JsonValue {
    if (data === null || data === undefined || !path) {
      return data ?? null;
    }

    let processedPath = path.trim();

    if (processedPath.startsWith('$')) {
      processedPath = processedPath.substring(1);
      if (processedPath.startsWith('.')) {
        processedPath = processedPath.substring(1);
      }
    }

    const fromMatch = processedPath.match(/^from\(([^)]+)\)$/);
    if (fromMatch) {
      processedPath = fromMatch[1];
    }

    if (!processedPath || processedPath === '.') {
      return data;
    }

    const parts = processedPath.split(/[.\[\]]+/).filter((p: string) => p.length > 0);
    let current: JsonValue = data;

    for (const part of parts) {
      if (current === null || current === undefined) {
        return null;
      }

      if (part === '*') {
        continue;
      }

      const index = parseInt(part, 10);
      if (!isNaN(index)) {
        if (Array.isArray(current)) {
          current = current[index] ?? null;
        } else {
          return null;
        }
      } else if (typeof current === 'object' && !Array.isArray(current)) {
        current = (current as JsonData)[part] ?? null;
      } else {
        return null;
      }
    }

    return current;
  }

  extractValue(data: JsonData, path: string): string {
    const value = this.resolvePath(data, path);
    return ParserResult.stringifyValue(value);
  }
}

export default JsonPathParser;
