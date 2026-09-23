import { common } from '@kit.AbilityKit';
import { HomeTab } from '../view/HomeTab';
import { FoodTab } from '../view/FoodTab';
import { ChatTab } from '../view/ChatTab';
import { PetTab } from '../view/PetTab';
import { ensureAppStorage } from '../common/AppState';
import { AuthService, LoginOutcome, REQUIRE_LOGIN } from '../service/AuthService';

/**
 * 主 Tab 容器（当前不要求登录）。
 *
 * 关于登录：`AuthService.REQUIRE_LOGIN` 为 false —— 应用内没有生成式 AI，
 * 不提供信息发布 / 即时通讯 / 合成生成内容服务，因此无需在登录环节核验真实身份，
 * 打开即用、也不联网。将来若要启用账号体系，把该开关改为 true 即可（登录页已就绪）。
 *
 * 关于隐私弹窗：应用已接入华为平台隐私声明托管服务，由平台在启动时统一弹一次标准隐私声明，
 * 应用自己不再另做一份同意弹窗（审核意见 4：两个隐私弹窗影响体验）。
 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State coverShown: boolean = true;
  @State coverOpacity: number = 1;
  /** 是否已登录（未登录时停在登录门禁页） */
  @State loggedIn: boolean = false;
  @State logging: boolean = false;
  /** 监听数据变更：用户在「我的」里注销账号后，这里要立刻切回登录页 */
  @StorageLink('dataVersion') @Watch('onDataVersion') dataVersion: number = 0;
  private controller: TabsController = new TabsController();

  onDataVersion(): void {
    const loggedIn = !REQUIRE_LOGIN || AuthService.isLoggedIn();
    if (loggedIn !== this.loggedIn) {
      this.loggedIn = loggedIn;
    }
  }

  aboutToAppear(): void {
    ensureAppStorage();
    this.loggedIn = !REQUIRE_LOGIN || AuthService.isLoggedIn();
    if (!this.loggedIn) {
      // 未登录：直接停在登录页，不做启动封面动画
      this.coverShown = false;
      return;
    }
    // 冷启动封面：等首帧把数据读出来就淡出，不做人为的长延时
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.coverOpacity = 0;
      });
      setTimeout(() => {
        this.coverShown = false;
      }, 320);
    }, 520);
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (err) {
    }
  }

  private async doLogin(): Promise<void> {
    if (this.logging) {
      return;
    }
    this.logging = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const outcome: LoginOutcome = await AuthService.login(context);
    this.logging = false;
    if (outcome.ok) {
      this.loggedIn = true;
      this.coverShown = false;
      this.toast('登录成功');
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '登录失败',
      message: outcome.message,
      confirm: {
        value: '我知道了',
        action: () => {
        }
      }
    });
  }

  @Builder
  BrandBlock() {
    Column() {
      Image($r('app.media.brand_icon'))
        .width(84)
        .height(84)
      Text('爪心')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16 })
      Text('科学养宠，吃对每一口')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /** 未登录时的门禁页：不登录就不进入应用主体 */
  @Builder
  LoginGate() {
    Column() {
      Column() {
        this.BrandBlock()
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text('登录后开始使用')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text('按照《网络安全法》对用户真实身份信息核验的要求，本应用需要先登录华为账号再使用。' +
          '华为账号是实名账号，登录即完成真实身份核验，我们不会额外向你索取证件信息。')
          .fontSize(13)
          .lineHeight(21)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
          .width('100%')

        Text('宠物档案、照片、对话记录与提醒仍然只保存在本机，不会上传到我们的服务器；' +
          '应用自身不发起网络请求，登录由系统华为账号服务完成。')
          .fontSize(13)
          .lineHeight(21)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
          .width('100%')

        Button(this.logging ? '正在登录…' : '华为账号登录')
          .width('100%')
          .fontSize(16)
          .backgroundColor($r('app.color.brand'))
          .margin({ top: 18 })
          .onClick(() => {
            this.doLogin();
          })

        Text('《隐私政策》全文')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .margin({ top: 14 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => {
            const params: Record<string, string> = { 'from': 'login' };
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage', params: params });
          })

        Text('登录即表示你已阅读并同意《隐私政策》。')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(20)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.page_padding'))
    .backgroundColor($r('app.color.start_window_background'))
  }

  /** 启动封面：和系统启动窗口同一底色，图标从系统启动页"接"过来 */
  @Builder
  Cover() {
    Column() {
      Image($r('app.media.brand_icon'))
        .width(88)
        .height(88)
      Text('爪心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 18 })
      Text('科学养宠，吃对每一口')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  TabItem(index: number, emoji: string, title: string) {
    Column() {
      Text(emoji)
        .fontSize(20)
      Text(title)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      if (this.loggedIn) {
        Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
          TabContent() {
            HomeTab({
              jumpTo: (index: number) => {
                this.controller.changeIndex(index);
              }
            })
          }
          .tabBar(this.TabItem(0, '🏠', '首页'))

          TabContent() {
            FoodTab()
          }
          .tabBar(this.TabItem(1, '🍎', '食物'))

          TabContent() {
            ChatTab()
          }
          .tabBar(this.TabItem(2, '💬', '问答'))

          TabContent() {
            PetTab()
          }
          .tabBar(this.TabItem(3, '🐾', '我的'))
        }
        .barHeight(58)
        .scrollable(false)
        .animationDuration(0)
        .backgroundColor($r('app.color.page_bg'))
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      } else {
        this.LoginGate()
      }

      if (this.coverShown) {
        Column() {
          this.Cover()
        }
        .width('100%')
        .height('100%')
        .opacity(this.coverOpacity)
      }
    }
    .width('100%')
    .height('100%')
  }
}
