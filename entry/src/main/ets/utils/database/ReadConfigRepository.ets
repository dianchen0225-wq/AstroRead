import relationalStore from '@ohos.data.relationalStore';
import { ReadConfig, MarginsConfig, DEFAULT_READ_CONFIG } from '../../models/ReadConfig';
import { Logger } from '../Logger';

export class ReadConfigRepository {
  private static readonly TAG = 'ReadConfigRepository';
  private rdbStore: relationalStore.RdbStore;

  constructor(rdbStore: relationalStore.RdbStore) {
    this.rdbStore = rdbStore;
  }

  async getOrCreateReadConfig(): Promise<ReadConfig> {
    const predicates = new relationalStore.RdbPredicates('read_config');

    try {
      const resultSet = await this.rdbStore.query(predicates, ['*']);

      const hasData = resultSet.rowCount > 0 && resultSet.goToFirstRow();
      
      if (hasData) {
        try {
          let margins: MarginsConfig = { top: 20, bottom: 20, left: 20, right: 20 };
          try {
            const marginsIndex = resultSet.getColumnIndex('margins');
            if (marginsIndex >= 0) {
              const marginsString = resultSet.getString(marginsIndex);
              if (marginsString) {
                margins = JSON.parse(marginsString) as MarginsConfig;
              }
            }
          } catch (error) {
            Logger.warn(ReadConfigRepository.TAG, `解析边距配置失败，使用默认值`);
          }

          const config: ReadConfig = {
            fontSize: this.safeGetLong(resultSet, 'font_size', DEFAULT_READ_CONFIG.fontSize),
            lineSpacing: this.safeGetDouble(resultSet, 'line_spacing', DEFAULT_READ_CONFIG.lineSpacing),
            letterSpacing: DEFAULT_READ_CONFIG.letterSpacing,
            pageTurnMode: this.safeGetString(resultSet, 'page_turn_mode', DEFAULT_READ_CONFIG.pageTurnMode) as 'cover' | 'slide' | 'scroll' | 'simulation',
            backgroundColor: this.safeGetString(resultSet, 'background_color', DEFAULT_READ_CONFIG.backgroundColor),
            textColor: this.safeGetString(resultSet, 'text_color', DEFAULT_READ_CONFIG.textColor),
            isNightMode: this.safeGetLong(resultSet, 'is_night_mode', 0) === 1,
            brightness: this.safeGetDouble(resultSet, 'brightness', DEFAULT_READ_CONFIG.brightness),
            autoScroll: this.safeGetLong(resultSet, 'auto_scroll', 0) === 1,
            scrollSpeed: this.safeGetLong(resultSet, 'scroll_speed', DEFAULT_READ_CONFIG.scrollSpeed),
            fontFamily: this.safeGetString(resultSet, 'font_family', DEFAULT_READ_CONFIG.fontFamily),
            margins: margins
          };
          resultSet.close();
          return config;
        } catch (parseError) {
          Logger.warn(ReadConfigRepository.TAG, `解析配置失败，将创建默认配置: ${parseError instanceof Error ? parseError.message : String(parseError)}`);
          resultSet.close();
        }
      } else {
        resultSet.close();
      }

      Logger.info(ReadConfigRepository.TAG, '创建默认阅读配置');
      const defaultConfig: ReadConfig = {
        fontSize: DEFAULT_READ_CONFIG.fontSize,
        lineSpacing: DEFAULT_READ_CONFIG.lineSpacing,
        letterSpacing: DEFAULT_READ_CONFIG.letterSpacing,
        pageTurnMode: DEFAULT_READ_CONFIG.pageTurnMode,
        backgroundColor: DEFAULT_READ_CONFIG.backgroundColor,
        textColor: DEFAULT_READ_CONFIG.textColor,
        isNightMode: DEFAULT_READ_CONFIG.isNightMode,
        brightness: DEFAULT_READ_CONFIG.brightness,
        autoScroll: DEFAULT_READ_CONFIG.autoScroll,
        scrollSpeed: DEFAULT_READ_CONFIG.scrollSpeed,
        fontFamily: DEFAULT_READ_CONFIG.fontFamily,
        margins: { top: DEFAULT_READ_CONFIG.margins.top, bottom: DEFAULT_READ_CONFIG.margins.bottom, left: DEFAULT_READ_CONFIG.margins.left, right: DEFAULT_READ_CONFIG.margins.right }
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

      try {
        await this.rdbStore.insert('read_config', valueBucket);
      } catch (insertError) {
        Logger.warn(ReadConfigRepository.TAG, `插入配置失败，可能已存在: ${insertError instanceof Error ? insertError.message : String(insertError)}`);
      }
      return defaultConfig;
    } catch (error) {
      Logger.error(ReadConfigRepository.TAG, `获取或创建阅读配置失败: ${error instanceof Error ? error.message : String(error)}`);
      return {
        fontSize: DEFAULT_READ_CONFIG.fontSize,
        lineSpacing: DEFAULT_READ_CONFIG.lineSpacing,
        letterSpacing: DEFAULT_READ_CONFIG.letterSpacing,
        pageTurnMode: DEFAULT_READ_CONFIG.pageTurnMode,
        backgroundColor: DEFAULT_READ_CONFIG.backgroundColor,
        textColor: DEFAULT_READ_CONFIG.textColor,
        isNightMode: DEFAULT_READ_CONFIG.isNightMode,
        brightness: DEFAULT_READ_CONFIG.brightness,
        autoScroll: DEFAULT_READ_CONFIG.autoScroll,
        scrollSpeed: DEFAULT_READ_CONFIG.scrollSpeed,
        fontFamily: DEFAULT_READ_CONFIG.fontFamily,
        margins: { top: DEFAULT_READ_CONFIG.margins.top, bottom: DEFAULT_READ_CONFIG.margins.bottom, left: DEFAULT_READ_CONFIG.margins.left, right: DEFAULT_READ_CONFIG.margins.right }
      };
    }
  }

  private safeGetLong(resultSet: relationalStore.ResultSet, columnName: string, defaultValue: number): number {
    try {
      const index = resultSet.getColumnIndex(columnName);
      if (index >= 0 && !resultSet.isColumnNull(index)) {
        return resultSet.getLong(index);
      }
    } catch (error) {
    }
    return defaultValue;
  }

  private safeGetDouble(resultSet: relationalStore.ResultSet, columnName: string, defaultValue: number): number {
    try {
      const index = resultSet.getColumnIndex(columnName);
      if (index >= 0 && !resultSet.isColumnNull(index)) {
        return resultSet.getDouble(index);
      }
    } catch (error) {
    }
    return defaultValue;
  }

  private safeGetString(resultSet: relationalStore.ResultSet, columnName: string, defaultValue: string): string {
    try {
      const index = resultSet.getColumnIndex(columnName);
      if (index >= 0 && !resultSet.isColumnNull(index)) {
        return resultSet.getString(index);
      }
    } catch (error) {
    }
    return defaultValue;
  }

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
      Logger.error(ReadConfigRepository.TAG, `更新阅读配置失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
