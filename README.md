# VocabPocket（词袋）

<p align="center">
  <img src="Support/AppIcon.svg" width="128" height="128" alt="VocabPocket app icon">
</p>

一款开源的 macOS 菜单栏快捷翻译工具：在任何应用中选中文字，按下全局快捷键即可翻译；遇到图片、PDF 扫描件或不可选文字时，可直接框选屏幕做 OCR。每次翻译都可以自动进入生词本，之后通过间隔复习再次巩固。

> 当前阶段：`0.2.0` 预发布版。最低支持 macOS 15；Apple Translation 不需要 API Key，其他翻译引擎使用你自己的账号或本地模型。

## 功能

- 全局快捷键，默认 `⌥⌘D`，支持三个预设快捷键
- 智能取词：优先读取当前选中文字，失败后自动进入截图 OCR
- 单独的截图 OCR 与手动输入入口
- 可切换翻译引擎：Apple Translation、DeepL、Google Cloud Translation、Microsoft Translator
- LLM 翻译：OpenAI 兼容 Chat Completions（含 Ollama / LM Studio）与 Anthropic Claude
- API 端点、模型、Azure Region 和 LLM 系统提示词均可配置，并可在设置中测试连通性
- API Key 只保存在 macOS 钥匙串，不写入偏好文件或生词本
- Vision 多阶段设备端 OCR：原图识别、放大/灰度/对比度增强重试、深色背景反相兜底
- 临时截图识别后立即删除，只有 OCR 得到的文字才会交给选定翻译引擎
- 翻译浮窗：展示原文、译文、复制和手动保存
- 本地生词本：搜索、收藏、笔记、去重、遇见次数统计
- 间隔复习：忘记 / 有点难 / 记住了三档反馈
- JSON 与 CSV 导出
- 菜单栏常驻，不占 Dock 位置

## 隐私

VocabPocket 没有后端服务，也不集成广告或统计 SDK。

- 使用 Apple Translation 时，翻译完全在设备端完成。
- 使用远程 Provider 时，识别后的文字会直接发送到你在设置中填写的 API 地址；VocabPocket 没有中转服务器。
- OpenAI 兼容模式可连接本机 Ollama / LM Studio，API Key 可留空。
- OCR 由 macOS Vision 在设备端完成。
- 截图只保存在系统临时目录，识别或取消后立即删除。
- 生词本保存在 `~/Library/Application Support/VocabPocket/vocabulary.json`。
- 兼容性复制取词会暂时读取剪贴板，并在约 140 ms 后恢复原内容。

应用需要“辅助功能”权限读取用户主动选中的文字，需要“屏幕录制”权限识别用户主动框选的屏幕区域。

## 翻译引擎配置

在 macOS 的 VocabPocket 设置中选择 Provider：

| Provider | 需要配置 | 默认接口 |
| --- | --- | --- |
| Apple Translation | 无 | 设备端 |
| DeepL | API Key；Free 用户保留默认地址，Pro 用户改为 `https://api.deepl.com/v2/translate` | DeepL Free |
| Google Cloud Translation | API Key | Translation Basic v2 |
| Microsoft Translator | API Key；部分 Azure 资源还需 Region | Translator v3 |
| OpenAI 兼容 LLM | 接口地址、模型；云服务通常还需 API Key | OpenAI Chat Completions |
| Anthropic Claude | API Key、模型 | Messages API |

LLM 提示词支持 `{target_language}` 与 `{target_language_code}` 占位符。连接 Ollama 或 LM Studio 时，可把接口填写为例如 `http://localhost:11434/v1`，应用会自动补全 `/chat/completions`。

## 构建

要求：

- macOS 15 或更高版本
- Xcode 16 或更高版本（不能只有 Command Line Tools）
- Swift 6.0 或更高版本

```bash
git clone <repository-url>
cd VocabPocket
swift test
./scripts/build-app.sh
open .build/VocabPocket.app
```

默认构建当前 Mac 架构；发布用 Universal（Apple Silicon + Intel）版本：

```bash
VOCABPOCKET_UNIVERSAL=1 ./scripts/build-app.sh
```

Swift Package 也可以直接用 Xcode 打开：

```bash
open Package.swift
```

首次运行后：

1. 在系统提示中授予“辅助功能”权限。
2. 第一次使用截图 OCR 时授予“屏幕录制”权限。
3. 在任意应用选中文字，按 `⌥⌘D`。

本地脚本只生成 ad-hoc 签名的开发包。面向普通用户分发时，应使用 Apple Developer ID 签名并完成公证。

## 项目结构

```text
Sources/VocabPocket/
├── App/          # SwiftUI App、菜单栏和浮窗控制器
├── Models/       # 生词与偏好模型
├── Services/     # 取词、截图、OCR、翻译桥接、快捷键、持久化
├── ViewModels/   # 完整取词翻译流程状态
└── Views/        # 生词本、复习、设置和使用指南
```

核心流程：

```text
全局快捷键
  ├─ 可访问的选中文字 ───────────┐
  └─ 无选中文字 → 框选截图 → 多阶段 OCR ─┤
                                            ├─ Apple / 翻译 API / LLM → 翻译浮窗
                                            └─ 本地生词本 → 间隔复习
```

## 路线图

- 可自由录制任意组合键的快捷键设置
- 生词本导入、iCloud 可选同步
- 更多复习统计与标签
- Developer ID 签名、公证和自动更新
- 更完整的本地化与 VoiceOver 验证

## 贡献与许可

欢迎提交 Issue 和 Pull Request，详见 [CONTRIBUTING.md](CONTRIBUTING.md)。项目使用 [MIT License](LICENSE)。

---

## English

VocabPocket is an open-source macOS menu bar app for instant translation. Select text anywhere and press a global shortcut, or draw a screen region to OCR text from images. Translations can be saved locally and reviewed with a lightweight spaced-repetition flow.

It requires macOS 15+, uses Vision for multi-pass on-device OCR, and supports Apple Translation, DeepL, Google Cloud, Microsoft Translator, OpenAI-compatible LLMs, and Anthropic Claude. API keys are stored in the macOS Keychain. The project is licensed under MIT.
