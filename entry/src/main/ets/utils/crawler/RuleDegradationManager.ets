import { Result, ErrorCode } from "../../core/Result";
import { ParserResult, ParseOptions } from "../parser/IParser";
import { IRuleDegradationManager, RuleDegradationConfig } from "./interfaces/IStability";
import { DegradationResult, DegradationType } from "./models/DegradationResult";
import { RuleFailureDetector } from "./RuleFailureDetector";
import { ExceptionIsolationGuard } from "./ExceptionIsolationGuard";
import { UnifiedParseEngine } from "../parser/UnifiedParseEngine";
import { Logger } from "../performance/Logger";

export class RuleDegradationManager implements IRuleDegradationManager {
  private static readonly TAG = 'RuleDegradationManager';

  private failureDetector: RuleFailureDetector;
  private isolationGuard: ExceptionIsolationGuard;
  private parseEngine: UnifiedParseEngine;
  private config: RuleDegradationConfig;
  private fallbackMap: Map<string, string[]> = new Map();

  constructor(
    failureDetector?: RuleFailureDetector,
    isolationGuard?: ExceptionIsolationGuard,
    parseEngine?: UnifiedParseEngine,
    config?: Partial<RuleDegradationConfig>
  ) {
    this.failureDetector = failureDetector ?? new RuleFailureDetector();
    this.isolationGuard = isolationGuard ?? new ExceptionIsolationGuard();
    this.parseEngine = parseEngine ?? UnifiedParseEngine.getInstance();
    this.config = {
      maxFallbackRules: config?.maxFallbackRules ?? 3,
      enableLooseMatch: config?.enableLooseMatch ?? true,
      failureThreshold: config?.failureThreshold ?? 10,
      failureWindowMs: config?.failureWindowMs ?? 24 * 60 * 60 * 1000,
    };
  }

  async tryDegradation(
    content: string,
    mainRule: string,
    fallbackRules: string[],
    options?: Record<string, string>
  ): Promise<Result<DegradationResult>> {
    const parseOptions = options ? new ParseOptions() : undefined;
    if (options && parseOptions) {
      parseOptions.context = new Map(Object.entries(options));
    }

    const mainResult = this.parseEngine.parse(content, mainRule, parseOptions);
    if (mainResult.isOk() && !mainResult.data!.isEmpty()) {
      return Result.ok(DegradationResult.fromMainRule(mainResult.data!, mainRule));
    }

    Logger.debug(RuleDegradationManager.TAG, `Main rule failed, trying fallback rules`);

    const allFallbacks = this.getAllFallbacks(mainRule, fallbackRules);
    const maxFallbacks = Math.min(allFallbacks.length, this.config.maxFallbackRules);

    for (let i = 0; i < maxFallbacks; i++) {
      const fallbackRule = allFallbacks[i];
      Logger.debug(RuleDegradationManager.TAG, `Trying fallback[${i}]: ${fallbackRule}`);

      const fallbackResult = this.parseEngine.parse(content, fallbackRule, parseOptions);
      if (fallbackResult.isOk() && !fallbackResult.data!.isEmpty()) {
        Logger.info(RuleDegradationManager.TAG, `Fallback rule[${i}] succeeded`);
        return Result.ok(DegradationResult.fromBackupRule(
          fallbackResult.data!, fallbackRule, mainRule, i
        ));
      }
    }

    if (this.config.enableLooseMatch) {
      Logger.debug(RuleDegradationManager.TAG, `Trying loose match degradation`);
      const looseResult = this.tryLooseMatch(content, mainRule, parseOptions);
      if (looseResult !== null) {
        return Result.ok(looseResult);
      }
    }

    this.failureDetector.recordFailure(mainRule);
    return Result.err(ErrorCode.PARSE_ERROR, '规则降级失败: 所有降级策略均无法解析内容');
  }

  addFallbackRule(ruleId: string, fallbackRule: string): void {
    const existing = this.fallbackMap.get(ruleId) ?? [];
    if (existing.length < this.config.maxFallbackRules) {
      existing.push(fallbackRule);
      this.fallbackMap.set(ruleId, existing);
    }
  }

  removeFallbackRule(ruleId: string, fallbackRule: string): void {
    const existing = this.fallbackMap.get(ruleId);
    if (existing) {
      const idx = existing.indexOf(fallbackRule);
      if (idx >= 0) {
        existing.splice(idx, 1);
      }
    }
  }

  getConfig(): RuleDegradationConfig {
    return { ...this.config };
  }

  private getAllFallbacks(mainRule: string, providedFallbacks: string[]): string[] {
    const registered = this.fallbackMap.get(mainRule) ?? [];
    const all = [...providedFallbacks];
    for (const r of registered) {
      if (!all.includes(r)) {
        all.push(r);
      }
    }
    return all;
  }

  private tryLooseMatch(content: string, rule: string, options?: ParseOptions): DegradationResult | null {
    let looseRule = rule;

    const lowerContent = content.toLowerCase();

    if (looseRule.startsWith('@css:')) {
      const selector = looseRule.substring(5);
      const looseSelector = selector
        .replace(/\[class="([^"]+)"\]/g, (_match: string, cls: string) => `[class*="${cls}"]`)
        .replace(/>/g, ' ');
      looseRule = `@css:${looseSelector}`;
    }

    const looseResult = this.parseEngine.parse(content, looseRule, options);
    if (looseResult.isOk() && !looseResult.data!.isEmpty()) {
      Logger.info(RuleDegradationManager.TAG, 'Loose match succeeded');
      return DegradationResult.fromLooseMatch(looseResult.data!, looseRule, rule);
    }

    return null;
  }
}
