/**
 * CSVParserAdapter - CSV 解析器适配器
 * 支持标准 CSV、带引号 CSV、自定义分隔符
 */

import {
  ParserType,
  ParseOptions,
  ParseResult,
  FormatOptions,
  ParseErrorInfo,
  ParseWarningInfo,
  CsvResult,
  CsvRow,
  ParseStatus,
  ValidateResultWithoutValid
} from '../../interfaces/IParser';
import { CachingParserAdapter } from '../ParserAdapter';
import { ParserError, ParserWarning, ParserErrorCode, ParseResultBuilder } from '../ParserError';

export interface CSVParseOptions extends ParseOptions {
  delimiter?: string;
  quote?: string;
  escape?: string;
  hasHeader?: boolean;
  skipEmptyLines?: boolean;
  trimValues?: boolean;
}

export class CSVParserAdapter extends CachingParserAdapter<CsvResult> {
  readonly type = ParserType.CSV;
  readonly name = 'CSVParser';
  readonly version = '1.0.0';
  readonly supportedExtensions = ['csv', 'tsv', 'txt'];
  readonly priority = 70;

  private defaultCSVOptions: CSVParseOptions = {
    delimiter: ',',
    quote: '"',
    escape: '"',
    hasHeader: true,
    skipEmptyLines: true,
    trimValues: true
  };

  protected async doParse(content: string, options: ParseOptions): Promise<ParseResult<CsvResult>> {
    const mergedOptions: CSVParseOptions = this.mergeOptions(options);
    return this.parseCSV(content, mergedOptions);
  }

  protected doParseSync(content: string, options: ParseOptions): ParseResult<CsvResult> {
    const mergedOptions: CSVParseOptions = this.mergeOptions(options);
    return this.parseCSV(content, mergedOptions);
  }

  protected mergeOptions(options: ParseOptions): CSVParseOptions {
    const mergedOptions: CSVParseOptions = {};
    
    // Copy default options first
    mergedOptions.delimiter = this.defaultCSVOptions.delimiter;
    mergedOptions.quote = this.defaultCSVOptions.quote;
    mergedOptions.escape = this.defaultCSVOptions.escape;
    mergedOptions.hasHeader = this.defaultCSVOptions.hasHeader;
    mergedOptions.skipEmptyLines = this.defaultCSVOptions.skipEmptyLines;
    mergedOptions.trimValues = this.defaultCSVOptions.trimValues;
    
    // Override with provided options
    if (options.encoding !== undefined) {
      mergedOptions.encoding = options.encoding;
    }
    if (options.strict !== undefined) {
      mergedOptions.strict = options.strict;
    }
    if (options.maxDepth !== undefined) {
      mergedOptions.maxDepth = options.maxDepth;
    }
    if (options.timeout !== undefined) {
      mergedOptions.timeout = options.timeout;
    }
    if (options.cacheKey !== undefined) {
      mergedOptions.cacheKey = options.cacheKey;
    }
    if (options.skipCache !== undefined) {
      mergedOptions.skipCache = options.skipCache;
    }
    if (options.customRules !== undefined) {
      mergedOptions.customRules = options.customRules;
    }
    
    return mergedOptions;
  }

  private parseCSV(content: string, options: CSVParseOptions): ParseResult<CsvResult> {
    const defaultCsvResult: CsvResult = {
      headers: [],
      rows: [],
      rowCount: 0,
      columnCount: 0
    };
    const builder = new ParseResultBuilder<CsvResult>(defaultCsvResult);
    builder.setMetadata({
      parserType: this.type,
      version: this.version
    });

    try {
      const delimiter: string = this.detectDelimiter(content, options.delimiter);
      const lines: string[] = this.splitLines(content, options.skipEmptyLines ?? true);

      if (lines.length === 0) {
        throw ParserError.emptyInput(this.type);
      }

      const headers: string[] = [];
      const rows: CsvRow[] = [];

      const firstRow: string[] = this.parseLine(lines[0], delimiter, options);

      if (options.hasHeader) {
        for (let i = 0; i < firstRow.length; i++) {
          headers.push(firstRow[i] || `column_${i + 1}`);
        }
      } else {
        for (let i = 0; i < firstRow.length; i++) {
          headers.push(`column_${i + 1}`);
        }
        rows.push(this.createRow(headers, firstRow));
      }

      const startIndex: number = options.hasHeader ? 1 : 0;
      for (let i = startIndex; i < lines.length; i++) {
        const values: string[] = this.parseLine(lines[i], delimiter, options);

        if (values.length === 0) {
          continue;
        }

        if (values.length !== headers.length) {
          builder.addWarning(new ParserWarning(
            'COLUMN_MISMATCH',
            `Line ${i + 1}: Expected ${headers.length} columns, got ${values.length}`
          ));
        }

        rows.push(this.createRow(headers, values));
      }

      const result: CsvResult = {
        headers,
        rows,
        rowCount: rows.length,
        columnCount: headers.length
      };

      // Use internal method to set data
      this.setBuilderData(builder, result);
      builder.setStatus(ParseStatus.SUCCESS);

    } catch (error) {
      const parseError = ParserError.fromError(error as Error, this.type);
      builder.addError(parseError);
      builder.setStatus(ParseStatus.FAILED);
    }

    return builder.build();
  }

