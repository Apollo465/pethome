const WEEK_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

export function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 格式化为 yyyy-MM-dd */
export function formatDate(ms: number): string {
  const d = new Date(ms);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

/** 「9月11日」，给首页封面用 */
export function formatCnMonthDay(ms: number): string {
  const d = new Date(ms);
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}

/** 「周五」 */
export function formatCnWeek(ms: number): string {
  const d = new Date(ms);
  return `周${WEEK_LABELS[d.getDay()]}`;
}

/** 格式化为 HH:mm */
export function formatTime(ms: number): string {
  const d = new Date(ms);
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

/** 格式化为 MM-dd HH:mm */
export function formatShortDateTime(ms: number): string {
  const d = new Date(ms);
  return `${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

export function todayKey(): string {
  return formatDate(Date.now());
}

/** 把 yyyy-MM-dd 解析为当天 00:00 的时间戳，失败返回 0 */
export function parseDateStr(text: string): number {
  if (text.length < 10) {
    return 0;
  }
  const parts: string[] = text.split('-');
  if (parts.length !== 3) {
    return 0;
  }
  const year = Number.parseInt(parts[0], 10);
  const month = Number.parseInt(parts[1], 10);
  const day = Number.parseInt(parts[2], 10);
  if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)) {
    return 0;
  }
  return new Date(year, month - 1, day, 0, 0, 0).getTime();
}

/** 根据生日生成“2岁3个月”这样的描述 */
export function petAgeText(birthday: string): string {
  const born = parseDateStr(birthday);
  if (born <= 0) {
    return '年龄未知';
  }
  const now = new Date();
  const birth = new Date(born);
  let months = (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
  if (now.getDate() < birth.getDate()) {
    months -= 1;
  }
  if (months < 0) {
    return '年龄未知';
  }
  const years = Math.floor(months / 12);
  const restMonths = months % 12;
  if (years <= 0) {
    return `${restMonths}个月`;
  }
  if (restMonths === 0) {
    return `${years}岁`;
  }
  return `${years}岁${restMonths}个月`;
}

export function speciesText(species: string): string {
  if (species === 'cat') {
    return '猫';
  }
  if (species === 'dog') {
    return '狗';
  }
  return '宠物';
}

export function kindText(kind: string): string {
  if (kind === 'vaccine') {
    return '疫苗';
  }
  if (kind === 'deworm') {
    return '驱虫';
  }
  if (kind === 'bath') {
    return '洗澡';
  }
  if (kind === 'medicine') {
    return '喂药';
  }
  if (kind === 'checkup') {
    return '体检';
  }
  return '其他';
}

export function repeatText(repeatDays: number[]): string {
  if (repeatDays.length === 0) {
    return '仅一次';
  }
  if (repeatDays.length === 7) {
    return '每天';
  }
  let text = '每周 ';
  for (let i = 0; i < repeatDays.length; i++) {
    text += `${WEEK_LABELS[repeatDays[i]]} `;
  }
  return text;
}

/** 计算提醒的下一次触发时间 */
export function nextTriggerTime(dateTime: number, repeatDays: number[]): number {
  if (repeatDays.length === 0) {
    return dateTime;
  }
  const base = new Date(dateTime);
  const now = Date.now();
  if (dateTime > now) {
    return dateTime;
  }
  for (let offset = 0; offset < 14; offset++) {
    const candidate = new Date(now);
    candidate.setDate(candidate.getDate() + offset);
    candidate.setHours(base.getHours(), base.getMinutes(), 0, 0);
    if (candidate.getTime() <= now) {
      continue;
    }
    if (repeatDays.indexOf(candidate.getDay()) >= 0) {
      return candidate.getTime();
    }
  }
  return dateTime;
}

/** 系统代理提醒用的 daysOfWeek：1-7 对应周一到周日 */
export function toSystemWeekDays(repeatDays: number[]): number[] {
  const result: number[] = [];
  for (let i = 0; i < repeatDays.length; i++) {
    const day = repeatDays[i];
    result.push(day === 0 ? 7 : day);
  }
  return result;
}

/**
 * 选择星期用的短标签，下标与 repeatDays 一致：0=周日 ... 6=周六。
 * 之前这里返回的是 ['', '周一', ...]，页面用 [day + 1] 取值，
 * 导致周一被当成周日，整排按钮错位一天。
 */
const DAY_SHORT_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

export function weekDayLabels(): string[] {
  return DAY_SHORT_LABELS;
}
