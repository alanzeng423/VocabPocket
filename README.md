# VocabPocket（词袋）

<p align="center">
  <img src="Support/AppIcon.svg" width="128" height="128" alt="VocabPocket app icon">
</p>

一款开源的 macOS 菜单栏快捷翻译工具：在任何应用中选中文字，按下全局快捷键即可翻译；遇到图片、PDF 扫描件或不可选文字时，可直接框选屏幕做 OCR。每次翻译都可以自动进入生词本，之后通过间隔复习再次巩固。

> 当前阶段：`0.1.0` MVP。最低支持 macOS 15，使用系统 Translation 与 Vision 框架，不需要第三方 API Key。

## 功能

- 全局快捷键，默认 `⌥⌘D`，支持三个预设快捷键
- 智能取词：优先读取当前选中文字，失败后自动进入截图 OCR
- 单独的截图 OCR 与手动输入入口
- Apple Translation 设备端翻译，自动识别源语言
- Vision 设备端 OCR，临时截图识别后立即删除
- 翻译浮窗：展示原文、译文、复制和手动保存
- 本地生词本：搜索、收藏、笔记、去重、遇见次数统计
- 间隔复习：忘记 / 有点难 / 记住了三档反馈
- JSON 与 CSV 导出
- 菜单栏常驻，不占 Dock 位置

## 隐私

VocabPocket 没有后端服务，也不集成广告或统计 SDK。

- 翻译由 macOS 的 Apple Translation 在设备端完成。
- OCR 由 macOS Vision 在设备端完成。
- 截图只保存在系统临时目录，识别或取消后立即删除。
- 生词本保存在 `~/Library/Application Support/VocabPocket/vocabulary.json`。
- 兼容性复制取词会暂时读取剪贴板，并在约 140 ms 后恢复原内容。

应用需要“辅助功能”权限读取用户主动选中的文字，需要“屏幕录制”权限识别用户主动框选的屏幕区域。

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
  └─ 无选中文字 → 框选截图 → OCR ├─ Apple Translation → 翻译浮窗
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

VocabPocket is an open-source macOS menu bar app for instant, private translation. Select text anywhere and press a global shortcut, or draw a screen region to OCR text from images. Translations can be saved locally and reviewed with a lightweight spaced-repetition flow.

It requires macOS 15+, uses Apple's on-device Translation and Vision frameworks, and is licensed under MIT.
