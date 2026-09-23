import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AccountInfo, ChatMessage, FoodLog, Pet, ReminderItem } from '../model/Models';

const DOMAIN = 0x0000;
const TAG = 'PetStore';
const STORE_NAME = 'pethome_store';

const KEY_PETS = 'pets';
const KEY_CURRENT_PET = 'current_pet';
const KEY_REMINDERS = 'reminders';
const KEY_MESSAGES = 'messages';
const KEY_FOOD_LOGS = 'food_logs';
const KEY_FORM_IDS = 'form_ids';
const KEY_ACCOUNT = 'account';

const MAX_MESSAGES = 200;
const MAX_FOOD_LOGS = 100;

export class PetStore {
  private static instance: PetStore | undefined = undefined;
  private prefs: preferences.Preferences | undefined = undefined;
  private appContext: common.Context | undefined = undefined;

  static get(): PetStore {
    if (PetStore.instance === undefined) {
      PetStore.instance = new PetStore();
    }
    return PetStore.instance;
  }

  /** 由 EntryAbility / FormExtensionAbility 在启动时注入上下文 */
  init(context: common.Context): void {
    if (this.prefs !== undefined) {
      return;
    }
    this.appContext = context;
    try {
      this.prefs = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init preferences failed: %{public}s', JSON.stringify(err) ?? '');
      this.prefs = undefined;
    }
  }

  private readString(key: string, defValue: string): string {
    if (this.prefs === undefined) {
      return defValue;
    }
    try {
      const value: string = this.prefs.getSync(key, defValue) as string;
      return value;
    } catch (err) {
      return defValue;
    }
  }

  private writeString(key: string, value: string): void {
    if (this.prefs === undefined) {
      return;
    }
    try {
      this.prefs.putSync(key, value);
      this.prefs.flushSync();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'write failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  // ---------------- 宠物档案 ----------------

  getPets(): Pet[] {
    const raw = this.readString(KEY_PETS, '[]');
    try {
      return JSON.parse(raw) as Pet[];
    } catch (err) {
      return [];
    }
  }

  private savePets(list: Pet[]): void {
    this.writeString(KEY_PETS, JSON.stringify(list));
  }

  getPet(id: string): Pet | undefined {
    const list = this.getPets();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return undefined;
  }

  savePet(pet: Pet): void {
    const list = this.getPets();
    let found = false;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === pet.id) {
        list[i] = pet;
        found = true;
        break;
      }
    }
    if (!found) {
      list.push(pet);
    }
    this.savePets(list);
    if (this.getCurrentPetId().length === 0) {
      this.setCurrentPetId(pet.id);
    }
  }

  deletePet(id: string): void {
    const list = this.getPets();
    const rest: Pet[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== id) {
        rest.push(list[i]);
      }
    }
    this.savePets(rest);

    const reminders = this.getReminders();
    const keep: ReminderItem[] = [];
    for (let i = 0; i < reminders.length; i++) {
      if (reminders[i].petId !== id) {
        keep.push(reminders[i]);
      }
    }
    this.saveReminders(keep);

