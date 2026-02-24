/**
 * ToastUtils - Toast 提示工具类
 * 封装 HarmonyOS Toast 提示功能
 */

import { promptAction } from '@kit.ArkUI';
import { Logger } from './Logger';

const TAG = 'ToastUtils';

export interface ToastOptions {
  message: string;
  duration?: number;
  bottom?: string | number;
}

/**
 * 显示 Toast 提示
 * @param options Toast 选项
 */
export function showToast(options: ToastOptions): void {
  try {
    promptAction.showToast({
      message: options.message,
      duration: options.duration ?? 2000,
      bottom: options.bottom
    });
  } catch (error) {
    Logger.error(TAG, `显示 Toast 失败: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * 显示短时长 Toast 提示（2秒）
 * @param message 提示消息
 */
export function showShortToast(message: string): void {
  showToast({ message, duration: 2000 });
}

/**
 * 显示长时长 Toast 提示（3.5秒）
 * @param message 提示消息
 */
export function showLongToast(message: string): void {
  showToast({ message, duration: 3500 });
}
