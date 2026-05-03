import { ParserType } from "./IParser";
import { IRuleTypeDetector, RuleTypeDetectionResult } from "./interfaces/IUnifiedParseEngine";
import { Logger } from "../performance/Logger";

export class RuleTypeDetector implements IRuleTypeDetector {
  private static readonly TAG = 'RuleTypeDetector';

  private static readonly PREFIX_MAP: Array<[string, ParserType]> = [
    ['@js:', ParserType.JS],
    ['<js>', ParserType.JS],
    ['javascript:', ParserType.JS],
    ['@json:', ParserType.JSON],
    ['$.', ParserType.JSON],
    ['##', ParserType.REGEX],
    ['@regex:', ParserType.REGEX],
    ['//', ParserType.XPATH],
    ['./', ParserType.XPATH],
    ['/html', ParserType.XPATH],
    ['@css:', ParserType.CSS],
    ['css:', ParserType.CSS],
  ];

  private static readonly SYNTAX_PATTERNS: Array<[RegExp, ParserType, number]> = [
    [/^\/[\w:@*]/, ParserType.XPATH, 0.7],
    [/^\$[\.\[]/, ParserType.JSON, 0.7],
    [/^[\w\-]+[\s]*[>.~+[#.:]/, ParserType.CSS, 0.5],
    [/^function\s|^\([\w,]*\)\s*=>|^var\s|^let\s|^const\s/, ParserType.JS, 0.4],
  ];

  private static readonly PRIORITY_ORDER: ParserType[] = [
    ParserType.XPATH,
    ParserType.JSON,
    ParserType.CSS,
    ParserType.REGEX,
    ParserType.JS,
  ];

  detect(rule: string): ParserType {
    if (!rule || rule.trim().length === 0) {
      return ParserType.AUTO;
    }

    const trimmed = rule.trim();

    for (const [prefix, type] of RuleTypeDetector.PREFIX_MAP) {
      if (trimmed.startsWith(prefix)) {
        Logger.debug(RuleTypeDetector.TAG, `Prefix match: ${prefix} → ${type}`);
        return type;
      }
    }

    const syntaxResult = this.detectBySyntax(trimmed);
    if (syntaxResult.type !== ParserType.AUTO) {
      return syntaxResult.type;
    }

    return ParserType.AUTO;
  }

  detectWithConfidence(rule: string): RuleTypeDetectionResult {
    if (!rule || rule.trim().length === 0) {
      return new RuleTypeDetectionResult(ParserType.AUTO, 0, 'empty');
    }

    const trimmed = rule.trim();

    for (const [prefix, type] of RuleTypeDetector.PREFIX_MAP) {
      if (trimmed.startsWith(prefix)) {
        return new RuleTypeDetectionResult(type, 1.0, `prefix:${prefix}`);
      }
    }

    const syntaxResult = this.detectBySyntax(trimmed);
    if (syntaxResult.type !== ParserType.AUTO) {
      return syntaxResult;
    }

    return new RuleTypeDetectionResult(ParserType.AUTO, 0, 'unknown');
  }

  private detectBySyntax(rule: string): RuleTypeDetectionResult {
    for (const [pattern, type, confidence] of RuleTypeDetector.SYNTAX_PATTERNS) {
      if (pattern.test(rule)) {
        return new RuleTypeDetectionResult(type, confidence, `syntax:${pattern.source}`);
      }
    }
    return new RuleTypeDetectionResult(ParserType.AUTO, 0, 'no_syntax_match');
  }

  getPriorityOrder(): ParserType[] {
    return [...RuleTypeDetector.PRIORITY_ORDER];
  }
}
