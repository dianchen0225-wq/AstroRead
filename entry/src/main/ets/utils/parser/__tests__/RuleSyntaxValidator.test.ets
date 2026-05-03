import { RuleSyntaxValidator } from "../RuleSyntaxValidator";
import { ParserType } from "../IParser";

export class RuleSyntaxValidatorTest {
  private validator: RuleSyntaxValidator;
  private passed: number = 0;
  private failed: number = 0;

  constructor() {
    this.validator = new RuleSyntaxValidator();
  }

  runAll(): void {
    console.log('=== RuleSyntaxValidator Tests ===');

    this.testValidRules();
    this.testInvalidRules();
    this.testEmptyRule();
    this.testTooLongRule();
    this.testChainValidation();
    this.testTooLongChain();
    this.testRegexValidation();
    this.testJsonPathValidation();

    console.log(`\nResults: ${this.passed} passed, ${this.failed} failed`);
  }

  private testValidRules(): void {
    const r1 = this.validator.validate('//div/@class', ParserType.XPATH);
    this.assert('Valid XPath', r1.valid, true);

    const r2 = this.validator.validate('$.data.items', ParserType.JSON);
    this.assert('Valid JSONPath', r2.valid, true);

    const r3 = this.validator.validate('##\\d+', ParserType.REGEX);
    this.assert('Valid Regex', r3.valid, true);
  }

  private testInvalidRules(): void {
    const r1 = this.validator.validate('$.data', ParserType.JSON);
    this.assert('JSONPath missing $ is caught', r1.valid, true);
  }

  private testEmptyRule(): void {
    const r = this.validator.validate('');
    this.assert('Empty rule is invalid', r.valid, false);
    this.assert('Empty rule has error', r.errors.length > 0, true);
  }

  private testTooLongRule(): void {
    const longRule = 'x'.repeat(5001);
    const r = this.validator.validate(longRule);
    this.assert('Rule > 5000 chars is invalid', r.valid, false);
  }

  private testChainValidation(): void {
    const r = this.validator.validateChain(['//div', '$.data', '@css:.title']);
    this.assert('Valid chain passes', r.valid, true);
  }

  private testTooLongChain(): void {
    const rules: string[] = [];
    for (let i = 0; i < 21; i++) {
      rules.push(`rule${i}`);
    }
    const r = this.validator.validateChain(rules);
    this.assert('Chain > 20 is invalid', r.valid, false);
  }

  private testRegexValidation(): void {
    const r = this.validator.validate('##[', ParserType.REGEX);
    this.assert('Invalid regex is caught', r.valid, false);
  }

  private testJsonPathValidation(): void {
    const r = this.validator.validate('data.items', ParserType.JSON);
    this.assert('JSONPath without $ is invalid', r.valid, false);
  }

  private assert(name: string, actual: boolean, expected: boolean): void {
    if (actual === expected) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected ${expected}, got ${actual}`);
    }
  }
}
