import { AnswerService } from '../service/AnswerService';
import { PetStore } from '../data/PetStore';
import { FoodLog, Pet, RiskLevel } from '../model/Models';
import { FoodItem, findFoodInText, foodById, searchFood } from '../data/FoodKnowledge';
import { PhotoService } from '../service/PhotoService';
import { VisionResult, VisionService } from '../service/VisionService';
import { refreshCard } from '../service/CardService';
import { formatShortDateTime } from '../common/DateUtil';
import { common } from '@kit.AbilityKit';

const QUICK_NAMES: string[] = [
  '巧克力', '葡萄', '洋葱', '木糖醇', '牛奶', '鸡胸肉', '苹果', '夏威夷果', '咖啡', '百合花'
];

@Component
export struct FoodTab {
  @StorageLink('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State keyword: string = '';
  @State current: FoodItem | undefined = undefined;
  @State answerText: string = '';
  /** 照片确认卡片的提示语（检测结果或"请手动点选"） */
  @State photoHint: string = '';
  @State photoQuery: string = '';
  @State photoPicked: boolean = false;
  @State imageUri: string = '';
  @State logs: FoodLog[] = [];
  @State message: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.logs = PetStore.get().getFoodLogs();
  }

  private showFood(item: FoodItem): void {
    const pet: Pet | undefined = PetStore.get().getCurrentPet();
    this.current = item;
    this.answerText = AnswerService.explainFood(item.id, pet).text;
    this.keyword = item.name;
  }

  private search(): void {
    const text = this.keyword.trim();
    if (text.length === 0) {
      return;
    }
    const byName = findFoodInText(text);
    const list = searchFood(text);
    const item = byName !== undefined ? byName : (list.length > 0 ? list[0] : undefined);
    if (item === undefined) {
      this.current = undefined;
      this.answerText = '';
      this.message = `知识库里还没有「${text}」。可以换一个说法，或者到「问答」页试试。`;
      return;
    }
    this.message = '';
    this.showFood(item);
    this.saveLog(item);
  }

  private saveLog(item: FoodItem): void {
    const pet = PetStore.get().getCurrentPet();
    const log: FoodLog = {
      id: `${Date.now()}`,
      petId: pet !== undefined ? pet.id : '',
      foodName: item.name,
      risk: item.risk,
      imageUri: this.imageUri,
      createdAt: Date.now()
    };
    PetStore.get().appendFoodLog(log);
    this.logs = PetStore.get().getFoodLogs();
  }

  private async takePhoto(): Promise<void> {
    const uri = await PhotoService.pickImage();
    if (uri.length === 0) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.Context;
    const sandboxPath = PhotoService.importToSandbox(context, uri, `food_${Date.now()}`);
    if (sandboxPath.length === 0) {
      this.toast('图片保存失败，请重试');
      return;
    }
    // 换照片时把上一张从沙箱清掉，避免越攒越多
    if (this.imageUri.length > 0 && this.imageUri !== sandboxPath) {
      PhotoService.removeSandboxFile(this.imageUri);
    }
    this.imageUri = sandboxPath;
    this.photoQuery = '';
    this.photoPicked = true;
    // 先把"可以点选确认"给出来，界面上永远有一个能点的下一步；
    // 系统检测跑完了再把它的观察结果补上（换过照片就不补，避免张冠李戴）。
    this.photoHint = '请点选或输入照片里的食物，我来查本地知识库';
    const result: VisionResult = await VisionService.analyze(sandboxPath);
    if (result.ran && this.photoPicked && this.imageUri === sandboxPath) {
      this.photoHint = result.message;
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
    }
  }

  /**
   * 照片确认卡片里的"确认"：不管系统检测跑没跑起来，
   * 具体是哪种食物一律由用户点选/输入，然后查本地知识库。
   * 这条路不依赖任何系统能力，所以任何机型上都能走通。
   */
  private confirmPhotoFood(name: string): void {
    const text = name.trim();
    if (text.length === 0) {
      this.toast('先填一个食物名称，比如 葡萄');
      return;
    }
    const byName = findFoodInText(text);
    const list = searchFood(text);
    const item = byName !== undefined ? byName : (list.length > 0 ? list[0] : undefined);
    if (item === undefined) {
      this.photoHint = `知识库里还没有「${text}」。换一个说法再试，或者到「问答」页问问看。`;
      return;
    }
    this.message = '';
    this.showFood(item);
    this.saveLog(item);
    this.photoPicked = false;
  }

  private riskColor(risk: string): Resource {
    if (risk === RiskLevel.FORBIDDEN) {
      return $r('app.color.risk_high');
    }
    if (risk === RiskLevel.CAUTION) {
      return $r('app.color.risk_mid');
    }
    return $r('app.color.risk_low');
  }

