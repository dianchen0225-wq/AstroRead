import httpClientTest from './HttpClient.test';
import networkConfigTest from './NetworkConfig.test';

export class NetworkTestRunner {
  private passed: number = 0;
  private failed: number = 0;

  async runAllTests(): Promise<boolean> {
    console.log('═══════════════════════════════════════════');
    console.log('🚀 Starting Network Module Tests');
    console.log('═══════════════════════════════════════════\n');

    const httpClientTestPassed = await httpClientTest.runAllTests();
    if (httpClientTestPassed) {
      this.passed++;
    } else {
      this.failed++;
    }

    console.log('');

    const networkConfigTestPassed = await networkConfigTest.runAllTests();
    if (networkConfigTestPassed) {
      this.passed++;
    } else {
      this.failed++;
    }

    console.log('\n═══════════════════════════════════════════');
    console.log('📊 Network Module Test Summary');
    console.log('═══════════════════════════════════════════');
    console.log(`Total Test Suites: ${this.passed + this.failed}`);
    console.log(`Passed: ${this.passed}`);
    console.log(`Failed: ${this.failed}`);
    console.log('═══════════════════════════════════════════');

    return this.failed === 0;
  }
}

const networkTestRunner = new NetworkTestRunner();
export default networkTestRunner;
