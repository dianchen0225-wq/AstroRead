import { Logger } from "../performance/Logger";
import { Result, ErrorCode } from "../../core/Result";
import { ParserRegistry, ParserResult, ParseOptions, ParserType } from "./IParser";
import { JsonPathParser } from './JsonPathParser';
import { RegexParser } from './RegexParser';
import { XPathParser } from './XPathParser';
import { JSParser } from './JSParser';
import { CssParser } from './CssParser';

export type JsonValue = string | number | boolean | object | null | undefined;
export type JsonData = Record<string, JsonValue>;
export type JsonArray = JsonValue[];

export { ParserResult, ParseOptions };

export class ParserCore {
  private static readonly TAG = 'ParserCore';
  private static registry: ParserRegistry = ParserRegistry.getInstance();
  private static initialized: boolean = false;

  static initialize(): void {
    if (ParserCore.initialized) return;

    ParserCore.registry.register(new JsonPathParser());
    ParserCore.registry.register(new RegexParser());
    ParserCore.registry.register(new XPathParser());
    ParserCore.registry.register(new JSParser());
    ParserCore.registry.register(new CssParser());

    ParserCore.initialized = true;
    Logger.info(ParserCore.TAG, 'ParserCore initialized with all parsers');
  }

  static parse(html: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    if (!ParserCore.initialized) {
      ParserCore.initialize();
    }

    if (!html || !rule) {
      return Result.err(ErrorCode.PARSE_ERROR, 'Parse: empty input');
    }

    return ParserCore.registry.parse(html, rule, options);
  }

  static parseList(html: string, rule: string, options?: ParseOptions): Result<string[]> {
    if (!ParserCore.initialized) {
      ParserCore.initialize();
    }

    if (!html || !rule) {
      return Result.err(ErrorCode.PARSE_ERROR, 'Parse: empty input');
    }

    return ParserCore.registry.parseList(html, rule, options);
  }

  static parseValue(html: string, rule: string, options?: ParseOptions): Result<string> {
    if (!ParserCore.initialized) {
      ParserCore.initialize();
    }

    if (!html || !rule) {
      return Result.err(ErrorCode.PARSE_ERROR, 'Parse: empty input');
    }

    return ParserCore.registry.parseValue(html, rule, options);
  }

  static getRegistry(): ParserRegistry {
    if (!ParserCore.initialized) {
      ParserCore.initialize();
    }
    return ParserCore.registry;
  }

  static getParser(type: ParserType) {
    if (!ParserCore.initialized) {
      ParserCore.initialize();
    }
    return ParserCore.registry.get(type);
  }

  static detectRuleType(rule: string): ParserType {
    if (!rule) return ParserType.AUTO;

    const trimmed = rule.trim();

    if (trimmed.startsWith('@js:') || trimmed.startsWith('<js>') || trimmed.startsWith('javascript:')) {
      return ParserType.JS;
    }

    if (trimmed.startsWith('@json:') || trimmed.startsWith('$.')) {
      return ParserType.JSON;
    }

    if (trimmed.startsWith('##') || trimmed.startsWith('@regex:')) {
      return ParserType.REGEX;
    }

    if (trimmed.startsWith('//') || trimmed.startsWith('./') || trimmed.startsWith('/html')) {
      return ParserType.XPATH;
    }

    if (trimmed.startsWith('@css:') || trimmed.startsWith('css:')) {
      return ParserType.CSS;
    }

    return ParserType.AUTO;
  }

  static parseJson(jsonStr: string, path: string): Result<ParserResult> {
    return ParserCore.parse(jsonStr, path.startsWith('@json:') ? path : `@json:${path}`);
  }

  static parseXPath(html: string, xpath: string): Result<ParserResult> {
    return ParserCore.parse(html, xpath);
  }

  static parseRegex(html: string, pattern: string): Result<ParserResult> {
    return ParserCore.parse(html, pattern.startsWith('##') ? pattern : `##${pattern}`);
  }

  static parseJS(content: string, script: string, options?: ParseOptions): Result<ParserResult> {
    return ParserCore.parse(content, script.startsWith('@js:') ? script : `@js:${script}`, options);
  }

  static parseCss(html: string, selector: string): Result<ParserResult> {
    return ParserCore.parse(html, selector.startsWith('@css:') ? selector : `@css:${selector}`);
  }
}

ParserCore.initialize();

export default ParserCore;
