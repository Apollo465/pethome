import { common } from '@kit.AbilityKit';
import { PetStore } from '../data/PetStore';
import { ReminderItem, ReminderKind } from '../model/Models';
import { formatDate, formatTime, kindText, repeatText, weekDayLabels } from '../common/DateUtil';
import { ReminderFailReason, ReminderService, ReminderResult } from '../service/ReminderService';
import { bumpDataVersion } from '../common/AppState';
import { refreshCard } from '../service/CardService';

interface KindOption {
  value: string;
  label: string;
}

@Entry
@Component
struct ReminderEditPage {
  @State reminderId: string = '';
  @State isNew: boolean = true;
  @State kind: string = ReminderKind.VACCINE;
  @State title: string = '';
  @State note: string = '';
  @State dateTime: number = Date.now() + 3600000;
  @State repeatDays: number[] = [];
  @State systemReminderId: number = -1;
  @State lastDoneDate: string = '';
  @State saving: boolean = false;
  /** 系统提醒没注册上时，本页要告诉用户"存下来了 + 下一步怎么做" */
  @State statusNote: string = '';
  @State needNotify: boolean = false;
  /** 系统侧提醒额度被占满时，多给一个"重置系统提醒"的兜底入口 */
  @State canRebuild: boolean = false;

  private kindOptions: KindOption[] = [
    { value: ReminderKind.VACCINE, label: '疫苗' },
    { value: ReminderKind.DEWORM, label: '驱虫' },
    { value: ReminderKind.BATH, label: '洗澡' },
    { value: ReminderKind.MEDICINE, label: '喂药' },
    { value: ReminderKind.CHECKUP, label: '体检' },
    { value: ReminderKind.OTHER, label: '其他' }
  ];

