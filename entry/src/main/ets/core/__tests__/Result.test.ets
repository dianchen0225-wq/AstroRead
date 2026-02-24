import {
  Result,
  ErrorCode,
  ErrorSeverity,
  ErrorRecoverability,
  AppError,
  ErrorFactory,
  type AppErrorOptions,
  type AppErrorDetail
} from '../Result';

export class ResultTest {
  private passed: number = 0;
  private failed: number = 0;

  testOkResult(): boolean {
    const result: Result<number> = Result.ok(42);
    
    if (!result.success) {
      console.error('❌ testOkResult: success should be true');
      this.failed++;
      return false;
    }
    
    if (result.data !== 42) {
      console.error('❌ testOkResult: data should be 42');
      this.failed++;
      return false;
    }
    
    if (result.error !== undefined) {
      console.error('❌ testOkResult: error should be undefined');
      this.failed++;
      return false;
    }
    
    console.log('✅ testOkResult passed');
    this.passed++;
    return true;
  }

  testErrResult(): boolean {
    const result: Result<number> = Result.err<number>(ErrorCode.NETWORK_ERROR, 'Network failed');
    
    if (result.success) {
      console.error('❌ testErrResult: success should be false');
      this.failed++;
      return false;
    }
    
    if (result.data !== undefined) {
      console.error('❌ testErrResult: data should be undefined');
      this.failed++;
      return false;
    }
    
    if (!result.error) {
      console.error('❌ testErrResult: error should be defined');
      this.failed++;
      return false;
    }
    
    if (result.error.code !== ErrorCode.NETWORK_ERROR) {
      console.error('❌ testErrResult: error code mismatch');
      this.failed++;
      return false;
    }
    
    console.log('✅ testErrResult passed');
    this.passed++;
    return true;
  }

  testIsOkIsErr(): boolean {
    const okResult: Result<string> = Result.ok('test');
    const errResult: Result<string> = Result.err<string>(ErrorCode.PARSE_ERROR, 'Parse failed');
    
    if (!okResult.isOk()) {
      console.error('❌ testIsOkIsErr: okResult.isOk() should be true');
      this.failed++;
      return false;
    }
    
    if (okResult.isErr()) {
      console.error('❌ testIsOkIsErr: okResult.isErr() should be false');
      this.failed++;
      return false;
    }
    
    if (!errResult.isErr()) {
      console.error('❌ testIsOkIsErr: errResult.isErr() should be true');
      this.failed++;
      return false;
    }
    
    if (errResult.isOk()) {
      console.error('❌ testIsOkIsErr: errResult.isOk() should be false');
      this.failed++;
      return false;
    }
    
    console.log('✅ testIsOkIsErr passed');
    this.passed++;
    return true;
  }

  testUnwrap(): boolean {
    const okResult: Result<number> = Result.ok(100);
    const errResult: Result<number> = Result.err<number>(ErrorCode.NETWORK_ERROR, 'Failed');

    const value: number = okResult.unwrap();
    if (value !== 100) {
      console.error('❌ testUnwrap: unwrap should return 100');
      this.failed++;
      return false;
    }
    
    try {
      errResult.unwrap();
      console.error('❌ testUnwrap: should throw on error result');
      this.failed++;
      return false;
    } catch (e) {
      // Expected
    }
    
    console.log('✅ testUnwrap passed');
    this.passed++;
    return true;
  }

  testUnwrapOr(): boolean {
    const okResult: Result<string> = Result.ok('value');
    const errResult: Result<string> = Result.err<string>(ErrorCode.PARSE_ERROR, 'Failed');

    const value1: string = okResult.unwrapOr('default');
    if (value1 !== 'value') {
      console.error('❌ testUnwrapOr: should return "value"');
      this.failed++;
      return false;
    }

    const value2: string = errResult.unwrapOr('default');
    if (value2 !== 'default') {
      console.error('❌ testUnwrapOr: should return "default"');
      this.failed++;
      return false;
    }
    
    console.log('✅ testUnwrapOr passed');
    this.passed++;
    return true;
  }

  testMap(): boolean {
    const result: Result<number> = Result.ok(5);
    const mapped: Result<number> = result.map((x: number) => x * 2);

    if (!mapped.success || mapped.data !== 10) {
      console.error('❌ testMap: mapped data should be 10');
      this.failed++;
      return false;
    }

    const errResult: Result<number> = Result.err<number>(ErrorCode.NETWORK_ERROR, 'Failed');
    const mappedErr: Result<number> = errResult.map((x: number) => x * 2);
    
    if (mappedErr.success) {
      console.error('❌ testMap: error result should remain error');
      this.failed++;
      return false;
    }
    
    console.log('✅ testMap passed');
    this.passed++;
    return true;
  }

