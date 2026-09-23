# 待上传材料包

这个文件夹里的东西就是提交应用市场时要用到的全部素材，按编号对应提交页面的栏目。

| 文件 | 用在哪 |
| --- | --- |
| 01-应用图标-216x216.png | AGC 应用信息 → 应用图标（216×216） |
| 02-截图-1..4.png | AGC 应用信息 → 应用截图（纯截图，未加装饰，至少 3 张） |
| 03-介绍图-1..4.png | 可选：推广位/宣传素材，带标题的版本 |
| 04-隐私政策-网页版.html | 需要先挂到公网，把网址填进 AGC「隐私政策网址」 |
| 05-市场文案.md | 一句话简介、应用介绍、版本特性，直接复制 |
| 06-上架清单.md | 提交前逐项自检 |
| 07-发布证书请求.csr | 在 AGC「证书管理 → 新增证书 → 发布证书」时上传这个文件，换回 .cer |
| 08-主题封面-1080x1920.png | 可选：活动/推广封面 |
| 09-审核备注（粘贴到AGC）.txt | 第二次提审时，粘到「版本信息 → 应用审核信息 → 备注」 |
| 10-审核意见逐条回复.md | 被驳回或申诉时作为材料提交 |

> ⚠️ 2026-09-15：01~03、08 这几张图是**改造前**的截图，画面里还有"AI 养宠问答"等旧文案，
> 提交前需要用新版本重新截图替换（新文案见 `05-市场文案.md`）。

## 关于 04 隐私政策网页

必须有公网可访问的网址，三个常见做法（都需要你自己的账号）：

1. **Gitee Pages**：新建公开仓库 → 上传 html → 服务 → Gitee Pages → 部署，得到 https://用户名.gitee.io/仓库名/privacy-policy.html
2. **GitHub Pages**：新建公开仓库 → 上传 html → Settings → Pages → 部署
3. **任意静态托管**：阿里云 OSS / 腾讯云 COS / 华为云 OBS 开启静态网站托管，上传 html

部署完把网址填到 AGC 的「隐私政策网址」，并确认应用内「我的 → 隐私政策」的内容与网页版一致（两处内容必须一致，这是审核硬性要求）。

## 关于 07 发布证书请求

本地已经生成好密钥库 `signing/release.p12`（口令 Zhuaxin2026，别名 debugKey）。
把 07 的 .csr 上传到 AGC 换回发布证书 .cer，再建一个发布 Profile 得到 .p7b，
两个文件都放回 `signing/` 目录，然后执行：

    powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 `
      -Keystore signing\release.p12 -KeystorePwd Zhuaxin2026 `
      -KeyPwd Zhuaxin2026 -KeyAlias debugKey `
      -Cert signing\release.cer -Profile signing\release.p7b
