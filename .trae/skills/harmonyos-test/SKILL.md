---
name: "harmonyos-test"
description: "Creates HarmonyOS unit test files with proper test framework templates and assertion patterns. Invoke when user needs to write tests for ArkTS code or create test runners."
---

# HarmonyOS Test Generator

This skill helps create unit test files for HarmonyOS ArkTS projects following the project's testing conventions.

## When to Invoke

- User asks to create a test file for existing code
- User wants to write unit tests for a parser, service, or component
- User needs a test runner for organizing and executing tests

## Test File Structure

Tests in this project follow a consistent pattern:

```
entry/src/main/ets/
├── core/__tests__/
│   ├── ParserCore.test.ets
│   ├── Result.test.ets
│   └── CoreTestRunner.ets
├── network/__tests__/
│   ├── HttpClient.test.ets
│   └── NetworkTestRunner.ets
```

## Test Class Template

```typescript
import { Result, ErrorCode } from '../core/Result';

export class YourClassTest {
  private passed: number = 0;
  private failed: number = 0;

  testBasicFunctionality(): boolean {
    const result = yourFunction('input');
    
    if (result.isErr()) {
      console.error('❌ testBasicFunctionality: should succeed');
      this.failed++;
      return false;
    }

    if (result.data !== 'expected') {
      console.error('❌ testBasicFunctionality: unexpected result');
      this.failed++;
      return false;
    }

    console.log('✅ testBasicFunctionality passed');
    this.passed++;
    return true;
  }

  testErrorHandling(): boolean {
    const result = yourFunction('');
    
    if (result.isOk()) {
      console.error('❌ testErrorHandling: should return error');
      this.failed++;
      return false;
    }

    console.log('✅ testErrorHandling passed');
    this.passed++;
    return true;
  }

  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting YourClass tests...');

    this.testBasicFunctionality();
    this.testErrorHandling();

    const total: number = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);

    return this.failed === 0;
  }
}

const yourClassTest: YourClassTest = new YourClassTest();
export default yourClassTest;
```

## Test Runner Template

```typescript
import { YourClassTest } from './YourClass.test';

export class TestRunner {
  private static async runAll(): Promise<void> {
    console.log('═══════════════════════════════════════');
    console.log('  Running All Tests');
    console.log('═══════════════════════════════════════');

    const yourClassTest = new YourClassTest();
    await yourClassTest.runAllTests();

    console.log('═══════════════════════════════════════');
    console.log('  All Tests Complete');
    console.log('═══════════════════════════════════════');
  }
}
```

## Best Practices

1. **Naming Convention**: Test files should be named `<ClassName>.test.ets`
2. **Test Methods**: Prefix test methods with `test` (e.g., `testJsonPathParserBasic`)
3. **Result Pattern**: Use `Result<T>` for functions that can fail
4. **Logging**: Use ✅ for passed tests and ❌ for failed tests
5. **Counter Pattern**: Track `passed` and `failed` counts for summary

## Common Assertion Patterns

```typescript
// Success assertion
if (result.isErr()) {
  console.error('❌ testName: should succeed');
  this.failed++;
  return false;
}

// Value assertion
if (result.data !== expected) {
  console.error(`❌ testName: expected "${expected}", got "${result.data}"`);
  this.failed++;
  return false;
}

// Error assertion
if (result.isOk()) {
  console.error('❌ testName: should return error');
  this.failed++;
  return false;
}

// Array length assertion
if (result.data.length !== expectedLength) {
  console.error(`❌ testName: expected ${expectedLength} items, got ${result.data.length}`);
  this.failed++;
  return false;
}
```
