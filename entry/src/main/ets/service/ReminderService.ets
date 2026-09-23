import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReminderItem } from '../model/Models';
import { PetStore } from '../data/PetStore';
import { nextTriggerTime, toSystemWeekDays } from '../common/DateUtil';

const DOMAIN = 0x0000;
const TAG = 'ReminderService';
const BUNDLE_NAME = 'com.pethome.xiaohong';
const ABILITY_NAME = 'EntryAbility';

/**
 * 系统代理提醒没能注册的原因。
 * 分类型是因为不同的原因要给用户不同的下一步动作，
 * 而不是一句"提醒设置失败"就把人挡回去。
 */
export enum ReminderFailReason {
  /** 注册成功 */
  NONE = 'none',
  /** 系统通知开关没开 */
  NOTIFICATION_OFF = 'notification_off',
  /** 系统代理提醒条数达到上限 */
  LIMIT = 'limit',
  /** 没有代理提醒权限 */
  PERMISSION = 'permission',
  /** 时间、重复等参数系统不接受 */
  PARAM = 'param',
  /** 其它原因（低概率的机型 / 系统问题） */
  UNKNOWN = 'unknown'
}

export interface ReminderResult {
  ok: boolean;
  /** 系统代理提醒的 id，未注册时为 -1 */
  systemId: number;
  /** 系统返回的错误码，成功时为 0，本机校验不通过时为 -1 */
  code: number;
  /** 给用户看的说明：只讲现状和下一步，不用"失败"这类让人以为数据丢了的说法 */
  message: string;
  reason: ReminderFailReason;
  /** true 表示原因是"系统通知没开"，界面要提供一键开启入口 */
  needNotification: boolean;
}

/** 提醒与通知的当前状态，「我的」页面用它给出可操作的提示 */
export interface ReminderState {
  notificationOn: boolean;
  total: number;
  registered: number;
  pending: number;
}

function okResult(systemId: number): ReminderResult {
  return {
    ok: true,
    systemId: systemId,
    code: 0,
    message: '提醒已保存，到点会通知你',
    reason: ReminderFailReason.NONE,
    needNotification: false
  };
}

function failResult(code: number, reason: ReminderFailReason, message: string,
  needNotification: boolean): ReminderResult {
  return {
    ok: false,
    systemId: -1,
    code: code,
    message: message,
    reason: reason,
    needNotification: needNotification
  };
}

/**
 * 通知 id 要和提醒一一对应：文档里"相同 id 号的提醒会覆盖"，
 * 都留默认值 0 的话后建的提醒会把先建的顶掉。
 * 这里用提醒 id 算一个稳定的号，重新保存同一条提醒时用的还是同一个号。
 */
function notificationIdOf(reminderId: string): number {
  let hash = 0;
  for (let i = 0; i < reminderId.length; i++) {
    hash = (hash * 31 + reminderId.charCodeAt(i)) % 90000;
  }
  return hash + 10000;
}

/** 系统错误码翻译成人话，见 @ohos.reminderAgentManager 的 publishReminder 说明 */
function describeError(error: BusinessError): ReminderResult {
  const code = error.code;
  if (code === 1700001) {
    return failResult(code, ReminderFailReason.NOTIFICATION_OFF,
      '系统通知没有打开，到点不会弹出来', true);
  }
  if (code === 1700002) {
    return failResult(code, ReminderFailReason.LIMIT,
      '系统代理提醒已经排满（每个应用最多 30 条），删掉不用的提醒再试一次', false);
  }
  if (code === 201) {
    return failResult(code, ReminderFailReason.PERMISSION,
      '系统没有给「爪心」代理提醒权限，重新安装应用后再试一次', false);
  }
  if (code === 401) {
    return failResult(code, ReminderFailReason.PARAM,
      '这条提醒的时间或重复设置系统不接受，换一个时间再试一次', false);
  }
  if (code === 1700007) {
    return failResult(code, ReminderFailReason.PARAM,
      '这条提醒的设置系统不接受，换一个时间或换个提醒类型再试一次', false);
  }
  return failResult(code, ReminderFailReason.UNKNOWN,
    `系统代理提醒暂时没能注册（错误码 ${code}）`, false);
}

export class ReminderService {
  /** 通知渠道只需要建一次，进程内缓存结果，避免每次保存都白跑一趟系统调用 */
  private static slotReady: boolean = false;

  /** 通知未开启时的标准结果，页面用它统一提示 */
  static notificationOffResult(): ReminderResult {
    return failResult(1700001, ReminderFailReason.NOTIFICATION_OFF,
      '系统通知没有打开，到点不会弹出来', true);
  }

