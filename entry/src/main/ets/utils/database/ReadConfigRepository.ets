import relationalStore from '@ohos.data.relationalStore';
import { ReadConfig, MarginsConfig } from '../../models/ReadConfig';

/**
 * 阅读配置数据库操作
 */
export class ReadConfigRepository {
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  /**
   * 获取或创建阅读配置
   */
  async getOrCreateReadConfig(): Promise<ReadConfig> {
    const predicates = new relationalStore.RdbPredicates('read_config');
    
    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow();
        const marginsString = resultSet.getString(resultSet.getColumnIndex('margins'));
        let margins: MarginsConfig = { top: 20, bottom: 20, left: 20, right: 20 };
        try {
          if (marginsString) {
            margins = JSON.parse(marginsString) as MarginsConfig;
          }
        } catch (error) {
          console.warn(`Failed to parse margins, using default: ${error instanceof Error ? error.message : String(error)}`);
        }

        const config: ReadConfig = {
          fontSize: resultSet.getLong(resultSet.getColumnIndex('font_size')) || 16,
          lineSpacing: resultSet.getDouble(resultSet.getColumnIndex('line_spacing')) || 1.5,
          letterSpacing: resultSet.getDouble(resultSet.getColumnIndex('letter_spacing')) || 0,
          pageTurnMode: (resultSet.getString(resultSet.getColumnIndex('page_turn_mode')) as 'cover' | 'slide' | 'scroll' | 'simulation') || 'cover',
          backgroundColor: resultSet.getString(resultSet.getColumnIndex('background_color')) || '#FFFFFF',
          textColor: resultSet.getString(resultSet.getColumnIndex('text_color')) || '#333333',
          isNightMode: resultSet.getLong(resultSet.getColumnIndex('is_night_mode')) === 1,
          brightness: resultSet.getDouble(resultSet.getColumnIndex('brightness')) || 0.5,
          autoScroll: resultSet.getLong(resultSet.getColumnIndex('auto_scroll')) === 1,
          scrollSpeed: resultSet.getLong(resultSet.getColumnIndex('scroll_speed')) || 50,
          fontFamily: resultSet.getString(resultSet.getColumnIndex('font_family')) || 'HarmonyOS Sans',
          margins: margins
        };
        resultSet.close();
        return config;
      } else {
        // 创建默认配置
        const defaultConfig: ReadConfig = {
          fontSize: 16,
          lineSpacing: 1.5,
          letterSpacing: 0,
          pageTurnMode: 'cover',
          backgroundColor: '#FFFFFF',
          textColor: '#333333',
          isNightMode: false,
          brightness: 0.5,
          autoScroll: false,
          scrollSpeed: 50,
          fontFamily: 'HarmonyOS Sans',
          margins: { top: 20, bottom: 20, left: 20, right: 20 }
        };
        
        const valueBucket: relationalStore.ValuesBucket = {
          'id': 'default',
          'font_size': defaultConfig.fontSize,
          'line_spacing': defaultConfig.lineSpacing,
          'page_turn_mode': defaultConfig.pageTurnMode,
          'background_color': defaultConfig.backgroundColor,
          'text_color': defaultConfig.textColor,
          'is_night_mode': defaultConfig.isNightMode ? 1 : 0,
          'brightness': defaultConfig.brightness,
          'auto_scroll': defaultConfig.autoScroll ? 1 : 0,
          'scroll_speed': defaultConfig.scrollSpeed,
          'font_family': defaultConfig.fontFamily,
          'margins': JSON.stringify(defaultConfig.margins),
          'update_time': Date.now()
        };
        
        await this.rdbStore.insert('read_config', valueBucket);
        return defaultConfig;
      }
    } catch (error) {
      console.error(`Failed to get or create read config: ${error instanceof Error ? error.message : String(error)}`);
      throw (error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 更新阅读配置
   */
  async updateReadConfig(config: ReadConfig): Promise<void> {
    const valueBucket: relationalStore.ValuesBucket = {
      'font_size': config.fontSize,
      'line_spacing': config.lineSpacing,
      'page_turn_mode': config.pageTurnMode,
      'background_color': config.backgroundColor,
      'text_color': config.textColor,
      'is_night_mode': config.isNightMode ? 1 : 0,
      'brightness': config.brightness,
      'auto_scroll': config.autoScroll ? 1 : 0,
      'scroll_speed': config.scrollSpeed,
      'font_family': config.fontFamily,
      'margins': JSON.stringify(config.margins),
      'update_time': Date.now()
    };

    try {
      const predicates = new relationalStore.RdbPredicates('read_config');
      predicates.equalTo('id', 'default');
      await this.rdbStore.update(valueBucket, predicates);
    } catch (error) {
      console.error(`Failed to update read config: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
