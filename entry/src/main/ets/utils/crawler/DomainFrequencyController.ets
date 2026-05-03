import { IDomainFrequencyController, DomainRateState, FrequencyControlMetrics } from "./interfaces/IAntiCrawl";
import { Logger } from "../performance/Logger";

export class DomainFrequencyController implements IDomainFrequencyController {
  private static readonly TAG = 'DomainFrequencyController';

  private static readonly DEFAULT_RATE = 5;
  private static readonly MIN_RATE = 0.5;
  private static readonly RATE_REDUCTION_FACTOR = 0.5;
  private static readonly RATE_RECOVERY_STEP = 0.1;
  private static readonly SUCCESS_WINDOW = 10;

  private domainStates: Map<string, DomainRateState> = new Map();
  private customRates: Map<string, number> = new Map();
  private totalRequests: number = 0;
  private throttledRequests: number = 0;

  async waitForPermission(domain: string): Promise<void> {
    const state = this.getOrCreateState(domain);
    this.totalRequests++;

    const now = Date.now();
    this.refillTokens(state, now);

    if (state.tokens < 1) {
      this.throttledRequests++;
      const waitMs = (1 - state.tokens) * (1000 / state.currentRate);
      Logger.debug(DomainFrequencyController.TAG,
        `Domain ${domain} rate limited, waiting ${waitMs.toFixed(0)}ms`);
      await this.sleep(waitMs);
      this.refillTokens(state, Date.now());
    }

    state.tokens -= 1;
    state.lastRequestTime = Date.now();
  }

  reportSuccess(domain: string): void {
    const state = this.getOrCreateState(domain);
    state.consecutiveSuccesses++;

    if (state.consecutiveSuccesses >= DomainFrequencyController.SUCCESS_WINDOW) {
      const oldRate = state.currentRate;
      state.currentRate = Math.min(
        state.currentRate + DomainFrequencyController.RATE_RECOVERY_STEP,
        this.customRates.get(domain) ?? DomainFrequencyController.DEFAULT_RATE
      );
      state.consecutiveSuccesses = 0;

      if (oldRate !== state.currentRate) {
        Logger.info(DomainFrequencyController.TAG,
          `Domain ${domain} rate recovered: ${oldRate.toFixed(1)} → ${state.currentRate.toFixed(1)}/s`);
      }
    }
  }

  reportThrottled(domain: string): void {
    const state = this.getOrCreateState(domain);
    state.consecutiveSuccesses = 0;

    const oldRate = state.currentRate;
    state.currentRate = Math.max(
      state.currentRate * DomainFrequencyController.RATE_REDUCTION_FACTOR,
      DomainFrequencyController.MIN_RATE
    );

    Logger.info(DomainFrequencyController.TAG,
      `Domain ${domain} rate reduced (429): ${oldRate.toFixed(1)} → ${state.currentRate.toFixed(1)}/s`);
  }

  setDomainRate(domain: string, ratePerSecond: number): void {
    this.customRates.set(domain, ratePerSecond);
    const state = this.getOrCreateState(domain);
    state.currentRate = ratePerSecond;
    Logger.debug(DomainFrequencyController.TAG,
      `Domain ${domain} rate set to ${ratePerSecond}/s`);
  }

  getDomainState(domain: string): DomainRateState | null {
    const state = this.domainStates.get(domain);
    if (!state) {
      return null;
    }
    const copy: DomainRateState = {
      domain: state.domain,
      currentRate: state.currentRate,
      consecutiveSuccesses: state.consecutiveSuccesses,
      lastRequestTime: state.lastRequestTime,
      tokens: state.tokens,
      lastRefillTime: state.lastRefillTime,
    };
    return copy;
  }

  getMetrics(): FrequencyControlMetrics {
    let totalRate = 0;
    this.domainStates.forEach((state: DomainRateState) => {
      totalRate += state.currentRate;
    });

    const metrics: FrequencyControlMetrics = {
      totalRequests: this.totalRequests,
      throttledRequests: this.throttledRequests,
      domainCount: this.domainStates.size,
      avgRatePerSecond: this.domainStates.size > 0
        ? totalRate / this.domainStates.size
        : 0,
    };
    return metrics;
  }

  private getOrCreateState(domain: string): DomainRateState {
    let state = this.domainStates.get(domain);
    if (!state) {
      const now = Date.now();
      state = {
        domain: domain,
        currentRate: this.customRates.get(domain) ?? DomainFrequencyController.DEFAULT_RATE,
        consecutiveSuccesses: 0,
        lastRequestTime: now,
        tokens: 1,
        lastRefillTime: now,
      };
      this.domainStates.set(domain, state);
    }
    return state;
  }

  private refillTokens(state: DomainRateState, now: number): void {
    const elapsed = (now - state.lastRefillTime) / 1000;
    const newTokens = elapsed * state.currentRate;
    state.tokens = Math.min(state.tokens + newTokens, state.currentRate * 2);
    state.lastRefillTime = now;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => resolve(), ms);
    });
  }
}
