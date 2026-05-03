import { Result, ErrorCode } from "../../core/Result";
import { IExceptionIsolationGuard } from "./interfaces/IStability";
import { CrawlErrorCode } from "./models/CrawlError";
import { Logger } from "../performance/Logger";

export class ExceptionIsolationGuard implements IExceptionIsolationGuard {
  private static readonly TAG = 'ExceptionIsolationGuard';

  executeSafely<T>(fn: () => T): Result<T> {
    try {
      const result = fn();
      return Result.ok(result);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      Logger.warn(ExceptionIsolationGuard.TAG, `Isolated exception: ${message}`);
      return Result.err(ErrorCode.PARSE_ERROR, message);
    }
  }

  executeIsolated<T>(fns: (() => T)[], index: number): Result<T>[] {
    const results: Result<T>[] = [];

    for (let i = 0; i < fns.length; i++) {
      results.push(this.executeSafely(fns[i]));
    }

    return results;
  }
}
