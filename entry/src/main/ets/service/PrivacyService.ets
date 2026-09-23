import { privacyManager } from '@kit.AppGalleryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'PrivacyService';

/**
 * 平台隐私声明托管服务。
 *
 * 应用已接入该服务：首次启动由系统统一弹出标准隐私声明并记录同意结果，
 * 应用不再自行实现一份同意弹窗（审核意见 4：两个隐私弹窗影响体验）。
 * 应用内保留隐私政策页，用户可以阅读全文、删除本机数据或撤回同意。
 */
export class PrivacyService {
  /** 是否已接入平台隐私声明托管服务；未接入时接口会抛 1006700003 */
  static isServiceAvailable(): boolean {
    try {
      privacyManager.getAppPrivacyMgmtInfo();
      return true;
    } catch (err) {
      return false;
    }
  }

  /** 用户是否已经通过平台弹窗同意了隐私声明 */
  static hasAgreed(): boolean {
    try {
      const results: privacyManager.AppPrivacyResult[] = privacyManager.getAppPrivacyResult();
      for (let i = 0; i < results.length; i++) {
        if (results[i].result === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED) {
          return true;
        }
      }
      return false;
    } catch (err) {
      return false;
    }
  }

  /**
   * 撤回隐私同意：清掉平台侧的同意状态，
   * 下次启动应用时系统会重新弹出隐私声明。返回是否成功通知到平台。
   */
  static revoke(): boolean {
    try {
      privacyManager.disableService();
      return true;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'disable privacy service failed: %{public}s', JSON.stringify(err) ?? '');
      return false;
    }
  }
}
