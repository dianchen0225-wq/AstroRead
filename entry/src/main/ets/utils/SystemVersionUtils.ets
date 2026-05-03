import { deviceInfo } from '@kit.BasicServicesKit';
import { Logger } from './performance/Logger';

const TAG = 'SystemVersionUtils';

export class SystemVersion {
  static readonly API_12 = 12;
  static readonly API_14 = 14;
  static readonly API_17 = 17;
  static readonly API_20 = 20;
}

let cachedApiVersion: number = -1;

function detectApiVersion(): number {
  if (cachedApiVersion >= 0) {
    return cachedApiVersion;
  }

  try {
    cachedApiVersion = deviceInfo.sdkApiVersion;
    Logger.info(TAG, `检测到SDK API版本: ${cachedApiVersion}`);
  } catch (error) {
    Logger.warn(TAG, `无法获取SDK API版本，使用默认值: ${error}`);
    cachedApiVersion = 12;
  }

  return cachedApiVersion;
}

export function getApiVersion(): number {
  return detectApiVersion();
}

export function isApiVersionAtLeast(version: number): boolean {
  return detectApiVersion() >= version;
}

export function isApiVersionBelow(version: number): boolean {
  return detectApiVersion() < version;
}
