---
name: "harmonyos-book-source"
description: "Creates and manages book source configuration files with validation rules. Invoke when user needs to add a new book source or debug source parsing issues."
---

# HarmonyOS Book Source Generator

This skill helps create and manage book source configurations for the AstroRead reading application.

## When to Invoke

- User wants to add a new book source
- User needs to debug a book source parsing issue
- User asks about book source JSON format

## Book Source Structure

Book sources are stored as JSON files with the following structure:

```json
{
  "bookSourceName": "Source Name",
  "bookSourceGroup": "Group Name",
  "bookSourceType": 0,
  "bookSourceUrl": "https://example.com",
  "bookSourceComment": "Source description",
  "loginUrl": "",
  "loginUi": "",
  "loginCheckJs": "",
  "header": "",
  "concurrentRate": "",
  "customOrder": 0,
  "enabled": true,
  "enabledExplore": true,
  "weight": 0,
  "lastUpdateTime": 0,
  "respondTime": 0,
  "exploreUrl": "",
  "searchUrl": {
    "url": "https://example.com/search?q={{key}}",
    "method": "GET",
    "header": "",
    "body": ""
  },
  "ruleSearch": {
    "checkKeyWord": "",
    "bookList": "//div[@class='book-item']",
    "name": ".//h3/text()",
    "author": ".//span[@class='author']/text()",
    "intro": ".//p[@class='intro']/text()",
    "kind": "",
    "lastChapter": ".//a[@class='last']/text()",
    "updateTime": "",
    "bookUrl": ".//a/@href",
    "coverUrl": ".//img/@src",
    "wordCount": ""
  },
  "ruleBookInfo": {
    "init": "",
    "name": "//h1/text()",
    "author": "//span[@class='author']/text()",
    "intro": "//div[@class='intro']//text()",
    "kind": "",
    "lastChapter": "//a[@class='last']/text()",
    "updateTime": "",
    "coverUrl": "//img[@class='cover']/@src",
    "tocUrl": "//a[@class='chapters']/@href",
    "wordCount": "",
    "canReName": ""
  },
  "ruleToc": {
    "chapterList": "//div[@class='chapter-list']//a",
    "chapterName": "./text()",
    "chapterUrl": "./@href",
    "isVip": "",
    "isPay": "",
    "updateTime": "",
    "nextTocUrl": ""
  },
  "ruleContent": {
    "content": "//div[@class='content']//text()",
    "nextContentUrl": "",
    "webJs": "",
    "sourceRegex": "",
    "replaceRegex": "",
    "imageStyle": "",
    "payAction": ""
  }
}
```

## Rule Types Reference

### XPath Rules
- `//element` - Select all elements
- `//element[@attr='value']` - Select by attribute
- `.//element` - Relative path
- `./text()` - Get text content
- `./@attr` - Get attribute value
- `//element[1]` - First element
- `//element[last()]` - Last element
- `//element[contains(@class, 'name')]` - Contains filter

### JSONPath Rules
- `$.data.items` - Navigate JSON path
- `$.items[*].name` - Array wildcard
- `$.items[0]` - Array index
- `$.items[?(@.id>5)]` - Filter expression

### Regex Rules
- `##pattern` - Regex with ## prefix
- `##<div[^>]*>([^<]+)</div>` - Capture group
- `@regex:pattern` - Alternative prefix

### CSS Selector Rules
- `@css:.class-name` - Class selector
- `@css:#id` - ID selector
- `@css:div > p` - Child selector
- `@css:div p` - Descendant selector

### JavaScript Rules
- `@js:result` - JavaScript expression
- `@js:JSON.parse(result).data` - Process result

## Book Source Validation

```typescript
interface BookSourceValidation {
  required: ['bookSourceName', 'bookSourceUrl'];
  urlPattern: /^https?:\/\/.+/;
  ruleRequired: {
    search: ['searchUrl', 'ruleSearch.bookList'],
    explore: ['exploreUrl'],
    toc: ['ruleToc.chapterList'],
    content: ['ruleContent.content']
  };
}
```

## Common Patterns

### Search URL with Parameters
```json
{
  "searchUrl": {
    "url": "https://example.com/search?q={{key}}&page={{page}}",
    "method": "GET",
    "header": "User-Agent: Mozilla/5.0"
  }
}
```

### POST Request Search
```json
{
  "searchUrl": {
    "url": "https://example.com/api/search",
    "method": "POST",
    "header": "Content-Type: application/json",
    "body": "{\"keyword\":\"{{key}}\"}"
  }
}
```

### Content with Replace Rules
```json
{
  "ruleContent": {
    "content": "//div[@id='content']//text()",
    "replaceRegex": "请.*?继续阅读|本章未完.*",
    "nextContentUrl": "//a[@class='next']/@href"
  }
}
```

## Debugging Tips

1. **Test Search**: Use `BookSourceDebugger` to test search rules
2. **Check Network**: Verify request/response with `HttpClient`
3. **Validate XPath**: Test XPath expressions in browser console
4. **Check Encoding**: Ensure proper character encoding for Chinese content
5. **Rate Limiting**: Add `concurrentRate` to avoid being blocked

## File Location

Book sources are typically stored in:
- App sandbox: `/data/storage/el2/base/files/booksources/`
- Import format: JSON files with `.json` extension
- Backup format: JSON array of sources
