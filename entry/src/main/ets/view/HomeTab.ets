import { PetStore } from '../data/PetStore';
import { DISCLAIMER, Pet } from '../model/Models';
import { formatCnMonthDay, formatCnWeek, petAgeText, speciesText } from '../common/DateUtil';
import { markTaskDone, refreshCard, todayTasks, TodayTask } from '../service/CardService';
import { bumpDataVersion } from '../common/AppState';
import { PhotoService } from '../service/PhotoService';

@Component
export struct HomeTab {
  @StorageLink('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State hasPet: boolean = false;
  @State petName: string = '';
  @State petDetail: string = '';
  @State avatarUri: string = '';
  @State tasks: TodayTask[] = [];
  /** 桌面上已添加的卡片数量；为 0 时首页要告诉用户怎么添加，而不是点了没反应 */
  @State cardCount: number = 0;
  jumpTo: (index: number) => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    const store = PetStore.get();
    const pet: Pet | undefined = store.getCurrentPet();
    if (pet === undefined) {
      this.hasPet = false;
      this.petName = '还没有宠物档案';
      this.petDetail = '添加后问答会自动结合它的年龄、体重';
      this.avatarUri = '';
    } else {
      this.hasPet = true;
      this.petName = pet.name;
      const parts: string[] = [speciesText(pet.species)];
      if (pet.breed.length > 0) {
        parts.push(pet.breed);
      }
      parts.push(petAgeText(pet.birthday));
      if (pet.weightKg > 0) {
        parts.push(`${pet.weightKg}kg`);
      }
      this.petDetail = parts.join(' · ');
      this.avatarUri = PhotoService.toDisplayUri(pet.avatarUri);
    }
    this.tasks = todayTasks();
    this.cardCount = PetStore.get().getFormIds().length;
  }

  @Builder
  BrandCover() {
    Row() {
      Column() {
        Image($r('app.media.brand_mark_cream'))
          .width(34)
          .height(34)
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#2EFFFFFF')
      .borderRadius(16)

      Column() {
        Text('爪心')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text('科学养宠，吃对每一口')
          .fontSize(12)
          .fontColor('#FFF0E8')
          .margin({ top: 5 })
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Column() {
        Text(formatCnMonthDay(Date.now()))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        Text(formatCnWeek(Date.now()))
          .fontSize(10)
          .fontColor('#FFF0E8')
          .margin({ top: 2 })
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('#33FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 12 })
    .borderRadius(20)
    .linearGradient({
      angle: 135,
      colors: [['#FFB77F', 0.0], ['#FF8A5B', 0.5], ['#ED6534', 1.0]]
    })
  }

  @Builder
  PetCard() {
    Row() {
      if (this.avatarUri.length > 0) {
        Image(this.avatarUri)
          .width(52)
          .height(52)
          .borderRadius(26)
          .objectFit(ImageFit.Cover)
      } else {
        Text('🐾')
          .fontSize(26)
          .width(52)
          .height(52)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.brand_light'))
          .borderRadius(26)
      }
      Column() {
        Text(this.petName)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.petDetail)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      Text(this.hasPet ? '编辑' : '添加')
        .fontSize(13)
        .fontColor($r('app.color.brand'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.card_radius'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.hasPet) {
        const params: Record<string, string> = { 'petId': PetStore.get().getCurrentPetId() };
        this.getUIContext().getRouter().pushUrl({ url: 'pages/PetEditPage', params: params });
      } else {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/PetEditPage' });
      }
    })
  }

  @Builder
  QuickEntry(emoji: string, title: string, subtitle: string, index: number) {
    Column() {
      Text(emoji)
        .fontSize(24)
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 8 })
      Text(subtitle)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.card_radius'))
    .onClick(() => {
      this.jumpTo(index);
    })
  }

  /**
   * 「同步到桌面卡片」的反馈处理。
   * 之前这里直接 await refreshCard()，没有卡片时函数自己就返回了，
   * 用户看到的就是"点了没反应"。现在三种结果都会给出明确提示。
   */
  private async syncCard(): Promise<void> {
    const result = await refreshCard();
    this.cardCount = result.total;
    if (result.total === 0) {
      this.getUIContext().showAlertDialog({
        title: '还没有添加桌面卡片',
        message: '长按桌面空白处 → 服务卡片（卡片）→ 找到「爪心 · 今日养宠待办」→ 拖到桌面上。\n\n' +
          '添加完成后回到这里再点一次，就能把今天的待办同步过去。',
        confirm: {
          value: '我知道了',
          action: () => {
          }
        }
      });
      return;
    }
    const message = result.failed > 0
      ? `同步完成：成功 ${result.updated} 张，失败 ${result.failed} 张`
      : `已同步到 ${result.updated} 张桌面卡片`;
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
    }
  }

  build() {
    Scroll() {
      Column() {
        this.BrandCover()

        this.PetCard()

        Column() {
          Row() {
            Text('今日待办')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(this.tasks.length > 0 ? `${this.tasks.length} 项` : '无')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')

          if (this.tasks.length > 0) {
            // key 里带上数据版本与内容：同一个提醒改了时间或标题后，ForEach 一定会重新渲染这一行
            ForEach(this.tasks, (item: TodayTask) => {
              Row() {
                Text('•')
                  .fontSize(14)
                  .fontColor($r('app.color.brand'))
                  .margin({ right: 6 })
                Text(`${item.timeText}  ${item.label}`)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('完成')
                  .fontSize(12)
                  .fontColor($r('app.color.brand'))
                  .padding({ left: 10, right: 4, top: 4, bottom: 4 })
                  .onClick(() => {
                    markTaskDone(item.id);
                    bumpDataVersion();
                    refreshCard();
                  })
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
            }, (item: TodayTask) => `${this.dataVersion}_${item.id}_${item.timeText}_${item.label}`)
          } else {
            Text('今天没有安排。疫苗、驱虫这类周期性的事，建议现在就排上。')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 12 })
              .width('100%')
          }

          Row() {
            Button('添加提醒')
              .fontSize(14)
              .backgroundColor($r('app.color.brand'))
              .layoutWeight(1)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderEditPage' });
              })
            Button(this.cardCount > 0 ? '同步到桌面卡片' : '如何添加桌面卡片')
              .fontSize(14)
              .backgroundColor($r('app.color.brand_light'))
              .fontColor($r('app.color.brand'))
              .layoutWeight(1)
              .margin({ left: 8 })
              .onClick(async () => {
                await this.syncCard();
              })
          }
          .width('100%')
          .margin({ top: 16 })

          if (this.cardCount === 0) {
            Text('桌面卡片还没添加：长按桌面空白处 → 服务卡片 → 找到「爪心」添加。')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 10 })
              .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Row() {
          this.QuickEntry('🍇', '食物安全速查', '明确能吃 / 不能吃', 1)
          Blank().width(12)
          this.QuickEntry('💬', '养宠问答', '本地知识库 · 结合档案', 2)
        }
        .width('100%')
        .margin({ top: 12 })

        Text(DISCLAIMER)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 16, bottom: 24 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding($r('app.float.page_padding'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