  private setBuilderData(builder: ParseResultBuilder<CsvResult>, data: CsvResult): void {
    builder.setData(data);
  }

  private detectDelimiter(content: string, preferred?: string): string {
    if (preferred) {
      return preferred;
    }

    const firstLine: string = content.split('\n')[0];

    const delimiters: string[] = [',', '\t', ';', '|'];
    let maxCount: number = 0;
    let detected: string = ',';

    for (const delim of delimiters) {
      const count: number = (firstLine.match(new RegExp(this.escapeRegex(delim), 'g')) || []).length;
      if (count > maxCount) {
        maxCount = count;
        detected = delim;
      }
    }

    return detected;
  }

  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  private splitLines(content: string, skipEmpty: boolean): string[] {
    const lines: string[] = content.split(/\r?\n/);

    if (skipEmpty) {
      return lines.filter((line: string): boolean => line.trim().length > 0);
    }

    return lines;
  }

  private parseLine(line: string, delimiter: string, options: CSVParseOptions): string[] {
    const values: string[] = [];
    let current: string = '';
    let inQuotes: boolean = false;
    const quote: string = options.quote ?? '"';
    const escape: string = options.escape ?? '"';

    for (let i = 0; i < line.length; i++) {
      const char: string = line[i];
      const nextChar: string | undefined = line[i + 1];

      if (inQuotes) {
        if (char === escape && nextChar === quote) {
          current += quote;
          i++;
        } else if (char === quote) {
          inQuotes = false;
        } else {
          current += char;
        }
      } else {
        if (char === quote) {
          inQuotes = true;
        } else if (char === delimiter) {
          values.push(this.processValue(current, options));
          current = '';
        } else {
          current += char;
        }
      }
    }

    values.push(this.processValue(current, options));

    return values;
  }

  private processValue(value: string, options: CSVParseOptions): string {
    if (options.trimValues ?? true) {
      value = value.trim();
    }
    return value;
  }

  private createRow(_headers: string[], values: string[]): CsvRow {
    return { values: values };
  }

  protected doValidate(content: string, options?: ParseOptions): ValidateResultWithoutValid {
    const errors: ParseErrorInfo[] = [];
    const warnings: ParseWarningInfo[] = [];

    const csvOptions: CSVParseOptions = this.mergeOptions(options ?? {});
    const delimiter: string = this.detectDelimiter(content, csvOptions.delimiter);
    const lines: string[] = this.splitLines(content, csvOptions.skipEmptyLines ?? true);

    if (lines.length === 0) {
      const errorInfo: ParseErrorInfo = {
        code: ParserErrorCode.EMPTY_INPUT,
        message: 'CSV content is empty',
        severity: 'error'
      };
      errors.push(errorInfo);
      return { errors, warnings };
    }

    const firstRow: string[] = this.parseLine(lines[0], delimiter, csvOptions);
    const expectedColumns: number = firstRow.length;

    for (let i = 1; i < lines.length; i++) {
      const values: string[] = this.parseLine(lines[i], delimiter, csvOptions);

      if (values.length !== expectedColumns) {
        const warningInfo: ParseWarningInfo = {
          code: 'COLUMN_MISMATCH',
          message: `Line ${i + 1}: Expected ${expectedColumns} columns, got ${values.length}`,
          severity: 'warning'
        };
        warnings.push(warningInfo);
      }
    }

    return { errors, warnings };
  }

