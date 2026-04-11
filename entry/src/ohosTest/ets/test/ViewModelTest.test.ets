import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { ReadConfigViewModel } from '../../../main/ets/viewmodel/ReadConfigViewModel';
import { DEFAULT_READ_CONFIG } from '../../../main/ets/models/ReadConfig';
import { BookmarkViewModel } from '../../../main/ets/viewmodel/BookmarkViewModel';

export default function ViewModelTest() {
  describe('ReadConfigViewModel', () => {
    let viewModel: ReadConfigViewModel;

    beforeEach(() => {
      viewModel = new ReadConfigViewModel();
    });

    it('should get default config', () => {
      const config = viewModel.getCurrentConfig();
      expect(config.fontSize).assertEqual(DEFAULT_READ_CONFIG.fontSize);
      expect(config.lineSpacing).assertEqual(DEFAULT_READ_CONFIG.lineSpacing);
    });

    it('should update font size', async () => {
      await viewModel.updateFontSize(20);
      const config = viewModel.getCurrentConfig();
      expect(config.fontSize).assertEqual(20);
    });

    it('should update line spacing', async () => {
      await viewModel.updateLineSpacing(2.0);
      const config = viewModel.getCurrentConfig();
      expect(config.lineSpacing).assertEqual(2.0);
    });

    it('should toggle night mode', async () => {
      await viewModel.toggleNightMode(true);
      const config = viewModel.getCurrentConfig();
      expect(config.isNightMode).assertTrue();
    });
  });

  describe('BookmarkViewModel', () => {
    let viewModel: BookmarkViewModel;

    beforeEach(() => {
      viewModel = new BookmarkViewModel();
      viewModel.setDeviceId('test-device');
    });

    it('should add bookmark', async () => {
      const bookmark = await viewModel.addBookmark(
        'book-001',
        'chapter-001',
        '第一章',
        '测试内容'
      );
      expect(bookmark.id.length).assertEqual(36);
      expect(bookmark.bookId).assertEqual('book-001');
      expect(bookmark.chapterId).assertEqual('chapter-001');
    });
  });
}
