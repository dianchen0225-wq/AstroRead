import { DesignSystem } from '../common/DesignSystem';
import { themeManager } from '../common/ThemeManager';
import { Book, SourceStatus } from '../models/Book';
import { purifyContent } from '../utils/ContentPurifier';

@ComponentV2
export struct BookCard {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  
  @Param book: Book | null = null;
  @Param showSourceStatus: boolean = false;
  @Param compact: boolean = false;
  @Param onCardClick: (book: Book) => void = () => {};
  @Param onAddToShelf: (book: Book) => void = () => {};
  
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  private getSourceStatusColor(): string {
    if (!this.book || !this.showSourceStatus) return 'transparent';
    switch (this.book.sourceStatus) {
      case SourceStatus.VALID:
        return DesignSystem.getSuccessColor(this.isLightMode);
      case SourceStatus.INVALID:
        return DesignSystem.getErrorColor(this.isLightMode);
      case SourceStatus.CHECKING:
        return DesignSystem.getWarningColor(this.isLightMode);
      default:
        return 'transparent';
    }
  }

  build() {
    Row() {
      if (this.book) {
        Stack() {
          if (this.book.cover) {
            Image(this.book.cover)
              .width(this.compact ? 50 : 60)
              .height(this.compact ? 70 : 80)
              .borderRadius(DesignSystem.BorderRadius.sm)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Text('📖')
                .fontSize(this.compact ? 20 : 24)
            }
            .width(this.compact ? 50 : 60)
            .height(this.compact ? 70 : 80)
            .borderRadius(DesignSystem.BorderRadius.sm)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .justifyContent(FlexAlign.Center)
          }
          
          if (this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID) {
            Column() {
              Text('无书源')
                .fontSize(8)
                .fontColor('#FFFFFF')
                .fontWeight(DesignSystem.Typography.weight.medium)
            }
            .width(this.compact ? 50 : 60)
            .height(this.compact ? 70 : 80)
            .borderRadius(DesignSystem.BorderRadius.sm)
            .backgroundColor('rgba(244, 67, 54, 0.75)')
            .justifyContent(FlexAlign.Center)
          } else if (this.showSourceStatus && this.book.sourceStatus === SourceStatus.CHECKING) {
            Column() {
              LoadingProgress()
                .width(16)
                .height(16)
                .color('#FFFFFF')
            }
            .width(this.compact ? 50 : 60)
            .height(this.compact ? 70 : 80)
            .borderRadius(DesignSystem.BorderRadius.sm)
            .backgroundColor('rgba(158, 158, 158, 0.75)')
            .justifyContent(FlexAlign.Center)
          }
        }

        Column() {
          Row() {
            Text(this.book.name)
              .fontSize(this.compact ? DesignSystem.Typography.size.sm : DesignSystem.Typography.size.base)
              .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
              .fontWeight(DesignSystem.Typography.weight.medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            
            if (this.showSourceStatus && this.book.sourceStatus === SourceStatus.VALID) {
              Text('✓')
                .fontSize(DesignSystem.Typography.size.sm)
                .fontColor(DesignSystem.getSuccessColor(this.isLightMode))
                .margin({ left: DesignSystem.Spacing.xs })
            } else if (this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID) {
              Text('✗')
                .fontSize(DesignSystem.Typography.size.sm)
                .fontColor(DesignSystem.getErrorColor(this.isLightMode))
                .margin({ left: DesignSystem.Spacing.xs })
            }
          }
          .width('100%')

          if (this.book.author) {
            Text(this.book.author)
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
              .margin({ top: DesignSystem.Spacing.xs })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          if (!this.compact && this.book.intro) {
            Text(purifyContent(this.book.intro))
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
              .margin({ top: DesignSystem.Spacing.xs })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .lineHeight(DesignSystem.Typography.lineHeight.tight * DesignSystem.Typography.size.xs)
          }

          Row() {
            if (this.book.bookSourceName) {
              Text(this.book.bookSourceName)
                .fontSize(10)
                .fontColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            
            if (this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID) {
              Text(' (书源不存在)')
                .fontSize(10)
                .fontColor(DesignSystem.getErrorColor(this.isLightMode))
            }
          }
          .margin({ top: DesignSystem.Spacing.xs })
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: DesignSystem.Spacing.md })
        .justifyContent(FlexAlign.Start)

        if (!this.compact) {
          Column() {
            Button(this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID ? '不可用' : '加入书架')
              .fontSize(DesignSystem.Typography.size.xs)
              .fontColor(this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID ?
                DesignSystem.getTertiaryTextColor(this.isLightMode) : '#FFFFFF')
              .backgroundColor(this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID ?
                DesignSystem.getBorderColor(this.isLightMode) : DesignSystem.getPrimaryColor(this.isLightMode))
              .borderRadius(DesignSystem.BorderRadius.sm)
              .height(32)
              .padding({ left: DesignSystem.Spacing.sm, right: DesignSystem.Spacing.sm })
              .enabled(!this.showSourceStatus || this.book.sourceStatus !== SourceStatus.INVALID)
              .onClick(() => {
                if (this.book) {
                  this.onAddToShelf(this.book);
                }
              })
          }
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .padding(this.compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .shadow({
      radius: 2,
      color: this.isLightMode ? 'rgba(0,0,0,0.03)' : 'rgba(0,0,0,0.2)',
      offsetX: 0,
      offsetY: 1
    })
    .opacity(this.isPressed ? 0.9 : (this.showSourceStatus && this.book && this.book.sourceStatus === SourceStatus.INVALID ? 0.7 : 1))
    .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (this.book && (!this.showSourceStatus || this.book.sourceStatus !== SourceStatus.INVALID)) {
        this.onCardClick(this.book);
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }
}

@ComponentV2
export struct BookGridCard {
  @Local isLightMode: boolean = true;
  @Local isPressed: boolean = false;
  
  @Param book: Book | null = null;
  @Param showSourceStatus: boolean = false;
  @Param onCardClick: (book: Book) => void = () => {};
  
  private themeListener: (isDark: boolean) => void = (isDark: boolean) => {
    this.isLightMode = !isDark;
  };

  aboutToAppear(): void {
    this.isLightMode = themeManager.isLightTheme();
    themeManager.addListener(this.themeListener);
  }

  aboutToDisappear(): void {
    themeManager.removeListener(this.themeListener);
  }

  build() {
    Column() {
      if (this.book) {
        Stack() {
          if (this.book.cover) {
            Image(this.book.cover)
              .width('100%')
              .aspectRatio(0.75)
              .borderRadius(DesignSystem.BorderRadius.md)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Text('📖')
                .fontSize(32)
            }
            .width('100%')
            .aspectRatio(0.75)
            .borderRadius(DesignSystem.BorderRadius.md)
            .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
            .justifyContent(FlexAlign.Center)
          }
          
          if (this.showSourceStatus && this.book.sourceStatus === SourceStatus.INVALID) {
            Column() {
              Text('无书源')
                .fontSize(10)
                .fontColor('#FFFFFF')
                .fontWeight(DesignSystem.Typography.weight.medium)
            }
            .width('100%')
            .aspectRatio(0.75)
            .borderRadius(DesignSystem.BorderRadius.md)
            .backgroundColor('rgba(244, 67, 54, 0.75)')
            .justifyContent(FlexAlign.Center)
          }
        }

        Text(this.book.name)
          .width('100%')
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
          .fontWeight(DesignSystem.Typography.weight.medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: DesignSystem.Spacing.sm })

        if (this.book.author) {
          Text(this.book.author)
            .width('100%')
            .fontSize(DesignSystem.Typography.size.xs)
            .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
    }
    .width('100%')
    .padding(DesignSystem.Spacing.sm)
    .borderRadius(DesignSystem.BorderRadius.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
    .opacity(this.isPressed ? 0.9 : 1)
    .scale({ x: this.isPressed ? 0.95 : 1, y: this.isPressed ? 0.95 : 1 })
    .animation({
      duration: DesignSystem.AnimationDuration.fast,
      curve: DesignSystem.AnimationCurve.easeOut
    })
    .onClick(() => {
      if (this.book && (!this.showSourceStatus || this.book.sourceStatus !== SourceStatus.INVALID)) {
        this.onCardClick(this.book);
      }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }
}
