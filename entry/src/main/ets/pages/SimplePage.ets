/**
 * 简单测试页面 - 用于验证应用是否能正常启动
 */
@Entry
@Component
export struct SimplePage {
  build() {
    Column() {
      Text('AstroRead')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 24 })
      
      Text('应用启动成功！')
        .fontSize(16)
        .fontColor('#666666')
      
      Text('这是一个简单的测试页面')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}