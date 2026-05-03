import { IRuleFailureDetector, RuleFailureRecord, RuleFailureDetectorConfig } from "./interfaces/IStability";
import { Logger } from "../performance/Logger";

export class RuleFailureDetector implements IRuleFailureDetector {
  private static readonly TAG = 'RuleFailureDetector';

  private records: Map<string, RuleFailureRecord> = new Map();
  private config: RuleFailureDetectorConfig;

  constructor(config?: Partial<RuleFailureDetectorConfig>) {
    this.config = {
      failureThreshold: config?.failureThreshold ?? 10,
      windowMs: config?.windowMs ?? 24 * 60 * 60 * 1000,
      autoRecoveryMs: config?.autoRecoveryMs ?? 60 * 60 * 1000,
    };
  }

  recordFailure(rule: string): void {
    const now = Date.now();
    let record = this.records.get(rule);

    if (!record) {
      record = {
        rule: rule,
        failureCount: 1,
        lastFailureTime: now,
        firstFailureTime: now,
        suspectedFailed: false,
      };
    } else {
      if (now - record.firstFailureTime > this.config.windowMs) {
        record.failureCount = 1;
        record.firstFailureTime = now;
      } else {
        record.failureCount++;
      }
      record.lastFailureTime = now;
    }

    if (record.failureCount >= this.config.failureThreshold && !record.suspectedFailed) {
      record.suspectedFailed = true;
      Logger.warn(RuleFailureDetector.TAG, `Rule suspected failed: ${rule} (${record.failureCount} failures)`);
    }

    this.records.set(rule, record);
  }

  recordSuccess(rule: string): void {
    const record = this.records.get(rule);
    if (record) {
      if (record.suspectedFailed) {
        Logger.info(RuleFailureDetector.TAG, `Rule recovered from failure: ${rule}`);
      }
      record.failureCount = 0;
      record.suspectedFailed = false;
      record.firstFailureTime = 0;
      this.records.set(rule, record);
    }
  }

  isRuleSuspectedFailed(rule: string): boolean {
    const record = this.records.get(rule);
    if (!record) return false;

    if (record.suspectedFailed) {
      const now = Date.now();
      if (now - record.lastFailureTime > this.config.autoRecoveryMs) {
        record.suspectedFailed = false;
        record.failureCount = 0;
        this.records.set(rule, record);
        Logger.info(RuleFailureDetector.TAG, `Rule auto-recovered: ${rule}`);
        return false;
      }
      return true;
    }

    return false;
  }

  getFailedRules(): RuleFailureRecord[] {
    const now = Date.now();
    const failed: RuleFailureRecord[] = [];

    this.records.forEach((record: RuleFailureRecord) => {
      if (record.suspectedFailed) {
        if (now - record.lastFailureTime > this.config.autoRecoveryMs) {
          record.suspectedFailed = false;
          record.failureCount = 0;
        } else {
          failed.push({ ...record });
        }
      }
    });

    return failed;
  }

  reset(rule: string): void {
    this.records.delete(rule);
    Logger.debug(RuleFailureDetector.TAG, `Reset failure record for: ${rule}`);
  }

  getConfig(): RuleFailureDetectorConfig {
    return { ...this.config };
  }
}
