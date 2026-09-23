# v1.0.0 合规改造中移除的"云端 AI"代码（备份）

2026-09-15，为了通过华为审核（个人主体拿不到《安全评估报告》与生成式 AI 备案），
应用删除了"用户自填第三方模型接口"的能力。这里保留关键代码，便于将来主体合规后恢复。

恢复时必须同时改回这几处，缺一不可：

1. `entry/src/main/module.json5`：加回网络权限

```json5
{
  "name": "ohos.permission.INTERNET",
  "reason": "$string:reason_internet",
  "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
}
```

2. `resources/*/element/string.json`：加回 `reason_internet`
3. `model/Models.ets`：加回 `AppSettings`（cloudEnabled / cloudBaseUrl / cloudApiKey / cloudModel）与 `emptySettings()`
4. `data/PetStore.ets`：加回 `KEY_SETTINGS` 的 `getSettings()` / `saveSettings()`，以及 `clearAllData()` 里的清空
5. `view/PetTab.ets`：加回"云端 AI（可选）"开关与接口地址 / 模型名 / API Key 输入区
6. `service/AnswerService.ets`：在 `ask()` 最后一步之前插入云端兜底（下面的代码），并把 `ask()` 改回 `async`
7. **重新提交前必须补齐**：安全评估报告、生成式 AI 服务备案、AI 生成合成内容标识、用户真实身份信息认证

## 云端请求相关代码（原 `AiService.ets`）

```ts
import { http } from '@kit.NetworkKit';

interface ChatPayloadMessage { role: string; content: string; }
interface ChatRequestBody { model: string; messages: ChatPayloadMessage[]; temperature: number; }
interface ChatResponseMessage { content?: string; }
interface ChatChoice { message?: ChatResponseMessage; }
interface ChatResponseBody { choices?: ChatChoice[]; }

const SYSTEM_PROMPT: string =
  '你是一名严谨的宠物护理科普助手，服务对象是中国大陆的猫狗主人。要求：\n' +
  '1. 只做科普，不做诊断，不开处方，不给任何药物剂量；\n' +
  '2. 回答要具体可执行，分点，控制在 200 字以内；\n' +
  '3. 明确指出什么情况下必须去医院；\n' +
  '4. 涉及呕吐、腹泻、抽搐、误食、呼吸困难等情况时，第一句就要建议立即就医；\n' +
  '5. 不推荐具体药品品牌和商品；\n' +
  '6. 结尾不要重复免责声明，界面会统一展示。';

async function askCloud(question: string, pet: Pet | undefined): Promise<AnswerResult | undefined> {
  const settings = PetStore.get().getSettings();
  if (!settings.cloudEnabled || settings.cloudApiKey.length === 0) {
    return undefined;
  }
  const url = `${settings.cloudBaseUrl.replace(/\/+$/, '')}/chat/completions`;
  const body: ChatRequestBody = {
    model: settings.cloudModel,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: `宠物档案：${petProfileText(pet)}\n\n主人提问：${question}` }
    ],
    temperature: 0.3
  };
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${settings.cloudApiKey}`
  };
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 45000
    });
    const raw = response.result as string;
    const parsed = JSON.parse(raw) as ChatResponseBody;
    const choices = parsed.choices;
    if (choices !== undefined && choices.length > 0) {
      const message = choices[0].message;
      if (message !== undefined && message.content !== undefined && message.content.length > 0) {
        return { text: message.content, emergency: false, source: 'cloud', topicId: 'cloud' };
      }
    }
    return undefined;
  } catch (err) {
    hilog.error(DOMAIN, TAG, 'cloud request failed: %{public}s', JSON.stringify(err) ?? '');
    return undefined;
  } finally {
    request.destroy();
  }
}
```

调用位置（`ask()` 的第 5 步，位于"常规科普话题"之后、`fallbackAnswer` 之前）：

```ts
const cloud = await askCloud(trimmed, pet);
if (cloud !== undefined) {
  return cloud;
}
```

界面上还要给云端回答加"AI 生成"显式标识（《人工智能生成合成内容标识办法》要求）。