    if (this.getCurrentPetId() === id) {
      this.setCurrentPetId(rest.length > 0 ? rest[0].id : '');
    }
  }

  getCurrentPetId(): string {
    return this.readString(KEY_CURRENT_PET, '');
  }

  setCurrentPetId(id: string): void {
    this.writeString(KEY_CURRENT_PET, id);
  }

  getCurrentPet(): Pet | undefined {
    const id = this.getCurrentPetId();
    if (id.length === 0) {
      const list = this.getPets();
      return list.length > 0 ? list[0] : undefined;
    }
    return this.getPet(id);
  }

  // ---------------- 提醒 ----------------

  getReminders(): ReminderItem[] {
    const raw = this.readString(KEY_REMINDERS, '[]');
    try {
      return JSON.parse(raw) as ReminderItem[];
    } catch (err) {
      return [];
    }
  }

  saveReminders(list: ReminderItem[]): void {
    this.writeString(KEY_REMINDERS, JSON.stringify(list));
  }

  saveReminder(item: ReminderItem): void {
    const list = this.getReminders();
    let found = false;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === item.id) {
        list[i] = item;
        found = true;
        break;
      }
    }
    if (!found) {
      list.push(item);
    }
    this.saveReminders(list);
  }

  deleteReminder(id: string): void {
    const list = this.getReminders();
    const rest: ReminderItem[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== id) {
        rest.push(list[i]);
      }
    }
    this.saveReminders(rest);
  }

  // ---------------- 对话记录 ----------------

  getMessages(): ChatMessage[] {
    const raw = this.readString(KEY_MESSAGES, '[]');
    try {
      return JSON.parse(raw) as ChatMessage[];
    } catch (err) {
      return [];
    }
  }

  getMessagesByPet(petId: string): ChatMessage[] {
    const all = this.getMessages();
    const result: ChatMessage[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].petId === petId) {
        result.push(all[i]);
      }
    }
    return result;
  }

  appendMessage(message: ChatMessage): void {
    const all = this.getMessages();
    all.push(message);
    while (all.length > MAX_MESSAGES) {
      all.shift();
    }
    this.writeString(KEY_MESSAGES, JSON.stringify(all));
  }

  clearMessages(petId: string): void {
    const all = this.getMessages();
    const rest: ChatMessage[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].petId !== petId) {
        rest.push(all[i]);
      }
    }
    this.writeString(KEY_MESSAGES, JSON.stringify(rest));
  }

  // ---------------- 食物记录 ----------------

  getFoodLogs(): FoodLog[] {
    const raw = this.readString(KEY_FOOD_LOGS, '[]');
    try {
      return JSON.parse(raw) as FoodLog[];
    } catch (err) {
      return [];
    }
  }

  appendFoodLog(log: FoodLog): void {
    const all = this.getFoodLogs();
    all.unshift(log);
    while (all.length > MAX_FOOD_LOGS) {
      all.pop();
    }
    this.writeString(KEY_FOOD_LOGS, JSON.stringify(all));
  }

  // ---------------- 卡片 id ----------------

  // ---------------- 账号 ----------------

  /** 当前登录账号；未登录返回 undefined */
  getAccount(): AccountInfo | undefined {
    const raw = this.readString(KEY_ACCOUNT, '');
    if (raw.length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(raw) as AccountInfo;
    } catch (err) {
      return undefined;
    }
  }

  saveAccount(account: AccountInfo): void {
    this.writeString(KEY_ACCOUNT, JSON.stringify(account));
  }

  clearAccount(): void {
    this.writeString(KEY_ACCOUNT, '');
  }

  /**
   * 清除本机保存的全部用户数据（档案、照片、对话、记录、提醒）。
   * 隐私同意状态由平台的隐私声明托管服务管理，这里不碰。
   */
  clearAllData(): void {
    this.writeString(KEY_PETS, '[]');
    this.writeString(KEY_CURRENT_PET, '');
    this.writeString(KEY_REMINDERS, '[]');
    this.writeString(KEY_MESSAGES, '[]');
    this.writeString(KEY_FOOD_LOGS, '[]');
    this.writeString(KEY_FORM_IDS, '[]');
    this.clearPhotos();
  }

  /** 删除沙箱里保存的宠物照片 */
  private clearPhotos(): void {
    const context = this.appContext;
    if (context === undefined) {
      return;
    }
    try {
      const dir = `${context.filesDir}/photos`;
      if (!fileIo.accessSync(dir)) {
        return;
      }
      const names = fileIo.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        try {
          fileIo.unlinkSync(`${dir}/${names[i]}`);
        } catch (err) {
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'clear photos failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  getFormIds(): string[] {
    const raw = this.readString(KEY_FORM_IDS, '[]');
    try {
      return JSON.parse(raw) as string[];
    } catch (err) {
      return [];
    }
  }

  addFormId(formId: string): void {
    const ids = this.getFormIds();
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      this.writeString(KEY_FORM_IDS, JSON.stringify(ids));
    }
  }

  removeFormId(formId: string): void {
    const ids = this.getFormIds();
    const rest: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      if (ids[i] !== formId) {
        rest.push(ids[i]);
      }
    }
    this.writeString(KEY_FORM_IDS, JSON.stringify(rest));
  }
}
