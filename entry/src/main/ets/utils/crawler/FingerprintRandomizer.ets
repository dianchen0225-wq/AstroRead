import { IFingerprintRandomizer } from "./interfaces/IAntiCrawl";
import { Logger } from "../performance/Logger";

export class FingerprintRandomizer implements IFingerprintRandomizer {
  private static readonly TAG = 'FingerprintRandomizer';

  addJitter(baseMs: number): number {
    const jitter = (Math.random() * 2 - 1) * 200;
    return Math.max(0, baseMs + jitter);
  }

  shuffleHeaderOrder(headers: Map<string, string>): Map<string, string> {
    const entries = Array.from(headers.entries());
    this.fisherYatesShuffle(entries);
    return new Map(entries);
  }

  randomizeRequestTiming(baseIntervalMs: number): number {
    const jitter = (Math.random() * 2 - 1) * 200;
    return Math.max(0, baseIntervalMs + jitter);
  }

  private fisherYatesShuffle<T>(array: T[]): void {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = array[i];
      array[i] = array[j];
      array[j] = temp;
    }
  }
}
