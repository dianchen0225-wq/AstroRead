import { Result, ErrorCode } from "../../core/Result";
import { ParserResult, ParseOptions, ParserType, ParserRegistry } from "./IParser";
import { IUnifiedParseEngine, IRuleTypeDetector, IParseResultCache, IRuleSyntaxValidator, RuleValidationReport, RuleChainOperator } from "./interfaces/IUnifiedParseEngine";
import { RuleTypeDetector } from "./RuleTypeDetector";
import { RuleSyntaxValidator } from "./RuleSyntaxValidator";
import { ParseResultCache } from "./ParseResultCache";
import { RuleChainExecutor } from "./RuleChainExecutor";
import { DegradationResult, DegradationType } from "../crawler/models/DegradationResult";
import { Logger } from "../performance/Logger";

export class UnifiedParseEngine implements IUnifiedParseEngine {
  private static readonly TAG = 'UnifiedParseEngine';
  private static instance: UnifiedParseEngine | null = null;

  private typeDetector: IRuleTypeDetector;
  private syntaxValidator: IRuleSyntaxValidator;
  private resultCache: IParseResultCache;
  private chainExecutor: RuleChainExecutor;
  private registry: ParserRegistry;

  private constructor(
    typeDetector?: IRuleTypeDetector,
    syntaxValidator?: IRuleSyntaxValidator,
    resultCache?: IParseResultCache
  ) {
    this.typeDetector = typeDetector ?? new RuleTypeDetector();
    this.syntaxValidator = syntaxValidator ?? new RuleSyntaxValidator();
    this.resultCache = resultCache ?? new ParseResultCache();
    this.chainExecutor = new RuleChainExecutor();
    this.registry = ParserRegistry.getInstance();
  }

  static getInstance(
    typeDetector?: IRuleTypeDetector,
    syntaxValidator?: IRuleSyntaxValidator,
    resultCache?: IParseResultCache
  ): UnifiedParseEngine {
    if (!UnifiedParseEngine.instance) {
      UnifiedParseEngine.instance = new UnifiedParseEngine(typeDetector, syntaxValidator, resultCache);
    }
    return UnifiedParseEngine.instance;
  }

  static resetInstance(): void {
    UnifiedParseEngine.instance = null;
  }

  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    const validation = this.syntaxValidator.validate(rule);
    if (!validation.valid) {
      Logger.warn(UnifiedParseEngine.TAG, `Rule validation failed: ${validation.errors.join('; ')}`);
      return Result.err(ErrorCode.SOURCE_RULE_INVALID, `规则校验失败: ${validation.errors.join('; ')}`);
    }

    const contentHash = this.hashContent(content);
    const cached = this.resultCache.get(contentHash, rule);
    if (cached !== null) {
      Logger.debug(UnifiedParseEngine.TAG, 'Cache hit, returning cached result');
      return Result.ok(cached);
    }

    const { rules, operator } = this.chainExecutor.splitRuleByOperator(rule);
    if (rules.length > 1) {
      const chainResult = this.chainExecutor.executeChain(
        content, rules, operator,
        (c, r, o) => this.parseSingle(c, r, o),
        options
      );
      if (chainResult.isOk()) {
        this.resultCache.set(contentHash, rule, chainResult.data!);
      }
      return chainResult;
    }

    const result = this.parseSingle(content, rule, options);
    if (result.isOk()) {
      this.resultCache.set(contentHash, rule, result.data!);
    }
    return result;
  }

  parseChain(content: string, rules: string[], operator: RuleChainOperator, options?: ParseOptions): Result<ParserResult> {
    const chainValidation = this.syntaxValidator.validateChain(rules);
    if (!chainValidation.valid) {
      return Result.err(ErrorCode.SOURCE_RULE_INVALID, `规则链校验失败: ${chainValidation.errors.join('; ')}`);
    }

    return this.chainExecutor.executeChain(
      content, rules, operator,
      (c, r, o) => this.parseSingle(c, r, o),
      options
    );
  }

  parseWithDegradation(content: string, rule: string, fallbackRules: string[], options?: ParseOptions): Result<DegradationResult> {
    const mainResult = this.parse(content, rule, options);
    if (mainResult.isOk() && !mainResult.data!.isEmpty()) {
      return Result.ok(DegradationResult.fromMainRule(mainResult.data!, rule));
    }

    for (let i = 0; i < Math.min(fallbackRules.length, 3); i++) {
      const fallbackRule = fallbackRules[i];
      Logger.debug(UnifiedParseEngine.TAG, `Trying fallback rule[${i}]: ${fallbackRule}`);
      const fallbackResult = this.parse(content, fallbackRule, options);
      if (fallbackResult.isOk() && !fallbackResult.data!.isEmpty()) {
        return Result.ok(DegradationResult.fromBackupRule(fallbackResult.data!, fallbackRule, rule, i));
      }
    }

    Logger.debug(UnifiedParseEngine.TAG, 'Trying loose match degradation');
    const looseResult = this.tryLooseMatch(content, rule, options);
    if (looseResult !== null) {
      return Result.ok(looseResult);
    }

    return Result.err(ErrorCode.PARSE_ERROR, '所有降级策略均失败，无法解析内容');
  }

  validateRule(rule: string, type?: ParserType): RuleValidationReport {
    const validation = this.syntaxValidator.validate(rule, type);
    if (validation.valid && !type) {
      const detected = this.typeDetector.detect(rule);
      validation.type = detected;
    }
    return validation;
  }

  getCache(): IParseResultCache {
    return this.resultCache;
  }

  getTypeDetector(): IRuleTypeDetector {
    return this.typeDetector;
  }

  private parseSingle(content: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    const detectedType = this.typeDetector.detect(rule);
    if (detectedType !== ParserType.AUTO) {
      const parser = this.registry.get(detectedType);
      if (parser !== null) {
        return parser.parse(content, rule, options);
      }
    }

    return this.registry.parse(content, rule, options);
  }

  private tryLooseMatch(content: string, rule: string, options?: ParseOptions): DegradationResult | null {
    let looseRule = rule;

    const lowerContent = content.toLowerCase();

    looseRule = looseRule.replace(/@css:/, '@css:');
    const lowerRule = looseRule.toLowerCase();

    const regexMatch = lowerRule.match(/##(.+)/);
    if (regexMatch) {
      try {
        const pattern = new RegExp(regexMatch[1], 'i');
        const match = pattern.exec(content);
        if (match && match.length > 1) {
          return DegradationResult.fromLooseMatch(
            ParserResult.fromValue(match[1]),
            looseRule,
            rule
          );
        }
      } catch (_) {
      }
    }

    return null;
  }

  private hashContent(content: string): string {
    if (content.length <= 64) {
      return content;
    }
    let hash = 0;
    const sampleSize = 64;
    const step = Math.max(1, Math.floor(content.length / sampleSize));
    for (let i = 0; i < content.length; i += step) {
      hash = ((hash << 5) - hash + content.charCodeAt(i)) | 0;
    }
    return Math.abs(hash).toString(36);
  }
}
