import { Logger } from '../utils/Logger';

export interface FloatingNavConfig {
  enabled: boolean;
  position: 'left' | 'center' | 'right' | 'bottom-left' | 'bottom-center' | 'bottom-right';
  width: number;
  height: number;
  borderRadius: number;
  opacity: number;
  backgroundOpacity: number;
  blurEnabled: boolean;
  autoHide: boolean;
  autoHideDelay: number;
  animationEnabled: boolean;
}

const DEFAULT_CONFIG: FloatingNavConfig = {
  enabled: false,
  position: 'bottom-center',
  width: 280,
  height: 56,
  borderRadius: 28,
  opacity: 1.0,
  backgroundOpacity: 0.95,
  blurEnabled: true,
  autoHide: false,
  autoHideDelay: 3000,
  animationEnabled: true
};

const STORAGE_KEY = 'floating_nav_config';

export class FloatingNavManager {
  private static instance: FloatingNavManager;
  private config: FloatingNavConfig = { ...DEFAULT_CONFIG };
  private configChangeListeners: ((config: FloatingNavConfig) => void)[] = [];

  static getInstance(): FloatingNavManager {
    if (!FloatingNavManager.instance) {
      FloatingNavManager.instance = new FloatingNavManager();
    }
    return FloatingNavManager.instance;
  }

  async loadConfig(): Promise<void> {
    try {
      const configStr = AppStorage.get<string>(STORAGE_KEY);
      if (configStr) {
        const loadedConfig = JSON.parse(configStr) as Partial<FloatingNavConfig>;
        this.config = { ...DEFAULT_CONFIG, ...loadedConfig };
        Logger.info('FloatingNavManager', '配置加载成功');
      }
    } catch (error) {
      Logger.error('FloatingNavManager', `加载配置失败: ${error}`);
      this.config = { ...DEFAULT_CONFIG };
    }
  }

  async saveConfig(): Promise<void> {
    try {
      AppStorage.setOrCreate<string>(STORAGE_KEY, JSON.stringify(this.config));
      this.notifyConfigChange();
      Logger.info('FloatingNavManager', '配置保存成功');
    } catch (error) {
      Logger.error('FloatingNavManager', `保存配置失败: ${error}`);
    }
  }

  getConfig(): FloatingNavConfig {
    return { ...this.config };
  }

  async updateConfig(updates: Partial<FloatingNavConfig>): Promise<void> {
    this.config = { ...this.config, ...updates };
    await this.saveConfig();
  }

  async setEnabled(enabled: boolean): Promise<void> {
    this.config.enabled = enabled;
    await this.saveConfig();
  }

  async setPosition(position: FloatingNavConfig['position']): Promise<void> {
    this.config.position = position;
    await this.saveConfig();
  }

  async setSize(width: number, height: number): Promise<void> {
    this.config.width = Math.max(200, Math.min(400, width));
    this.config.height = Math.max(44, Math.min(80, height));
    await this.saveConfig();
  }

  async setBorderRadius(radius: number): Promise<void> {
    this.config.borderRadius = Math.max(0, Math.min(40, radius));
    await this.saveConfig();
  }

  async setOpacity(opacity: number): Promise<void> {
    this.config.opacity = Math.max(0.3, Math.min(1.0, opacity));
    await this.saveConfig();
  }

  async setBackgroundOpacity(opacity: number): Promise<void> {
    this.config.backgroundOpacity = Math.max(0.3, Math.min(1.0, opacity));
    await this.saveConfig();
  }

  async setBlurEnabled(enabled: boolean): Promise<void> {
    this.config.blurEnabled = enabled;
    await this.saveConfig();
  }

  async setAutoHide(enabled: boolean): Promise<void> {
    this.config.autoHide = enabled;
    await this.saveConfig();
  }

  async setAutoHideDelay(delay: number): Promise<void> {
    this.config.autoHideDelay = Math.max(1000, Math.min(10000, delay));
    await this.saveConfig();
  }

  async setAnimationEnabled(enabled: boolean): Promise<void> {
    this.config.animationEnabled = enabled;
    await this.saveConfig();
  }

  resetToDefault(): void {
    this.config = { ...DEFAULT_CONFIG };
    this.saveConfig();
  }

  addConfigChangeListener(listener: (config: FloatingNavConfig) => void): void {
    this.configChangeListeners.push(listener);
  }

  removeConfigChangeListener(listener: (config: FloatingNavConfig) => void): void {
    const index = this.configChangeListeners.indexOf(listener);
    if (index > -1) {
      this.configChangeListeners.splice(index, 1);
    }
  }

  private notifyConfigChange(): void {
    this.configChangeListeners.forEach(listener => {
      try {
        listener(this.getConfig());
      } catch (error) {
        Logger.error('FloatingNavManager', `通知配置变更失败: ${error}`);
      }
    });
  }

  getPositionStyle(screenWidth: number, screenHeight: number, safeAreaBottom: number): {
    x: number | string;
    y: number | string;
  } {
    const { position, width } = this.config;
    const bottomOffset = safeAreaBottom + 20;

    switch (position) {
      case 'left':
        return { x: 20, y: '50%' };
      case 'center':
        return { x: '50%', y: '50%' };
      case 'right':
        return { x: screenWidth - width - 20, y: '50%' };
      case 'bottom-left':
        return { x: 20, y: screenHeight - bottomOffset - this.config.height };
      case 'bottom-center':
        return { x: '50%', y: screenHeight - bottomOffset - this.config.height };
      case 'bottom-right':
        return { x: screenWidth - width - 20, y: screenHeight - bottomOffset - this.config.height };
      default:
        return { x: '50%', y: screenHeight - bottomOffset - this.config.height };
    }
  }
}

export const floatingNavManager = FloatingNavManager.getInstance();
