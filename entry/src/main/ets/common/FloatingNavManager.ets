import { Logger } from '../utils/Logger';

export interface FloatingNavConfig {
  enabled: boolean;
  position: FloatingNavPosition;
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

export type FloatingNavPosition = 'left' | 'center' | 'right' | 'bottom-left' | 'bottom-center' | 'bottom-right';

export interface PositionStyle {
  x: number | string;
  y: number | string;
}

function createDefaultConfig(): FloatingNavConfig {
  return {
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
}

function cloneConfig(config: FloatingNavConfig): FloatingNavConfig {
  return {
    enabled: config.enabled,
    position: config.position,
    width: config.width,
    height: config.height,
    borderRadius: config.borderRadius,
    opacity: config.opacity,
    backgroundOpacity: config.backgroundOpacity,
    blurEnabled: config.blurEnabled,
    autoHide: config.autoHide,
    autoHideDelay: config.autoHideDelay,
    animationEnabled: config.animationEnabled
  };
}

const STORAGE_KEY = 'floating_nav_config';

export class FloatingNavManager {
  private static instance: FloatingNavManager;
  private config: FloatingNavConfig = createDefaultConfig();
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
        const loadedConfig = JSON.parse(configStr) as FloatingNavConfig;
        this.config = this.mergeWithDefaults(loadedConfig);
        Logger.info('FloatingNavManager', '配置加载成功');
      }
    } catch (error) {
      Logger.error('FloatingNavManager', `加载配置失败: ${error}`);
      this.config = createDefaultConfig();
    }
  }

  private mergeWithDefaults(loaded: FloatingNavConfig): FloatingNavConfig {
    const result = createDefaultConfig();
    if (loaded.enabled !== undefined) result.enabled = loaded.enabled;
    if (loaded.position !== undefined) result.position = loaded.position;
    if (loaded.width !== undefined) result.width = loaded.width;
    if (loaded.height !== undefined) result.height = loaded.height;
    if (loaded.borderRadius !== undefined) result.borderRadius = loaded.borderRadius;
    if (loaded.opacity !== undefined) result.opacity = loaded.opacity;
    if (loaded.backgroundOpacity !== undefined) result.backgroundOpacity = loaded.backgroundOpacity;
    if (loaded.blurEnabled !== undefined) result.blurEnabled = loaded.blurEnabled;
    if (loaded.autoHide !== undefined) result.autoHide = loaded.autoHide;
    if (loaded.autoHideDelay !== undefined) result.autoHideDelay = loaded.autoHideDelay;
    if (loaded.animationEnabled !== undefined) result.animationEnabled = loaded.animationEnabled;
    return result;
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
    return cloneConfig(this.config);
  }

  async updateConfig(updates: Partial<FloatingNavConfig>): Promise<void> {
    if (updates.enabled !== undefined) this.config.enabled = updates.enabled;
    if (updates.position !== undefined) this.config.position = updates.position;
    if (updates.width !== undefined) this.config.width = updates.width;
    if (updates.height !== undefined) this.config.height = updates.height;
    if (updates.borderRadius !== undefined) this.config.borderRadius = updates.borderRadius;
    if (updates.opacity !== undefined) this.config.opacity = updates.opacity;
    if (updates.backgroundOpacity !== undefined) this.config.backgroundOpacity = updates.backgroundOpacity;
    if (updates.blurEnabled !== undefined) this.config.blurEnabled = updates.blurEnabled;
    if (updates.autoHide !== undefined) this.config.autoHide = updates.autoHide;
    if (updates.autoHideDelay !== undefined) this.config.autoHideDelay = updates.autoHideDelay;
    if (updates.animationEnabled !== undefined) this.config.animationEnabled = updates.animationEnabled;
    await this.saveConfig();
  }

  async setEnabled(enabled: boolean): Promise<void> {
    this.config.enabled = enabled;
    await this.saveConfig();
  }

  async setPosition(position: FloatingNavPosition): Promise<void> {
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
    this.config = createDefaultConfig();
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
    for (const listener of this.configChangeListeners) {
      try {
        listener(this.getConfig());
      } catch (error) {
        Logger.error('FloatingNavManager', `通知配置变更失败: ${error}`);
      }
    }
  }

  getPositionStyle(screenWidth: number, screenHeight: number, safeAreaBottom: number): PositionStyle {
    const position = this.config.position;
    const width = this.config.width;
    const height = this.config.height;
    const bottomOffset = safeAreaBottom + 20;
    const result: PositionStyle = { x: '50%', y: screenHeight - bottomOffset - height };

    if (position === 'left') {
      result.x = 20;
      result.y = '50%';
    } else if (position === 'center') {
      result.x = '50%';
      result.y = '50%';
    } else if (position === 'right') {
      result.x = screenWidth - width - 20;
      result.y = '50%';
    } else if (position === 'bottom-left') {
      result.x = 20;
      result.y = screenHeight - bottomOffset - height;
    } else if (position === 'bottom-center') {
      result.x = '50%';
      result.y = screenHeight - bottomOffset - height;
    } else if (position === 'bottom-right') {
      result.x = screenWidth - width - 20;
      result.y = screenHeight - bottomOffset - height;
    }

    return result;
  }
}

export const floatingNavManager = FloatingNavManager.getInstance();
