import { common } from '@kit.AbilityKit';
import { PetStore } from '../data/PetStore';
import { bumpDataVersion } from '../common/AppState';
import { PrivacyService } from '../service/PrivacyService';
import { ReminderService } from '../service/ReminderService';

interface PolicySection {
  title: string;
  body: string;
}

/**
 * 应用内隐私政策。
 * 内容需与 AGC 上填写的隐私政策网址保持一致（审核指南 7.1）。
 * 开发者信息：王宇辉 / 3169089967@qq.com，需与 AGC 上提交的信息保持一致。
 */
const POLICY_INTRO: string =
  '爪心（以下简称"本应用"）由王宇辉开发。本政策说明我们如何处理你在使用本应用过程中涉及的信息，' +
  '以及你对这些信息享有的权利。\n\n' +
  '本应用打开即用，没有账号体系，也不需要注册或登录。' +
  '应用已接入华为平台隐私声明托管服务，首次启动时由系统统一弹出标准隐私声明；' +
  '在系统侧同意之前，应用不会读写你的任何数据。' +
  '如果你不同意本政策，我们不会处理你的信息，你也无法使用本应用的功能。';

const POLICY_SECTIONS: PolicySection[] = [
  {
    title: '一、我们处理哪些信息',
    body: '本应用全部在本机运行，不向我们的服务器上传任何信息，也不采集任何个人信息用于统计或广告。' +
      '我们处理的都是你主动录入或选择的信息：\n\n' +
      '· 宠物档案：名字、种类、品种、生日、体重、过敏史、既往病史、是否绝育。用于生成个性化养宠建议，' +
      '并在回答中引用你的档案。\n' +
      '· 宠物照片：你通过系统图片选择器主动选择的图片，由应用复制到本机沙箱，用于应用内展示。\n' +
      '· 对话记录：你在"问答"中输入的问题与应用给出的回答，用于你回看历史问答。\n' +
      '· 食物查询记录：你查询过的食物名称、结论与时间，用于回看最近查询。\n' +
      '· 提醒事项：提醒类型、标题、备注、时间、重复规则，用于到点提醒你。\n\n' +
      '我们不收集通讯录、短信、通话记录、精确位置、麦克风录音、设备识别码、剪贴板，也不读取应用安装列表，' +
      '不做用户画像与广告投放。'
  },
  {
    title: '二、信息如何存储',
    body: '上述信息全部保存在你设备上的应用沙箱内：档案、对话、提醒保存在应用私有存储中；' +
      '照片保存在应用沙箱 files/photos/ 目录。\n\n' +
      '对话记录最多保留 200 条、食物查询记录最多保留 100 条，超出后按时间先后自动删除最早的记录。\n\n' +
      '我们不会把这些信息上传到服务器，也不做云端备份。卸载本应用会一并删除这些数据且无法恢复，请自行留意备份。'
  },
  {
    title: '三、内容来源与人工智能说明',
    body: '本应用不提供人工智能生成合成服务：应用内没有接入任何生成式人工智能模型，' +
      '包体不含模型文件，也不具备联网能力（应用未声明网络权限）。\n\n' +
      '你看到的问答与食物结论是这样产生的：\n\n' +
      '· 食物能不能吃：由应用内置的食物安全知识库给出明确定论与原因，不经过任何模型推断；\n' +
      '· 养宠问答：按关键词匹配本机知识库条目，输出预先撰写好的科普文案，回答中会标注内容出处；\n' +
      '· 知识库没有覆盖的问题：应用会明确回答"知识库里没有"，不会编造内容。\n\n' +
      '由于不涉及人工智能生成合成内容，本应用不需要提供人工智能生成合成内容标识，' +
      '也无需办理生成式人工智能服务相关备案。'
  },
  {
    title: '四、我们申请的权限',
    body: '本应用仅声明一个权限，且只在你保存提醒时使用：\n\n' +
      '· 通知 / 代理提醒（ohos.permission.PUBLISH_AGENT_REMINDER）：' +
      '用于在疫苗、驱虫、喂药等时间点由系统代理发送提醒，App 不需要常驻后台。\n\n' +
      '本应用不申请网络、相册、存储、位置、通讯录、短信、麦克风、相机、日历等权限。' +
      '选择宠物照片时使用系统提供的图片选择器，只有你主动选中的那一张图片会被应用读取。\n\n' +
      '如果你关闭系统通知，提醒会保留在应用内的今日待办里，但到点不会弹出系统通知；' +
      '重新开启通知后可以在提醒详情页重试注册。'
  },
  {
    title: '五、你的权利',
    body: '你可以随时行使以下权利，无需向我们提出申请：\n\n' +
      '· 查阅、更正档案：「我的 → 宠物档案 → 编辑」；\n' +
      '· 删除某只宠物及其提醒：「编辑 → 删除这只宠物」；\n' +
      '· 删除提醒：「我的 → 全部提醒 → 进入提醒 → 删除这条提醒」；\n' +
      '· 删除对话记录：「问答 → 清空对话」；\n' +
      '· 删除全部数据：「我的 → 清除全部数据」；\n' +
      '· 撤回隐私同意：「我的 → 隐私政策 → 撤回隐私同意并删除本机数据」，' +
      '撤回后应用会删除本机全部数据，并在下次启动时重新弹出隐私声明。\n\n' +
      '如对个人信息处理有疑问、投诉或举报，可通过下方联系方式与我们联系，我们会在 15 个工作日内答复处理。'
  },
  {
    title: '六、信息安全',
    body: '我们通过"数据不离开设备"的方式降低风险：本应用不设账号体系，不联网，不同步到云端。' +
      '请你自行保管好设备与锁屏密码；设备丢失或被他人使用时，本机保存的宠物档案、照片与对话记录可能被查看。'
  },
  {
    title: '七、未成年人保护',
    body: '本应用面向宠物主人，不以未成年人为目标用户，也不会主动收集未成年人的个人信息。' +
      '未成年人应在监护人指导下使用本应用。'
  },
  {
    title: '八、本政策的更新',
    body: '当本应用的功能或信息处理方式发生变化时，我们会更新本政策，并在新版本中以弹窗或页面形式再次提示你阅读确认。' +
      '更新后的政策自公示之日起生效。'
  },
  {
    title: '九、联系我们',
    body: '开发者：王宇辉\n联系邮箱：3169089967@qq.com\n\n' +
      '如对本政策有任何疑问、意见或投诉，欢迎通过上述邮箱与我们联系。'
  }
];

