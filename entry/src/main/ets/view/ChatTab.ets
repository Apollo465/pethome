import { AnswerResult, AnswerService, sourceLabel } from '../service/AnswerService';
import { PetStore } from '../data/PetStore';
import { ChatMessage, DISCLAIMER, Pet } from '../model/Models';
import { formatTime } from '../common/DateUtil';
import { CareTopic, suggestedTopics } from '../data/CareKnowledge';

@Component
export struct ChatTab {
  @StorageLink('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State messages: ChatMessage[] = [];
  @State input: string = '';
  @State thinking: boolean = false;
  @State hasPet: boolean = false;
  @State petName: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    const store = PetStore.get();
    const pet: Pet | undefined = store.getCurrentPet();
    this.hasPet = pet !== undefined;
    this.petName = pet !== undefined ? pet.name : '';
    if (pet === undefined) {
      // 没有档案时提问照样能用，记录挂在空 petId 下，别让它们切个页就消失
      this.messages = store.getMessagesByPet('');
      return;
    }
    this.messages = store.getMessagesByPet(pet.id);
    this.scrollToBottom();
  }

  scrollToBottom(): void {
    if (this.messages.length > 0) {
      this.scroller.scrollEdge(Edge.Bottom);
    }
  }

  private append(role: string, text: string, emergency: boolean, source: string): void {
    const pet = PetStore.get().getCurrentPet();
    const message: ChatMessage = {
      id: `${Date.now()}_${Math.random()}`,
      petId: pet !== undefined ? pet.id : '',
      role: role,
      text: text,
      timeMs: Date.now(),
      emergency: emergency,
      source: source
    };
    PetStore.get().appendMessage(message);
    this.messages = PetStore.get().getMessagesByPet(message.petId);
  }

  send(text: string): void {
    const question = text.trim();
    if (question.length === 0 || this.thinking) {
      return;
    }
    const pet = PetStore.get().getCurrentPet();
    this.input = '';
    this.append('user', question, false, '');
    this.thinking = true;
    this.scrollToBottom();
    try {
      const answer: AnswerResult = AnswerService.ask(pet, question);
      this.append('assistant', answer.text, answer.emergency, answer.source);
    } catch (err) {
      this.append('assistant', '抱歉，查找这条问题时出错了，请稍后再试。', false, '');
    }
    this.thinking = false;
    this.scrollToBottom();
  }

  @Builder
  Bubble(item: ChatMessage) {
    Column() {
      if (item.role !== 'user' && item.source !== undefined && item.source.length > 0) {
        // 内容出处显式标注：答案来自哪一本知识库、是不是模型生成，用户一眼能看到
        Text(`来源：${sourceLabel(item.source)}（预置内容）`)
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 6 })
      }
      Text(item.text)
        .fontSize(14)
        .fontColor(item.role === 'user' ? Color.White : $r('app.color.text_primary'))
        .textAlign(TextAlign.Start)
      Text(formatTime(item.timeMs))
        .fontSize(10)
        .fontColor(item.role === 'user' ? '#FFE6DA' : $r('app.color.text_secondary'))
        .margin({ top: 6 })
    }
    .padding(12)
    .backgroundColor(item.role === 'user'
      ? $r('app.color.brand')
      : (item.emergency ? '#FDECEA' : $r('app.color.card_bg')))
    .borderRadius(12)
    .border(item.emergency ? { width: 1, color: $r('app.color.risk_high') } : { width: 0 })
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ top: 8 })
  }

  build() {
    Column() {
      List({ scroller: this.scroller }) {
        ListItem() {
          Column() {
            Text(this.hasPet
              ? `已结合「${this.petName}」的档案回答`
              : '还没有宠物档案，回答无法个性化，建议先去"我的"添加')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.brand_light'))
              .borderRadius(10)

            Text('答案全部来自应用内置的本地知识库（预置文案），不接入生成式 AI，应用也不联网，提问不会上传。')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 8 })
              .width('100%')

            if (this.messages.length === 0) {
              Text('可以问我：')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 16 })
                .width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(suggestedTopics(), (topic: CareTopic) => {
                  Text(topic.title)
                    .fontSize(12)
                    .fontColor($r('app.color.brand'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor($r('app.color.brand_light'))
                    .borderRadius(14)
                    .margin({ right: 8, top: 8 })
                    .onClick(() => {
                      this.send(topic.title);
                    })
                }, (topic: CareTopic) => topic.id)
              }
              .width('100%')
            }

            ForEach(this.messages, (item: ChatMessage) => {
              this.Bubble(item)
            }, (item: ChatMessage) => item.id)

            if (this.thinking) {
              Text('正在查本地知识库…')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 12 })
                .width('100%')
            }
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .padding({ left: 16, right: 16, top: 8 })

      Column() {
        Row() {
          TextInput({ text: this.input, placeholder: '描述你的问题，例如：狗能吃葡萄吗' })
            .layoutWeight(1)
            .fontSize(14)
            .backgroundColor($r('app.color.page_bg'))
            .onChange((value: string) => {
              this.input = value;
            })
            .onSubmit(() => {
              this.send(this.input);
            })
          Button('发送')
            .fontSize(14)
            .backgroundColor($r('app.color.brand'))
            .margin({ left: 8 })
            .onClick(() => {
              this.send(this.input);
            })
        }
        .width('100%')

        if (this.messages.length > 0) {
          Text('清空对话')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .onClick(() => {
              const pet = PetStore.get().getCurrentPet();
              if (pet !== undefined) {
                PetStore.get().clearMessages(pet.id);
                this.reload();
              }
            })
        }

        Text(DISCLAIMER)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8, bottom: 8 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.card_bg'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
