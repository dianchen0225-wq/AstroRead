import { Result, ErrorCode } from "../../core/Result";
import { ParserResult, ParseOptions } from "./IParser";
import { RuleAnalyzer } from "./RuleAnalyzer";
import { IUnifiedParseEngine, RuleChainOperator } from "./interfaces/IUnifiedParseEngine";
import { Logger } from "../performance/Logger";

export class RuleChainExecutor {
  private static readonly TAG = 'RuleChainExecutor';

  executeChain(
    content: string,
    rules: string[],
    operator: RuleChainOperator,
    parseFn: (content: string, rule: string, options?: ParseOptions) => Result<ParserResult>,
    options?: ParseOptions
  ): Result<ParserResult> {
    if (!rules || rules.length === 0) {
      return Result.ok(ParserResult.empty());
    }

    if (rules.length === 1) {
      return parseFn(content, rules[0], options);
    }

    switch (operator) {
      case RuleChainOperator.AND:
        return this.executeAnd(content, rules, parseFn, options);
      case RuleChainOperator.OR:
        return this.executeOr(content, rules, parseFn, options);
      case RuleChainOperator.MERGE:
        return this.executeMerge(content, rules, parseFn, options);
      default:
        return Result.err(ErrorCode.PARSE_ERROR, `Unknown chain operator: ${operator}`);
    }
  }

  private executeAnd(
    content: string,
    rules: string[],
    parseFn: (content: string, rule: string, options?: ParseOptions) => Result<ParserResult>,
    options?: ParseOptions
  ): Result<ParserResult> {
    let currentContent = content;
    let lastResult: Result<ParserResult> | null = null;

    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i];
      lastResult = parseFn(currentContent, rule, options);

      if (lastResult.isErr()) {
        Logger.debug(RuleChainExecutor.TAG, `AND chain short-circuit at rule[${i}]: error`);
        return lastResult;
      }

      const data = lastResult.data!;
      if (data.isEmpty()) {
        Logger.debug(RuleChainExecutor.TAG, `AND chain short-circuit at rule[${i}]: empty result`);
        return Result.ok(ParserResult.empty());
      }

      currentContent = data.value || data.values.join('\n');
    }

    return lastResult!;
  }

  private executeOr(
    content: string,
    rules: string[],
    parseFn: (content: string, rule: string, options?: ParseOptions) => Result<ParserResult>,
    options?: ParseOptions
  ): Result<ParserResult> {
    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i];
      const result = parseFn(content, rule, options);

      if (result.isOk()) {
        const data = result.data!;
        if (!data.isEmpty()) {
          Logger.debug(RuleChainExecutor.TAG, `OR chain short-circuit at rule[${i}]: success`);
          return result;
        }
      }
    }

    Logger.debug(RuleChainExecutor.TAG, 'OR chain: all rules returned empty');
    return Result.ok(ParserResult.empty());
  }

  private executeMerge(
    content: string,
    rules: string[],
    parseFn: (content: string, rule: string, options?: ParseOptions) => Result<ParserResult>,
    options?: ParseOptions
  ): Result<ParserResult> {
    const allValues: string[] = [];
    let hasError = false;
    let errorMsg = '';

    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i];
      const result = parseFn(content, rule, options);

      if (result.isErr()) {
        hasError = true;
        errorMsg = result.error?.message ?? 'Parse error';
        continue;
      }

      const data = result.data!;
      if (!data.isEmpty()) {
        allValues.push(...data.values);
      }
    }

    if (allValues.length === 0 && hasError) {
      return Result.err(ErrorCode.PARSE_ERROR, errorMsg);
    }

    return Result.ok(ParserResult.fromValues(allValues));
  }

  splitRuleByOperator(rule: string): { rules: string[], operator: RuleChainOperator } {
    if (rule.includes('%%')) {
      return { rules: this.splitByOperator(rule, '%%'), operator: RuleChainOperator.MERGE };
    }
    if (rule.includes('||')) {
      return { rules: this.splitByOperator(rule, '||'), operator: RuleChainOperator.OR };
    }
    if (rule.includes('&&')) {
      return { rules: this.splitByOperator(rule, '&&'), operator: RuleChainOperator.AND };
    }
    return { rules: [rule], operator: RuleChainOperator.AND };
  }

  private splitByOperator(rule: string, operator: string): string[] {
    const analyzer = new RuleAnalyzer(rule);
    const parts: string[] = [];

    while (analyzer.pos < rule.length) {
      analyzer.start = analyzer.pos;
      analyzer.startX = analyzer.pos;

      const part = analyzer.splitRule(operator);
      if (part !== null && part.length > 0) {
        parts.push(part);
      }

      if (analyzer.step === 0) {
        break;
      }
      analyzer.pos += analyzer.step;
    }

    if (parts.length === 0) {
      return [rule];
    }

    return parts;
  }
}
