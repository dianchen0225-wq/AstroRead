import { ScriptEngine, ScriptContext } from '../utils/ScriptEngine';

export class ScriptEngineTest {
  private passed: number = 0;
  private failed: number = 0;
  private engine: ScriptEngine = ScriptEngine.getInstance();

  testBasicArithmetic(): boolean {
    const result = this.engine.executeAsString('1 + 2 * 3', {});
    if (result !== '7') {
      console.error(`❌ testBasicArithmetic: expected "7", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testBasicArithmetic passed');
    this.passed++;
    return true;
  }

  testStringConcatenation(): boolean {
    const result = this.engine.executeAsString("'Hello' + ' ' + 'World'", {});
    if (result !== 'Hello World') {
      console.error(`❌ testStringConcatenation: expected "Hello World", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testStringConcatenation passed');
    this.passed++;
    return true;
  }

  testVariableDeclaration(): boolean {
    const result = this.engine.executeAsString('let x = 10; let y = 20; return x + y;', {});
    if (result !== '30') {
      console.error(`❌ testVariableDeclaration: expected "30", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testVariableDeclaration passed');
    this.passed++;
    return true;
  }

  testIfStatement(): boolean {
    const script = `
      let x = 10;
      if (x > 5) {
        return 'greater';
      }
      return 'smaller';
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'greater') {
      console.error(`❌ testIfStatement: expected "greater", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testIfStatement passed');
    this.passed++;
    return true;
  }

  testForLoop(): boolean {
    const script = `
      let sum = 0;
      for (let i = 1; i <= 5; i++) {
        sum = sum + i;
      }
      return sum;
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== '15') {
      console.error(`❌ testForLoop: expected "15", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testForLoop passed');
    this.passed++;
    return true;
  }

  testWhileLoop(): boolean {
    const script = `
      let count = 0;
      let i = 0;
      while (i < 5) {
        count = count + 1;
        i = i + 1;
      }
      return count;
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== '5') {
      console.error(`❌ testWhileLoop: expected "5", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testWhileLoop passed');
    this.passed++;
    return true;
  }

  testFunctionDeclaration(): boolean {
    const script = `
      function add(a, b) {
        return a + b;
      }
      return add(3, 4);
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== '7') {
      console.error(`❌ testFunctionDeclaration: expected "7", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testFunctionDeclaration passed');
    this.passed++;
    return true;
  }

  testBuiltInFunction(): boolean {
    const script = `return encodeURIComponent('hello world')`;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'hello%20world') {
      console.error(`❌ testBuiltInFunction: expected "hello%20world", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testBuiltInFunction passed');
    this.passed++;
    return true;
  }

  testContextVariables(): boolean {
    const context: ScriptContext = {
      key: 'test keyword',
      page: 2
    };
    const script = `return key + ' - page ' + page`;
    const result = this.engine.executeAsString(script, context);
    if (result !== 'test keyword - page 2') {
      console.error(`❌ testContextVariables: expected "test keyword - page 2", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testContextVariables passed');
    this.passed++;
    return true;
  }

  testArrayOperations(): boolean {
    const script = `
      let arr = [1, 2, 3, 4, 5];
      let sum = 0;
      for (let i = 0; i < arr.length; i++) {
        sum = sum + arr[i];
      }
      return sum;
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== '15') {
      console.error(`❌ testArrayOperations: expected "15", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testArrayOperations passed');
    this.passed++;
    return true;
  }

  testObjectOperations(): boolean {
    const script = `
      let obj = { name: 'Test', value: 100 };
      return obj.name + ': ' + obj.value;
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'Test: 100') {
      console.error(`❌ testObjectOperations: expected "Test: 100", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testObjectOperations passed');
    this.passed++;
    return true;
  }

  testTernaryOperator(): boolean {
    const script = `
      let x = 10;
      return x > 5 ? 'big' : 'small';
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'big') {
      console.error(`❌ testTernaryOperator: expected "big", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testTernaryOperator passed');
    this.passed++;
    return true;
  }

  testLogicalOperators(): boolean {
    const script = `
      let a = true;
      let b = false;
      if (a && !b) {
        return 'pass';
      }
      return 'fail';
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'pass') {
      console.error(`❌ testLogicalOperators: expected "pass", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testLogicalOperators passed');
    this.passed++;
    return true;
  }

  testComplexScript(): boolean {
    const script = `
      function buildUrl(baseUrl, keyword, page) {
        let encodedKey = encodeURIComponent(keyword);
        let url = baseUrl + '?q=' + encodedKey + '&page=' + page;
        return url;
      }
      
      let url = buildUrl('https://example.com/search', '测试关键词', 1);
      return url;
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'https://example.com/search?q=%E6%B5%8B%E8%AF%95%E5%85%B3%E9%94%AE%E8%AF%8D&page=1') {
      console.error(`❌ testComplexScript: got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testComplexScript passed');
    this.passed++;
    return true;
  }

  testBase64Encoding(): boolean {
    const script = `return base64Encode('Hello World')`;
    const result = this.engine.executeAsString(script, {});
    if (result !== 'SGVsbG8gV29ybGQ=') {
      console.error(`❌ testBase64Encoding: expected "SGVsbG8gV29ybGQ=", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testBase64Encoding passed');
    this.passed++;
    return true;
  }

  testBreakContinue(): boolean {
    const script = `
      let sum = 0;
      for (let i = 0; i < 10; i++) {
        if (i === 3) continue;
        if (i === 7) break;
        sum = sum + i;
      }
      return sum;
    `;
    const result = this.engine.executeAsString(script, {});
    if (result !== '15') {
      console.error(`❌ testBreakContinue: expected "15", got "${result}"`);
      this.failed++;
      return false;
    }
    console.log('✅ testBreakContinue passed');
    this.passed++;
    return true;
  }

  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting ScriptEngine tests...');

    this.testBasicArithmetic();
    this.testStringConcatenation();
    this.testVariableDeclaration();
    this.testIfStatement();
    this.testForLoop();
    this.testWhileLoop();
    this.testFunctionDeclaration();
    this.testBuiltInFunction();
    this.testContextVariables();
    this.testArrayOperations();
    this.testObjectOperations();
    this.testTernaryOperator();
    this.testLogicalOperators();
    this.testComplexScript();
    this.testBase64Encoding();
    this.testBreakContinue();

    const total: number = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);

    if (this.failed === 0) {
      console.log('✅ All ScriptEngine tests passed!');
      return true;
    } else {
      console.log('❌ Some ScriptEngine tests failed');
      return false;
    }
  }
}

const scriptEngineTest: ScriptEngineTest = new ScriptEngineTest();
export default scriptEngineTest;
