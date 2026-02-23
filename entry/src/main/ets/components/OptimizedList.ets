/**
 * OptimizedListComponents - 优化的列表渲染组件
 * 使用 LazyForEach 和 cachedCount 提升性能
 */

import { Book } from '../models/Book';
import { BookSource } from '../models/BookSource';
import { DesignSystem } from '../common/DesignSystem';
import { BookCoverImage } from './BookCoverImage';

/**
 * 书籍列表数据源 - 用于 LazyForEach
 */
export class BookListDataSource implements IDataSource {
  private books: Book[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(books: Book[] = []) {
    this.books = books;
  }

  totalCount(): number {
    return this.books.length;
  }

  getData(index: number): Book {
    return this.books[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 更新数据
  updateData(books: Book[]): void {
    this.books = books;
    this.notifyDataReload();
  }

  // 添加数据
  appendData(books: Book[]): void {
    const startIndex = this.books.length;
    this.books = this.books.concat(books);
    this.notifyDataAdd(startIndex);
  }

  // 清空数据
  clear(): void {
    this.books = [];
    this.notifyDataReload();
  }

  private notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  private notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  private notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  private notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }
}

/**
 * 书源列表数据源 - 用于 LazyForEach
 */
export class BookSourceListDataSource implements IDataSource {
  private sources: BookSource[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(sources: BookSource[] = []) {
    this.sources = sources;
  }

  totalCount(): number {
    return this.sources.length;
  }

  getData(index: number): BookSource {
    return this.sources[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  updateData(sources: BookSource[]): void {
    this.sources = sources;
    this.notifyDataReload();
  }

  clear(): void {
    this.sources = [];
    this.notifyDataReload();
  }

  private notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }
}

/**
 * 优化的书籍列表项组件
 */
@ComponentV2
export struct OptimizedBookListItem {
  @Param book: Book = {} as Book;
  @Param isLightMode: boolean = true;
  @Require @Param onItemClick?: (book: Book) => void;

  build() {
    Row() {
      BookCoverImage({
        src: this.book.cover || $r('app.media.startIcon'),
        bookWidth: 60,
        bookHeight: 80,
        radius: 6
      })

      Column() {
        Text(this.book.name)
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(600)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 4 })

        if (this.book.author) {
          Text(this.book.author)
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 8 })
        }

        Row() {
          Progress({
            value: this.book.readProgress || 0,
            total: 100,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(4)
            .color(DesignSystem.getPrimaryColor(this.isLightMode))
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .margin({ right: 10 })

          Text(`${this.book.readProgress || 0}%`)
            .fontSize(11)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .width(35)
            .textAlign(TextAlign.End)
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(15)
    .borderRadius(12)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick(this.book);
      }
    })
  }
}

/**
 * 优化的搜索结果列表项组件
 */
@ComponentV2
export struct OptimizedSearchResultItem {
  @Param book: Book = {} as Book;
  @Param isLightMode: boolean = true;
  @Require @Param onItemClick?: (book: Book) => void;

  build() {
    Row() {
      BookCoverImage({
        src: this.book.cover || $r('app.media.startIcon'),
        bookWidth: 60,
        bookHeight: 80,
        radius: 4
      })

      Column() {
        Text(this.book.name)
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(500)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 4 })

        if (this.book.author) {
          Text(this.book.author)
            .fontSize(13)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 4 })
        }

        if (this.book.intro) {
          Text(this.book.intro)
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 4 })
        }

        if (this.book.bookSourceName) {
          Text(this.book.bookSourceName)
            .fontSize(11)
            .fontColor(DesignSystem.getPrimaryColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick(this.book);
      }
    })
  }
}

/**
 * 优化的书源列表项组件
 */
@ComponentV2
export struct OptimizedBookSourceItem {
  @Param source: BookSource = {} as BookSource;
  @Param isLightMode: boolean = true;
  @Require @Param onItemClick?: (source: BookSource) => void;

  build() {
    Row() {
      Column() {
        Text(this.source.name)
          .fontSize(16)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(500)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.source.url) {
          Text(this.source.url)
            .fontSize(12)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.source.enabled })
        .selectedColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .onChange((isOn: boolean) => {
          // 处理开关状态变化
          this.source.enabled = isOn;
        })
    }
    .width('100%')
    .padding(15)
    .borderRadius(12)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick(this.source);
      }
    })
  }
}