  /** 系统通知是否已开启。查询失败时按"已开启"处理，交给发布流程去报错 */
  static async notificationEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'query notification state failed: %{public}s', JSON.stringify(err) ?? '');
      return true;
    }
  }

  /**
   * 申请通知授权，返回最终的通知开关状态。
   * 系统通知没开时发布代理提醒会直接失败（错误码 1700001），所以必须先确认这一步。
   */
  static async ensureNotificationEnabled(context: common.UIAbilityContext): Promise<boolean> {
    if (await ReminderService.notificationEnabled()) {
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(context);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'request notification failed: %{public}s', JSON.stringify(err) ?? '');
    }
    return await ReminderService.notificationEnabled();
  }

  /** 打开系统通知设置页，用户可以在里面手动允许「爪心」发通知 */
  static async openNotificationSettings(context: common.UIAbilityContext): Promise<void> {
    try {
      await notificationManager.openNotificationSettings(context);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'open notification settings failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  /**
   * 建好提醒要用的通知渠道。
   * 部分机型上渠道不存在时发布代理提醒会直接抛错，所以每次注册前都确认一次；
   * 建失败也不拦流程，交给 publishReminder 去暴露真正的原因。
   */
  static async ensureSlot(): Promise<void> {
    if (ReminderService.slotReady) {
      return;
    }
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      ReminderService.slotReady = true;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'add notification slot failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  /**
   * 单次发布：rich=true 时带上按钮、响铃与稍后提醒这些锦上添花的字段，
   * rich=false 时只留最少字段，用于第一次被系统拒绝后的兜底重试。
   */
  private static async publish(item: ReminderItem, triggerMs: number, rich: boolean): Promise<ReminderResult> {
    const date = new Date(triggerMs);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: date.getFullYear(),
        month: date.getMonth() + 1,
        day: date.getDate(),
        hour: date.getHours(),
        minute: date.getMinutes()
      },
      title: item.title.length > 0 ? item.title : '养宠提醒',
      content: item.note.length > 0 ? item.note : '该给毛孩子安排上了',
      notificationId: notificationIdOf(item.id),
      wantAgent: {
        pkgName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      }
    };
    if (rich) {
      request.expiredContent = '这条提醒已经过期，打开应用查看详情';
      request.snoozeContent = '稍后再提醒';
      request.ringDuration = 5;
      // snoozeTimes 必须配上 timeInterval：系统要求间隔不少于 30 秒，
      // 只给次数不给间隔会被当成参数不合法直接拒掉（1700007）。
      request.snoozeTimes = 2;
      request.timeInterval = 300;
      request.actionButton = [
        {
          title: '已完成',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ];
    }
    const weekDays = toSystemWeekDays(item.repeatDays);
    if (weekDays.length > 0) {
      request.daysOfWeek = weekDays;
    }
    try {
      const id = await reminderAgentManager.publishReminder(request);
      hilog.info(DOMAIN, TAG, 'reminder published: %{public}d', id);
      return okResult(id);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'publish failed (rich=%{public}s): %{public}s',
        rich ? 'true' : 'false', JSON.stringify(error) ?? '');
      return describeError(error);
    }
  }

  /**
   * 注册系统代理提醒：即使 App 没在运行也会按时提醒。
   *
   * 这里不再"一失败就返回失败"：先按完整参数注册，被系统拒绝时用最精简的参数再试一次。
   * 两次都没成也会把具体原因（通知没开 / 条数排满 / 权限 / 参数）带回去，
   * 由页面告诉用户下一步怎么做；提醒本身已经落库，不会丢。
   */
  static async register(item: ReminderItem): Promise<ReminderResult> {
    if (!await ReminderService.notificationEnabled()) {
      return ReminderService.notificationOffResult();
    }
    await ReminderService.ensureSlot();

    // 系统只接受将来的时间：重复提醒落到下一个符合的星期，一次性提醒过期就如实说明
    const trigger = nextTriggerTime(item.dateTime, item.repeatDays);
    if (item.repeatDays.length === 0 && trigger <= Date.now()) {
      return failResult(-1, ReminderFailReason.PARAM, '提醒时间已经过去，改成一个将来的时间再存一次', false);
    }

    const full = await ReminderService.publish(item, trigger, true);
    if (full.ok) {
      return full;
    }
    // 通知没开时重试也没用，直接如实返回
    if (full.reason === ReminderFailReason.NOTIFICATION_OFF) {
      return full;
    }
    // 额度排满：多半是历史版本/重装留下的孤儿提醒占着，先清掉再试一次
    if (full.reason === ReminderFailReason.LIMIT) {
      const pruned = await ReminderService.pruneOrphans();
      if (pruned === 0) {
        return full;
      }
      const afterPrune = await ReminderService.publish(item, trigger, true);
      return afterPrune;
    }
    const simple = await ReminderService.publish(item, trigger, false);
    if (simple.ok) {
      return simple;
    }
    return full.reason !== ReminderFailReason.UNKNOWN ? full : simple;
  }

  static async cancel(systemId: number): Promise<void> {
    if (systemId < 0) {
      return;
    }
    try {
      await reminderAgentManager.cancelReminder(systemId);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'cancel failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  /**
   * 清掉系统里"本机数据已经不认识"的孤儿提醒。
   *
   * 卸载重装、清除数据、跨版本升级都会留下这类残留：提醒还挂在系统里占着
   * "每个应用最多 30 条"的额度，应用里却看不到、也删不掉。
   * 遇到额度已满（1700002）时先清一遍，再重新注册，用户不用自己去找。
   * 返回清掉的条数。
   */
  private static async pruneOrphans(): Promise<number> {
    let removed = 0;
    try {
      const infos = await reminderAgentManager.getAllValidReminders();
      const known: number[] = [];
      const list = PetStore.get().getReminders();
      for (let i = 0; i < list.length; i++) {
        if (list[i].systemReminderId >= 0) {
          known.push(list[i].systemReminderId);
        }
      }
      for (let i = 0; i < infos.length; i++) {
        const id = infos[i].reminderId;
        if (known.indexOf(id) < 0) {
          await ReminderService.cancel(id);
          removed++;
        }
      }
      if (removed > 0) {
        hilog.info(DOMAIN, TAG, 'pruned orphan reminders: %{public}d', removed);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'prune reminders failed: %{public}s', JSON.stringify(err) ?? '');
    }
    return removed;
  }

  /**
   * 注销本应用注册过的全部系统代理提醒。
   * 「清除全部数据」「撤回同意」这类操作必须先调用它，
   * 否则提醒会留在系统里继续弹，还会占满「每个应用最多 30 条」的额度。
   */
  static async cancelAll(): Promise<void> {
    try {
      // 直接注销本应用在系统里注册过的全部代理提醒：
      // 应用数据被系统清理或重装过时，本机记录的 id 会丢，只有系统侧一次全销才清得干净，
      // 否则残留的提醒会一直占用「每个应用最多 30 条」的额度。
      await reminderAgentManager.cancelAllReminders();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'cancel all reminders failed: %{public}s', JSON.stringify(err) ?? '');
    }
    const list = PetStore.get().getReminders();
    for (let i = 0; i < list.length; i++) {
      list[i].systemReminderId = -1;
      PetStore.get().saveReminder(list[i]);
    }
  }

  /**
   * 把还没注册到系统代理的提醒补注册一次。
   * 用户在系统设置里打开通知后回到应用，提醒会自动生效，不用重新建一遍。
   */
  static async syncPending(): Promise<number> {
    if (!await ReminderService.notificationEnabled()) {
      return 0;
    }
    await ReminderService.ensureSlot();
    const store = PetStore.get();
    const list = store.getReminders();
    let registered = 0;
    for (let i = 0; i < list.length; i++) {
      const item = list[i];
      if (!item.enabled || item.systemReminderId >= 0) {
        continue;
      }
      // 一次性的过期提醒不再补注册，否则一打开应用就会补弹一条早就过去的提醒
      if (item.repeatDays.length === 0 && item.dateTime <= Date.now()) {
        continue;
      }
      const result = await ReminderService.register(item);
      if (result.ok) {
        item.systemReminderId = result.systemId;
        store.saveReminder(item);
        registered++;
      }
    }
    return registered;
  }

  /** 「我的」页面读取当前状态：通知开关、提醒总数、已注册数 */
  static async inspect(): Promise<ReminderState> {
    const list = PetStore.get().getReminders();
    let registered = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].enabled && list[i].systemReminderId >= 0) {
        registered++;
      }
    }
    return {
      notificationOn: await ReminderService.notificationEnabled(),
      total: list.length,
      registered: registered,
      pending: list.length - registered
    };
  }

  /**
   * 一键修复：先确认通知开关（没开就弹系统授权），再补注册所有待注册的提醒。
   * 返回这次补上的条数；调用方负责给用户反馈。
   */
  static async repair(context: common.UIAbilityContext): Promise<number> {
    const ready = await ReminderService.ensureNotificationEnabled(context);
    if (!ready) {
      return 0;
    }
    await ReminderService.ensureSlot();
    return await ReminderService.syncPending();
  }

  /**
   * 兜底重建：把系统里本应用的代理提醒全部注销，再按本机数据重新注册一遍。
   *
   * 用在系统侧提醒状态已经乱了的时候——例如额度被占满、提醒对不上、无法枚举出残留项。
   * 提醒内容都在本机数据库里，重建不会丢东西，只是换一批系统提醒 id。
   * 返回重新注册上的条数。
   */
  static async rebuildAll(context: common.UIAbilityContext): Promise<number> {
    await ReminderService.cancelAll();
    const ready = await ReminderService.ensureNotificationEnabled(context);
    if (!ready) {
      return 0;
    }
    await ReminderService.ensureSlot();
    return await ReminderService.syncPending();
  }
}
