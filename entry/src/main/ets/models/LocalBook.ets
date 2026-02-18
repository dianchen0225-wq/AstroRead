import { Book } from './Book';
import { Chapter } from './Book';

export interface LocalBook extends Book {
  filePath: string;
  fileType: 'txt' | 'epub';
  fileSize: number;
  encoding?: string;
  chapters?: LocalChapter[];
}

export interface LocalChapter extends Chapter {
  content?: string;
  startIndex: number;
  endIndex: number;
}

export interface LocalBookMetadata {
  title: string;
  author?: string;
  cover?: string;
  description?: string;
  language?: string;
  publisher?: string;
  publishDate?: string;
}

export interface TxtParseResult {
  book: LocalBook;
  chapters: LocalChapter[];
}

export interface EpubParseResult {
  book: LocalBook;
  chapters: LocalChapter[];
  resources: Map<string, ArrayBuffer>;
}
