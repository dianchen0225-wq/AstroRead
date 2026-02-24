import { BookViewModel } from './BookViewModel';
import { BookSourceViewModel } from './BookSourceViewModel';
import { ChapterViewModel } from './ChapterViewModel';
import { BookmarkViewModel } from './BookmarkViewModel';
import { CategoryViewModel } from './CategoryViewModel';
import { ReadConfigViewModel } from './ReadConfigViewModel';
import { common } from '@kit.AbilityKit';

export class ViewModelManager {
  private static instance: ViewModelManager | null = null;
  private static isDestroyed: boolean = false;
  
  private bookViewModel: BookViewModel | null = null;
  private bookSourceViewModel: BookSourceViewModel | null = null;
  private chapterViewModel: ChapterViewModel | null = null;
  private bookmarkViewModel: BookmarkViewModel | null = null;
  private categoryViewModel: CategoryViewModel | null = null;
  private readConfigViewModel: ReadConfigViewModel | null = null;
  
  private context: common.UIAbilityContext | null = null;
  
  private constructor() {}
  
  static getInstance(): ViewModelManager {
    if (ViewModelManager.instance === null || ViewModelManager.isDestroyed) {
      ViewModelManager.instance = new ViewModelManager();
      ViewModelManager.isDestroyed = false;
    }
    return ViewModelManager.instance;
  }
  
  static destroyInstance(): void {
    if (ViewModelManager.instance !== null) {
      ViewModelManager.instance.clearAll();
      ViewModelManager.instance.context = null;
      ViewModelManager.isDestroyed = true;
      ViewModelManager.instance = null;
    }
  }
  
  static isInstanceAlive(): boolean {
    return ViewModelManager.instance !== null && !ViewModelManager.isDestroyed;
  }
  
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }
  
  getContext(): common.UIAbilityContext | null {
    return this.context;
  }
  
  getBookViewModel(): BookViewModel {
    if (this.bookViewModel === null) {
      this.bookViewModel = new BookViewModel();
      if (this.context) {
        this.bookViewModel.setContext(this.context);
      }
    }
    return this.bookViewModel;
  }
  
  getBookSourceViewModel(): BookSourceViewModel {
    if (this.bookSourceViewModel === null) {
      this.bookSourceViewModel = BookSourceViewModel.getInstance();
      if (this.context) {
        this.bookSourceViewModel.setContext(this.context);
      }
    }
    return this.bookSourceViewModel;
  }
  
  getChapterViewModel(): ChapterViewModel {
    if (this.chapterViewModel === null) {
      this.chapterViewModel = new ChapterViewModel();
      if (this.context) {
        this.chapterViewModel.setContext(this.context);
      }
    }
    return this.chapterViewModel;
  }
  
  getBookmarkViewModel(): BookmarkViewModel {
    if (this.bookmarkViewModel === null) {
      this.bookmarkViewModel = new BookmarkViewModel();
    }
    return this.bookmarkViewModel;
  }
  
  getCategoryViewModel(): CategoryViewModel {
    if (this.categoryViewModel === null) {
      this.categoryViewModel = new CategoryViewModel();
    }
    return this.categoryViewModel;
  }
  
  getReadConfigViewModel(): ReadConfigViewModel {
    if (this.readConfigViewModel === null) {
      this.readConfigViewModel = new ReadConfigViewModel();
    }
    return this.readConfigViewModel;
  }
  
  clearAll(): void {
    // 调用各个 ViewModel 的销毁方法，防止内存泄漏
    if (this.bookViewModel !== null) {
      this.bookViewModel.destroy();
    }
    
    if (this.chapterViewModel !== null) {
      this.chapterViewModel.destroy();
    }
    
    this.bookViewModel = null;
    this.bookSourceViewModel = null;
    this.chapterViewModel = null;
    this.bookmarkViewModel = null;
    this.categoryViewModel = null;
    this.readConfigViewModel = null;
  }
}

export const viewModelManager = ViewModelManager.getInstance();
