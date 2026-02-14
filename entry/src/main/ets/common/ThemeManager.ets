/**
 * 主题管理器
 * 提供全局的主题状态管理和切换功能
 */

import { preferences } from '@kit.ArkData';
import { Logger } from '../utils/Logger';

const THEME_PREFERENCES_NAME = 'theme_preferences';
const THEME_MODE_KEY = 'theme_mode';

export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark',
  AUTO = 'auto'
}

export class ThemeManager {
  private static readonly TAG = 'ThemeManager';
  private static instance: ThemeManager;
  private currentMode: ThemeMode = ThemeMode.LIGHT;
  private isDarkMode: boolean = false;
  private listeners: Array<(isDark: boolean) => void> = [];
  private preferences: preferences.Preferences | null = null;

  private constructor() {
    this.initPreferences();
  }

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  private async initPreferences(): Promise<void> {
    try {
      this.preferences = await preferences.getPreferences(getContext(), THEME_PREFERENCES_NAME);
      const savedMode = await this.preferences.get(THEME_MODE_KEY, ThemeMode.LIGHT) as ThemeMode;
      await this.setThemeMode(savedMode);
    } catch (error) {
      Logger.error(ThemeManager.TAG, `初始化主题偏好设置失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  public async setThemeMode(mode: ThemeMode): Promise<void> {
    this.currentMode = mode;

    if (mode === ThemeMode.AUTO) {
      // 根据系统主题自动切换
      this.isDarkMode = this.isSystemDarkMode();
    } else {
      this.isDarkMode = mode === ThemeMode.DARK;
    }

    // 保存到持久化存储
    if (this.preferences) {
      await this.preferences.put(THEME_MODE_KEY, mode);
      await this.preferences.flush();
    }

    // 通知所有监听器
    this.notifyListeners();
  }

  public getThemeMode(): ThemeMode {
    return this.currentMode;
  }

  public isDarkTheme(): boolean {
    return this.isDarkMode;
  }

  public isLightTheme(): boolean {
    return !this.isDarkMode;
  }

  public toggleTheme(): void {
    const newMode = this.isDarkMode ? ThemeMode.LIGHT : ThemeMode.DARK;
    this.setThemeMode(newMode);
  }

  public addListener(listener: (isDark: boolean) => void): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  public removeListener(listener: (isDark: boolean) => void): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    this.listeners.forEach(listener => {
      try {
        listener(this.isDarkMode);
      } catch (error) {
        Logger.error(ThemeManager.TAG, `通知主题监听器失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    });
  }

  private isSystemDarkMode(): boolean {
    // 检查系统是否处于深色模式
    try {
      const systemTheme = AppStorage.get('systemTheme') as string;
      return systemTheme === 'dark';
    } catch (error) {
      Logger.error(ThemeManager.TAG, `检查系统主题失败: ${error instanceof Error ? error.message : String(error)}`);
      return false;
    }
  }
}

// 导出单例实例
export const themeManager = ThemeManager.getInstance();
