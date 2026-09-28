# 昭臣打卡 App

## Web 版部署

Web 版使用 `https://www.zhaochen-construction.com` 的 Java API。生产请求前缀是 `/app/api`，测试请求前缀是 `/apptest/api`；例如登录接口分别为 `/app/api/ck/auth/login` 和 `/apptest/api/ck/auth/login`。用户打卡需要浏览器授予定位和摄像头权限。

两个 Web 环境位于同一域名，浏览器存储中的登录凭证使用独立键名：`checkin.web.prod.*` 与 `checkin.web.test.*`。更新到此版本后，两个网页环境需要各登录一次。打卡 API 使用 Bearer token，项目代码不写入 Cookie；若服务器以后设置认证 Cookie，应分别限制到 `/app/` 和 `/apptest/` 路径。

本地 `tool/web-deploy.local.ps1` 已配置服务器 SSH 连接、OpenSSH `.pem` 密钥和两个发布目录，且被 Git 忽略。迁移到其他电脑时，可从 `tool/web-deploy.example.ps1` 复制并填写对应信息，无需将私钥或密码写入仓库。

在 Windows 双击 `build-web-prod.bat` 或 `build-web-test.bat`。脚本会构建、核对资源、上传整个目录，并在上传成功后通过 SSH 分别执行 `chmod -R 755 /data/static-5100` 或 `chmod -R 755 /data/static-5200`。任一步失败会停止后续步骤。等效构建命令：

```powershell
flutter build web --release --dart-define=ENV=prod --base-href "/app/checkin/"
powershell -NoProfile -ExecutionPolicy Bypass -File tool/stage-web-build.ps1 -Environment prod
flutter build web --release --dart-define=ENV=test --base-href "/apptest/checkin/"
powershell -NoProfile -ExecutionPolicy Bypass -File tool/stage-web-build.ps1 -Environment test
```

上传和权限修复由 `tool/deploy-web.ps1 -Environment prod` 或 `-Environment test` 执行。

生产文件在 `build/web-prod/`，对应 `https://www.zhaochen-construction.com/app/checkin/`；测试文件在 `build/web-test/`，对应 `https://www.zhaochen-construction.com/apptest/checkin/`。脚本先使用 Flutter 默认输出目录 `build/web/` 构建，再核对并复制完整文件到对应版本目录，避免直接使用 `--output` 时资源目录缺失。将各版本目录内的文件（包括整个 `assets/` 目录）分别发布到对应网站目录。静态服务器需将不存在的网页路径回退到该版本的 `index.html`，但 `/app/api/` 与 `/apptest/api/` 请求必须转发到对应的 Java 环境，不得回退到网页。

例如，Nginx 可使用如下路由配置；将两个 Java 端口改为实际值，并在外层 `server` 配置证书与 HTTPS：

```nginx
location /app/api/ {
    proxy_pass http://127.0.0.1:8082/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location /apptest/api/ {
    proxy_pass http://127.0.0.1:8083/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location /app/checkin/ {
    alias /data/static-5100/checkin/;
    try_files $uri $uri/ /app/checkin/index.html;
}

location /apptest/checkin/ {
    alias /data/static-5200/checkin/;
    try_files $uri $uri/ /apptest/checkin/index.html;
}
```

上线后在手机浏览器验证登录、定位、现场拍照、照片上传和打卡。地图瓦片与照片访问地址也需要能从 HTTPS 页面正常加载。

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
