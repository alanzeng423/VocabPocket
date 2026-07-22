# 参与贡献

感谢你帮助改进 VocabPocket。

## 本地开发

需要 macOS 15、Xcode 16 或更高版本。

```bash
git clone <repository-url>
cd VocabPocket
swift test
./scripts/build-app.sh
open .build/VocabPocket.app
```

也可以直接在 Xcode 中打开 `Package.swift`，选择 `VocabPocket` scheme 运行。

## 提交变更

1. 为修复或功能创建独立分支。
2. 尽量为数据层和复习算法添加测试。
3. 执行 `swift test` 和 `./scripts/build-app.sh`。
4. 在 Pull Request 中解释动机、实现和人工验证方式。

请勿提交 API Key、个人生词本、签名证书或构建产物。
