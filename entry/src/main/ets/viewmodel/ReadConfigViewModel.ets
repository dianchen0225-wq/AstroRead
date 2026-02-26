import { ReadConfig, DEFAULT_READ_CONFIG } from '../models/ReadConfig';
import { databaseManager } from '../utils/file/DatabaseManager';
import { Logger } from '../utils/performance/Logger';
import { dataCacheManager, CacheKeys } from '../utils/cache/DataCacheManager';

export class ReadConfigViewModel {
  private readConfig: ReadConfig = DEFAULT_READ_CONFIG;
  private readonly databaseManager = databaseManager;
  private static readonly TAG = 'ReadConfigViewModel';

  static DEFAULT_READ_CONFIG: ReadConfig = DEFAULT_READ_CONFIG;

  /**
   * 加载阅读配置（带缓存）
   */
  async loadReadConfig(): Promise<ReadConfig> {
    const startTime = Date.now();
    
    try {
      const cached = dataCacheManager.get<ReadConfig>(CacheKeys.READ_CONFIG);
      if (cached !== null) {
        Logger.debug(ReadConfigViewModel.TAG, `使用缓存阅读配置, 耗时: ${Date.now() - startTime}ms`);
        this.readConfig = cached;
        return cached;
      }
      
      this.readConfig = await this.databaseManager.getOrCreateReadConfig();
      dataCacheManager.set(CacheKeys.READ_CONFIG, this.readConfig);
      
      Logger.info(ReadConfigViewModel.TAG, `加载阅读配置完成, 耗时: ${Date.now() - startTime}ms`);
      return this.readConfig;
    } catch (error) {
      Logger.error(ReadConfigViewModel.TAG, `加载阅读配置失败: ${error instanceof Error ? error.message : String(error)}`);
      return DEFAULT_READ_CONFIG;
    }
  }

  async updateReadConfig(config: Partial<ReadConfig>): Promise<void> {
    try {
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
        margins: config.margins !== undefined ? config.margins : this.readConfig.margins,
        volumeKeyPageTurn: config.volumeKeyPageTurn !== undefined ? config.volumeKeyPageTurn : this.readConfig.volumeKeyPageTurn,
        clickPageTurn: config.clickPageTurn !== undefined ? config.clickPageTurn : this.readConfig.clickPageTurn
      };
      this.readConfig = updatedConfig;
      await this.databaseManager.updateReadConfig(this.readConfig);
      
      dataCacheManager.set(CacheKeys.READ_CONFIG, this.readConfig);
    } catch (error) {
      Logger.error(ReadConfigViewModel.TAG, `更新阅读配置失败: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  getCurrentConfig(): ReadConfig {
    return this.readConfig;
  }

  /**
   * 获取阅读配置（异步版本，带缓存）
   */
  async getReadConfig(): Promise<ReadConfig> {
    const cached = dataCacheManager.get<ReadConfig>(CacheKeys.READ_CONFIG);
    if (cached !== null) {
      this.readConfig = cached;
      return cached;
    }
    return await this.loadReadConfig();
  }

  /**
   * 重置为默认配置
   */
  async resetToDefault(): Promise<void> {
    try {
      this.readConfig = DEFAULT_READ_CONFIG;
      await this.databaseManager.updateReadConfig(this.readConfig);
      dataCacheManager.set(CacheKeys.READ_CONFIG, this.readConfig);
    } catch (error) {
      Logger.error(ReadConfigViewModel.TAG, `重置阅读配置失败: ${error instanceof Error ? error.message : String(error)}`);
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
