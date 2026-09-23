import { PetStore } from '../data/PetStore';
import { AccountInfo, Pet, ReminderItem, Species } from '../model/Models';
import { formatShortDateTime, kindText, petAgeText, repeatText, speciesText } from '../common/DateUtil';
import { PhotoService } from '../service/PhotoService';
import { bumpDataVersion } from '../common/AppState';
import { refreshCard } from '../service/CardService';
import { AuthService } from '../service/AuthService';
import { ReminderService, ReminderState } from '../service/ReminderService';
import { common } from '@kit.AbilityKit';

@Component
export struct PetTab {
  @StorageLink('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State pets: Pet[] = [];
  @State currentId: string = '';
  @State reminders: ReminderItem[] = [];
  @State account: AccountInfo | undefined = undefined;
  /** 提醒与通知的状态：通知开关、提醒总数、已交给系统按时提醒的条数 */
  @State reminderState: ReminderState = { notificationOn: true, total: 0, registered: 0, pending: 0 };
  @State repairing: boolean = false;

  aboutToAppear(): void {
    this.reload();
    this.refreshReminderState();
  }

  private async refreshReminderState(): Promise<void> {
    this.reminderState = await ReminderService.inspect();
  }

  /**
   * 兜底重建：系统里的提醒状态对不上时（额度被占满、提醒对不上号），
   * 把本应用的系统提醒全部注销，再按本机数据重新注册一遍。
   */
  private async rebuildReminders(): Promise<void> {
    if (this.repairing) {
      return;
    }
    this.repairing = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const restored = await ReminderService.rebuildAll(context);
    await this.refreshReminderState();
    this.repairing = false;
    this.reload();
    let message = '系统提醒已按本机数据重建';
    if (!this.reminderState.notificationOn) {
      message = '系统通知还没打开：请在设置里允许「爪心」发送通知';
    } else if (restored === 0 && this.reminderState.pending > 0) {
      message = '系统侧的提醒服务暂时异常，稍后再试一次';
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (err) {
    }
  }

  /**
   * 检查并修复：先确认系统通知开关，再把没注册上的提醒补注册一次。
   * 这条路径能兜住"新建提醒时通知没开 / 用户后来才打开通知"的情况。
   */
  private async repairReminders(): Promise<void> {
    if (this.repairing) {
      return;
    }
    this.repairing = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const added = await ReminderService.repair(context);
    await this.refreshReminderState();
    this.repairing = false;
    this.reload();
    let message = '提醒注册状态正常';
    if (!this.reminderState.notificationOn) {
      message = '系统通知还没打开：请在设置里允许「爪心」发送通知';
    } else if (this.reminderState.pending > 0) {
      message = added > 0 ? `已补上 ${added} 条提醒` : '还有提醒没能注册上，稍后再试一次';
    }
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (err) {
    }
  }

  reload(): void {
    const store = PetStore.get();
    this.pets = store.getPets();
    this.currentId = store.getCurrentPetId();
    this.reminders = store.getReminders();
    this.account = store.getAccount();
  }

  /** 退出登录：只清登录态，用户数据留在本机 */
  private doSignOut(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录',
      message: '退出后需要重新登录华为账号才能继续使用。本机保存的宠物档案、照片、对话与提醒会保留。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '退出登录',
        fontColor: $r('app.color.risk_high'),
        action: () => {
          AuthService.signOut();
          // 触发 Index 的 dataVersion 监听，立刻切回登录页
          bumpDataVersion();
        }
      }
    });
  }

  /** 注销账号：清本机全部数据与登录态 */
  private confirmDeleteAccount(): void {
    this.getUIContext().showAlertDialog({
      title: '注销账号',
      message: '将删除本机保存的宠物档案、照片、对话记录和提醒，并退出当前华为账号登录。' +
        '账号本身是华为账号，由华为账号体系管理。此操作无法撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '注销并删除数据',
        fontColor: $r('app.color.risk_high'),
        action: () => {
          AuthService.deleteAccount();
          bumpDataVersion();
        }
      }
    });
  }

  private petLine(pet: Pet): string {
    const parts: string[] = [speciesText(pet.species)];
    if (pet.breed.length > 0) {
      parts.push(pet.breed);
    }
    parts.push(petAgeText(pet.birthday));
    if (pet.weightKg > 0) {
      parts.push(`${pet.weightKg}kg`);
    }
    return parts.join(' · ');
  }

  /** 清除本机全部数据：先二次确认，再清空并刷新界面 */
  private confirmClearAll(): void {
    this.getUIContext().showAlertDialog({
      title: '清除全部数据',
      message: '将删除本机保存的宠物档案、照片、对话记录和提醒，并注销已经注册的系统提醒。此操作无法撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清除',
        fontColor: $r('app.color.risk_high'),
        action: () => {
          this.doClearAll();
        }
      }
    });
  }

  /** 清除全部数据：先注销系统代理提醒，再清本机数据 */
  private async doClearAll(): Promise<void> {
    await ReminderService.cancelAll();
    PetStore.get().clearAllData();
    bumpDataVersion();
    this.reload();
    try {
      this.getUIContext().getPromptAction().showToast({ message: '已清除本机全部数据', duration: 2000 });
    } catch (err) {
    }
  }

  @Builder
  PetRow(pet: Pet) {
    Row() {
      if (pet.avatarUri.length > 0) {
        Image(PhotoService.toDisplayUri(pet.avatarUri))
          .width(46)
          .height(46)
          .borderRadius(23)
          .objectFit(ImageFit.Cover)
      } else {
        Text(pet.species === Species.DOG ? '🐶' : '🐱')
          .fontSize(22)
          .width(46)
          .height(46)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.brand_light'))
          .borderRadius(23)
      }

      Column() {
        Row() {
          Text(pet.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          if (pet.id === this.currentId) {
            Text('当前')
              .fontSize(10)
              .fontColor($r('app.color.brand'))
              .backgroundColor($r('app.color.brand_light'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(8)
              .margin({ left: 8 })
          }
        }
        .width('100%')

        Text(this.petLine(pet))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Text('编辑')
        .fontSize(13)
        .fontColor($r('app.color.brand'))
        .padding(8)
        .onClick(() => {
          const params: Record<string, string> = { 'petId': pet.id };
          this.getUIContext().getRouter().pushUrl({ url: 'pages/PetEditPage', params: params });
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      PetStore.get().setCurrentPetId(pet.id);
      bumpDataVersion();
      refreshCard();
    })
  }

  build() {
    Scroll() {
      Column() {
        // 账号卡片只在登录状态下出现（当前 REQUIRE_LOGIN 为 false，正常情况下不显示）
        if (this.account !== undefined) {
          Column() {
          Row() {
            Text('👤')
              .fontSize(22)
              .width(46)
              .height(46)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand_light'))
              .borderRadius(23)
            Column() {
              Text('已登录华为账号')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text(this.account !== undefined ? `账号标识：${AuthService.maskedId()}` : '')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
              Text(this.account !== undefined
                ? `登录时间：${formatShortDateTime(this.account.loginAtMs)}`
                : '')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('华为账号是实名账号，登录即完成真实身份信息核验；档案、照片与对话仍然只保存在本机。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 10 })
            .width('100%')

          Row() {
            Text('退出登录')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                this.doSignOut();
              })
            Text('注销账号')
              .fontSize(13)
              .fontColor($r('app.color.risk_high'))
              .margin({ left: 20 })
              .onClick(() => {
                this.confirmDeleteAccount();
              })
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))
        .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 12 })
        }

        Text('宠物档案')
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text('点一下切换当前宠物，问答与建议会结合它的档案。')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4, bottom: 8 })
          .width('100%')

        Column() {
          if (this.pets.length === 0) {
            Text('还没有宠物档案，先添加一只吧')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .padding({ top: 20, bottom: 20 })
          } else {
            // key 里带上数据版本 + 档案内容：改完档案回到这一页，ForEach 一定会重新渲染这一行
            ForEach(this.pets, (pet: Pet) => {
              this.PetRow(pet)
            }, (pet: Pet) => `${this.dataVersion}_${pet.id}_${pet.name}_${pet.species}_${pet.breed}_${pet.birthday}_${pet.weightKg}_${pet.avatarUri}_${pet.sterilized}_${pet.allergy}_${pet.chronic}`)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Button('+ 添加宠物')
          .width('100%')
          .fontSize(15)
          .backgroundColor($r('app.color.brand'))
          .margin({ top: 12 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PetEditPage' });
          })

        Column() {
          Row() {
            Text('全部提醒')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Text('+ 新建')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderEditPage' });
              })
          }
          .width('100%')

          if (this.reminders.length === 0) {
            Text('还没有提醒。疫苗、驱虫这类周期性的事，建议现在就排上。')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 12 })
              .width('100%')
          } else {
            ForEach(this.reminders, (item: ReminderItem) => {
              Row() {
                Column() {
                  Row() {
                    Text(`${kindText(item.kind)} · ${item.title}`)
                      .fontSize(14)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.systemReminderId < 0) {
                      Text('仅应用内提醒')
                        .fontSize(10)
                        .fontColor($r('app.color.risk_mid'))
                        .backgroundColor('#FFF3E0')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(8)
                        .margin({ left: 6 })
                    }
                  }
                  .width('100%')
                  Text(`${formatShortDateTime(item.dateTime)} · ${repeatText(item.repeatDays)}`)
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 4 })
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text('›')
                  .fontSize(18)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
              .onClick(() => {
                const params: Record<string, string> = { 'reminderId': item.id };
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderEditPage', params: params });
              })
            }, (item: ReminderItem) => `${this.dataVersion}_${item.id}_${item.title}_${item.dateTime}_${item.repeatDays.join(',')}_${item.enabled}_${item.systemReminderId}_${item.lastDoneDate}`)
          }
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Column() {
          Row() {
            Text('提醒与通知')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Text(this.repairing ? '检查中…' : '检查并修复')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                this.repairReminders();
              })
          }
          .width('100%')

          Text(this.reminderState.notificationOn ? '系统通知：已开启' : '系统通知：未开启')
            .fontSize(12)
            .fontColor(this.reminderState.notificationOn ? $r('app.color.text_secondary') : $r('app.color.risk_mid'))
            .margin({ top: 8 })
            .width('100%')

          Text(this.reminderState.pending > 0
            ? `共 ${this.reminderState.total} 条提醒，${this.reminderState.registered} 条会由系统按时提醒，` +
              `${this.reminderState.pending} 条目前只在应用内的「今日待办」里`
            : `共 ${this.reminderState.total} 条提醒，都会由系统按时提醒`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
            .width('100%')

          Text('提醒内容只保存在本机，没注册上不会丢。点了「检查并修复」不会重新登记提醒，' +
            '只是再把它们交给系统一次。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .width('100%')

          Row() {
            Text('打开系统通知设置')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                ReminderService.openNotificationSettings(
                  this.getUIContext().getHostContext() as common.UIAbilityContext);
              })
            if (this.reminderState.pending > 0) {
              Text(this.repairing ? '重建中…' : '重置系统提醒')
                .fontSize(13)
                .fontColor($r('app.color.brand'))
                .margin({ left: 20 })
                .onClick(() => {
                  this.rebuildReminders();
                })
            }
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Column() {
          Text('内容来源')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text('食物能不能吃、养宠问题怎么处理，全部由应用内置的本地知识库' +
            '（约 70 条食物条目 + 27 个养宠话题）按规则匹配后给出预置文案，' +
            '不接入任何生成式 AI，应用也不具备联网能力。' +
            '知识库里没有的问题会明确告诉你"没有把握"，不会编造答案。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Column() {
          Text('数据与隐私')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text('宠物档案、照片、对话记录都保存在本机应用沙箱。' +
            '我们不申请相册权限，只有你通过系统选择器主动选中的照片才能被读取。' +
            '卸载应用会一并删除这些数据，请自行留意备份。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .width('100%')

          Row() {
            Text('隐私政策')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 })
          .border({ width: { top: 1 }, color: $r('app.color.divider') })
          .margin({ top: 12 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
          })

          Row() {
            Text('清除全部数据')
              .fontSize(14)
              .fontColor($r('app.color.risk_high'))
              .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ bottom: 4 })
          .onClick(() => {
            this.confirmClearAll();
          })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Column() {
          Row() {
            Image($r('app.media.brand_icon'))
              .width(44)
              .height(44)
            Column() {
              Text('爪心')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text('v1.0.1 · 本地知识库版')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('食物判断来自本地知识库，不由 AI 自由生成，避免出现安全类幻觉。\n' +
            '所有健康建议仅供科普参考，不能替代执业兽医的诊断与治疗。')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ top: 12, bottom: 24 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))
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
