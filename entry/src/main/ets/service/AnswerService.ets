import { DISCLAIMER, Pet, RiskLevel } from '../model/Models';
import { petAgeText, speciesText } from '../common/DateUtil';
import {
  CARE_TOPICS,
  CareTopic,
  EMERGENCY_KEYWORDS,
  WARNING_KEYWORDS,
  hitAnyKeyword,
  matchTopic
} from '../data/CareKnowledge';
import { FoodItem, findFoodInText, foodById } from '../data/FoodKnowledge';

/**
 * 问答引擎。
 * 全部答案都来自应用内置的知识库与规则，输出的是预置文案：
 * 不接入任何生成式模型，应用也不声明网络权限，所以不存在 AI 生成合成内容。
 * 顺序很重要——安全相关的问题绝不能交给概率模型自由发挥。
 */

/** 答案的出处，界面上要原样标给用户看 */
export enum AnswerSource {
  /** 食物安全知识库 */
  FOOD = 'food',
  /** 养宠科普知识库 */
  CARE = 'care',
  /** 急诊提示 */
  EMERGENCY = 'emergency',
  /** 建议就诊 */
  WARNING = 'warning',
  /** 知识库没有覆盖 */
  FALLBACK = 'fallback'
}

export interface AnswerResult {
  text: string;
  /** 是否为需要立即就医的紧急情况 */
  emergency: boolean;
  /** AnswerSource 的值 */
  source: string;
  /** 命中的话题 id，便于追问与排查 */
  topicId: string;
}

export function sourceLabel(source: string): string {
  if (source === AnswerSource.FOOD) {
    return '食物安全知识库';
  }
  if (source === AnswerSource.CARE) {
    return '养宠科普知识库';
  }
  if (source === AnswerSource.EMERGENCY) {
    return '急诊关键词 · 立即就医提示';
  }
  if (source === AnswerSource.WARNING) {
    return '就诊提示';
  }
  return '知识库未覆盖';
}

function fillTemplate(template: string, pet: Pet | undefined): string {
  if (pet === undefined) {
    return template
      .replace('{name}', '你的宠物')
      .replace('{species}', '宠物')
      .replace('{age}', '年龄未知')
      .replace('{weight}', '体重未知')
      .replace('{breed}', '');
  }
  const weightText = pet.weightKg > 0 ? `${pet.weightKg}` : '未记录';
  return template
    .replace('{name}', pet.name.length > 0 ? pet.name : '你的宠物')
    .replace('{species}', speciesText(pet.species))
    .replace('{age}', petAgeText(pet.birthday))
    .replace('{weight}', weightText)
    .replace('{breed}', pet.breed.length > 0 ? pet.breed : '');
}

function petProfileText(pet: Pet | undefined): string {
  if (pet === undefined) {
    return '（尚未建立宠物档案）';
  }
  const parts: string[] = [];
  parts.push(`${speciesText(pet.species)}「${pet.name}」`);
  if (pet.breed.length > 0) {
    parts.push(pet.breed);
  }
  parts.push(petAgeText(pet.birthday));
  if (pet.weightKg > 0) {
    parts.push(`${pet.weightKg}kg`);
  }
  if (pet.sterilized) {
    parts.push('已绝育');
  }
  if (pet.allergy.length > 0) {
    parts.push(`过敏：${pet.allergy}`);
  }
  if (pet.chronic.length > 0) {
    parts.push(`既往问题：${pet.chronic}`);
  }
  return parts.join('，');
}

function riskLabel(risk: string): string {
  if (risk === RiskLevel.FORBIDDEN) {
    return '⛔ 不能吃';
  }
  if (risk === RiskLevel.CAUTION) {
    return '⚠️ 谨慎 / 限量';
  }
  return '✅ 可以吃（适量）';
}

function emergencyAnswer(question: string, pet: Pet | undefined): AnswerResult {
  const name = pet !== undefined && pet.name.length > 0 ? pet.name : '宠物';
  const text = `⚠️ 这可能是需要立即处理的情况，请不要在家等待观察。\n\n` +
    `请马上联系你的兽医或 24 小时宠物急诊，并在电话里说明：${question}\n\n` +
    `去医院的路上准备好这些信息，能显著加快处置：\n` +
    `1. 误食物 / 毒物的名称、包装或照片，以及大概的量；\n` +
    `2. 发生时间，到现在多久了；\n` +
    `3. ${name}的体重、年龄和有无基础病；\n` +
    `4. 已经出现的症状和开始时间。\n\n` +
    `不要自行催吐，也不要喂牛奶、油或任何"解毒"偏方——有些处理会加重损伤。`;
  return { text: text, emergency: true, source: AnswerSource.EMERGENCY, topicId: 'emergency' };
}

