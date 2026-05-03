import { Result } from "../../../core/Result";
import { ParserResult, ParseOptions, ParserType } from "../IParser";
import { DegradationResult } from "../../crawler/models/DegradationResult";

export interface RuleValidationReport {
  valid: boolean;
  rule: string;
  type: ParserType | null;
  errors: string[];
  warnings: string[];
}

export interface IRuleTypeDetector {
  detect(rule: string): ParserType;
  detectWithConfidence(rule: string): RuleTypeDetectionResult;
}

export class RuleTypeDetectionResult {
  type: ParserType = ParserType.AUTO;
  confidence: number = 0;
  method: string = '';

  constructor(type: ParserType, confidence: number, method: string) {
    this.type = type;
    this.confidence = confidence;
    this.method = method;
  }
}

export interface IParseResultCache {
  get(contentHash: string, rule: string): ParserResult | null;
  set(contentHash: string, rule: string, result: ParserResult): void;
  invalidate(contentHash: string, rule: string): boolean;
  clear(): void;
  getStats(): CacheStats;
}

export class CacheStats {
  hits: number = 0;
  misses: number = 0;
  hitRate: number = 0;
  size: number = 0;
  capacity: number = 0;
  memoryUsageBytes: number = 0;
}

export interface IRuleSyntaxValidator {
  validate(rule: string, type?: ParserType): RuleValidationReport;
  validateChain(rules: string[]): RuleValidationReport;
}

export interface IUnifiedParseEngine {
  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult>;
  parseChain(content: string, rules: string[], operator: RuleChainOperator, options?: ParseOptions): Result<ParserResult>;
  parseWithDegradation(content: string, rule: string, fallbackRules: string[], options?: ParseOptions): Result<DegradationResult>;
  validateRule(rule: string, type?: ParserType): RuleValidationReport;
}

export enum RuleChainOperator {
  AND = '&&',
  OR = '||',
  MERGE = '%%'
}
