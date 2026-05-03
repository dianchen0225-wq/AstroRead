import { RuleTypeDetector } from "../RuleTypeDetector";
import { ParserType } from "../IParser";

export class RuleTypeDetectorTest {
  private detector: RuleTypeDetector;
  private passed: number = 0;
  private failed: number = 0;

  constructor() {
    this.detector = new RuleTypeDetector();
  }

  runAll(): void {
    console.log('=== RuleTypeDetector Tests ===');

    this.testXPathDetection();
    this.testJsonPathDetection();
    this.testCssDetection();
    this.testRegexDetection();
    this.testJSDetection();
    this.testAutoDetection();
    this.testEmptyRule();

    console.log(`\nResults: ${this.passed} passed, ${this.failed} failed`);
  }

  private testXPathDetection(): void {
    this.assert('XPath: //div/@class', this.detector.detect('//div/@class'), ParserType.XPATH);
    this.assert('XPath: ./span/text()', this.detector.detect('./span/text()'), ParserType.XPATH);
    this.assert('XPath: /html/body/div', this.detector.detect('/html/body/div'), ParserType.XPATH);
  }

  private testJsonPathDetection(): void {
    this.assert('JSONPath: $.data.items', this.detector.detect('$.data.items'), ParserType.JSON);
    this.assert('JSONPath: @json:$.result', this.detector.detect('@json:$.result'), ParserType.JSON);
  }

  private testCssDetection(): void {
    this.assert('CSS: @css:.book-title', this.detector.detect('@css:.book-title'), ParserType.CSS);
    this.assert('CSS: css:div.content', this.detector.detect('css:div.content'), ParserType.CSS);
  }

  private testRegexDetection(): void {
    this.assert('Regex: ##pattern', this.detector.detect('##\\d+'), ParserType.REGEX);
    this.assert('Regex: @regex:pattern', this.detector.detect('@regex:\\w+'), ParserType.REGEX);
  }

  private testJSDetection(): void {
    this.assert('JS: @js:script', this.detector.detect('@js:result.data'), ParserType.JS);
    this.assert('JS: <js>script</js>', this.detector.detect('<js>return html'), ParserType.JS);
    this.assert('JS: javascript:expr', this.detector.detect('javascript:document.title'), ParserType.JS);
  }

  private testAutoDetection(): void {
    const result = this.detector.detect('unknown_rule_format');
    this.assert('Unknown rule returns AUTO', result, ParserType.AUTO);
  }

  private testEmptyRule(): void {
    this.assert('Empty rule returns AUTO', this.detector.detect(''), ParserType.AUTO);
    this.assert('Whitespace rule returns AUTO', this.detector.detect('   '), ParserType.AUTO);
  }

  private assert(name: string, actual: ParserType, expected: ParserType): void {
    if (actual === expected) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected ${expected}, got ${actual}`);
    }
  }
}
