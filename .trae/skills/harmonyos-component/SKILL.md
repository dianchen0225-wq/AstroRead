---
name: "harmonyos-component"
description: "Creates HarmonyOS UI components following project design system and conventions. Invoke when user needs to create new UI components or pages."
---

# HarmonyOS Component Generator

This skill helps create UI components for HarmonyOS ArkTS following the project's design system.

## When to Invoke

- User wants to create a new UI component
- User needs to create a new page
- User asks about component styling or theming

## Design System Reference

The project uses a centralized design system in `DesignSystem.ets`:

```typescript
import { DesignSystem } from '../common/DesignSystem';

// Colors
DesignSystem.getPrimaryColor(isLightMode)      // #B8860B / #E8C547
DesignSystem.getPrimaryTextColor(isLightMode)  // #1A1A1A / #FAF8F5
DesignSystem.getSecondaryBackgroundColor(isLightMode)  // Card backgrounds

// Spacing
DesignSystem.Spacing.xs   // 2px
DesignSystem.Spacing.sm   // 4px
DesignSystem.Spacing.md   // 8px
DesignSystem.Spacing.lg   // 12px
DesignSystem.Spacing.xl   // 16px
DesignSystem.Spacing.xxl  // 24px

// Typography
DesignSystem.Typography.size.sm      // 13px
DesignSystem.Typography.size.base    // 15px
DesignSystem.Typography.weight.medium  // 500
DesignSystem.Typography.weight.bold    // 700

// Border Radius
DesignSystem.BorderRadius.sm   // 6px
DesignSystem.BorderRadius.md   // 10px
DesignSystem.BorderRadius.lg   // 14px

// Shadows
DesignSystem.Shadows.sm.light  // Light mode shadow
DesignSystem.Shadows.md.dark   // Dark mode shadow
```

## Component Template

Create file: `entry/src/main/ets/components/YourComponent.ets`

```typescript
import { DesignSystem } from '../common/DesignSystem';

export interface YourComponentProps {
  title: string;
  subtitle?: string;
  onAction?: () => void;
}

@Component
export struct YourComponent {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop onAction: () => void = () => {};

  @StorageLink('isLightMode') private isLightMode: boolean = true;

  build() {
    Column() {
      Text(this.title)
        .fontSize(DesignSystem.Typography.size.lg)
        .fontWeight(DesignSystem.Typography.weight.semibold)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

      if (this.subtitle) {
        Text(this.subtitle)
          .fontSize(DesignSystem.Typography.size.sm)
          .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
          .margin({ top: DesignSystem.Spacing.xs })
      }

      Button('Action')
        .width('100%')
        .height(44)
        .backgroundColor(DesignSystem.getPrimaryColor(this.isLightMode))
        .borderRadius(DesignSystem.BorderRadius.md)
        .fontColor('#FFFFFF')
        .margin({ top: DesignSystem.Spacing.lg })
        .onClick(() => {
          if (this.onAction) {
            this.onAction();
          }
        })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .borderRadius(DesignSystem.BorderRadius.lg)
  }
}
```

## Page Template

Create file: `entry/src/main/ets/pages/YourPage.ets`

```typescript
import { DesignSystem } from '../common/DesignSystem';
import { YourComponent } from '../components/YourComponent';

@Entry
@Component
struct YourPage {
  @State private isLoading: boolean = false;
  @State private data: string[] = [];
  @StorageLink('isLightMode') private isLightMode: boolean = true;

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    this.isLoading = true;
    try {
      // Load data
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      this.TitleBar()
      
      if (this.isLoading) {
        this.LoadingView()
      } else {
        this.ContentArea()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignSystem.getPrimaryBackgroundColor(this.isLightMode))
  }

  @Builder
  TitleBar() {
    Row() {
      Text('Page Title')
        .fontSize(DesignSystem.Typography.size.xl)
        .fontWeight(DesignSystem.Typography.weight.bold)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
    }
    .width('100%')
    .height(56)
    .padding({ left: DesignSystem.Spacing.xl, right: DesignSystem.Spacing.xl })
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
  }

  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(DesignSystem.getPrimaryColor(this.isLightMode))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ContentArea() {
    List() {
      ForEach(this.data, (item: string, index: number) => {
        ListItem() {
          YourComponent({
            title: item,
            onAction: () => {
              console.info(`Item ${index} clicked`);
            }
          })
        }
        .margin({ bottom: DesignSystem.Spacing.md })
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding(DesignSystem.Spacing.lg)
  }
}
```

## Common Component Patterns

### Card Component
```typescript
@Component
struct AppCard {
  @Prop title: string = '';
  @Prop content: string = '';
  @StorageLink('isLightMode') isLightMode: boolean = true;

  build() {
    Column() {
      Text(this.title)
        .fontSize(DesignSystem.Typography.size.base)
        .fontWeight(DesignSystem.Typography.weight.medium)
        .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))

      Text(this.content)
        .fontSize(DesignSystem.Typography.size.sm)
        .fontColor(DesignSystem.getSecondaryTextColor(this.isLightMode))
        .margin({ top: DesignSystem.Spacing.xs })
    }
    .width('100%')
    .padding(DesignSystem.Spacing.lg)
    .backgroundColor(DesignSystem.getSecondaryBackgroundColor(this.isLightMode))
    .borderRadius(DesignSystem.BorderRadius.lg)
    .border({
      width: 1,
      color: DesignSystem.getBorderColor(this.isLightMode)
    })
  }
}
```

### Input Component
```typescript
@Component
struct AppInput {
  @Link value: string;
  @Prop placeholder: string = '';
  @Prop onEnter?: () => void;
  @StorageLink('isLightMode') isLightMode: boolean = true;

  build() {
    TextInput({ text: this.value, placeholder: this.placeholder })
      .width('100%')
      .height(44)
      .fontSize(DesignSystem.Typography.size.base)
      .fontColor(DesignSystem.getPrimaryTextColor(this.isLightMode))
      .placeholderColor(DesignSystem.getTertiaryTextColor(this.isLightMode))
      .backgroundColor(DesignSystem.getTertiaryBackgroundColor(this.isLightMode))
      .borderRadius(DesignSystem.BorderRadius.md)
      .padding({ left: DesignSystem.Spacing.md, right: DesignSystem.Spacing.md })
      .onChange((value: string) => {
        this.value = value;
      })
      .onSubmit(() => {
        if (this.onEnter) {
          this.onEnter();
        }
      })
  }
}
```

## Best Practices

1. **Use DesignSystem**: Always reference `DesignSystem` for colors, spacing, typography
2. **Theme Support**: Use `@StorageLink('isLightMode')` for theme awareness
3. **State Management**: Use `@State` for local state, `@Prop` for inputs, `@Link` for two-way binding
4. **Builder Methods**: Extract complex UI into `@Builder` methods
5. **Accessibility**: Ensure minimum touch target of 44px
6. **Responsive**: Use percentage widths and `layoutWeight` for flexible layouts

## Register Page

Add to `entry/src/main/resources/base/profile/main_pages.json`:

```json
{
  "src": [
    "pages/YourPage"
  ]
}
```
