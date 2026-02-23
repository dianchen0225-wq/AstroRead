import { Logger } from '../performance/Logger';
import { Result, ErrorCode } from '../../core/Result';
import { BaseParser, IParser, ParserResult, ParserType, ParseOptions } from './IParser';
import { ScriptEngine, ScriptContext } from '../scripting/ScriptEngine';

export class JSParser extends BaseParser {
  readonly type: ParserType = ParserType.JS;
  readonly name: string = 'JSParser';
  private static readonly TAG = 'JSParser';
  private scriptEngine: ScriptEngine = ScriptEngine.getInstance();

  canHandle(rule: string): boolean {
    if (!rule) return false;
    const trimmed = rule.trim();
    return trimmed.startsWith('@js:') || 
           trimmed.startsWith('<js>') ||
           trimmed.startsWith('javascript:');
  }

  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    if (!this.validateInput(content, rule)) {
      return this.createErrorResult('JS parse: empty input');
    }

    try {
      let jsCode = rule.trim();
      
      if (jsCode.startsWith('@js:')) {
        jsCode = jsCode.substring(4).trim();
      } else if (jsCode.startsWith('<js>')) {
        const jsMatch = jsCode.match(/<js>([\s\S]*?)<\/js>/);
        if (jsMatch) {
          jsCode = jsMatch[1].trim();
        }
      } else if (jsCode.startsWith('javascript:')) {
        jsCode = jsCode.substring(11).trim();
      }

      const context: ScriptContext = {
        result: content,
        baseUrl: options?.baseUrl ?? ''
      };

      // ArkTS 不支持索引访问，使用 Map 的 entries 遍历
      if (options?.context) {
        const entries = options.context.entries();
        for (const entry of entries) {
          const key = entry[0];
          const value = entry[1];
          // 使用 Object.assign 或扩展运算符合并属性
          if (key === 'key') {
            context.key = value;
          } else if (key === 'page') {
            context.page = parseInt(value, 10);
          } else {
            // 其他属性通过 Object 方式处理
            (context as Record<string, string | number | boolean | object | null | undefined>)[key] = value;
          }
        }
      }

      const result = this.scriptEngine.executeAsString(jsCode, context);
      return Result.ok(ParserResult.fromValue(result));
    } catch (error) {
      Logger.error(JSParser.TAG, `JS解析失败: ${error}`);
      return this.createErrorResult(
        `JS parse failed: ${error}`,
        ErrorCode.PARSE_ERROR,
        error instanceof Error ? error.stack : String(error)
      );
    }
  }

  parseList(content: string, rule: string, options?: ParseOptions): Result<string[]> {
    const result = this.parse(content, rule, options);
    if (result.isErr()) {
      return Result.err(result.error!);
    }
    return Result.ok(result.data!.values);
  }

  execute(script: string, context: ScriptContext): string {
    return this.scriptEngine.executeAsString(script, context);
  }
}

export default JSParser;
