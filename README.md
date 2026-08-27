# 昭臣打卡 App

## 版本与发布

- `bump-version.bat`：调整构建号、修订版本、次版本或主版本。
- `build-test.bat`：构建并发布测试环境 APK。
- `build-prod.bat`：构建并发布生产环境 APK。

首次使用发布脚本时，将 `tool/oss-credentials.example.bat` 复制为
`tool/oss-credentials.local.bat` 并填写 OSS 发布密钥。`local` 文件已被 Git
忽略，不会上传到代码仓库。

发布目录与物料申请 App 独立：

- 测试：`apps/checkin/test/app.apk` 和 `apps/checkin/test/version.json`
- 生产：`apps/checkin/prod/app.apk` 和 `apps/checkin/prod/version.json`

App 启动后会按当前环境自动检查 `version.json`，新版本可在 App 内下载并调起 Android 安装。

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
