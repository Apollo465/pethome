let storage = new LocalStorage();

/**
 * 桌面卡片：只做「今天要做什么」这一件事。
 * 数据由 EntryFormAbility 通过 FormBindingData 注入，点击任意位置进入 App。
 */
@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('title') title: string = '今日养宠待办';
  @LocalStorageProp('petName') petName: string = '';
  @LocalStorageProp('summary') summary: string = '今天没有安排';
  @LocalStorageProp('item1') item1: string = '';
  @LocalStorageProp('item2') item2: string = '';
  @LocalStorageProp('item3') item3: string = '';
  @LocalStorageProp('emptyText') emptyText: string = '';
  @LocalStorageProp('updateText') updateText: string = '';

  @Builder
  TaskLine(text: string) {
    Row() {
      Text('•')
        .fontSize(12)
        .fontColor('#FF8A5B')
        .margin({ right: 4 })
      Text(text)
        .fontSize(12)
        .fontColor('#1F1B18')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 4 })
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.brand_mark_orange'))
          .width(14)
          .height(14)
          .margin({ right: 5 })
        Text(this.title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F1B18')
          .layoutWeight(1)
        Text(this.petName)
          .fontSize(11)
          .fontColor('#8A8078')
      }
      .width('100%')

      Text(this.summary)
        .fontSize(11)
        .fontColor('#FF8A5B')
        .margin({ top: 4 })
        .width('100%')

      if (this.item1.length > 0) {
        this.TaskLine(this.item1)
      }
      if (this.item2.length > 0) {
        this.TaskLine(this.item2)
      }
      if (this.item3.length > 0) {
        this.TaskLine(this.item3)
      }
      if (this.emptyText.length > 0) {
        Text(this.emptyText)
          .fontSize(11)
          .fontColor('#8A8078')
          .margin({ top: 6 })
          .width('100%')
      }

      Blank()

      Text(this.updateText)
        .fontSize(9)
        .fontColor('#B8AFA8')
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .onClick(() => {
      // 动态卡片必须用 postCardAction 才能跳转，FormLink 只对静态卡片生效
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          message: 'open-home'
        }
      });
    })
  }
}
