import { Logger } from '../performance/Logger';
import { Result, ErrorCode } from '../../core/Result';
import { BaseParser, ParserResult, ParserType, ParseOptions } from './IParser';
import { SafeRegex, RegexMatchResult } from '../security/SafeRegex';

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
      let processedRule: string = rule.trim();
      if (processedRule.startsWith('##')) {
        processedRule = processedRule.substring(2);
      } else if (processedRule.startsWith('@regex:')) {
        processedRule = processedRule.substring(7);
      }

      const flags: string = options?.flags ?? 'gi';
      const result: ParserResult = this.parseWithFlags(html, processedRule, flags);
      return Result.ok(result);
    } catch (error) {
      const err = error as Error;
      Logger.error(RegexParser.TAG, `正则解析失败: ${err.message}`);
      return this.createErrorResult(
        `Regex parse failed: ${err.message}`,
        ErrorCode.PARSE_REGEX_ERROR,
        err.stack ?? String(err)
      );
    }
  }

  private parseWithFlags(html: string, pattern: string, flags: string): ParserResult {
    let processedPattern: string = pattern;
    let processedFlags: string = flags;

    if (processedPattern.startsWith('(?s)')) {
      processedPattern = processedPattern.substring(4);
      processedFlags += 's';
    }

    const matches: RegexMatchResult[] = SafeRegex.safeMatchAll(processedPattern, html, processedFlags);
    const results: string[] = [];

    for (let i: number = 0; i < matches.length; i++) {
      const match: RegexMatchResult = matches[i];
      results.push(match.getGroup(1) || match.getMatch());
    }

    return ParserResult.fromValues(results);
  }

  parseFirst(html: string, pattern: string, flags: string = 'i'): Result<string> {
    if (!html || !pattern) {
      return Result.err(ErrorCode.PARSE_ERROR, 'Regex parse: empty input');
    }

    try {
      let processedPattern: string = pattern;
      let processedFlags: string = flags;

      if (processedPattern.startsWith('(?s)')) {
        processedPattern = processedPattern.substring(4);
        processedFlags += 's';
      }

      const match: RegExpMatchArray | null = SafeRegex.safeMatch(processedPattern, html, processedFlags);

      if (match !== null) {
        return Result.ok(match[1] || match[0]);
      }

      return Result.ok('');
    } catch (error) {
      const err = error as Error;
      Logger.error(RegexParser.TAG, `正则解析失败: ${err.message}`);
      return Result.err(ErrorCode.PARSE_REGEX_ERROR, `Regex parse failed: ${err.message}`);
    }
  }

  replace(text: string, pattern: string, replacement: string): string {
    if (!text || !pattern) {
      return text || '';
    }

    try {
      return SafeRegex.safeReplace(text, pattern, replacement);
    } catch (error) {
      const err = error as Error;
      Logger.warn(RegexParser.TAG, `正则替换失败: ${err.message}`);
      return text;
    }
  }

  escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}

export default RegexParser;
