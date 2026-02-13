/**
 * 主题管理器
 * 提供全局的主题状态管理和切换功能
 */

import { preferences } from '@kit.ArkData';

const THEME_PREFERENCES_NAME = 'theme_preferences';
const THEME_MODE_KEY = 'theme_mode';

export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark',
  AUTO = 'auto'
}

export class ThemeManager {
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
      console.error('Failed to init theme preferences:', error);
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
        console.error('Error notifying theme listener:', error);
      }
    });
  }

  private isSystemDarkMode(): boolean {
    // 检查系统是否处于深色模式
    try {
      const systemTheme = AppStorage.get('systemTheme') as string;
      return systemTheme === 'dark';
    } catch (error) {
      console.error('Failed to check system theme:', error);
      return false;
    }
  }
}

// 导出单例实例
export const themeManager = ThemeManager.getInstance();