  testAndThen(): boolean {
    const result: Result<number> = Result.ok(5);
    const chained: Result<number> = result.andThen((x: number) => Result.ok(x * 2));

    if (!chained.success || chained.data !== 10) {
      console.error('❌ testAndThen: chained data should be 10');
      this.failed++;
      return false;
    }

    const errChained: Result<number> = result.andThen((x: number) => Result.err<number>(ErrorCode.PARSE_ERROR, 'Failed'));
    
    if (errChained.success) {
      console.error('❌ testAndThen: should propagate error');
      this.failed++;
      return false;
    }
    
    console.log('✅ testAndThen passed');
    this.passed++;
    return true;
  }

  testAppError(): boolean {
    const errorOptions: AppErrorOptions = {
      severity: ErrorSeverity.HIGH,
      recoverability: ErrorRecoverability.RETRYABLE,
      userMessage: '网络连接超时，请稍后重试',
      retryCount: 1,
      maxRetries: 3
    };
    const error: AppError = new AppError(
      ErrorCode.NETWORK_ERROR,
      'Connection timeout',
      errorOptions
    );
    
    if (error.code !== ErrorCode.NETWORK_ERROR) {
      console.error('❌ testAppError: code mismatch');
      this.failed++;
      return false;
    }
    
    if (error.severity !== ErrorSeverity.HIGH) {
      console.error('❌ testAppError: severity mismatch');
      this.failed++;
      return false;
    }
    
    if (error.recoverability !== ErrorRecoverability.RETRYABLE) {
      console.error('❌ testAppError: recoverability mismatch');
      this.failed++;
      return false;
    }
    
    if (!error.isRetryable()) {
      console.error('❌ testAppError: should be retryable');
      this.failed++;
      return false;
    }
    
    console.log('✅ testAppError passed');
    this.passed++;
    return true;
  }

  testErrorFactory(): boolean {
    const networkError: AppError = ErrorFactory.network('Connection refused', { sourceId: 'source-1' });

    if (networkError.code !== ErrorCode.NETWORK_ERROR) {
      console.error('❌ testErrorFactory: network error code mismatch');
      this.failed++;
      return false;
    }

    const parseError: AppError = ErrorFactory.parse('Invalid JSON', { code: ErrorCode.PARSE_JSON_ERROR });

    if (parseError.code !== ErrorCode.PARSE_JSON_ERROR) {
      console.error('❌ testErrorFactory: parse error code mismatch');
      this.failed++;
      return false;
    }

    const timeoutError: AppError = ErrorFactory.timeout('Request timed out');
    
    if (timeoutError.code !== ErrorCode.NETWORK_TIMEOUT) {
      console.error('❌ testErrorFactory: timeout error code mismatch');
      this.failed++;
      return false;
    }
    
    console.log('✅ testErrorFactory passed');
    this.passed++;
    return true;
  }

  testFromThrow(): boolean {
    const result: Result<number> = Result.fromThrow((): number => {
      return 42;
    });

    if (!result.success || result.data !== 42) {
      console.error('❌ testFromThrow: should return ok result with 42');
      this.failed++;
      return false;
    }

    const errResult: Result<number> = Result.fromThrow((): number => {
      throw new Error('Test error');
    });
    
    if (errResult.success) {
      console.error('❌ testFromThrow: should return error result');
      this.failed++;
      return false;
    }
    
    console.log('✅ testFromThrow passed');
    this.passed++;
    return true;
  }

  async testFromAsync(): Promise<boolean> {
    const result: Result<string> = await Result.fromAsync((async (): Promise<string> => {
      return 'async value';
    })());

    if (!result.success || result.data !== 'async value') {
      console.error('❌ testFromAsync: should return ok result');
      this.failed++;
      return false;
    }

    const errResult: Result<string> = await Result.fromAsync((async (): Promise<string> => {
      throw new Error('Async error');
    })());
    
    if (errResult.success) {
      console.error('❌ testFromAsync: should return error result');
      this.failed++;
      return false;
    }
    
    console.log('✅ testFromAsync passed');
    this.passed++;
    return true;
  }

  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting Result tests...');
    
    this.testOkResult();
    this.testErrResult();
    this.testIsOkIsErr();
    this.testUnwrap();
    this.testUnwrapOr();
    this.testMap();
    this.testAndThen();
    this.testAppError();
    this.testErrorFactory();
    this.testFromThrow();
    await this.testFromAsync();
    
    const total = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);
    
    if (this.failed === 0) {
      console.log('✅ All Result tests passed!');
      return true;
    } else {
      console.log('❌ Some Result tests failed');
      return false;
    }
  }
}

const resultTest = new ResultTest();
export default resultTest;
