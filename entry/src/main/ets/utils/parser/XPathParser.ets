import { Logger } from '../performance/Logger';
import { Result, ErrorCode } from '../../core/Result';
import { BaseParser, IParser, ParserResult, ParserType, ParseOptions } from './IParser';
import { XPathEngine } from './XPathEngine';

export class XPathParser extends BaseParser {
  readonly type: ParserType = ParserType.XPATH;
  readonly name: string = 'XPathParser';
  private static readonly TAG = 'XPathParser';
  private xpathEngine: XPathEngine = XPathEngine.getInstance();

  canHandle(rule: string): boolean {
    if (!rule) return false;
    const trimmed = rule.trim();
    return trimmed.startsWith('//') || 
           trimmed.startsWith('./') || 
           trimmed.startsWith('/html') ||
           trimmed.startsWith('/body');
  }

  parse(html: string, rule: string, _options?: ParseOptions): Result<ParserResult> {
    if (!this.validateInput(html, rule)) {
      return this.createErrorResult('XPath parse: empty input');
    }

    try {
      const result = this.xpathEngine.evaluate(html, rule);
      
      const xpathResult = new ParserResult(
        result.values.length > 0 ? result.values[0] : '',
        result.values,
        result.values
      );
      return Result.ok(xpathResult);
    } catch (error) {
      Logger.error(XPathParser.TAG, `XPath解析失败: ${error}`);
      return this.createErrorResult(
        `XPath parse failed: ${error}`,
        ErrorCode.PARSE_XPATH_ERROR,
        error instanceof Error ? error.stack : String(error)
      );
    }
  }

  selectElements(html: string, xpath: string): string[] {
    return this.xpathEngine.selectElements(html, xpath);
  }

  selectFirst(html: string, xpath: string): string {
    return this.xpathEngine.selectFirst(html, xpath);
  }

  extractAttribute(html: string, xpath: string, attrName: string): string {
    return this.xpathEngine.extractAttribute(html, xpath, attrName);
  }
}

export default XPathParser;
