import resultTest from './Result.test';
import parserCoreTest from './ParserCore.test';
import parserFacadeTest from './ParserFacade.test';

export class CoreTestRunner {
  private passed: number = 0;
  private failed: number = 0;

  async runAllTests(): Promise<boolean> {
    console.log('═══════════════════════════════════════════');
    console.log('🚀 Starting Core Module Tests');
    console.log('═══════════════════════════════════════════\n');

    const resultTestPassed = await resultTest.runAllTests();
    if (resultTestPassed) {
      this.passed++;
    } else {
      this.failed++;
    }

    console.log('');

    const parserCoreTestPassed = await parserCoreTest.runAllTests();
    if (parserCoreTestPassed) {
      this.passed++;
    } else {
      this.failed++;
    }

    console.log('');

    const parserFacadeTestPassed = await parserFacadeTest.runAllTests();
    if (parserFacadeTestPassed) {
      this.passed++;
    } else {
      this.failed++;
    }

    console.log('\n═══════════════════════════════════════════');
    console.log('📊 Core Module Test Summary');
    console.log('═══════════════════════════════════════════');
    console.log(`Total Test Suites: ${this.passed + this.failed}`);
    console.log(`Passed: ${this.passed}`);
    console.log(`Failed: ${this.failed}`);
    console.log('═══════════════════════════════════════════');

    return this.failed === 0;
  }
}

const coreTestRunner = new CoreTestRunner();
export default coreTestRunner;
