import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AccountInfo } from '../model/Models';
import { PetStore } from '../data/PetStore';

const DOMAIN = 0x0000;
const TAG = 'AuthService';

/**
 * 是否强制登录后使用。
 *
 * 当前为 false：应用打开即用，不需要账号。
 * 原因：应用内已无生成式 AI，不提供信息发布 / 即时通讯 / 合成生成内容服务，
 * 法规不要求做用户真实身份信息核验；不登录才能保持"无网络能力"的单机形态，
 * 备案信息可按"单机 APP"填写。
 *
 * 若将来要做账号体系（例如恢复云端 AI、或做多端同步），需要先完成 APP 备案
 * （个人主体需有已 ICP 备案的域名 / 服务器），再把这里改成 true，
 * 并在 AGC 开通华为账号服务、填写 client_id（见 module.json5 里的注释）。
 */
export const REQUIRE_LOGIN: boolean = false;

export interface LoginOutcome {
  ok: boolean;
  message: string;
}

/** 华为账号登录的错误码翻译成人话，便于开发者定位与用户理解 */
function describeLoginError(error: BusinessError): string {
  const code = error.code;
  if (code === 1001502001) {
    return '本机还没有登录华为账号，请先在系统「设置 → 华为账号」里登录后再试';
  }
  if (code === 1001500001) {
    return '应用签名校验失败，请使用正式签名包（或在 AGC 配置对应的应用证书指纹）';
  }
  if (code === 1001502002) {
    return '应用未获华为账号授权：请在 AGC 开通「华为账号」服务，并确认签名证书指纹与 AGC 配置一致';
  }
  if (code === 1001502003) {
    return '华为账号登录参数校验失败：通常是 AGC 尚未开通「华为账号」服务，或 module.json5 里的 client_id 没填对';
  }
  if (code === 1001502014) {
    return '应用未开通华为账号登录能力，请先在 AGC 开通并填写 client_id';
  }
  if (code === 1001500003) {
    return '应用申请的权限（scope）未开通，请先在 AGC 申请';
  }
  if (code === 1001502012) {
    return '已取消登录';
  }
  return `华为账号登录失败（错误码 ${code}）`;
}

/**
 * 账号与真实身份核验。
 *
 * 本应用要求先登录后使用，登录方式为华为账号：
 * 华为账号本身是实名账号（注册与使用均需完成实名认证），
 * 因此登录即完成《网络安全法》要求的用户真实身份信息核验。
 *
 * 注意：登录态与账号信息只保存在本机，应用不会把用户数据上传到服务器；
 * 华为账号登录由系统服务完成，应用自身不发起网络请求。
 */
export class AuthService {
  static current(): AccountInfo | undefined {
    return PetStore.get().getAccount();
  }

  static isLoggedIn(): boolean {
    const account: AccountInfo | undefined = AuthService.current();
    return account !== undefined && account.unionId.length > 0;
  }

  /** 华为账号登录（首次登录会拉起华为账号登录页） */
  static async login(context: common.UIAbilityContext): Promise<LoginOutcome> {
    try {
      const provider = new authentication.HuaweiIDProvider();
      const request = provider.createLoginWithHuaweiIDRequest();
      // 未登录华为账号时拉起登录页；登录成功后由系统返回本应用可用的用户标识
      request.forceLogin = true;
      request.state = `pethome_${Date.now()}`;
      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(request) as authentication.LoginWithHuaweiIDResponse;
      const credential: authentication.LoginWithHuaweiIDCredential | undefined = response.data;
      if (credential === undefined) {
        return { ok: false, message: '华为账号没有返回登录凭据，请重试' };
      }
      const unionId: string = credential.unionID !== undefined ? credential.unionID : '';
      const openId: string = credential.openID !== undefined ? credential.openID : '';
      if (unionId.length === 0 && openId.length === 0) {
        return { ok: false, message: '华为账号没有返回用户标识，请重试' };
      }
      const account: AccountInfo = {
        unionId: unionId.length > 0 ? unionId : openId,
        openId: openId,
        nickName: '',
        avatarUri: '',
        realNameVerified: true,
        loginAtMs: Date.now()
      };
      PetStore.get().saveAccount(account);
      hilog.info(DOMAIN, TAG, 'huawei id login ok');
      return { ok: true, message: '登录成功' };
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'huawei id login failed: %{public}s', JSON.stringify(error) ?? '');
      return { ok: false, message: describeLoginError(error) };
    }
  }

  /** 退出登录：只清掉本机登录态，不动用户数据 */
  static signOut(): void {
    PetStore.get().clearAccount();
  }

  /** 注销账号：清掉本机全部数据 + 登录态（账号由华为账号体系管理，应用侧不留任何副本） */
  static deleteAccount(): void {
    PetStore.get().clearAllData();
    PetStore.get().clearAccount();
  }

  /** 用于界面展示的脱敏标识 */
  static maskedId(): string {
    const account: AccountInfo | undefined = AuthService.current();
    if (account === undefined) {
      return '';
    }
    const id = account.unionId.length > 0 ? account.unionId : account.openId;
    if (id.length <= 8) {
      return id;
    }
    return `${id.substring(0, 4)}****${id.substring(id.length - 4)}`;
  }
}
