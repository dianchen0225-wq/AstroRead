import { IRateSmoother } from "./interfaces/IConcurrency";
import { Logger } from "../performance/Logger";

export class RateSmoother implements IRateSmoother {
  private static readonly TAG = 'RateSmoother';

  private ratePerSecond: number;
  private intervalMs: number;
  private lastRequestTime: number = 0;

  constructor(ratePerSecond: number = 10) {
    this.ratePerSecond = ratePerSecond;
    this.intervalMs = 1000 / ratePerSecond;
  }

  async wait(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastRequestTime;
    const waitTime = this.intervalMs - elapsed;

    if (waitTime > 0) {
      Logger.debug(RateSmoother.TAG, `Rate limiting: waiting ${waitTime.toFixed(1)}ms`);
      await this.sleep(waitTime);
    }

    this.lastRequestTime = Date.now();
  }

  updateRate(ratePerSecond: number): void {
    if (ratePerSecond <= 0) {
      Logger.warn(RateSmoother.TAG, `Invalid rate: ${ratePerSecond}, ignoring`);
      return;
    }
    this.ratePerSecond = ratePerSecond;
    this.intervalMs = 1000 / ratePerSecond;
    Logger.debug(RateSmoother.TAG, `Rate updated to ${ratePerSecond}/s (interval: ${this.intervalMs.toFixed(1)}ms)`);
  }

  getRate(): number {
    return this.ratePerSecond;
  }

  getWaitTimeMs(): number {
    const now = Date.now();
    const elapsed = now - this.lastRequestTime;
    return Math.max(0, this.intervalMs - elapsed);
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: Function) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }
}
