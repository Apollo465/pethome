import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'PhotoService';

export class PhotoService {
  /**
   * 用系统图片选择器选一张图。
   * 走选择器意味着不需要申请相册权限，用户主动选择哪张，我们才能读哪张。
   */
  static async pickImage(): Promise<string> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await picker.select(options);
      const uris = result.photoUris;
      if (uris.length === 0) {
        return '';
      }
      return uris[0];
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'pick image canceled or failed: %{public}s', JSON.stringify(err) ?? '');
      return '';
    }
  }

  /**
   * 把选中的图片复制到应用沙箱。
   * 好处有两个：一是权限到期后仍然能显示，二是照片始终留在本机。
   * 返回沙箱内的绝对路径，失败返回空串。
   */
  static importToSandbox(context: common.Context, sourceUri: string, fileName: string): string {
    if (sourceUri.length === 0) {
      return '';
    }
    try {
      const dir = `${context.filesDir}/photos`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
      const destPath = `${dir}/${fileName}.jpg`;
      const src = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      const dest = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.copyFileSync(src.fd, dest.fd);
      fileIo.closeSync(src);
      fileIo.closeSync(dest);
      return destPath;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'import failed: %{public}s', JSON.stringify(err) ?? '');
      return '';
    }
  }

  /** 供 ArkUI 的 Image 组件使用 */
  static toDisplayUri(sandboxPath: string): string {
    if (sandboxPath.length === 0) {
      return '';
    }
    return `file://${sandboxPath}`;
  }

  /** 换照片后把旧文件删掉，避免沙箱里越攒越多。失败不影响主流程 */
  static removeSandboxFile(sandboxPath: string): void {
    if (sandboxPath.length === 0) {
      return;
    }
    try {
      fileIo.unlinkSync(sandboxPath);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'remove file failed: %{public}s', JSON.stringify(err) ?? '');
    }
  }
}
