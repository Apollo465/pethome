import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CardSnapshot, buildTodaySnapshot } from '../service/CardService';
import { PetStore } from '../data/PetStore';

const DOMAIN = 0x0000;
const TAG = 'PetHomeForm';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onAddForm');
    PetStore.get().init(this.context);
    // 记录卡片 id，之后数据变化时才能主动刷新它
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
    if (formId !== undefined && formId.length > 0) {
      PetStore.get().addFormId(formId);
    }
    const snapshot: CardSnapshot = buildTodaySnapshot();
    return formBindingData.createFormBindingData(snapshot);
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onCastToNormalForm: %{public}s', formId);
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm: %{public}s', formId);
    PetStore.get().init(this.context);
    const snapshot: CardSnapshot = buildTodaySnapshot();
    try {
      formProvider.updateForm(formId, formBindingData.createFormBindingData(snapshot));
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'update form failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'onChangeFormVisibility');
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent: %{public}s %{public}s', formId, message);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm: %{public}s', formId);
    PetStore.get().removeFormId(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