  private riskText(risk: string): string {
    if (risk === RiskLevel.FORBIDDEN) {
      return '不能吃';
    }
    if (risk === RiskLevel.CAUTION) {
      return '谨慎 / 限量';
    }
    return '可以吃（适量）';
  }

  build() {
    Scroll() {
      Column() {
        Text('食物安全速查')
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .margin({ bottom: 12 })

        Row() {
          TextInput({ text: this.keyword, placeholder: '输入食物名称，如 葡萄' })
            .layoutWeight(1)
            .fontSize(14)
            .backgroundColor($r('app.color.card_bg'))
            .onChange((value: string) => {
              this.keyword = value;
            })
            .onSubmit(() => {
              this.search();
            })
          Button('查一下')
            .fontSize(14)
            .backgroundColor($r('app.color.brand'))
            .margin({ left: 8 })
            .onClick(() => {
              this.search();
            })
        }
        .width('100%')

        Row() {
          Button('📷 拍照识别')
            .fontSize(14)
            .backgroundColor($r('app.color.brand_light'))
            .fontColor($r('app.color.brand'))
            .layoutWeight(1)
            .onClick(() => {
              this.takePhoto();
            })
        }
        .width('100%')
        .margin({ top: 10 })

        Text('选好照片后，系统会提示画面里有没有食物；具体是哪种食物由你点选确认，再查本地知识库。' +
          '照片只保存在本机，不会上传。')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
          .width('100%')

        if (this.photoPicked && this.imageUri.length > 0) {
          Column() {
            Row() {
              Text('确认照片里的食物')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Text('收起')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => {
                  this.photoPicked = false;
                })
            }
            .width('100%')

            Image(PhotoService.toDisplayUri(this.imageUri))
              .width('100%')
              .height(160)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .margin({ top: 10 })

            Text(this.photoHint)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 8 })
              .width('100%')

            Row() {
              TextInput({ text: this.photoQuery, placeholder: '输入照片里的食物，如 葡萄' })
                .layoutWeight(1)
                .fontSize(14)
                .onChange((value: string) => {
                  this.photoQuery = value;
                })
                .onSubmit(() => {
                  this.confirmPhotoFood(this.photoQuery);
                })
              Button('确认')
                .fontSize(14)
                .backgroundColor($r('app.color.brand'))
                .margin({ left: 8 })
                .onClick(() => {
                  this.confirmPhotoFood(this.photoQuery);
                })
            }
            .width('100%')
            .margin({ top: 10 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(QUICK_NAMES, (name: string) => {
                Text(name)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.page_bg'))
                  .borderRadius(14)
                  .margin({ right: 8, top: 8 })
                  .onClick(() => {
                    this.confirmPhotoFood(name);
                  })
              }, (name: string) => `photo_${name}`)
            }
            .width('100%')

            Row() {
              Text('换一张照片')
                .fontSize(13)
                .fontColor($r('app.color.brand'))
                .onClick(() => {
                  this.takePhoto();
                })
              Text('不用照片，直接搜')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 20 })
                .onClick(() => {
                  this.photoPicked = false;
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('100%')
          .padding(16)
          .margin({ top: 10 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.card_radius'))
          .alignItems(HorizontalAlign.Start)
        }

        Text('常见高风险食物')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .margin({ top: 16, bottom: 8 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(QUICK_NAMES, (name: string) => {
            Text(name)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(14)
              .margin({ right: 8, top: 8 })
              .onClick(() => {
                const item = findFoodInText(name);
                if (item !== undefined) {
                  this.showFood(item);
                  this.saveLog(item);
                }
              })
          }, (name: string) => name)
        }
        .width('100%')

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor($r('app.color.risk_mid'))
            .margin({ top: 12 })
            .width('100%')
        }

        if (this.current !== undefined) {
          Column() {
            Row() {
              Text(this.current.name)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Text(this.riskText(this.current.risk))
                .fontSize(13)
                .fontColor(Color.White)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.riskColor(this.current.risk))
                .borderRadius(12)
            }
            .width('100%')

            Text(this.answerText)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 10 })
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .margin({ top: 12 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.card_radius'))
          .border({ width: 1, color: this.riskColor(this.current.risk) })
        }

        if (this.logs.length > 0) {
          Text('最近的查询')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ top: 20, bottom: 8 })

          ForEach(this.logs.slice(0, 8), (log: FoodLog) => {
            Row() {
              Text(log.foodName)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Text(formatShortDateTime(log.createdAt))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
            .onClick(() => {
              const item = foodById(log.foodName.length > 0 ? this.idByName(log.foodName) : '');
              if (item !== undefined) {
                this.showFood(item);
              }
            })
          }, (log: FoodLog) => log.id)
        }

        Text('以上内容仅供科普参考，不能替代执业兽医的诊断与治疗。误食后请立即联系兽医。')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 20, bottom: 24 })
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

  private idByName(name: string): string {
    const item = findFoodInText(name);
    return item !== undefined ? item.id : '';
  }
}
