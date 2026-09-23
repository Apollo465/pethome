import { objectDetection, visionBase } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'VisionService';
/** 端侧模型对输入分辨率有限制，手机原图动辄上千万像素，先缩到这个尺寸再送进去 */
const MAX_SIDE = 1280; 

/**
 * 视觉能力说明（务必对用户诚实）：
 * 系统提供的端点检测只能判断画面里"有没有食物/猫狗"，
 * 不能识别具体是哪种食物。具体食物一律由用户确认后查本地知识库判定。
 *
 * 另外：这是端侧 AI 能力，是否可用取决于机型和系统版本（模型资源可能缺失、引擎可能异常）。
 * 所以它的结果只是"提示"，任何情况下都不能挡住后面的手动确认流程。
 */
export interface VisionResult {
  /** 这次系统检测是否真的跑完了 */
  ran: boolean;
  /** 设备是否声明支持该能力 */
  supported: boolean;
  /** 是否检测到食物 */
  hasFood: boolean;
  /** 是否检测到猫或狗 */
  hasPet: boolean;
  /** 检测到的物体总数 */
  objectCount: number;
  /** 给用户看的一句话：不管哪种结果，都要能继续往下走 */
  message: string;
}

const LABEL_FOOD = 11;
const LABEL_CAT_HEAD = 9;
const LABEL_DOG_HEAD = 10;
const LABEL_ANIMAL = 1;

/** 取检测器的结果：detector 为空表示没取到，code 是系统错误码 */
interface DetectorResult {
  detector?: objectDetection.ObjectDetector;
  code: number;
}

function notRan(message: string, supported: boolean): VisionResult {
  return {
    ran: false,
    supported: supported,
    hasFood: false,
    hasPet: false,
    objectCount: 0,
    message: message
  };
}

export class VisionService {
  static isSupported(): boolean {
    try {
      return canIUse('SystemCapability.AI.Vision.ObjectDetection');
    } catch (err) {
      return false;
    }
  }

  /**
   * 解码成像素图。先按最长边缩到 MAX_SIDE 再送进模型：
   * 原图直接解码既占内存，也容易让端侧模型超时或跑失败。
   * 缩放失败就退回原尺寸，不影响后面的流程。
   */
  private static async decode(source: image.ImageSource): Promise<image.PixelMap> {
    let width = 0;
    let height = 0;
    try {
      const info: image.ImageInfo = await source.getImageInfo();
      width = info.size.width;
      height = info.size.height;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'read image info failed: %{public}s', JSON.stringify(err) ?? '');
    }
    const longest = width > height ? width : height;
    if (longest > MAX_SIDE) {
      const scale = MAX_SIDE / longest;
      const options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(width * scale)),
          height: Math.max(1, Math.round(height * scale))
        },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      try {
        return await source.createPixelMap(options);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'scaled decode failed, use origin size: %{public}s', JSON.stringify(err) ?? '');
      }
    }
    return await source.createPixelMap();
  }

  /**
   * 取检测器实例。端侧服务偶发"服务异常"（1011000001 / 1011000002），
   * 同一进程里再要一次实例基本能恢复，所以最多试两次；
   * 两次都不行就把失败原因带回去，由调用方降级到手动确认。
   */
  private static async createDetector(): Promise<DetectorResult> {
    let lastCode = -1;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const detector = await objectDetection.ObjectDetector.create();
        return { detector: detector, code: 0 };
      } catch (err) {
        const error = err as BusinessError;
        lastCode = error.code;
        hilog.warn(DOMAIN, TAG, 'create detector failed (%{public}d): %{public}s',
          attempt, JSON.stringify(error) ?? '');
      }
    }
    return { code: lastCode };
  }

  /**
   * 分析沙箱中的图片。
   * 任何一步不成功都不再抛给界面一句"暂不可用"，
   * 而是返回 ran=false + 一句能继续操作的说明，由界面接着让用户点选食物。
   */
  static async analyze(sandboxPath: string): Promise<VisionResult> {
    if (!VisionService.isSupported()) {
      return notRan('这台设备没有提供系统图像检测，请直接点选照片里的食物，查询结果一样准确', false);
    }
    let detector: objectDetection.ObjectDetector | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(sandboxPath, fileIo.OpenMode.READ_ONLY);
      const source = image.createImageSource(file.fd);
      pixelMap = await VisionService.decode(source);
      await source.release();
      const created: DetectorResult = await VisionService.createDetector();
      if (created.detector === undefined) {
        return notRan('系统图像检测这次没能用上，请直接点选照片里的食物，查询结果一样准确', true);
      }
      detector = created.detector;
      const request = new visionBase.Request();
      const imageData: visionBase.ImageData = { pixelMap: pixelMap };
      request.inputData = imageData;
      const response = await detector.process(request);
      let hasFood = false;
      let hasPet = false;
      const objects = response.objects;
      for (let i = 0; i < objects.length; i++) {
        const labels = objects[i].labels;
        for (let j = 0; j < labels.length; j++) {
          if (labels[j] === LABEL_FOOD) {
            hasFood = true;
          }
          if (labels[j] === LABEL_CAT_HEAD || labels[j] === LABEL_DOG_HEAD || labels[j] === LABEL_ANIMAL) {
            hasPet = true;
          }
        }
      }
      const message = hasFood
        ? '系统检测：画面里有食物，请点选确认具体是哪一种'
        : '系统检测：画面里没有明显的食物；如果照片里有，请直接点选确认';
      return {
        ran: true,
        supported: true,
        hasFood: hasFood,
        hasPet: hasPet,
        objectCount: objects.length,
        message: message
      };
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'vision analyze failed: %{public}s', JSON.stringify(err) ?? '');
      return notRan('系统图像检测这次没能用上，请直接点选照片里的食物，查询结果一样准确', true);
    } finally {
      if (detector !== undefined) {
        try {
          await detector.destroy();
        } catch (err) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (err) {
        }
      }
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (err) {
        }
      }
    }
  }
}
