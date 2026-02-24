/**
 * ServiceContainer - 依赖注入容器
 * 解决模块间耦合问题，支持服务注册、解析和生命周期管理
 */

export enum ServiceLifetime {
  SINGLETON = 'singleton',
  TRANSIENT = 'transient',
  SCOPED = 'scoped'
}

export interface ServiceDescriptor<T = object> {
  token: string;
  factory: (container: ServiceContainer) => T;
  lifetime: ServiceLifetime;
  instance?: T;
}

export interface ServiceRegistrationOptions {
  lifetime?: ServiceLifetime;
  asDefault?: boolean;
}

type FactoryFunction<T> = (container: ServiceContainer) => T;

/**
 * 服务容器 - 实现依赖注入
 */
export class ServiceContainer {
  private services: Map<string, ServiceDescriptor> = new Map();
  private singletons: Map<string, object> = new Map();
  private scopedInstances: Map<string, object> = new Map();
  private parent?: ServiceContainer;
  private isDisposed: boolean = false;

  constructor(parent?: ServiceContainer) {
    this.parent = parent;
  }

  /**
   * 注册单例服务
   */
  registerSingleton<T>(token: string, factory: FactoryFunction<T>): ServiceContainer {
    this.validateNotDisposed();
    this.services.set(token, {
      token,
      factory: factory as FactoryFunction<object>,
      lifetime: ServiceLifetime.SINGLETON
    });
    return this;
  }

  /**
   * 注册瞬态服务（每次请求创建新实例）
   */
  registerTransient<T>(token: string, factory: FactoryFunction<T>): ServiceContainer {
    this.validateNotDisposed();
    this.services.set(token, {
      token,
      factory: factory as FactoryFunction<object>,
      lifetime: ServiceLifetime.TRANSIENT
    });
    return this;
  }

  /**
   * 注册作用域服务
   */
  registerScoped<T>(token: string, factory: FactoryFunction<T>): ServiceContainer {
    this.validateNotDisposed();
    this.services.set(token, {
      token,
      factory: factory as FactoryFunction<object>,
      lifetime: ServiceLifetime.SCOPED
    });
    return this;
  }

  /**
   * 注册实例（直接使用已有实例）
   */
  registerInstance<T>(token: string, instance: T): ServiceContainer {
    this.validateNotDisposed();
    this.singletons.set(token, instance as object);
    return this;
  }

  /**
   * 解析服务
   */
  resolve<T>(token: string): T {
    this.validateNotDisposed();

    // 1. 检查单例缓存
    const singletonInstance = this.singletons.get(token);
    if (singletonInstance !== undefined) {
      return singletonInstance as T;
    }

    // 2. 检查作用域缓存
    const scopedInstance = this.scopedInstances.get(token);
    if (scopedInstance !== undefined) {
      return scopedInstance as T;
    }

    // 3. 获取服务描述符
    const descriptor = this.services.get(token);
    if (!descriptor) {
      // 尝试从父容器解析
      if (this.parent) {
        return this.parent.resolve<T>(token);
      }
      throw new Error(`Service not found: ${token}`);
    }

    // 4. 创建实例
    const instance = descriptor.factory(this);

    // 5. 根据生命周期缓存实例
    switch (descriptor.lifetime) {
      case ServiceLifetime.SINGLETON:
        this.singletons.set(token, instance);
        break;
      case ServiceLifetime.SCOPED:
        this.scopedInstances.set(token, instance);
        break;
      // TRANSIENT 不缓存
    }

    return instance as T;
  }

  /**
   * 尝试解析服务（不抛出异常）
   */
  tryResolve<T>(token: string): T | null {
    try {
      return this.resolve<T>(token);
    } catch {
      return null;
    }
  }

  /**
   * 检查服务是否已注册
   */
  isRegistered(token: string): boolean {
    if (this.services.has(token) || this.singletons.has(token)) {
      return true;
    }
    if (this.parent) {
      return this.parent.isRegistered(token);
    }
    return false;
  }

  /**
   * 创建作用域
   */
  createScope(): ServiceContainer {
    this.validateNotDisposed();
    return new ServiceContainer(this);
  }

  /**
   * 释放资源
   */
  dispose(): void {
    if (this.isDisposed) return;

    // 释放作用域实例
    this.scopedInstances.forEach((instance: object) => {
      if (typeof (instance as { dispose?: () => void }).dispose === 'function') {
        (instance as { dispose: () => void }).dispose();
      }
    });
    this.scopedInstances.clear();

    // 标记为已释放
    this.isDisposed = true;
  }

  /**
   * 清除所有服务
   */
  clear(): void {
    this.dispose();
    this.services.clear();
    this.singletons.clear();
  }

  private validateNotDisposed(): void {
    if (this.isDisposed) {
      throw new Error('ServiceContainer has been disposed');
    }
  }
}

/**
 * 服务令牌 - 类型安全的服务标识
 */
export class ServiceToken<T> {
  constructor(public readonly name: string) {}

  toString(): string {
    return this.name;
  }
}

/**
 * 全局服务容器实例
 */
let globalContainer: ServiceContainer | null = null;

/**
 * 获取全局服务容器
 */
export function getGlobalContainer(): ServiceContainer {
  if (!globalContainer) {
    globalContainer = new ServiceContainer();
  }
  return globalContainer;
}

/**
 * 重置全局服务容器（用于测试）
 */
export function resetGlobalContainer(): void {
  if (globalContainer) {
    globalContainer.dispose();
    globalContainer = null;
  }
}

/**
 * 服务令牌常量
 */
export const ServiceTokens = {
  // 网络服务
  NETWORK_MANAGER: 'NetworkManager',
  HTTP_CLIENT: 'HttpClient',
  COOKIE_MANAGER: 'CookieManager',
  REQUEST_THROTTLER: 'RequestThrottler',

  // 数据库服务
  DATABASE_MANAGER: 'DatabaseManager',
  BOOK_REPOSITORY: 'BookRepository',
  BOOK_SOURCE_REPOSITORY: 'BookSourceRepository',
  CHAPTER_REPOSITORY: 'ChapterRepository',
  BOOKMARK_REPOSITORY: 'BookmarkRepository',

  // 书源服务
  BOOK_SOURCE_MANAGER: 'BookSourceManager',
  BOOK_SOURCE_SEARCH_ENGINE: 'BookSourceSearchEngine',
  BOOK_SOURCE_PARSER: 'BookSourceParser',
  BOOK_SOURCE_DEBUGGER: 'BookSourceDebugger',

  // 解析服务
  HTML_PARSER: 'HTMLParser',
  CSS_SELECTOR_PARSER: 'CssSelectorParser',
  CONTENT_PARSER: 'ContentParser',
  PARSER_CACHE: 'ParseCache',

  // JS 引擎
  JS_ENGINE: 'JSEngine',
  ENHANCED_JS_ENGINE: 'EnhancedJSEngine',
  ASTRO_READ_JS_RUNTIME: 'AstroReadJSRuntime',

  // 工具服务
  LOGGER: 'Logger',
  ERROR_HANDLER: 'ErrorHandler',
  PERFORMANCE_MONITOR: 'PerformanceMonitor',
  FILE_MANAGER: 'FileManager',

  // 配置服务
  NETWORK_CONFIG: 'NetworkConfig',
  APP_CONFIG: 'AppConfig'
} as const;

export default ServiceContainer;
