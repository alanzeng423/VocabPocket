# Provider 配置指南

VocabPocket 直接从 Mac 请求你选择的翻译服务，没有中转服务器。端点、模型和非敏感参数保存在 macOS 偏好设置；API Key、Token 及组合凭证保存在 macOS 钥匙串。

## 设备端与官方翻译 API

| Provider | 钥匙串凭证 | 额外配置 |
| --- | --- | --- |
| Apple Translation | 无 | macOS 系统语言模型 |
| DeepL | API Key | Free 默认端点；Pro 改为 `https://api.deepl.com/v2/translate`，也可填写兼容端点 |
| Google Cloud Translation | API Key | Translation Basic v2 端点 |
| Microsoft Translator | API Key | 部分 Azure 资源还需 Region |
| 百度通用翻译 | `AppID#密钥` | 自动检测源语言 |
| 百度领域翻译 | `AppID#密钥` | 领域代码，例如 `electronics`、`medicine` |
| 有道智云 | `应用ID#应用密钥` | 可选领域与术语表 ID |
| 有道翻译大模型 | `应用ID#应用密钥` | 模型档位填 `pro` 或 `lite`，可填写翻译要求 |
| 小牛翻译 NiuTrans | API Key | 默认使用官方文本翻译接口 |
| 彩云小译 | Token | 使用 `x-authorization` 官方鉴权 |
| 阿里云机器翻译 | `AccessKeyID#AccessKeySecret` | 默认地域 `cn-hangzhou` |
| 腾讯云机器翻译 | `SecretId#SecretKey` | 默认地域 `ap-shanghai`、项目 ID `0`；使用 TC3-HMAC-SHA256 签名 |
| 火山引擎机器翻译 | `AccessKeyID#SecretAccessKey` | 默认地域 `cn-beijing`；使用 HMAC-SHA256 签名 |
| 讯飞机器翻译 | `AppID#APISecret#APIKey` | 默认连接 niutrans `/v2/ots` |
| OpenL | API Key | 另填逗号分隔的服务列表，例如 `google,deepl` |

组合凭证中的 `#` 是分隔符，字段顺序必须与表格一致。应用会把整个值作为一个钥匙串项目保存，不会写入偏好文件。

## LLM

| Provider | 关键配置 |
| --- | --- |
| OpenAI 兼容 LLM | 完整端点或 API 根地址、模型、提示词；Ollama / LM Studio 可不填 Key |
| Anthropic Claude | API Key、模型、提示词 |
| Azure OpenAI | Azure 资源根地址、API Key、部署名称、API 版本、提示词 |
| Google Gemini | API Key、模型、提示词；默认使用 `generateContent` |
| Qwen-MT | 百炼 API Key、Qwen-MT 模型；可选领域提示 |

OpenAI 兼容、Claude、Azure OpenAI 与 Gemini 的提示词可以使用 `{target_language}` 和 `{target_language_code}` 占位符。Qwen-MT 使用专用的 `translation_options` 参数，不把领域提示当作普通系统提示词。

## 自托管

| Provider | 默认地址 | 说明 |
| --- | --- | --- |
| DeepLX | `http://localhost:1188/translate` | 支持常见 DeepLX JSON 响应；可选 Bearer Token |
| LibreTranslate | `http://localhost:5000/translate` | API Key 可选，取决于实例配置 |
| MTranServer | `http://localhost:8989/translate` | Token 可选；语言代码模式可填 `base` 或 `bcp47` |
| NLLB | `http://localhost:6060` | 后端填 `nllb-serve`；也支持 `nllb-api` 的 `/api/v4/translator` |

macOS 可能在第一次访问局域网服务时请求“本地网络”权限。HTTP 仅建议用于本机或可信局域网；公网端点应使用 HTTPS。

## 免费网页接口（实验性）

Google Translate、Bing、有道、火山翻译和腾讯 Transmart 的实验性入口不需要 Key，但它们不是面向第三方应用承诺稳定性的正式 API。服务方可能随时修改格式、限流、要求验证或停用接口；设置页会始终显示橙色警告。

如果需要稳定使用，优先选择官方 API、自托管服务或本地 LLM。不要通过实验性入口翻译机密、个人或受监管数据。

## 与参考项目的范围差异

Provider 清单参考 [windingwind/zotero-pdf-translate](https://github.com/windingwind/zotero-pdf-translate) 的句子翻译服务，并结合服务官方文档独立实现。以下项目没有作为 VocabPocket Provider：

- CNKI：依赖私有网页协议、硬编码网页加密流程和验证码，无法承诺可用性。
- 海词：依赖已经过时的非 HTTPS 网页接口和临时令牌抓取。
- Pot：其接口负责唤起 Pot 弹窗，不返回译文，无法安全接入“翻译后自动加入生词本”的闭环。
- Cambridge、Collins、Free Dictionary、Bing Dict、Youdao Dict 等：它们是查词服务，不是句子翻译 Provider。

DeepL Free / Pro / Custom 统一由一个可编辑端点的 DeepL Provider 覆盖；GPT 与多个 Custom GPT 入口统一由 OpenAI 兼容 Provider 覆盖。
