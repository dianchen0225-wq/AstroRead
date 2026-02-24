/**
 * ServiceContainer - 依赖注入容器
 * 管理服务实例的生命周期和依赖关系
 */

import { ISearchEngine, ISearchEngineFactory } from '../interfaces/ISearchEngine';
import { BookSourceSearchEngine } from '../../utils/BookSourceSearchEngine';
import { BookSourceManager } from '../../utils/BookSourceManager';
import { Logger } from '../../utils/Logger';

/**
 * 服务生命周期类型
 */
export enum ServiceLifetime {
  /** 单例 - 整个应用生命周期只有一个实例 */
  Singleton = 'singleton',
  /** 作用域 - 每个作用域一个实例 */
  Scoped = 'scoped',
  /** 瞬态 - 每次请求创建新实例 */
  Transient = 'transient'
}

/**
 * 服务注册信息
 */
interface ServiceRegistration<T> {
  lifetime: ServiceLifetime;
  factory: () => T;
  instance?: T;
}

/**
 * 依赖注入容器
 */
export class ServiceContainer {
  private static instance: ServiceContainer | null = null;
  private services: Map<string, ServiceRegistration<unknown>> = new Map();
  private readonly TAG = 'ServiceContainer';

  private constructor() {
    this.registerDefaultServices();
  }

  static getInstance(): ServiceContainer {
    if (!ServiceContainer.instance) {
      ServiceContainer.instance = new ServiceContainer();
    }
    return ServiceContainer.instance;
  }

  /**
   * 注册默认服务
   */
  private registerDefaultServices(): void {
    // 注册搜索引擎为单例
    this.register<ISearchEngine>('searchEngine', ServiceLifetime.Singleton, () => {
      return BookSourceSearchEngine.getInstance();
    });

    // 注册书源管理器为单例
    this.register<BookSourceManager>('bookSourceManager', ServiceLifetime.Singleton, () => {
      const searchEngine = this.resolve<ISearchEngine>('searchEngine');
      return BookSourceManager.getInstanceWithEngine(searchEngine);
    });
  }

  /**
   * 注册服务
   * @param key 服务标识
   * @param lifetime 生命周期
   * @param factory 工厂函数
   */
  register<T>(key: string, lifetime: ServiceLifetime, factory: () => T): void {
    this.services.set(key, {
      lifetime,
      factory
    });
    Logger.debug(this.TAG, `注册服务: ${key}, 生命周期: ${lifetime}`);
  }

  /**
   * 注册单例服务
   * @param key 服务标识
   * @param factory 工厂函数
   */
  registerSingleton<T>(key: string, factory: () => T): void {
    this.register<T>(key, ServiceLifetime.Singleton, factory);
  }

  /**
   * 注册瞬态服务
   * @param key 服务标识
   * @param factory 工厂函数
   */
  registerTransient<T>(key: string, factory: () => T): void {
    this.register<T>(key, ServiceLifetime.Transient, factory);
  }

  /**
   * 解析服务
   * @param key 服务标识
   * @returns 服务实例
   */
  resolve<T>(key: string): T {
    const registration = this.services.get(key) as ServiceRegistration<T>;
    
    if (!registration) {
      throw new Error(`服务未注册: ${key}`);
    }

    switch (registration.lifetime) {
      case ServiceLifetime.Singleton:
        if (!registration.instance) {
          registration.instance = registration.factory();
          Logger.debug(this.TAG, `创建单例服务: ${key}`);
        }
        return registration.instance;

      case ServiceLifetime.Transient:
        Logger.debug(this.TAG, `创建瞬态服务: ${key}`);
        return registration.factory();

      case ServiceLifetime.Scoped:
        // 作用域服务在当前简单实现中按瞬态处理
        Logger.debug(this.TAG, `创建作用域服务: ${key}`);
        return registration.factory();

      default:
        throw new Error(`未知的服务生命周期: ${registration.lifetime}`);
    }
  }

  /**
   * 检查服务是否已注册
   * @param key 服务标识
   */
  isRegistered(key: string): boolean {
    return this.services.has(key);
  }

  /**
   * 移除服务注册
   * @param key 服务标识
   */
  unregister(key: string): void {
    this.services.delete(key);
    Logger.debug(this.TAG, `注销服务: ${key}`);
  }

  /**
   * 清空所有服务
   */
  clear(): void {
    this.services.clear();
    Logger.debug(this.TAG, '清空所有服务');
  }

  /**
   * 获取所有已注册的服务键
   */
  getRegisteredKeys(): string[] {
    return Array.from(this.services.keys());
  }
}

/**
 * 全局服务容器实例
 */
export const serviceContainer = ServiceContainer.getInstance();

/**
 * 搜索引擎工厂实现
 */
export class SearchEngineFactory implements ISearchEngineFactory {
  private static instance: SearchEngineFactory | null = null;

  static getInstance(): SearchEngineFactory {
    if (!SearchEngineFactory.instance) {
      SearchEngineFactory.instance = new SearchEngineFactory();
    }
    return SearchEngineFactory.instance;
  }

  createSearchEngine(): ISearchEngine {
    return BookSourceSearchEngine.getInstance();
  }

  getDefaultEngine(): ISearchEngine {
    return serviceContainer.resolve<ISearchEngine>('searchEngine');
  }
}