  protected detectContent(content: string): boolean {
    const lines: string[] = content.trim().split('\n');
    if (lines.length < 1) {
      return false;
    }

    const firstLine: string = lines[0];
    const delimiter: string = this.detectDelimiter(firstLine);

    const delimiterCount: number = (firstLine.match(new RegExp(this.escapeRegex(delimiter), 'g')) || []).length;

    if (delimiterCount >= 1) {
      if (lines.length > 1) {
        const secondLine: string = lines[1];
        const secondDelimiterCount: number = (secondLine.match(new RegExp(this.escapeRegex(delimiter), 'g')) || []).length;
        return Math.abs(delimiterCount - secondDelimiterCount) <= 1;
      }
      return true;
    }

    return false;
  }

  format(data: CsvResult, options?: FormatOptions): string {
    const delimiter: string = this.getCustomRule(options, 'delimiter', ',');
    const quote: string = this.getCustomRule(options, 'quote', '"');

    const lines: string[] = [];

    lines.push(this.formatRow(data.headers, delimiter, quote));

    for (const row of data.rows) {
      lines.push(this.formatRow(row.values, delimiter, quote));
    }

    return lines.join('\n');
  }

  private getCustomRule(options: FormatOptions | undefined, rule: string, defaultValue: string): string {
    if (options?.customRules) {
      const value = options.customRules.get(rule);
      if (value !== undefined) {
        return value;
      }
    }
    return defaultValue;
  }

  private formatRow(values: string[], delimiter: string, quote: string): string {
    const formattedValues: string[] = values.map((value: string): string => this.formatValue(value, delimiter, quote));
    return formattedValues.join(delimiter);
  }

  private formatValue(value: string, delimiter: string, quote: string): string {
    if (value.includes(delimiter) || value.includes(quote) || value.includes('\n')) {
      const escaped: string = value.replace(new RegExp(quote, 'g'), quote + quote);
      return quote + escaped + quote;
    }
    return value;
  }

  query(data: CsvResult, path: string): CsvRow[] {
    if (!path || path === '*') {
      return data.rows;
    }

    if (path.startsWith('$[')) {
      const indexMatch: RegExpMatchArray | null = path.match(/\$\[(\d+)\]/);
      if (indexMatch) {
        const index: number = parseInt(indexMatch[1], 10);
        return index >= 0 && index < data.rows.length ? [data.rows[index]] : [];
      }
    }

    return data.rows;
  }

  getColumn(data: CsvResult, columnIndex: number): string[] {
    return data.rows.map((row: CsvRow): string => {
      if (columnIndex >= 0 && columnIndex < row.values.length) {
        return row.values[columnIndex];
      }
      return '';
    });
  }

  getUniqueValues(data: CsvResult, columnIndex: number): string[] {
    const values: Set<string> = new Set<string>();
    for (const row of data.rows) {
      if (columnIndex >= 0 && columnIndex < row.values.length) {
        const value = row.values[columnIndex];
        if (value !== undefined && value !== '') {
          values.add(value);
        }
      }
    }
    return Array.from(values);
  }

  filter(data: CsvResult, predicate: (row: CsvRow) => boolean): CsvResult {
    const filteredRows = data.rows.filter(predicate);
    return {
      headers: data.headers,
      rows: filteredRows,
      rowCount: filteredRows.length,
      columnCount: data.columnCount
    };
  }

  sort(data: CsvResult, columnIndex: number, ascending: boolean = true): CsvResult {
    const sortedRows: CsvRow[] = this.copyArray(data.rows).sort((a: CsvRow, b: CsvRow): number => {
      const aVal: string = columnIndex >= 0 && columnIndex < a.values.length ? a.values[columnIndex] : '';
      const bVal: string = columnIndex >= 0 && columnIndex < b.values.length ? b.values[columnIndex] : '';

      const aNum: number = parseFloat(aVal);
      const bNum: number = parseFloat(bVal);

      if (!isNaN(aNum) && !isNaN(bNum)) {
        return ascending ? aNum - bNum : bNum - aNum;
      }

      return ascending ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
    });

    return {
      headers: data.headers,
      rows: sortedRows,
      rowCount: sortedRows.length,
      columnCount: data.columnCount
    };
  }

  private copyArray<T>(array: T[]): T[] {
    const result: T[] = [];
    for (const item of array) {
      result.push(item);
    }
    return result;
  }
}

export default new CSVParserAdapter();