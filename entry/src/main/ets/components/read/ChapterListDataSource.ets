import { Chapter } from '../../models/Book';

export class ChapterListDataSource implements IDataSource {
  private chapters: Chapter[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(chapters: Chapter[] = []) {
    this.chapters = chapters;
  }

  totalCount(): number {
    return this.chapters.length;
  }

  getData(index: number): Chapter {
    return this.chapters[index];
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

  getChapters(): Chapter[] {
    return this.chapters;
  }

  updateData(chapters: Chapter[]): void {
    this.chapters = chapters;
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  clear(): void {
    this.chapters = [];
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }
}
