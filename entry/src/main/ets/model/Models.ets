/**
 * 爪心 —— 数据模型定义
 * 所有数据默认只保存在本机（preferences + 应用沙箱），不联网。
 */

export enum Species {
  CAT = 'cat',
  DOG = 'dog',
  OTHER = 'other'
}

export enum RiskLevel {
  /** 绝对禁食 */
  FORBIDDEN = 'forbidden',
  /** 谨慎 / 少量 / 需处理 */
  CAUTION = 'caution',
  /** 可以吃（仍需适量） */
  SAFE = 'safe'
}

export enum ReminderKind {
  VACCINE = 'vaccine',
  DEWORM = 'deworm',
  BATH = 'bath',
  MEDICINE = 'medicine',
  CHECKUP = 'checkup',
  OTHER = 'other'
}

export interface Pet {
  id: string;
  name: string;
  /** Species 的值 */
  species: string;
  breed: string;
  /** yyyy-MM-dd，允许为空串 */
  birthday: string;
  weightKg: number;
  /** 沙箱内的图片路径，允许为空串 */
  avatarUri: string;
  allergy: string;
  chronic: string;
  sterilized: boolean;
  createdAt: number;
}

export interface ReminderItem {
  id: string;
  petId: string;
  /** ReminderKind 的值 */
  kind: string;
  title: string;
  note: string;
  /** 首次提醒时间（毫秒时间戳） */
  dateTime: number;
  /** 重复的星期，0=周日 ... 6=周六；空数组表示只提醒一次 */
  repeatDays: number[];
  enabled: boolean;
  /** 系统代理提醒返回的 id，-1 表示未注册 */
  systemReminderId: number;
  /** 最近一次完成日期 yyyy-MM-dd */
  lastDoneDate: string;
}

export interface FoodLog {
  id: string;
  petId: string;
  foodName: string;
  /** RiskLevel 的值 */
  risk: string;
  imageUri: string;
  createdAt: number;
}

export interface ChatMessage {
  id: string;
  petId: string;
  /** 'user' | 'assistant' */
  role: string;
  text: string;
  timeMs: number;
  emergency: boolean;
  /** 回答的出处（AnswerSource 的值），用户发的消息为空串 */
  source?: string;
}

/**
 * 登录后的账号信息。
 * 目前只在本机保存：华为账号返回的 openID / unionID 用于标识用户，
 * 昵称与头像用于界面展示，不向我们的服务器上传任何内容（应用本身不联网）。
 */
export interface AccountInfo {
  /** 华为账号在开放平台下的唯一标识（同一开发者帐号下唯一） */
  unionId: string;
  /** 华为账号在本应用下的唯一标识 */
  openId: string;
  nickName: string;
  avatarUri: string;
  /** 是否已记录完成真实身份核验（华为账号为实名账号，登录即完成核验） */
  realNameVerified: boolean;
  /** 登录时间（毫秒时间戳） */
  loginAtMs: number;
}

export function emptyPet(): Pet {
  return {
    id: '',
    name: '',
    species: Species.CAT,
    breed: '',
    birthday: '',
    weightKg: 0,
    avatarUri: '',
    allergy: '',
    chronic: '',
    sterilized: false,
    createdAt: 0
  };
}

export const DISCLAIMER: string = '以上内容仅供科普参考，不能替代执业兽医的诊断与治疗。';
