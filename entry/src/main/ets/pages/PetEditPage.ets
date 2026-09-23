import { common } from '@kit.AbilityKit';
import { PetStore } from '../data/PetStore';
import { Pet, ReminderItem, Species } from '../model/Models';
import { formatDate, parseDateStr, petAgeText } from '../common/DateUtil';
import { PhotoService } from '../service/PhotoService';
import { ReminderService } from '../service/ReminderService';
import { bumpDataVersion } from '../common/AppState';
import { refreshCard } from '../service/CardService';

@Entry
@Component
struct PetEditPage {
  @State petId: string = '';
  @State isNew: boolean = true;
  @State name: string = '';
  @State species: string = Species.CAT;
  @State breed: string = '';
  @State birthday: string = '';
  @State weightText: string = '';
  @State allergy: string = '';
  @State chronic: string = '';
  @State sterilized: boolean = false;
  @State avatarUri: string = '';
  @State createdAt: number = 0;
  @State ageText: string = '';
  @State pickerDate: Date = new Date();

  aboutToAppear(): void {
    let targetId = '';
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
      if (params !== undefined && params !== null) {
        const value = params['petId'];
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
    const pet: Pet | undefined = PetStore.get().getPet(targetId);
    if (pet === undefined) {
      return;
    }
    this.petId = pet.id;
    this.isNew = false;
    this.name = pet.name;
    this.species = pet.species;
    this.breed = pet.breed;
    this.birthday = pet.birthday;
    this.weightText = pet.weightKg > 0 ? `${pet.weightKg}` : '';
    this.allergy = pet.allergy;
    this.chronic = pet.chronic;
    this.sterilized = pet.sterilized;
    this.avatarUri = pet.avatarUri;
    this.createdAt = pet.createdAt;
    this.ageText = petAgeText(pet.birthday);
    const parsed = parseDateStr(pet.birthday);
    if (parsed > 0) {
      this.pickerDate = new Date(parsed);
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
    }
  }

  private updateAge(): void {
    this.ageText = this.birthday.length > 0 ? petAgeText(this.birthday) : '';
  }

  private async pickAvatar(): Promise<void> {
    const uri = await PhotoService.pickImage();
    if (uri.length === 0) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.Context;
    // 文件名带上时间戳：同一只宠物换照片时不会命中 Image 的旧缓存
    const id = this.isNew ? 'new' : this.petId;
    const path = PhotoService.importToSandbox(context, uri, `pet_${id}_${Date.now()}`);
    if (path.length === 0) {
      this.toast('照片保存失败，请重试');
      return;
    }
    const previous = this.avatarUri;
    this.avatarUri = path;
    if (previous.length > 0 && previous !== path) {
      PhotoService.removeSandboxFile(previous);
    }
  }

  private async save(): Promise<void> {
    if (this.name.trim().length === 0) {
      this.toast('请先给它起个名字');
      return;
    }
    const weight = Number.parseFloat(this.weightText);
    const pet: Pet = {
      id: this.isNew ? `pet_${Date.now()}` : this.petId,
      name: this.name.trim(),
      species: this.species,
      breed: this.breed.trim(),
      birthday: this.birthday,
      weightKg: Number.isNaN(weight) ? 0 : weight,
      avatarUri: this.avatarUri,
      allergy: this.allergy.trim(),
      chronic: this.chronic.trim(),
      sterilized: this.sterilized,
      createdAt: this.isNew ? Date.now() : this.createdAt
    };
    PetStore.get().savePet(pet);
    // 新建时自动切到新宠物；编辑别的宠物不要偷偷改掉当前宠物
    if (this.isNew) {
      PetStore.get().setCurrentPetId(pet.id);
    }
    bumpDataVersion();
    await refreshCard();
    this.toast(this.isNew ? '档案已创建' : '档案已更新');
    this.getUIContext().getRouter().back();
  }

  @Builder
  SpeciesChip(value: string, label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.species === value ? Color.White : $r('app.color.text_primary'))
      .backgroundColor(this.species === value ? $r('app.color.brand') : $r('app.color.page_bg'))
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .borderRadius(18)
      .margin({ right: 10 })
      .onClick(() => {
        this.species = value;
      })
  }

