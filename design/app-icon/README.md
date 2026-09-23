# 爪心 · 品牌与图标

## 名字

**爪心**（zhuǎ xīn）：取"爪印 + 心形掌垫"，和图标一一对应——名字即图形，这是最难被抄的组合。

改名前查过的记录（2026-09-11，华为应用市场网页版 + 应用宝 + 必应）：

- 「小鸿宠物」：应用市场与应用宝均无同名；但"小X宠物"格式已被小佩宠物、小慧宠物占据，辨识度低
- 「灵宠」：宠物行业里已有灵宠优品、灵宠科技、河南灵宠智能科技、四川灵宠口袋等公司字号，以及 QPET灵宠、爱它灵宠、赛博灵宠、灵宠大陆等品牌/App，商标风险高，弃用
- 「爪心」：应用市场无同名；仅有一家 2014 年的"杭州爪心电子商务"小微企业，不在宠物赛道

> 应用市场名称最终以华为审核为准；正式上架前建议再查中国商标网第 9/42 类（APP）与第 31/44 类（宠物服务），并准备软著。

## 图形

标记 = 四个脚趾（**爪**）+ 心形掌垫（**心**）+ 一点高光 + 右上角的星火（AI）。

配色取自应用内的品牌色：底 `#FFB77F → #FF8A5B → #ED6534`，主体 `#FFFFFF → #FFF7F4 → #FFE6D8`。
整体倾斜 8°，主体占画布约 63%，落在系统圆角遮罩的安全区内。

**几何只有一处来源**：`mark_geometry.py`。图标前景层、应用内品牌素材、主题封面都从它取，
改比例只需改这一个文件，然后重跑脚本。

## 三个方案

| 方案 | 文件 | 想法 | 小尺寸表现 |
| --- | --- | --- | --- |
| A 爪心（定稿） | 由 `mark_geometry.py` 生成 | 爪 + 心 + 星火 | 最好，44px 仍认得出 |
| B 对话猫 | `concept-b-chat-cat.svg` | 会回答问题的毛孩子 | 104px 清楚，64px 开始糊 |
| C 爱心毛孩子 | `concept-c-heart-pet.svg` | 猫耳 + 狗耳合成一颗心 | 尚可，易看成狐狸 |

对照图见 `out/contact-sheet.png`（每行一个方案，依次是圆角遮罩、圆形遮罩、104px、64px）。

## 应用内的品牌视觉

| 素材 | 用在哪 |
| --- | --- |
| `brand_icon.png` | 冷启动封面、我的 → 关于卡片 |
| `brand_mark_cream.png` | 首页品牌封面（橙底用奶白爪印） |
| `brand_mark_orange.png` | 桌面卡片标题前的小标、白底场景 |
| `out/store-cover.png` | 应用市场 / 分享用的 1080×1920 主题封面 |
| `out/store-216.png` | 应用市场要求的小图标 |

对应界面：

- **冷启动封面**（`pages/Index.ets`）：与系统启动窗口同底色 `#FFF7F4`，图标 + 名字 + slogan，520ms 后淡出
- **首页品牌封面**（`view/HomeTab.ets`）：橙色渐变卡片，奶白爪印 + 名字 + slogan + 日期
- **关于卡片**（`view/PetTab.ets`）：圆角图标 + 版本号
- **桌面卡片**（`widget/pages/WidgetCard.ets`）：标题前 14px 的橙色爪印

## 目录

```
design/app-icon/
├── mark_geometry.py          标记几何唯一来源（图标前景 / 品牌素材 / 封面都取这里）
├── background.svg            图标底色层：暖橙渐变 + 左上柔光
├── concept-b-chat-cat.svg    备选方案
├── concept-c-heart-pet.svg   备选方案
├── store-cover-bg.svg        主题封面底层（页面底色 + 主视觉卡片）
├── store-cover-text.svg      主题封面文字层（名字 / slogan / 卖点 / 页脚）
├── render.py                 渲染 + 生成对照图
├── apply_icon.py             把选定的图标方案写进工程资源
├── brand_assets.py           生成应用内品牌素材 + 主题封面 + 市场图标
├── render/                   中间 HTML（可删）
├── out/                      渲染结果：图标、品牌标记、主题封面、对照图
└── original/                 替换前的 DevEco 模板图标（备份）
```

## 怎么用

```powershell
$py = "C:\Users\31690\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

# 1) 看三个方案长什么样（生成 out/contact-sheet.png）
& $py design\app-icon\render.py

# 2) 把图标写进工程资源（默认方案 a；b / c 会同时替换分层图标的前景层）
& $py design\app-icon\apply_icon.py --concept a

# 3) 重新生成应用内品牌素材、主题封面、市场图标
& $py design\app-icon\brand_assets.py
```

渲染用 Edge（Chromium）无头截图，透明背景靠 `--default-background-color=00000000`；
合成、缩放、圆角遮罩用 Pillow。脚本只写 `design/` 和下面这些资源文件，不动业务代码。

## 资源落地位置

| 文件 | 用途 | 规格 |
| --- | --- | --- |
| `AppScope/resources/base/media/foreground.png` | 分层图标前景层 | 1024×1024，透明 |
| `AppScope/resources/base/media/background.png` | 分层图标底色层 | 1024×1024 |
| `AppScope/resources/base/media/app_icon.png` | 备用合成图 | 1024×1024 |
| `entry/src/main/resources/base/media/foreground.png` | 同上（模块级） | 1024×1024，透明 |
| `entry/src/main/resources/base/media/background.png` | 同上（模块级） | 1024×1024 |
| `entry/src/main/resources/base/media/startIcon.png` | 启动窗口图标 | 144×144，圆角透明 |
| `entry/src/main/resources/base/media/brand_icon.png` | 应用内圆角图标 | 256×256，圆角透明 |
| `entry/src/main/resources/base/media/brand_mark_cream.png` | 奶白爪印 | 256×256，透明 |
| `entry/src/main/resources/base/media/brand_mark_orange.png` | 橙色爪印 | 256×256，透明 |

`layered_image.json` 通过 `$media:foreground` / `$media:background` 引用前两层，改文件名要同步改这个 json。

## 查重名的小工具

`design/tools/page-text.mjs` 用 CDP 驱动 Edge 打印某个页面渲染后的正文，
应用市场是 SPA，普通 HTTP 抓不到内容时用它：

```powershell
node design\tools\page-text.mjs "https://appgallery.huawei.com/search/爪心" 9000
```

## 上架前还可以再补

- 应用市场要求的 3-5 张功能截图（用同一套配色加标题条）
- 节日/活动的换色版封面（改 `brand_assets.py` 里的 `PALETTES` 即可）
- 商标检索与软著登记
