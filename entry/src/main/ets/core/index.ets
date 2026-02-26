/**
 * ParserFacade Module - 统一解析器接口层
 * 导出所有解析器相关类型和类
 */

import ParserFacade from './ParserFacade';
import { JSONParserAdapter } from './adapters/JSONParserAdapter';
import { XMLParserAdapter } from './adapters/XMLParserAdapter';
import { HTMLParserAdapter } from './adapters/HTMLParserAdapter';
import { CSVParserAdapter } from './adapters/CSVParserAdapter';

export * from '../interfaces/IParser';
export * from './ParserError';
export * from './ParserAdapter';
export * from './ParserFacade';
export * from './Result';
export * from '../utils/parser/ParserCore';

export { EntityDecoder } from './utils/EntityDecoder';
export { PositionTracker } from './utils/PositionTracker';

export { JSONParserAdapter } from './adapters/JSONParserAdapter';
export { XMLParserAdapter } from './adapters/XMLParserAdapter';
export { HTMLParserAdapter } from './adapters/HTMLParserAdapter';
export { CSVParserAdapter, CSVParseOptions } from './adapters/CSVParserAdapter';

class ParserRegistry {
  json: JSONParserAdapter;
  xml: XMLParserAdapter;
  html: HTMLParserAdapter;
  csv: CSVParserAdapter;

  constructor() {
    this.json = new JSONParserAdapter();
    this.xml = new XMLParserAdapter();
    this.html = new HTMLParserAdapter();
    this.csv = new CSVParserAdapter();
  }
}

export const Parsers = new ParserRegistry();

export default ParserFacade;
