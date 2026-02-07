/**
 * 测试页面 - 用于验证应用是否能正常显示
 */
@Entry
@Component
export struct TestPage {
  build() {
    Column() {
      Text('测试页面')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 24 })
      
      Text('如果看到此页面，说明应用能正常显示')
        .fontSize(16)
        .fontColor('#666666')
      
      Button('返回主页')
        .margin({ top: 24 })
        .onClick(() => {
          // 这里可以添加返回主页的逻辑
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}