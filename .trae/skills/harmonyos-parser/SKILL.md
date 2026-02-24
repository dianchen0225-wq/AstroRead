---
name: "harmonyos-parser"
description: "Creates new parser components implementing IParser interface with automatic registration. Invoke when user needs to add a new content parser type to the project."
---

# HarmonyOS Parser Generator

This skill helps create new parser components for the AstroRead parsing system.

## When to Invoke

- User wants to add a new parser type (e.g., XML parser, CSV parser)
- User needs to implement custom content parsing logic
- User asks about extending the parser registry

## Parser Architecture

The project uses a registry-based parser system:

```
entry/src/main/ets/utils/
├── IParser.ets              # Interface and base classes
├── ParserCore.ets           # Main parser facade
└── parsers/
    ├── JsonPathParser.ets
    ├── RegexParser.ets
    ├── XPathParser.ets
    ├── CssParser.ets
    └── JSParser.ets
```

## IParser Interface

```typescript
export interface IParser {
  readonly type: ParserType;
  readonly name: string;

  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult>;

  parseList(content: string, rule: string, options?: ParseOptions): Result<string[]>;

  parseValue(content: string, rule: string, options?: ParseOptions): Result<string>;

  canHandle(rule: string): boolean;
}
```

## New Parser Template

Create file: `entry/src/main/ets/utils/parsers/YourParser.ets`

```typescript
import { Result, ErrorCode, ErrorFactory, ParseErrorOptions } from '../../core/Result';
import { 
  IParser, 
  BaseParser, 
  ParserResult, 
  ParseOptions, 
  ParserType 
} from '../IParser';
import { Logger } from '../Logger';

export class YourParser extends BaseParser {
  readonly type: ParserType = ParserType.YOUR_TYPE;
  readonly name: string = 'YourParser';
  private static readonly TAG = 'YourParser';

  parse(content: string, rule: string, options?: ParseOptions): Result<ParserResult> {
    if (!this.validateInput(content, rule)) {
      return this.createErrorResult('Empty input or rule');
    }

    try {
      const processedRule = this.preprocessRule(rule);
      const result = this.doParse(content, processedRule, options);
      
      if (result.isEmpty()) {
        Logger.warn(YourParser.TAG, 'No results found');
      }

      return Result.ok(result);
    } catch (e) {
      const error = e as Error;
      Logger.error(YourParser.TAG, `Parse error: ${error.message}`);
      return this.createErrorResult(error.message, ErrorCode.PARSE_ERROR, error.stack);
    }
  }

  canHandle(rule: string): boolean {
    if (!rule) return false;
    const trimmed = rule.trim();
    
    return trimmed.startsWith('@your:') || 
           trimmed.startsWith('your:');
  }

  private preprocessRule(rule: string): string {
    let processed = rule.trim();
    
    if (processed.startsWith('@your:')) {
      processed = processed.substring(6);
    } else if (processed.startsWith('your:')) {
      processed = processed.substring(5);
    }

    return processed;
  }

  private doParse(
    content: string, 
    rule: string, 
    options?: ParseOptions
  ): ParserResult {
    // Implement your parsing logic here
    // Return ParserResult.fromValue() or ParserResult.fromValues()
    
    const matches: string[] = [];
    
    // Your parsing implementation
    // ...
    
    return ParserResult.fromValues(matches);
  }
}

export default YourParser;
```

## Register New Parser

Add to `ParserCore.ets`:

```typescript
import { YourParser } from './parsers/YourParser';

static initialize(): void {
  if (ParserCore.initialized) return;

  ParserCore.registry.register(new JsonPathParser());
  ParserCore.registry.register(new RegexParser());
  ParserCore.registry.register(new XPathParser());
  ParserCore.registry.register(new JSParser());
  ParserCore.registry.register(new CssParser());
  ParserCore.registry.register(new YourParser());  // Add this line

  ParserCore.initialized = true;
}
```

## Add ParserType Enum

Add to `IParser.ets`:

```typescript
export enum ParserType {
  JSON = 'json',
  XPATH = 'xpath',
  REGEX = 'regex',
  CSS = 'css',
  JS = 'js',
  YOUR_TYPE = 'your_type',  // Add this line
  AUTO = 'auto'
}
```

## Rule Detection Pattern

Update `ParserCore.detectRuleType()`:

```typescript
static detectRuleType(rule: string): ParserType {
  if (!rule) return ParserType.AUTO;

  const trimmed = rule.trim();

  if (trimmed.startsWith('@your:') || trimmed.startsWith('your:')) {
    return ParserType.YOUR_TYPE;
  }

  // ... other patterns

  return ParserType.AUTO;
}
```

## Best Practices

1. **Extend BaseParser**: Inherit from `BaseParser` to get common utilities
2. **Use Result Pattern**: Always return `Result<ParserResult>` for error handling
3. **Log Appropriately**: Use Logger for warnings and errors
4. **Rule Prefix**: Use `@type:` prefix for rule identification
5. **Empty Results**: Return `ParserResult.empty()` for no matches, not errors
