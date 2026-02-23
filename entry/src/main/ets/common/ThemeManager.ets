/**
 * 主题管理器
 * 提供全局的主题状态管理和切换功能
 */

import { preferences } from '@kit.ArkData';
import { Logger } from '../utils/Logger';
import common from '@ohos.app.ability.common';

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
  private initPromise: Promise<void> | null = null;
  private isInitialized: boolean = false;
  private context: common.UIAbilityContext | null = null;
  private isTransitioning: boolean = false;
  private transitionDuration: number = 300;
  private batchUpdateScheduled: boolean = false;
  private pendingNotify: boolean = false;

  private constructor() {
  }

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    if (!this.initPromise) {
      this.initPromise = this.initPreferences();
    }
  }

  async ensureInitialized(): Promise<void> {
    if (this.initPromise) {
      await this.initPromise;
    }
  }

  isReady(): boolean {
    return this.isInitialized;
  }

  private async initPreferences(): Promise<void> {
    if (!this.context) {
      Logger.error(ThemeManager.TAG, 'Context未设置，无法初始化主题偏好设置');
      this.isInitialized = true;
      return;
    }
    try {
      this.preferences = await preferences.getPreferences(this.context, THEME_PREFERENCES_NAME);
      const savedMode = await this.preferences.get(THEME_MODE_KEY, ThemeMode.LIGHT) as ThemeMode;
      this.currentMode = savedMode;
      
      if (savedMode === ThemeMode.AUTO) {
        this.isDarkMode = this.isSystemDarkMode();
      } else {
        this.isDarkMode = savedMode === ThemeMode.DARK;
      }
      
      this.isInitialized = true;
      this.notifyListeners();
    } catch (error) {
      Logger.error(ThemeManager.TAG, `初始化主题偏好设置失败: ${error instanceof Error ? error.message : String(error)}`);
      this.isInitialized = true;
    }
  }

  public async setThemeMode(mode: ThemeMode): Promise<void> {
    const previousMode = this.currentMode;
    this.currentMode = mode;

    if (mode === ThemeMode.AUTO) {
      this.isDarkMode = this.isSystemDarkMode();
    } else {
      this.isDarkMode = mode === ThemeMode.DARK;
    }

    if (this.preferences) {
      try {
        await this.preferences.put(THEME_MODE_KEY, mode);
        await this.preferences.flush();
      } catch (error) {
        Logger.error(ThemeManager.TAG, `保存主题设置失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    if (previousMode !== mode) {
      this.notifyListeners();
    }
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

  public removeAllListeners(): void {
    this.listeners = [];
  }

  private notifyListeners(): void {
    if (this.batchUpdateScheduled) {
      this.pendingNotify = true;
      return;
    }
    this.batchUpdateScheduled = true;
    this.pendingNotify = false;
    
    setTimeout(() => {
      this.batchUpdateScheduled = false;
      if (this.pendingNotify) {
        this.pendingNotify = false;
        this.notifyListeners();
        return;
      }
      
      const listenersCopy = [...this.listeners];
      const batchSize = 5;
      let currentIndex = 0;
      
      const processBatch = (): void => {
        const endIndex = Math.min(currentIndex + batchSize, listenersCopy.length);
        for (let i = currentIndex; i < endIndex; i++) {
          try {
            listenersCopy[i](this.isDarkMode);
          } catch (error) {
            Logger.error(ThemeManager.TAG, `通知主题监听器失败: ${error instanceof Error ? error.message : String(error)}`);
          }
        }
        currentIndex = endIndex;
        
        if (currentIndex < listenersCopy.length) {
          setTimeout(processBatch, 0);
        } else {
          this.isTransitioning = false;
        }
      };
      
      this.isTransitioning = true;
      processBatch();
    }, 16);
  }

  public isThemeTransitioning(): boolean {
    return this.isTransitioning;
  }

  public getTransitionDuration(): number {
    return this.transitionDuration;
  }

  public setTransitionDuration(duration: number): void {
    this.transitionDuration = duration;
  }

  private isSystemDarkMode(): boolean {
    try {
      const systemTheme = AppStorage.get('systemTheme') as string;
      return systemTheme === 'dark';
    } catch (error) {
      Logger.error(ThemeManager.TAG, `检查系统主题失败: ${error instanceof Error ? error.message : String(error)}`);
      return false;
    }
  }
}

export const themeManager = ThemeManager.getInstance();
