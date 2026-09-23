const KEY_DATA_VERSION = 'dataVersion';

export function ensureAppStorage(): void {
  const current = AppStorage.get<number>(KEY_DATA_VERSION);
  if (current === undefined) {
    AppStorage.setOrCreate(KEY_DATA_VERSION, 0);
  }
}

/** 数据发生变更后调用，通知所有页面刷新 */
export function bumpDataVersion(): void {
  const current = AppStorage.get<number>(KEY_DATA_VERSION);
  const next = (current === undefined ? 0 : current) + 1;
  AppStorage.setOrCreate(KEY_DATA_VERSION, next);
}
