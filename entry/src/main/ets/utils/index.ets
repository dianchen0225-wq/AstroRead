/**
 * 工具类统一导出
 */

export { StringUtils } from './StringUtils';
export { ParserCore, concurrentParseChapterList, concurrentParseBookList, concurrentParseContent, ParseResult, ChapterInfo, BookInfo } from './ParserCore';
export { Logger } from './Logger';
export { IdGenerator } from './IdGenerator';
export { ToastUtils } from './ToastUtils';
export { ErrorHandler, AppError, ErrorType, ErrorSeverity, ErrorInfo, DegradationStrategy, DegradationResult, ErrorContext, errorHandlingService, ErrorHandlingService } from './ErrorHandlingService';
export { PerformanceUtils } from './PerformanceUtils';
export { DataValidator } from './DataValidator';

import { ParserCore } from './ParserCore';
export const HtmlUtils = {
  decodeHtmlEntities: ParserCore.decodeHtmlEntities,
  extractText: ParserCore.extractText,
  cleanText: ParserCore.cleanText,
  escapeRegex: ParserCore.escapeRegex,
  resolveUrl: ParserCore.resolveUrl,
  selectElements: ParserCore.selectElements
};
