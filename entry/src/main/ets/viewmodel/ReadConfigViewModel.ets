import { ReadConfig, DEFAULT_READ_CONFIG } from '../models/ReadConfig';
import { databaseManager } from '../utils/DatabaseManager';
/**
 * 阅读配置视图模型
 * 负责管理阅读配置相关的业务逻辑和状态
 */
export class ReadConfigViewModel {
  private readConfig: ReadConfig = DEFAULT_READ_CONFIG;
  private readonly databaseManager = databaseManager;

  // 静态属性：默认阅读配置
  static DEFAULT_READ_CONFIG: ReadConfig = DEFAULT_READ_CONFIG;

  /**
   * 加载阅读配置
   */
  async loadReadConfig(): Promise<ReadConfig> {
    try {
      this.readConfig = await this.databaseManager.getOrCreateReadConfig();
      return this.readConfig;
    } catch (error) {
      console.error('Failed to load read config:', error);
      return DEFAULT_READ_CONFIG;
    }
  }

  /**
   * 更新阅读配置
   */
  async updateReadConfig(config: Partial<ReadConfig>): Promise<void> {
    try {
      // 使用对象合并替代 spread 操作
      const updatedConfig: ReadConfig = {
        fontSize: config.fontSize !== undefined ? config.fontSize : this.readConfig.fontSize,
        lineSpacing: config.lineSpacing !== undefined ? config.lineSpacing : this.readConfig.lineSpacing,
        letterSpacing: config.letterSpacing !== undefined ? config.letterSpacing : this.readConfig.letterSpacing,
        pageTurnMode: config.pageTurnMode !== undefined ? config.pageTurnMode : this.readConfig.pageTurnMode,
        backgroundColor: config.backgroundColor !== undefined ? config.backgroundColor : this.readConfig.backgroundColor,
        textColor: config.textColor !== undefined ? config.textColor : this.readConfig.textColor,
        isNightMode: config.isNightMode !== undefined ? config.isNightMode : this.readConfig.isNightMode,
        brightness: config.brightness !== undefined ? config.brightness : this.readConfig.brightness,
        autoScroll: config.autoScroll !== undefined ? config.autoScroll : this.readConfig.autoScroll,
        scrollSpeed: config.scrollSpeed !== undefined ? config.scrollSpeed : this.readConfig.scrollSpeed,
        fontFamily: config.fontFamily !== undefined ? config.fontFamily : this.readConfig.fontFamily,
        margins: config.margins !== undefined ? config.margins : this.readConfig.margins
      };
      this.readConfig = updatedConfig;
      await this.databaseManager.updateReadConfig(this.readConfig);
    } catch (error) {
      console.error('Failed to update read config:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }
  /**
   * 获取当前阅读配置
   */
  getCurrentConfig(): ReadConfig {
    return this.readConfig;
  }

  /**
   * 获取阅读配置（异步版本）
   */
  async getReadConfig(): Promise<ReadConfig> {
    return await this.loadReadConfig();
  }

  /**
   * 重置为默认配置
   */
  async resetToDefault(): Promise<void> {
    try {
      this.readConfig = DEFAULT_READ_CONFIG;
      await this.databaseManager.updateReadConfig(this.readConfig);
    } catch (error) {
      console.error('Failed to reset read config:', error);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 更新字体大小
   */
  async updateFontSize(fontSize: number): Promise<void> {
    await this.updateReadConfig({ fontSize });
  }

  /**
   * 更新行间距
   */
  async updateLineSpacing(lineSpacing: number): Promise<void> {
    await this.updateReadConfig({ lineSpacing });
  }

  /**
   * 更新翻页模式
   */
  async updatePageTurnMode(mode: 'cover' | 'slide' | 'scroll' | 'simulation'): Promise<void> {
    await this.updateReadConfig({ pageTurnMode: mode });
  }

  /**
   * 切换夜间模式
   */
  async toggleNightMode(isNightMode: boolean): Promise<void> {
    if (isNightMode) {
      await this.updateReadConfig({
        isNightMode: true,
        backgroundColor: '#1E1E1E',
        textColor: '#CCCCCC'
      });
    } else {
      await this.updateReadConfig({
        isNightMode: false,
        backgroundColor: '#FFFFFF',
        textColor: '#333333'
      });
    }
  }
}