  @Builder
  FieldLabel(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .margin({ top: 14, bottom: 6 })
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
          Text(this.isNew ? '新建档案' : '编辑档案')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('保存')
            .fontSize(14)
            .fontColor($r('app.color.brand'))
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })

        Column() {
          Row() {
            if (this.avatarUri.length > 0) {
              Image(PhotoService.toDisplayUri(this.avatarUri))
                .width(72)
                .height(72)
                .borderRadius(36)
                .objectFit(ImageFit.Cover)
            } else {
              Text(this.species === Species.DOG ? '🐶' : '🐱')
                .fontSize(30)
                .width(72)
                .height(72)
                .textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.brand_light'))
                .borderRadius(36)
            }
            Column() {
              Text('宠物照片')
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
              Text('照片只保存在本机')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
              Text('选择照片')
                .fontSize(13)
                .fontColor($r('app.color.brand'))
                .margin({ top: 6 })
                .onClick(() => {
                  this.pickAvatar();
                })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 16 })
          }
          .width('100%')

          this.FieldLabel('名字')
          TextInput({ text: this.name, placeholder: '例如：豆豆' })
            .fontSize(14)
            .onChange((value: string) => {
              this.name = value;
            })

          this.FieldLabel('种类')
          Row() {
            this.SpeciesChip(Species.CAT, '猫')
            this.SpeciesChip(Species.DOG, '狗')
            this.SpeciesChip(Species.OTHER, '其他')
          }
          .width('100%')

          this.FieldLabel('品种（选填）')
          TextInput({ text: this.breed, placeholder: '例如：英短、柯基' })
            .fontSize(14)
            .onChange((value: string) => {
              this.breed = value;
            })

          this.FieldLabel(this.ageText.length > 0 ? `生日 · ${this.ageText}` : '生日')
          Row() {
            Text(this.birthday.length > 0 ? this.birthday : '未设置')
              .fontSize(14)
              .fontColor(this.birthday.length > 0 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
              .layoutWeight(1)
            Text('选择')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
              .onClick(() => {
                this.getUIContext().showDatePickerDialog({
                  start: new Date(1990, 0, 1),
                  end: new Date(),
                  selected: this.pickerDate,
                  onDateAccept: (value: Date) => {
                    this.pickerDate = value;
                    this.birthday = formatDate(value.getTime());
                    this.updateAge();
                  }
                });
              })
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.page_bg'))
          .borderRadius(10)
          .alignItems(VerticalAlign.Center)

          this.FieldLabel('体重（kg）')
          TextInput({ text: this.weightText, placeholder: '例如：4.2' })
            .type(InputType.NUMBER_DECIMAL)
            .fontSize(14)
            .onChange((value: string) => {
              this.weightText = value;
            })

          this.FieldLabel('过敏史（选填）')
          TextInput({ text: this.allergy, placeholder: '例如：某品牌粮、鸡肉' })
            .fontSize(14)
            .onChange((value: string) => {
              this.allergy = value;
            })

          this.FieldLabel('既往病史（选填）')
          TextInput({ text: this.chronic, placeholder: '例如：皮肤敏感、慢性肾病' })
            .fontSize(14)
            .onChange((value: string) => {
              this.chronic = value;
            })

          Row() {
            Text('已绝育')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.sterilized })
              .selectedColor($r('app.color.brand'))
              .onChange((isOn: boolean) => {
                this.sterilized = isOn;
              })
          }
          .width('100%')
          .margin({ top: 16 })

          if (!this.isNew) {
            Button('删除这只宠物')
              .width('100%')
              .fontSize(15)
              .backgroundColor('#FDECEA')
              .fontColor($r('app.color.risk_high'))
              .margin({ top: 24 })
              .onClick(() => {
                this.getUIContext().showAlertDialog({
                  title: '删除档案',
                  message: `删除「${this.name}」的档案和它的提醒？此操作无法撤销。`,
                  primaryButton: {
                    value: '取消',
                    action: () => {
                    }
                  },
                  secondaryButton: {
                    value: '删除',
                    fontColor: $r('app.color.risk_high'),
                    action: () => {
                      this.doDelete();
                    }
                  }
                });
              })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.card_radius'))

        Text('名字、生日和体重是问答给出个性化建议的依据，填得越准，回答越贴合。')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12, bottom: 24 })
          .width('100%')
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
    const store = PetStore.get();
    // 先把这只宠物的系统代理提醒注销掉，否则删了档案提醒还会照常弹出
    const reminders: ReminderItem[] = store.getReminders();
    for (let i = 0; i < reminders.length; i++) {
      if (reminders[i].petId === this.petId) {
        await ReminderService.cancel(reminders[i].systemReminderId);
      }
    }
    store.deletePet(this.petId);
    bumpDataVersion();
    await refreshCard();
    this.getUIContext().getRouter().back();
  }
}