/**
 * 列表渲染配置
 */
export interface ListRenderConfig {
  cachedCount: number;
  itemSpacing: number;
  listPadding: number;
}

/**
 * 设备性能等级
 */
export enum DevicePerformanceLevel {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high'
}

/**
 * 设备性能检测器
 */
export class DevicePerformanceDetector {
  private static instance: DevicePerformanceDetector;
  private performanceLevel: DevicePerformanceLevel = DevicePerformanceLevel.MEDIUM;
  private cpuCores: number = 4;
  private totalMemory: number = 2048;
  private isDetected: boolean = false;

  private constructor() {}

  public static getInstance(): DevicePerformanceDetector {
    if (!DevicePerformanceDetector.instance) {
      DevicePerformanceDetector.instance = new DevicePerformanceDetector();
    }
    return DevicePerformanceDetector.instance;
  }

  public async detectDevicePerformance(): Promise<DevicePerformanceLevel> {
    if (this.isDetected) {
      return this.performanceLevel;
    }

    try {
      this.cpuCores = this.getCPUCoreCount();
      this.totalMemory = this.getEstimatedMemory();
      
      if (this.cpuCores <= 4 || this.totalMemory <= 2048) {
        this.performanceLevel = DevicePerformanceLevel.LOW;
      } else if (this.cpuCores >= 8 && this.totalMemory >= 6144) {
        this.performanceLevel = DevicePerformanceLevel.HIGH;
      } else {
        this.performanceLevel = DevicePerformanceLevel.MEDIUM;
      }
    } catch (error) {
      this.performanceLevel = DevicePerformanceLevel.MEDIUM;
    }

    this.isDetected = true;
    return this.performanceLevel;
  }

  private getCPUCoreCount(): number {
    try {
      const hardwareInfo = AppStorage.get('cpuCoreCount') as number;
      return hardwareInfo || 4;
    } catch {
      return 4;
    }
  }

  private getEstimatedMemory(): number {
    try {
      const memoryInfo = AppStorage.get('totalMemoryMB') as number;
      return memoryInfo || 4096;
    } catch {
      return 4096;
    }
  }

  public getPerformanceLevel(): DevicePerformanceLevel {
    return this.performanceLevel;
  }

  public getCachedCountForPerformance(): number {
    switch (this.performanceLevel) {
      case DevicePerformanceLevel.LOW:
        return 3;
      case DevicePerformanceLevel.HIGH:
        return 10;
      case DevicePerformanceLevel.MEDIUM:
      default:
        return 5;
    }
  }

  public getCpuCores(): number {
    return this.cpuCores;
  }

  public getTotalMemory(): number {
    return this.totalMemory;
  }
}

/**
 * 动态列表渲染配置生成器
 */
export function getDynamicListConfig(): ListRenderConfig {
  const detector = DevicePerformanceDetector.getInstance();
  const cachedCount = detector.getCachedCountForPerformance();
  
  return {
    cachedCount: cachedCount,
    itemSpacing: 12,
    listPadding: 20
  };
}

/**
 * 默认列表渲染配置（使用动态缓存）
 */
export function getDefaultListConfig(): ListRenderConfig {
  return getDynamicListConfig();
}

export const DEFAULT_LIST_CONFIG: ListRenderConfig = {
  cachedCount: 5,
  itemSpacing: 12,
  listPadding: 20
};

/**
 * 大数据量列表渲染配置
 */
export function getLargeListConfig(): ListRenderConfig {
  const detector = DevicePerformanceDetector.getInstance();
  const baseCachedCount = detector.getCachedCountForPerformance();
  return {
    cachedCount: Math.min(baseCachedCount + 5, 15),
    itemSpacing: 8,
    listPadding: 16
  };
}

export const LARGE_LIST_CONFIG: ListRenderConfig = {
  cachedCount: 10,
  itemSpacing: 8,
  listPadding: 16
};

/**
 * 紧凑列表渲染配置
 */
export function getCompactListConfig(): ListRenderConfig {
  const detector = DevicePerformanceDetector.getInstance();
  const baseCachedCount = detector.getCachedCountForPerformance();
  return {
    cachedCount: Math.max(baseCachedCount - 2, 2),
    itemSpacing: 6,
    listPadding: 12
  };
}

export const COMPACT_LIST_CONFIG: ListRenderConfig = {
  cachedCount: 3,
  itemSpacing: 6,
  listPadding: 12
};