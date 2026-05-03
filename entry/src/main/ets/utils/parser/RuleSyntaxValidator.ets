import { ParserType } from "./IParser";
import { IRuleSyntaxValidator, RuleValidationReport } from "./interfaces/IUnifiedParseEngine";
import { CrawlErrorCode, CrawlError } from "../crawler/models/CrawlError";
import { Logger } from "../performance/Logger";

export class RuleSyntaxValidator implements IRuleSyntaxValidator {
  private static readonly TAG = 'RuleSyntaxValidator';
  private static readonly MAX_CHAIN_LENGTH = 20;
  private static readonly MAX_RULE_LENGTH = 5000;

  validate(rule: string, type?: ParserType): RuleValidationReport {
    const report: RuleValidationReport = {
      valid: true,
      rule: rule,
      type: type ?? null,
      errors: [],
      warnings: [],
    };

    if (!rule || rule.trim().length === 0) {
      report.valid = false;
      report.errors.push('规则不能为空');
      return report;
    }

    if (rule.length > RuleSyntaxValidator.MAX_RULE_LENGTH) {
      report.valid = false;
      report.errors.push(
        CrawlError.create(CrawlErrorCode.RULE_CONTENT_TOO_LONG, `规则内容超过${RuleSyntaxValidator.MAX_RULE_LENGTH}字符上限`).getLocalizedMessage()
      );
      return report;
    }

    const detectedType = type ?? ParserType.AUTO;
    if (detectedType !== ParserType.AUTO) {
      this.validateByType(rule, detectedType, report);
    }

    return report;
  }

  validateChain(rules: string[]): RuleValidationReport {
    const report: RuleValidationReport = {
      valid: true,
      rule: rules.join('&&'),
      type: null,
      errors: [],
      warnings: [],
    };

    if (rules.length > RuleSyntaxValidator.MAX_CHAIN_LENGTH) {
      report.valid = false;
      report.errors.push(
        CrawlError.create(CrawlErrorCode.RULE_CHAIN_TOO_LONG, `规则链长度${rules.length}超过上限${RuleSyntaxValidator.MAX_CHAIN_LENGTH}`).getLocalizedMessage()
      );
      return report;
    }

    for (let i = 0; i < rules.length; i++) {
      const singleReport = this.validate(rules[i]);
      if (!singleReport.valid) {
        report.valid = false;
        report.errors.push(`规则[${i}]: ${singleReport.errors.join('; ')}`);
      }
      report.warnings.push(...singleReport.warnings.map((w: string) => `规则[${i}]: ${w}`));
    }

    return report;
  }

  private validateByType(rule: string, type: ParserType, report: RuleValidationReport): void {
    switch (type) {
      case ParserType.XPATH:
        this.validateXPath(rule, report);
        break;
      case ParserType.JSON:
        this.validateJsonPath(rule, report);
        break;
      case ParserType.REGEX:
        this.validateRegex(rule, report);
        break;
      case ParserType.CSS:
        this.validateCss(rule, report);
        break;
      case ParserType.JS:
        this.validateJS(rule, report);
        break;
      default:
        break;
    }
  }

  private validateXPath(rule: string, report: RuleValidationReport): void {
    const cleanRule = rule.replace(/^\/\//, '/').replace(/^@css:|^css:/, '');
    if (cleanRule.includes('///')) {
      report.warnings.push('XPath包含连续斜杠，可能不是有效表达式');
    }
    if (!/[a-zA-Z\*@]/.test(cleanRule)) {
      report.valid = false;
      report.errors.push('XPath表达式缺少有效节点名称');
    }
  }

  private validateJsonPath(rule: string, report: RuleValidationReport): void {
    const cleanRule = rule.replace(/^@json:/, '');
    if (!cleanRule.startsWith('$')) {
      report.valid = false;
      report.errors.push('JSONPath必须以$开头');
    }
    if (/\.\./.test(cleanRule) && !cleanRule.includes('$..')) {
      report.warnings.push('JSONPath包含非标准双点语法');
    }
  }

  private validateRegex(rule: string, report: RuleValidationReport): void {
    const cleanRule = rule.replace(/^##/, '').replace(/^@regex:/, '');
    try {
      new RegExp(cleanRule);
    } catch (e) {
      report.valid = false;
      report.errors.push(`正则表达式语法错误: ${e instanceof Error ? e.message : String(e)}`);
    }
    if (cleanRule.length > 2000) {
      report.warnings.push('正则表达式过长，可能存在ReDoS风险');
    }
  }

  private validateCss(rule: string, report: RuleValidationReport): void {
    const cleanRule = rule.replace(/^@css:/, '').replace(/^css:/, '');
    if (!cleanRule || cleanRule.trim().length === 0) {
      report.valid = false;
      report.errors.push('CSS选择器不能为空');
    }
    if (/[{}]/.test(cleanRule) && !cleanRule.includes('::')) {
      report.warnings.push('CSS选择器包含花括号，可能不是有效选择器');
    }
  }

  private validateJS(rule: string, report: RuleValidationReport): void {
    const cleanRule = rule.replace(/^@js:/, '').replace(/^<js>/, '').replace(/<\/js>/, '').replace(/^javascript:/, '');
    if (!cleanRule || cleanRule.trim().length === 0) {
      report.valid = false;
      report.errors.push('JS脚本不能为空');
    }
    if (cleanRule.includes('eval(') || cleanRule.includes('Function(')) {
      report.warnings.push('JS脚本包含eval/Function调用，存在安全风险');
    }
  }
}
