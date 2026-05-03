import { Result, ErrorCode } from "../../core/Result";
import { IJSRenderScheduler, JSRenderResult, JSRenderOptions } from "./interfaces/IAntiCrawl";
import { Logger } from "../performance/Logger";

interface RenderTimeoutOptions {
  timeoutMs: number;
  blockResources: string[];
  waitForSelector?: string;
  userAgent?: string;
}

export class JSRenderScheduler implements IJSRenderScheduler {
  private static readonly TAG = 'JSRenderScheduler';

  private maxConcurrency: number;
  private defaultTimeoutMs: number;
  private blockedResources: string[];
  private activeRenders: number = 0;
  private available: boolean = true;
  private crashed: boolean = false;

  constructor(
    maxConcurrency: number = 3,
    defaultTimeoutMs: number = 10000,
    blockedResources: string[] = ['image', 'stylesheet', 'font', 'media']
  ) {
    this.maxConcurrency = maxConcurrency;
    this.defaultTimeoutMs = defaultTimeoutMs;
    this.blockedResources = blockedResources;
  }

  async render(url: string, options?: JSRenderOptions): Promise<Result<JSRenderResult>> {
    if (this.crashed) {
      Logger.warn(JSRenderScheduler.TAG, 'JS render engine crashed, cannot render');
      return Result.err(ErrorCode.PARSE_ERROR, 'JS渲染引擎不可用');
    }

    if (this.activeRenders >= this.maxConcurrency) {
      Logger.debug(JSRenderScheduler.TAG, `Max render concurrency reached (${this.maxConcurrency})`);
      await this.waitForSlot();
    }

    this.activeRenders++;
    const timeoutMs = options?.timeoutMs ?? this.defaultTimeoutMs;
    const startTime = Date.now();

    try {
      Logger.debug(JSRenderScheduler.TAG, `Rendering: ${url} (timeout=${timeoutMs}ms)`);

      const renderOptions: RenderTimeoutOptions = {
        timeoutMs: timeoutMs,
        blockResources: options?.blockResources ?? this.blockedResources,
        waitForSelector: options?.waitForSelector,
        userAgent: options?.userAgent,
      };
      const html = await this.renderWithTimeout(url, renderOptions);

      const renderTime = Date.now() - startTime;
      this.activeRenders--;

      const successResult: JSRenderResult = {
        html: html,
        renderTimeMs: renderTime,
        success: true,
      };
      return Result.ok(successResult);
    } catch (e) {
      this.activeRenders--;
      const message = e instanceof Error ? e.message : String(e);

      if (message.includes('crash') || message.includes('OOM')) {
        this.crashed = true;
        this.available = false;
        Logger.error(JSRenderScheduler.TAG, `JS render engine crashed: ${message}`);
      }

      const failResult: JSRenderResult = {
        html: '',
        renderTimeMs: Date.now() - startTime,
        success: false,
        error: message,
      };
      return Result.ok(failResult);
    }
  }

  isAvailable(): boolean {
    return this.available && !this.crashed;
  }

  getConcurrency(): number {
    return this.activeRenders;
  }

  shutdown(): void {
    this.available = false;
    this.activeRenders = 0;
    Logger.info(JSRenderScheduler.TAG, 'JSRenderScheduler shutdown');
  }

  markCrashed(): void {
    this.crashed = true;
    this.available = false;
    Logger.error(JSRenderScheduler.TAG, 'JS render engine manually marked as crashed');
  }

  recover(): void {
    this.crashed = false;
    this.available = true;
    Logger.info(JSRenderScheduler.TAG, 'JS render engine recovered');
  }

  private async renderWithTimeout(
    url: string,
    options: RenderTimeoutOptions
  ): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void) => {
      const timer = setTimeout(() => {
        reject(new Error(`JS渲染超时 (${options.timeoutMs}ms)`));
      }, options.timeoutMs);

      setTimeout(() => {
        clearTimeout(timer);
        resolve(`<!-- JS rendered: ${url} -->`);
      }, Math.min(options.timeoutMs / 2, 100));
    });
  }

  private async waitForSlot(): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      const check = (): void => {
        if (this.activeRenders < this.maxConcurrency) {
          resolve();
        } else {
          setTimeout(check, 100);
        }
      };
      setTimeout(check, 100);
    });
  }
}
