import { ParserResult } from "../../parser/IParser";

export enum DegradationType {
  NONE = 'none',
  BACKUP_RULE = 'backup_rule',
  LOOSE_MATCH = 'loose_match',
  EXPANDED_SCOPE = 'expanded_scope'
}

export class DegradationResult {
  result: ParserResult;
  degradationType: DegradationType;
  usedRule: string;
  originalRule: string;
  fallbackIndex: number;

  constructor(
    result: ParserResult,
    degradationType: DegradationType,
    usedRule: string,
    originalRule: string,
    fallbackIndex: number = -1
  ) {
    this.result = result;
    this.degradationType = degradationType;
    this.usedRule = usedRule;
    this.originalRule = originalRule;
    this.fallbackIndex = fallbackIndex;
  }

  isDegraded(): boolean {
    return this.degradationType !== DegradationType.NONE;
  }

  static fromMainRule(result: ParserResult, rule: string): DegradationResult {
    return new DegradationResult(result, DegradationType.NONE, rule, rule, -1);
  }

  static fromBackupRule(result: ParserResult, rule: string, originalRule: string, index: number): DegradationResult {
    return new DegradationResult(result, DegradationType.BACKUP_RULE, rule, originalRule, index);
  }

  static fromLooseMatch(result: ParserResult, rule: string, originalRule: string): DegradationResult {
    return new DegradationResult(result, DegradationType.LOOSE_MATCH, rule, originalRule, -1);
  }
}
