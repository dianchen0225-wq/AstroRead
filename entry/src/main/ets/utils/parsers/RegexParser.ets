import { Logger } from '../performance/Logger';
import { Result, ErrorCode } from '../../core/Result';
import { BaseParser, IParser, ParserResult, ParserType, ParseOptions } from '../parser/IParser';
import { SafeRegex } from '../security/SafeRegex';

export class RegexParser extends BaseParser {
  readonly type: ParserType = ParserType.REGEX;
  readonly name: string = 'RegexParser';
  private static readonly TAG = 'RegexParser';

  canHandle(rule: string): boolean {
    if (!rule) return false;
    const trimmed = rule.trim();
    return trimmed.startsWith('##') || trimmed.startsWith('@regex:');
  }

  parse(html: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    if (!this.validateInput(html, rule)) {
      return this.createErrorResult('Regex parse: empty input');
    }

    try {
      let processedRule = rule.trim();
      if (processedRule.startsWith('##')) {
        processedRule = processedRule.substring(2);
      } else if (processedRule.startsWith('@regex:')) {
        processedRule = processedRule.substring(7);
      }

      const flags = options?.flags ?? 'gi';
      const result = this.parseWithFlags(html, processedRule, flags);
      return Result.ok(result);
    } catch (error) {
      Logger.error(RegexParser.TAG, `正则解析失败: ${error}`);
      return this.createErrorResult(
        `Regex parse failed: ${error}`,
        ErrorCode.PARSE_REGEX_ERROR,
        error instanceof Error ? error.stack : String(error)
      );
    }
  }

  private parseWithFlags(html: string, pattern: string, flags: string): ParserResult {
    let processedPattern = pattern;
    let processedFlags = flags;

    if (processedPattern.startsWith('(?s)')) {
      processedPattern = processedPattern.substring(4);
      processedFlags += 's';
    }

    const matches = SafeRegex.safeMatchAll(processedPattern, html, processedFlags);
    const results: string[] = [];

    for (const match of matches) {
      results.push(match[1] || match[0]);
    }

    return ParserResult.fromValues(results);
  }

  parseFirst(html: string, pattern: string, flags: string = 'i'): Result<string> {
    if (!html || !pattern) {
      return Result.err(ErrorCode.PARSE_ERROR, 'Regex parse: empty input');
    }

    try {
      let processedPattern = pattern;
      let processedFlags = flags;

      if (processedPattern.startsWith('(?s)')) {
        processedPattern = processedPattern.substring(4);
        processedFlags += 's';
      }

      const match = SafeRegex.safeMatch(processedPattern, html, processedFlags);

      if (match) {
        return Result.ok(match[1] || match[0]);
      }

      return Result.ok('');
    } catch (error) {
      Logger.error(RegexParser.TAG, `正则解析失败: ${error}`);
      return Result.err(ErrorCode.PARSE_REGEX_ERROR, `Regex parse failed: ${error}`);
    }
  }

  replace(text: string, pattern: string, replacement: string): string {
    if (!text || !pattern) {
      return text || '';
    }

    try {
      return SafeRegex.safeReplace(text, pattern, replacement);
    } catch (error) {
      Logger.warn(RegexParser.TAG, `正则替换失败: ${error}`);
      return text;
    }
  }

  escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}

export default RegexParser;
