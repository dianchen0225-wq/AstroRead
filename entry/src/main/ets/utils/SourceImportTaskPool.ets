import { taskpool } from '@kit.ArkTS';
import { BookSource } from '../models/BookSource';
import { SecurityScanResult, SourceSandbox } from './SourceSandbox';
import BookSourceParser from './BookSourceParser';
import SourceImportManager from './SourceImportManager';
import { DatabaseManager } from './DatabaseManager';
import { Logger } from './Logger';

export interface ImportTaskResult {
  success: boolean;
  message: string;
  count: number;
}

const TAG = 'SourceImportTaskPool';

@Concurrent
export function scanSecurityTask(content: string): SecurityScanResult {
  return SourceSandbox.scanSourceContent(content);
}

@Concurrent
export function detectFormatTask(content: string): string {
  return BookSourceParser.detectFormat(content);
}

@Concurrent
export async function importSourcesTask(content: string, format: string, skipSafetyCheck: boolean): Promise<ImportTaskResult> {
  const result = await SourceImportManager.importSources(content, format, skipSafetyCheck);
  return {
    success: result.success,
    message: result.message,
    count: result.importedCount
  };
}

@Concurrent
export async function saveBookSourcesTask(sources: BookSource[]): Promise<boolean> {
  try {
    const dbManager = DatabaseManager.getInstance();
    await dbManager.batchUpsertBookSources(sources);
    return true;
  } catch (error) {
    Logger.error('SaveBookSourcesTask', `保存书源失败: ${error}`);
    return false;
  }
}

export class SourceImportTaskPool {
  static async scanSecurity(content: string): Promise<SecurityScanResult> {
    try {
      const result = await taskpool.execute(scanSecurityTask, content) as SecurityScanResult;
      return result;
    } catch (error) {
      Logger.error(TAG, `安全扫描失败: ${error}`);
      const failResult: SecurityScanResult = {
        isSafe: false,
        riskLevel: 'high',
        risks: [],
        summary: '扫描失败'
      };
      return failResult;
    }
  }

  static async detectFormat(content: string): Promise<string> {
    try {
      const result = await taskpool.execute(detectFormatTask, content) as string;
      return result;
    } catch (error) {
      Logger.error(TAG, `格式检测失败: ${error}`);
      return 'unknown';
    }
  }

  static async importSources(content: string, format: string, skipSafetyCheck: boolean): Promise<ImportTaskResult> {
    try {
      const result = await taskpool.execute(importSourcesTask, content, format, skipSafetyCheck) as ImportTaskResult;
      return result;
    } catch (error) {
      Logger.error(TAG, `导入失败: ${error}`);
      const failResult: ImportTaskResult = {
        success: false,
        message: error instanceof Error ? error.message : '导入失败',
        count: 0
      };
      return failResult;
    }
  }
}