@Entry
@Component
struct PrivacyPage {

  @Builder
  Section(title: string, body: string) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(body)
        .fontSize(13)
        .lineHeight(22)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.card_radius'))
    .alignItems(HorizontalAlign.Start)
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (err) {
    }
  }

  /** 撤回同意：删除本机数据 + 撤回平台侧的同意状态，然后退出应用 */
  private revoke(): void {
    this.getUIContext().showAlertDialog({
      title: '撤回同意',
      message: '将删除本机保存的宠物档案、照片、对话记录和提醒，并撤回隐私声明同意；' +
        '下次打开应用时会重新弹出隐私声明。此操作无法撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '撤回并删除',
        fontColor: $r('app.color.risk_high'),
        action: () => {
          this.doRevoke();
        }
      }
    });
  }

  /** 撤回同意：先注销系统代理提醒，再清数据、撤回平台同意，最后退出应用 */
  private async doRevoke(): Promise<void> {
    await ReminderService.cancelAll();
    PetStore.get().clearAllData();
    const notified = PrivacyService.revoke();
    bumpDataVersion();
    this.toast(notified ? '已删除本机数据并撤回同意' : '已删除本机数据');
    setTimeout(() => {
      this.exitApp();
    }, 600);
  }

  /** 撤回同意后的标准处理：退出应用，不在未同意状态下继续使用 */
  private exitApp(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.terminateSelf();
    } catch (err) {
    }
  }

  build() {
    Column() {
      // 标题栏固定，不随内容滚动，长文里也能随时返回
      Row() {
        Text('返回')
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
        Blank()
        Text('隐私政策')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('')
          .fontSize(14)
          .width(28)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      Scroll() {
        Column() {
          this.Section('引言', POLICY_INTRO)
          ForEach(POLICY_SECTIONS, (item: PolicySection) => {
            this.Section(item.title, item.body)
          }, (item: PolicySection) => item.title)

          Text('更新日期：2026 年 9 月 15 日')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 16, bottom: 24 })
            .width('100%')
            .textAlign(TextAlign.Center)

          Button('撤回隐私同意并删除本机数据')
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.risk_high'))
            .backgroundColor('#FDECEA')
            .margin({ bottom: 32 })
            .onClick(() => {
              this.revoke();
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.page_padding'))
    .backgroundColor($r('app.color.page_bg'))
  }
}
