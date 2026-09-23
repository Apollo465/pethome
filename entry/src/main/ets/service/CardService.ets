import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PetStore } from '../data/PetStore';
import { Pet, ReminderItem } from '../model/Models';
import { formatTime, nextTriggerTime, todayKey, kindText } from '../common/DateUtil';

const DOMAIN = 0x0000;
const TAG = 'CardService';

/** 卡片只接收扁平字段，规避卡片侧的类型转换问题 */
export interface CardSnapshot {
  title: string;
  petName: string;
  summary: string;
  item1: string;
  item2: string;
  item3: string;
  emptyText: string;
  updateText: string;
}

export interface TodayTask {
  id: string;
  timeText: string;
  label: string;
  timeMs: number;
}

/** 桌面卡片的同步结果，用来给用户明确的反馈，而不是点一下什么都不发生 */
export interface CardRefreshResult {
  /** 桌面上已添加的卡片数量，0 表示用户还没添加过卡片 */
  total: number;
  updated: number;
  failed: number;
}

function collectTodayTasks(pet: Pet | undefined): TodayTask[] {
  const store = PetStore.get();
  const all: ReminderItem[] = store.getReminders();
  const today = todayKey();
  const dayIndex = new Date().getDay();
  const tasks: TodayTask[] = [];
  for (let i = 0; i < all.length; i++) {
    const item = all[i];
    if (!item.enabled) {
      continue;
    }
    if (pet !== undefined && item.petId !== pet.id) {
      continue;
    }
    const trigger = nextTriggerTime(item.dateTime, item.repeatDays);
    const triggerDate = new Date(trigger);
    const isToday = triggerDate.getFullYear() === new Date().getFullYear()
      && triggerDate.getMonth() === new Date().getMonth()
      && triggerDate.getDate() === new Date().getDate();
    const repeatToday = item.repeatDays.length > 0 && item.repeatDays.indexOf(dayIndex) >= 0;
    if (!isToday && !repeatToday) {
      continue;
    }
    if (item.lastDoneDate === today) {
      continue;
    }
    tasks.push({
      id: item.id,
      timeText: formatTime(item.dateTime),
      label: `${kindText(item.kind)} · ${item.title}`,
      timeMs: item.dateTime
    });
  }
  tasks.sort((a: TodayTask, b: TodayTask) => a.timeMs - b.timeMs);
  return tasks;
}

export function buildTodaySnapshot(): CardSnapshot {
  const store = PetStore.get();
  const pet = store.getCurrentPet();
  const tasks = collectTodayTasks(pet);
  const petName = pet !== undefined && pet.name.length > 0 ? pet.name : '还没有宠物档案';
  let summary = '今天没有安排，安心摸鱼';
  if (tasks.length > 0) {
    summary = `今天有 ${tasks.length} 项要完成`;
  }
  const now = new Date();
  const updateText = `更新于 ${formatTime(now.getTime())}`;
  return {
    title: '今日养宠待办',
    petName: petName,
    summary: summary,
    item1: tasks.length > 0 ? `${tasks[0].timeText}  ${tasks[0].label}` : '',
    item2: tasks.length > 1 ? `${tasks[1].timeText}  ${tasks[1].label}` : '',
    item3: tasks.length > 2 ? `${tasks[2].timeText}  ${tasks[2].label}` : '',
    emptyText: tasks.length === 0 ? '点一下添加疫苗、驱虫提醒' : '',
    updateText: updateText
  };
}

export function todayTaskCount(): number {
  return collectTodayTasks(PetStore.get().getCurrentPet()).length;
}

/** 首页今日待办：带 id，便于打卡 */
export function todayTasks(): TodayTask[] {
  return collectTodayTasks(PetStore.get().getCurrentPet());
}

/** 打卡：把这一天标记为已完成，重复提醒会在下一个周期再次出现 */
export function markTaskDone(reminderId: string): void {
  const store = PetStore.get();
  const list: ReminderItem[] = store.getReminders();
  for (let i = 0; i < list.length; i++) {
    if (list[i].id === reminderId) {
      list[i].lastDoneDate = todayKey();
      store.saveReminder(list[i]);
      return;
    }
  }
}

/**
 * 数据变化后刷新所有桌面卡片。
 * 返回值告诉调用方"到底有没有卡片被刷新"，首页那个按钮要靠它给出反馈。
 */
export async function refreshCard(): Promise<CardRefreshResult> {
  const store = PetStore.get();
  const ids = store.getFormIds();
  const result: CardRefreshResult = { total: ids.length, updated: 0, failed: 0 };
  if (ids.length === 0) {
    return result;
  }
  const snapshot = buildTodaySnapshot();
  for (let i = 0; i < ids.length; i++) {
    try {
      const data = formBindingData.createFormBindingData(snapshot);
      await formProvider.updateForm(ids[i], data);
      result.updated++;
    } catch (err) {
      result.failed++;
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'update form failed: %{public}s', JSON.stringify(error) ?? '');
      // 卡片已经被用户从桌面删掉了：丢弃这条失效记录，避免以后每次都白试一遍
      if (error.code === 16501001 || error.code === 16501003) {
        store.removeFormId(ids[i]);
      }
    }
  }
  return result;
}
