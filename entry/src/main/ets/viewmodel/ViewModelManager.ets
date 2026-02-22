import { BookViewModel } from './BookViewModel';
import { BookSourceViewModel } from './BookSourceViewModel';
import { ChapterViewModel } from './ChapterViewModel';
import { BookmarkViewModel } from './BookmarkViewModel';
import { CategoryViewModel } from './CategoryViewModel';
import { ReadConfigViewModel } from './ReadConfigViewModel';
import common from '@ohos.app.ability.common';

export class ViewModelManager {
  private static instance: ViewModelManager | null = null;
  
  private bookViewModel: BookViewModel | null = null;
  private bookSourceViewModel: BookSourceViewModel | null = null;
  private chapterViewModel: ChapterViewModel | null = null;
  private bookmarkViewModel: BookmarkViewModel | null = null;
  private categoryViewModel: CategoryViewModel | null = null;
  private readConfigViewModel: ReadConfigViewModel | null = null;
  
  private context: common.UIAbilityContext | null = null;
  
  private constructor() {}
  
  static getInstance(): ViewModelManager {
    if (ViewModelManager.instance === null) {
      ViewModelManager.instance = new ViewModelManager();
    }
    return ViewModelManager.instance;
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
    this.bookViewModel = null;
    this.bookSourceViewModel = null;
    this.chapterViewModel = null;
    this.bookmarkViewModel = null;
    this.categoryViewModel = null;
    this.readConfigViewModel = null;
  }
}

export const viewModelManager = ViewModelManager.getInstance();
