import { ParserCore, ParserResult } from '../../utils/ParserCore';
import { JsonPathParser } from '../../utils/parsers/JsonPathParser';
import { RegexParser } from '../../utils/parsers/RegexParser';
import { XPathParser } from '../../utils/parsers/XPathParser';
import type { Result } from '../Result';

export class ParserCoreTest {
  private passed: number = 0;
  private failed: number = 0;

  testJsonPathParserBasic(): boolean {
    const json: string = '{"name": "张三", "age": 25}';
    const result: Result<ParserResult> = JsonPathParser.parse(json, '$.name');

    if (result.isErr()) {
      console.error('❌ testJsonPathParserBasic: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== '张三') {
      console.error('❌ testJsonPathParserBasic: value should be "张三"');
      this.failed++;
      return false;
    }

    console.log('✅ testJsonPathParserBasic passed');
    this.passed++;
    return true;
  }

  testJsonPathParserNested(): boolean {
    const json: string = '{"user": {"profile": {"name": "李四"}}}';
    const result: Result<ParserResult> = JsonPathParser.parse(json, '$.user.profile.name');

    if (result.isErr()) {
      console.error('❌ testJsonPathParserNested: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== '李四') {
      console.error('❌ testJsonPathParserNested: value should be "李四"');
      this.failed++;
      return false;
    }

    console.log('✅ testJsonPathParserNested passed');
    this.passed++;
    return true;
  }

  testJsonPathParserArray(): boolean {
    const json: string = '{"items": [{"id": 1}, {"id": 2}, {"id": 3}]}';
    const result: Result<ParserResult> = JsonPathParser.parse(json, '$.items');

    if (result.isErr()) {
      console.error('❌ testJsonPathParserArray: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (!Array.isArray(data.raw)) {
      console.error('❌ testJsonPathParserArray: raw should be array');
      this.failed++;
      return false;
    }

    console.log('✅ testJsonPathParserArray passed');
    this.passed++;
    return true;
  }

  testJsonPathParserInvalidJson(): boolean {
    const invalidJson: string = 'not a json';
    const result: Result<ParserResult> = JsonPathParser.parse(invalidJson, '$.name');

    if (result.isOk()) {
      console.error('❌ testJsonPathParserInvalidJson: should return error for invalid JSON');
      this.failed++;
      return false;
    }

    console.log('✅ testJsonPathParserInvalidJson passed');
    this.passed++;
    return true;
  }

  testRegexParserBasic(): boolean {
    const html: string = '<div class="content">Hello World</div>';
    const result: Result<ParserResult> = RegexParser.parse(html, '<div[^>]*>([^<]+)</div>');

    if (result.isErr()) {
      console.error('❌ testRegexParserBasic: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== 'Hello World') {
      console.error('❌ testRegexParserBasic: value should be "Hello World"');
      this.failed++;
      return false;
    }

    console.log('✅ testRegexParserBasic passed');
    this.passed++;
    return true;
  }

  testRegexParserMultiple(): boolean {
    const html: string = '<a href="link1">Link1</a><a href="link2">Link2</a>';
    const result: Result<ParserResult> = RegexParser.parse(html, '<a[^>]*>([^<]+)</a>');

    if (result.isErr()) {
      console.error('❌ testRegexParserMultiple: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.values.length !== 2) {
      console.error('❌ testRegexParserMultiple: should find 2 matches');
      this.failed++;
      return false;
    }

    console.log('✅ testRegexParserMultiple passed');
    this.passed++;
    return true;
  }

  testRegexParserFirst(): boolean {
    const text: string = 'Price: $100, Discount: $20';
    const result: Result<string> = RegexParser.parseFirst(text, '\\$(\\d+)');

    if (result.isErr()) {
      console.error('❌ testRegexParserFirst: parse should succeed');
      this.failed++;
      return false;
    }

    const data: string = result.data!;
    if (data !== '100') {
      console.error('❌ testRegexParserFirst: value should be "100"');
      this.failed++;
      return false;
    }

    console.log('✅ testRegexParserFirst passed');
    this.passed++;
    return true;
  }

  testRegexParserReplace(): boolean {
    const text: string = 'Hello World';
    const result: string = RegexParser.replace(text, 'World', 'ArkTS');

    if (result !== 'Hello ArkTS') {
      console.error('❌ testRegexParserReplace: result should be "Hello ArkTS"');
      this.failed++;
      return false;
    }

    console.log('✅ testRegexParserReplace passed');
    this.passed++;
    return true;
  }

  testRegexParserEscape(): boolean {
    const escaped: string = RegexParser.escapeRegex('a.b*c+d?');

    if (escaped !== 'a\\.b\\*c\\+d\\?') {
      console.error('❌ testRegexParserEscape: escape result incorrect');
      this.failed++;
      return false;
    }

    console.log('✅ testRegexParserEscape passed');
    this.passed++;
    return true;
  }

  testXPathParserBasic(): boolean {
    const html: string = '<root><item>Value1</item><item>Value2</item></root>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//item');

    if (result.isErr()) {
      console.error('❌ testXPathParserBasic: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.values.length !== 2) {
      console.error(`❌ testXPathParserBasic: should find 2 items, found ${data.values.length}`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserBasic passed');
    this.passed++;
    return true;
  }

  testXPathParserAttribute(): boolean {
    const html: string = '<div class="test" id="main">Content</div>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//div[@class="test"]');

    if (result.isErr()) {
      console.error('❌ testXPathParserAttribute: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.values.length !== 1) {
      console.error(`❌ testXPathParserAttribute: should find 1 item, found ${data.values.length}`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserAttribute passed');
    this.passed++;
    return true;
  }

  testXPathParserPosition(): boolean {
    const html: string = '<ul><li>First</li><li>Second</li><li>Third</li></ul>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//li[1]');

    if (result.isErr()) {
      console.error('❌ testXPathParserPosition: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== 'First') {
      console.error(`❌ testXPathParserPosition: value should be "First", got "${data.value}"`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserPosition passed');
    this.passed++;
    return true;
  }

  testXPathParserContains(): boolean {
    const html: string = '<div class="container main"><span>Content</span></div>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//div[contains(@class, "main")]');

    if (result.isErr()) {
      console.error('❌ testXPathParserContains: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.values.length !== 1) {
      console.error(`❌ testXPathParserContains: should find 1 item, found ${data.values.length}`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserContains passed');
    this.passed++;
    return true;
  }

  testXPathParserNestedPath(): boolean {
    const html: string = '<div class="outer"><div class="inner"><span>Nested Content</span></div></div>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//div[@class="outer"]//span');

    if (result.isErr()) {
      console.error('❌ testXPathParserNestedPath: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== 'Nested Content') {
      console.error(`❌ testXPathParserNestedPath: value should be "Nested Content", got "${data.value}"`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserNestedPath passed');
    this.passed++;
    return true;
  }

  testXPathParserLast(): boolean {
    const html: string = '<ul><li>First</li><li>Second</li><li>Third</li></ul>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//li[last()]');

    if (result.isErr()) {
      console.error('❌ testXPathParserLast: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== 'Third') {
      console.error(`❌ testXPathParserLast: value should be "Third", got "${data.value}"`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserLast passed');
    this.passed++;
    return true;
  }

  testXPathParserWildcard(): boolean {
    const html: string = '<div><span>A</span><p>B</p><a>C</a></div>';
    const result: Result<ParserResult> = XPathParser.parse(html, '//div/*');

    if (result.isErr()) {
      console.error('❌ testXPathParserWildcard: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.values.length !== 3) {
      console.error(`❌ testXPathParserWildcard: should find 3 items, found ${data.values.length}`);
      this.failed++;
      return false;
    }

    console.log('✅ testXPathParserWildcard passed');
    this.passed++;
    return true;
  }

  testParserCoreJsonPath(): boolean {
    const json: string = '{"result": "success"}';
    const result: Result<ParserResult> = ParserCore.parse(json, '$.result');

    if (result.isErr()) {
      console.error('❌ testParserCoreJsonPath: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== 'success') {
      console.error('❌ testParserCoreJsonPath: value should be "success"');
      this.failed++;
      return false;
    }

    console.log('✅ testParserCoreJsonPath passed');
    this.passed++;
    return true;
  }

  testParserCoreRegex(): boolean {
    const html: string = '<title>Page Title</title>';
    const result: Result<ParserResult> = ParserCore.parse(html, '##<title>([^<]+)</title>');

    if (result.isErr()) {
      console.error('❌ testParserCoreRegex: parse should succeed');
      this.failed++;
      return false;
    }

    const data: ParserResult = result.data!;
    if (data.value !== 'Page Title') {
      console.error('❌ testParserCoreRegex: value should be "Page Title"');
      this.failed++;
      return false;
    }

    console.log('✅ testParserCoreRegex passed');
    this.passed++;
    return true;
  }

  testParserCoreXPath(): boolean {
    const html: string = '<root><name>Test</name></root>';
    const result: Result<ParserResult> = ParserCore.parse(html, '//name');

    if (result.isErr()) {
      console.error('❌ testParserCoreXPath: parse should succeed');
      this.failed++;
      return false;
    }

    console.log('✅ testParserCoreXPath passed');
    this.passed++;
    return true;
  }

  testParserCoreEmptyInput(): boolean {
    const result: Result<ParserResult> = ParserCore.parse('', '$.test');

    if (result.isOk()) {
      console.error('❌ testParserCoreEmptyInput: should return error for empty input');
      this.failed++;
      return false;
    }

    console.log('✅ testParserCoreEmptyInput passed');
    this.passed++;
    return true;
  }

  testParserCoreParseList(): boolean {
    const html: string = '<ul><li>Item1</li><li>Item2</li><li>Item3</li></ul>';
    const result: Result<string[]> = ParserCore.parseList(html, '//li');

    if (result.isErr()) {
      console.error('❌ testParserCoreParseList: parse should succeed');
      this.failed++;
      return false;
    }

    const data: string[] = result.data!;
    if (data.length !== 3) {
      console.error('❌ testParserCoreParseList: should find 3 items');
      this.failed++;
      return false;
    }

    console.log('✅ testParserCoreParseList passed');
    this.passed++;
    return true;
  }

  testParserCoreParseValue(): boolean {
    const json: string = '{"key": "value"}';
    const result: Result<string> = ParserCore.parseValue(json, '$.key');

    if (result.isErr()) {
      console.error('❌ testParserCoreParseValue: parse should succeed');
      this.failed++;
      return false;
    }

    const data: string = result.data!;
    if (data !== 'value') {
      console.error('❌ testParserCoreParseValue: value should be "value"');
      this.failed++;
      return false;
    }

    console.log('✅ testParserCoreParseValue passed');
    this.passed++;
    return true;
  }

  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting ParserCore tests...');

    this.testJsonPathParserBasic();
    this.testJsonPathParserNested();
    this.testJsonPathParserArray();
    this.testJsonPathParserInvalidJson();
    this.testRegexParserBasic();
    this.testRegexParserMultiple();
    this.testRegexParserFirst();
    this.testRegexParserReplace();
    this.testRegexParserEscape();
    this.testXPathParserBasic();
    this.testXPathParserAttribute();
    this.testXPathParserPosition();
    this.testXPathParserContains();
    this.testXPathParserNestedPath();
    this.testXPathParserLast();
    this.testXPathParserWildcard();
    this.testParserCoreJsonPath();
    this.testParserCoreRegex();
    this.testParserCoreXPath();
    this.testParserCoreEmptyInput();
    this.testParserCoreParseList();
    this.testParserCoreParseValue();

    const total: number = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);

    if (this.failed === 0) {
      console.log('✅ All ParserCore tests passed!');
      return true;
    } else {
      console.log('❌ Some ParserCore tests failed');
      return false;
    }
  }
}

const parserCoreTest: ParserCoreTest = new ParserCoreTest();
export default parserCoreTest;