  aboutToAppear(): void {
    let targetId = '';
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
      if (params !== undefined && params !== null) {
        const value = params['reminderId'];
        if (value !== undefined) {
          targetId = value;
        }
      }
    } catch (err) {
      targetId = '';
    }
    if (targetId.length === 0) {
      return;
    }
    const list = PetStore.get().getReminders();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === targetId) {
        const item = list[i];
        this.reminderId = item.id;
        this.isNew = false;
        this.kind = item.kind;
        this.title = item.title;
        this.note = item.note;
        this.dateTime = item.dateTime;
        this.repeatDays = item.repeatDays;
        this.systemReminderId = item.systemReminderId;
        this.lastDoneDate = item.lastDoneDate;
        break;
      }
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (err) {
    }
  }

  private defaultTitle(kind: string): string {
    return `${kindText(kind)}提醒`;
  }

  private toggleDay(day: number): void {
    const next: number[] = [];
    let removed = false;
    for (let i = 0; i < this.repeatDays.length; i++) {
      if (this.repeatDays[i] === day) {
        removed = true;
      } else {
        next.push(this.repeatDays[i]);
      }
    }
    if (!removed) {
      next.push(day);
    }
    next.sort((a: number, b: number) => a - b);
    this.repeatDays = next;
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    const pet = PetStore.get().getCurrentPet();
    if (pet === undefined) {
      this.toast('请先添加宠物档案');
      return;
    }
    if (this.repeatDays.length === 0 && this.dateTime <= Date.now()) {
      this.toast('提醒时间已经过去，请选择将来的时间');
      return;
    }
    this.saving = true;
    this.statusNote = '';

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    // 系统通知没开时，代理提醒发布一定会被系统拒掉（错误码 1700001），所以先申请一次；
    // 用户不同意也不影响保存：提醒先落在应用内的「今日待办」里。
    const notificationReady = await ReminderService.ensureNotificationEnabled(context);

    const previousSystemId = this.systemReminderId;
    const item: ReminderItem = this.buildItem(pet.id);
    // 先落库再注册：注册只是"让它到点弹系统通知"的增强，不该决定用户填的内容能不能存下来。
    // 同时把这条提醒切到"已存在"，用户再点一次保存时不会又存出一条重复的。
    item.systemReminderId = -1;
    this.reminderId = item.id;
    this.isNew = false;
    this.systemReminderId = -1;
    PetStore.get().saveReminder(item);
    bumpDataVersion();

    if (previousSystemId >= 0) {
      await ReminderService.cancel(previousSystemId);
    }
    const result: ReminderResult = notificationReady
      ? await ReminderService.register(item)
      : ReminderService.notificationOffResult();
    await this.applyRegisterResult(item, result);
  }

  /**
   * 注册结果的统一处理：
   * 成功 → 提示并返回上一页；
   * 没注册上 → 留在本页，把"提醒已经存下来了"和下一步该做什么说清楚。
   */
  private async applyRegisterResult(item: ReminderItem, result: ReminderResult): Promise<void> {
    item.systemReminderId = result.ok ? result.systemId : -1;
    this.systemReminderId = item.systemReminderId;
    PetStore.get().saveReminder(item);
    bumpDataVersion();
    await refreshCard();
    this.saving = false;

    if (result.ok) {
      this.needNotify = false;
      this.canRebuild = false;
      this.statusNote = '';
      this.toast(result.message);
      this.getUIContext().getRouter().back();
      return;
    }
    this.needNotify = result.needNotification;
    this.canRebuild = result.reason === ReminderFailReason.LIMIT;
    this.statusNote = `提醒已经保存到「今日待办」，内容不会丢。${result.message}。`;
    this.toast('提醒已保存到「今日待办」');
  }

  /** 把页面上的内容组装成一条提醒数据，新建与重试注册共用 */
  private buildItem(petId: string): ReminderItem {
    return {
      id: this.isNew ? `rem_${Date.now()}` : this.reminderId,
      petId: petId,
      kind: this.kind,
      title: this.title.trim().length > 0 ? this.title.trim() : this.defaultTitle(this.kind),
      note: this.note.trim(),
      dateTime: this.dateTime,
      repeatDays: this.repeatDays,
      enabled: true,
      systemReminderId: -1,
      lastDoneDate: this.lastDoneDate
    };
  }

  /** 编辑已有提醒时，如果它还没注册到系统代理，用户可以在这一页直接重试 */
  private async retryRegister(): Promise<void> {
    if (this.saving) {
      return;
    }
    const pet = PetStore.get().getCurrentPet();
    if (pet === undefined) {
      this.toast('请先添加宠物档案');
      return;
    }
    this.saving = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ready = await ReminderService.ensureNotificationEnabled(context);
    if (!ready) {
      this.saving = false;
      this.needNotify = true;
      this.canRebuild = false;
      this.statusNote = '提醒还在「今日待办」里，但系统通知没有打开，到点不会弹出来。';
      return;
    }
    const item: ReminderItem = this.buildItem(pet.id);
    item.id = this.reminderId;
    item.systemReminderId = -1;
    const result: ReminderResult = await ReminderService.register(item);
    await this.applyRegisterResult(item, result);
  }

  /** 兜底重建：系统里的提醒对不上时，全销后按本机数据重新注册一遍 */
  private async rebuildReminders(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await ReminderService.rebuildAll(context);
    const list = PetStore.get().getReminders();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.reminderId) {
        this.systemReminderId = list[i].systemReminderId;
        break;
      }
    }
    bumpDataVersion();
    this.saving = false;
    this.canRebuild = false;
    if (this.systemReminderId >= 0) {
      this.needNotify = false;
      this.statusNote = '';
      this.toast('系统提醒已重建，到点会通知你');
      return;
    }
    this.needNotify = !await ReminderService.notificationEnabled();
    this.statusNote = '系统提醒还没能重建，多半是系统侧的提醒服务暂时异常，稍后再试一次。';
    this.toast('暂时没能重建，请稍后再试');
  }

  @Builder
  KindChip(option: KindOption) {
    Text(option.label)
      .fontSize(14)
      .fontColor(this.kind === option.value ? Color.White : $r('app.color.text_primary'))
      .backgroundColor(this.kind === option.value ? $r('app.color.brand') : $r('app.color.page_bg'))
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(18)
      .margin({ right: 8, top: 8 })
      .onClick(() => {
        this.kind = option.value;
        if (this.title.trim().length === 0) {
          this.title = this.defaultTitle(option.value);
        }
      })
  }

  @Builder
  DayChip(day: number, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.repeatDays.indexOf(day) >= 0 ? Color.White : $r('app.color.text_primary'))
      .backgroundColor(this.repeatDays.indexOf(day) >= 0 ? $r('app.color.brand') : $r('app.color.page_bg'))
      .width(40)
      .height(36)
      .textAlign(TextAlign.Center)
      .borderRadius(10)
      .margin({ right: 6 })
      .onClick(() => {
        this.toggleDay(day);
      })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('返回')
            .fontSize(14)
            .fontColor($r('app.color.brand'))
            .onClick(() => {
              this.getUIContext().getRouter().back();
            })
          Blank()
          Text(this.isNew ? '新建提醒' : '编辑提醒')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(this.saving ? '保存中' : '保存')
            .fontSize(14)
            .fontColor($r('app.color.brand'))
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })

        Column() {
          Text('提醒类型')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.kindOptions, (option: KindOption) => {
              this.KindChip(option)
            }, (option: KindOption) => option.value)
          }
          .width('100%')

          Text('标题')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 18, bottom: 6 })
          TextInput({ text: this.title, placeholder: this.defaultTitle(this.kind) })
            .fontSize(14)
            .onChange((value: string) => {
              this.title = value;
            })

          Text('备注（选填）')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 14, bottom: 6 })
          TextInput({ text: this.note, placeholder: '例如：该打第三针了，记得带疫苗本' })
            .fontSize(14)
            .onChange((value: string) => {
              this.note = value;
            })

          Text('时间')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 18, bottom: 6 })
          Row() {
            Text(formatDate(this.dateTime))
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .padding(10)
              .backgroundColor($r('app.color.page_bg'))
              .borderRadius(10)
              .onClick(() => {
                this.getUIContext().showDatePickerDialog({
                  start: new Date(2020, 0, 1),
                  end: new Date(2035, 11, 31),
                  selected: new Date(this.dateTime),
                  onDateAccept: (value: Date) => {
                    const current = new Date(this.dateTime);
                    const next = new Date(value.getFullYear(), value.getMonth(), value.getDate(),
                      current.getHours(), current.getMinutes());
                    this.dateTime = next.getTime();
                  }
                });
              })
            Text(formatTime(this.dateTime))
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .padding(10)
              .backgroundColor($r('app.color.page_bg'))
              .borderRadius(10)
              .margin({ left: 10 })
              .onClick(() => {
                this.getUIContext().showTimePickerDialog({
                  selected: new Date(this.dateTime),
                  onAccept: (value: TimePickerResult) => {
                    const current = new Date(this.dateTime);
                    const next = new Date(current.getFullYear(), current.getMonth(), current.getDate(),
                      value.hour, value.minute);
                    this.dateTime = next.getTime();
                  }
                });
              })
          }
          .width('100%')

          Text('重复')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 18, bottom: 6 })
          Row() {
            ForEach([0, 1, 2, 3, 4, 5, 6], (day: number) => {
              this.DayChip(day, weekDayLabels()[day])
            }, (day: number) => `${day}`)
          }
          .width('100%')

          Row() {
            Text(repeatText(this.repeatDays))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
            Text('每天')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                this.repeatDays = [0, 1, 2, 3, 4, 5, 6];
              })
            Text('清空')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .margin({ left: 16 })
              .onClick(() => {
                this.repeatDays = [];
              })
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        if (!this.isNew && this.systemReminderId < 0) {
          Column() {
            Text('系统提醒还没生效')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.risk_high'))
              .width('100%')
            Text(this.statusNote.length > 0
              ? this.statusNote
              : '这条提醒现在只出现在应用内的「今日待办」里，到点不会弹系统通知。' +
                '点下面的按钮可以再注册一次，不用重新填。')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
              .width('100%')
            Row() {
              if (this.needNotify) {
                Text('去开启通知')
                  .fontSize(13)
                  .fontColor($r('app.color.brand'))
                  .margin({ right: 20 })
                  .onClick(() => {
                    ReminderService.openNotificationSettings(
                      this.getUIContext().getHostContext() as common.UIAbilityContext);
                  })
              }
              Text(this.saving ? '正在重试…' : '重试注册系统提醒')
                .fontSize(13)
                .fontColor($r('app.color.brand'))
                .onClick(() => {
                  this.retryRegister();
                })
              if (this.canRebuild) {
                Text(this.saving ? '' : '重置系统提醒')
                  .fontSize(13)
                  .fontColor($r('app.color.brand'))
                  .margin({ left: 20 })
                  .onClick(() => {
                    this.rebuildReminders();
                  })
              }
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .padding(16)
          .margin({ top: 12 })
          .backgroundColor('#FFF3E0')
          .borderRadius($r('app.float.card_radius'))
          .alignItems(HorizontalAlign.Start)
        }

        Column() {
          Text('提醒由系统代理发送，App 不用常驻后台也能准时弹出。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Text('完成打卡后会同步到桌面卡片。系统通知没开时，提醒会留在应用内的待办里，但不会弹通知。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.brand_light'))
        .borderRadius($r('app.float.card_radius'))

        if (!this.isNew) {
          Button('删除这条提醒')
            .width('100%')
            .fontSize(15)
            .backgroundColor('#FDECEA')
            .fontColor($r('app.color.risk_high'))
            .margin({ top: 20, bottom: 24 })
            .onClick(() => {
              this.doDelete();
            })
        }
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

  private async doDelete(): Promise<void> {
    await ReminderService.cancel(this.systemReminderId);
    PetStore.get().deleteReminder(this.reminderId);
    bumpDataVersion();
    await refreshCard();
    this.getUIContext().getRouter().back();
  }
}
