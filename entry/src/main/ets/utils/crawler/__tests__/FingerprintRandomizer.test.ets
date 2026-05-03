import { FingerprintRandomizer } from "../FingerprintRandomizer";

export class FingerprintRandomizerTest {
  private randomizer: FingerprintRandomizer;
  private passed: number = 0;
  private failed: number = 0;

  constructor() {
    this.randomizer = new FingerprintRandomizer();
  }

  runAll(): void {
    console.log('=== FingerprintRandomizer Tests ===');

    this.testJitterRange();
    this.testHeaderShuffle();
    this.testRequestTiming();

    console.log(`\nResults: ${this.passed} passed, ${this.failed} failed`);
  }

  private testJitterRange(): void {
    const base = 1000;
    let minResult = Infinity;
    let maxResult = -Infinity;

    for (let i = 0; i < 100; i++) {
      const result = this.randomizer.addJitter(base);
      minResult = Math.min(minResult, result);
      maxResult = Math.max(maxResult, result);
    }

    this.assert('Jitter min >= 800 (base-200)', minResult >= 800, true);
    this.assert('Jitter max <= 1200 (base+200)', maxResult <= 1200, true);
    this.assert('Jitter produces variation', minResult < maxResult, true);
  }

  private testHeaderShuffle(): void {
    const headers = new Map<string, string>();
    headers.set('Accept', 'text/html');
    headers.set('User-Agent', 'Mozilla/5.0');
    headers.set('Accept-Language', 'zh-CN');
    headers.set('Connection', 'keep-alive');

    const originalKeys = Array.from(headers.keys());
    let shuffled = false;

    for (let i = 0; i < 20; i++) {
      const result = this.randomizer.shuffleHeaderOrder(headers);
      const resultKeys = Array.from(result.keys());
      if (resultKeys.join(',') !== originalKeys.join(',')) {
        shuffled = true;
        break;
      }
    }

    this.assert('Header order can be shuffled', shuffled, true);

    const result = this.randomizer.shuffleHeaderOrder(headers);
    this.assert('Shuffled headers preserve all keys', result.size, headers.size);
  }

  private testRequestTiming(): void {
    const base = 500;
    const result = this.randomizer.randomizeRequestTiming(base);
    this.assert('Request timing is positive', result >= 0, true);
    this.assert('Request timing within jitter range', result <= 700, true);
  }

  private assert(name: string, actual: number | boolean, expected: number | boolean): void {
    if (actual === expected) {
      this.passed++;
      console.log(`  ✓ ${name}`);
    } else {
      this.failed++;
      console.log(`  ✗ ${name}: expected ${expected}, got ${actual}`);
    }
  }
}
