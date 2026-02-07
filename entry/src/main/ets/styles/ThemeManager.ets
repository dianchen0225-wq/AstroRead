/**
 * 主题管理器
 * 管理应用主题状态，支持动态切换
 */

import { LightTheme, DarkTheme, ThemeType, AppTheme } from './Theme';

@Observed
export class ThemeManager {
  private _currentTheme: AppTheme = LightTheme;
  private _themeType: ThemeType = ThemeType.LIGHT;
  
  // 主题变更回调
  private themeChangeCallbacks: ((theme: AppTheme) => void)[] = [];
  
  // 单例模式
  private static instance: ThemeManager;
  
  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }
  
  // 获取当前主题
  get currentTheme(): AppTheme {
    return this._currentTheme;
  }
  
  get themeType(): ThemeType {
    return this._themeType;
  }
  
  // 切换主题
  toggleTheme(): void {
    this._themeType = this._themeType === ThemeType.LIGHT ? ThemeType.DARK : ThemeType.LIGHT;
    this._currentTheme = this._themeType === ThemeType.LIGHT ? LightTheme : DarkTheme;
    this.notifyThemeChange();
  }
  
  // 设置主题
  setTheme(themeType: ThemeType): void {
    this._themeType = themeType;
    this._currentTheme = themeType === ThemeType.LIGHT ? LightTheme : DarkTheme;
    this.notifyThemeChange();
  }
  
  // 注册主题变更回调
  onThemeChange(callback: (theme: AppTheme) => void): void {
    this.themeChangeCallbacks.push(callback);
  }
  
  // 移除主题变更回调
  offThemeChange(callback: (theme: AppTheme) => void): void {
    const index = this.themeChangeCallbacks.indexOf(callback);
    if (index > -1) {
      this.themeChangeCallbacks.splice(index, 1);
    }
  }
  
  // 通知主题变更
  private notifyThemeChange(): void {
    this.themeChangeCallbacks.forEach(callback => {
      callback(this._currentTheme);
    });
  }
  
  // 检查是否为暗黑模式
  get isDarkMode(): boolean {
    return this._themeType === ThemeType.DARK;
  }
  
  // 获取系统主题（未来可扩展为跟随系统）
  getSystemTheme(): ThemeType {
    // 暂时返回当前主题，后续可集成系统主题检测
    return this._themeType;
  }
}