function foodAnswer(item: FoodItem, pet: Pet | undefined, question: string): AnswerResult {
  const profile = pet !== undefined ? `${pet.name}（${petProfileText(pet)}）` : '你的宠物';
  let speciesNote = '';
  if (item.species === 'dog' && pet !== undefined && pet.species === 'cat') {
    speciesNote = '\n\n备注：这一条主要来自犬的资料，猫同样建议避免。';
  } else if (item.species === 'cat' && pet !== undefined && pet.species === 'dog') {
    speciesNote = '\n\n备注：这一条主要来自猫的资料，犬也建议避免。';
  }
  const text = `【${item.name}】${riskLabel(item.risk)}\n\n` +
    `${item.summary}\n\n` +
    `原因：${item.detail}\n\n` +
    `建议：${item.advice}` +
    `${speciesNote}\n\n` +
    `参考：${item.source}\n` +
    `对象：${profile}`;
  const emergency = item.risk === RiskLevel.FORBIDDEN && hitAnyKeyword(question, ['误食', '吃了', '吞了']);
  return { text: text, emergency: emergency, source: AnswerSource.FOOD, topicId: `food_${item.id}` };
}

function careAnswer(topic: CareTopic, pet: Pet | undefined): AnswerResult {
  const profile = pet !== undefined ? `\n\n档案参考：${petProfileText(pet)}` : '';
  const followText = topic.followUps.length > 0 ? `\n\n还可以问：${topic.followUps.join(' / ')}` : '';
  const text = `${fillTemplate(topic.answer, pet)}${profile}${followText}`;
  return { text: text, emergency: false, source: AnswerSource.CARE, topicId: topic.id };
}

function warningAnswer(question: string, pet: Pet | undefined): AnswerResult {
  const name = pet !== undefined && pet.name.length > 0 ? pet.name : '宠物';
  const text = `你描述的这些表现，靠线上问答判断不了具体原因，建议尽快带去兽医检查。\n\n` +
    `去之前先记录好这几项，医生会很需要：\n` +
    `1. ${name}今天吃了几顿、吃了多少、喝水是否正常；\n` +
    `2. 排便排尿的次数和形态（最好拍照）；\n` +
    `3. 症状从什么时候开始、有没有加重；\n` +
    `4. 最近有没有换粮、换环境、接触其他动物或误食可能。\n\n` +
    `如果症状持续超过 24 小时，或出现精神明显变差、不吃不喝，请不要再等。`;
  return { text: text, emergency: false, source: AnswerSource.WARNING, topicId: 'warning' };
}

function fallbackAnswer(pet: Pet | undefined): AnswerResult {
  const samples: string[] = ['每天喂多少', '驱虫和疫苗怎么安排', '软便怎么处理', '猫乱尿怎么办'];
  const text = `这个问题不在应用内置的知识库里，我不编答案，换一种问法可能更准确。\n\n` +
    `知识库里有这些话题：\n` +
    samples.map((s: string) => `· ${s}`).join('\n') +
    `\n\n也可以直接问具体食物，例如"狗能吃葡萄吗"，我会给出明确的能吃 / 不能吃结论。` +
    (pet !== undefined ? `\n\n当前档案：${petProfileText(pet)}` : '');
  return { text: text, emergency: false, source: AnswerSource.FALLBACK, topicId: 'fallback' };
}

export class AnswerService {
  /**
   * 主入口：按规则在本地知识库里查找答案，查不到就如实说明。
   * 顺序不可调换，急诊判断永远排在最前面。
   */
  static ask(pet: Pet | undefined, question: string): AnswerResult {
    const trimmed = question.trim();
    if (trimmed.length === 0) {
      return fallbackAnswer(pet);
    }

    // 1. 急诊关键词
    if (hitAnyKeyword(trimmed, EMERGENCY_KEYWORDS)) {
      const food = findFoodInText(trimmed);
      if (food !== undefined && (trimmed.indexOf('能吃') >= 0 || trimmed.indexOf('可以吃') >= 0)) {
        return foodAnswer(food, pet, trimmed);
      }
      return emergencyAnswer(trimmed, pet);
    }

    // 2. 食物安全（带明确判定的知识库）
    const food = findFoodInText(trimmed);
    if (food !== undefined) {
      return foodAnswer(food, pet, trimmed);
    }

    // 3. 需要就诊但不紧急
    if (hitAnyKeyword(trimmed, WARNING_KEYWORDS)) {
      const topic = matchTopic(trimmed);
      if (topic !== undefined && topic.id !== 'no_appetite') {
        return careAnswer(topic, pet);
      }
      return warningAnswer(trimmed, pet);
    }

    // 4. 常规科普话题
    const topic = matchTopic(trimmed);
    if (topic !== undefined) {
      return careAnswer(topic, pet);
    }

    return fallbackAnswer(pet);
  }

  /** 食物页直接调用：给定食物 id 返回结论 */
  static explainFood(foodId: string, pet: Pet | undefined): AnswerResult {
    const item = foodById(foodId);
    if (item === undefined) {
      return fallbackAnswer(pet);
    }
    return foodAnswer(item, pet, '');
  }

  static profileText(pet: Pet | undefined): string {
    return petProfileText(pet);
  }

  static topicTitle(topicId: string): string {
    for (let i = 0; i < CARE_TOPICS.length; i++) {
      if (CARE_TOPICS[i].id === topicId) {
        return CARE_TOPICS[i].title;
      }
    }
    return '';
  }

  static disclaimer(): string {
    return DISCLAIMER;
  }
}
