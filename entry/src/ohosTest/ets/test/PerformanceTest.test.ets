import { describe, it, expect } from '@ohos/hypium';
import { ReadConfigViewModel } from '../../../main/ets/viewmodel/ReadConfigViewModel';
import { BookmarkViewModel } from '../../../main/ets/viewmodel/BookmarkViewModel';

export default function PerformanceTest() {
  describe('Performance', () => {
    it('should update settings efficiently', () => {
      const viewModel = new ReadConfigViewModel();
      const startTime = Date.now();
      viewModel.getCurrentConfig().fontSize = 20;
      const elapsed = Date.now() - startTime;
      expect(elapsed).assertLess(10);
    });

    it('should add bookmark efficiently', async () => {
      const viewModel = new BookmarkViewModel();
      const startTime = Date.now();
      await viewModel.addBookmark('book-001', 'chapter-001', '第一章', '测试内容');
      const elapsed = Date.now() - startTime;
      expect(elapsed).assertLess(1000);
    });

    it('should get bookmarks efficiently', async () => {
      const viewModel = new BookmarkViewModel();
      const startTime = Date.now();
      await viewModel.getBookmarksByBookId('book-001');
      const elapsed = Date.now() - startTime;
      expect(elapsed).assertLess(500);
    });
  });
}
