# PetPogo App

宠物 AI 语音识别 & 硬件管理移动应用（Flutter）

- **包名 Android**：`com.junxin.petpogo_and`
- **包名 iOS**：`com.jxpetai.furwhisper`
- **当前版本**：`1.0.8 (Build 8)`

---

## 环境要求

| 工具 | 版本 |
|------|------|
| Flutter | >= 3.0.0 |
| Dart | >= 3.0.0 |
| Xcode | >= 14（iOS 打包） |
| Android SDK | >= 34 |
| CocoaPods | >= 1.12（iOS 依赖） |

---

## 安装依赖

```bash
cd petpogo_app

flutter pub get

# iOS 额外需要
cd ios && pod install && cd ..
```

---

## 打包指令

### Android APK

```bash
# Debug（快速测试）
flutter build apk --debug

# Release（正式发布）
flutter build apk --release --build-name=1.0.8 --build-number=8

# 输出路径
# build/app/outputs/flutter-apk/app-release.apk
```

### iOS IPA

```bash
flutter build ipa \
  --release \
  --export-method app-store \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --build-name=1.0.8 \
  --build-number=8

# 输出路径
# build/ios/ipa/petpogo_app.ipa
```

---

## 启动 Android 模拟器

```bash
# 查看可用模拟器列表
~/Library/Android/sdk/emulator/emulator -list-avds

# 启动指定模拟器（替换 <AVD_NAME> 为列表中的名称）
~/Library/Android/sdk/emulator/emulator -avd <AVD_NAME> &

# 打包 Debug + 安装 + 启动（一键）
flutter build apk --debug && \
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk && \
~/Library/Android/sdk/platform-tools/adb shell am start -n com.junxin.petpogo_and/.MainActivity
```

---

## 调试日志（AI 语音）

```bash
# 只看 AI 相关日志
~/Library/Android/sdk/platform-tools/adb logcat | grep -E "AI_REPO|AI_CTRL"

# 看完整应用日志
~/Library/Android/sdk/platform-tools/adb logcat --pid=$(~/Library/Android/sdk/platform-tools/adb shell pidof -s com.junxin.petpogo_and)
```

---

## 关键配置文件

| 文件 | 作用 |
|------|------|
| `lib/core/config/app_config.dart` | API 地址、OAuth 凭证、版本号 |
| `lib/core/api/api_endpoints.dart` | 所有接口路径 |
| `android/app/build.gradle.kts` | Android 包名、版本（从 pubspec 读取） |
| `ios/Runner/Info.plist` | iOS 包名、权限说明 |
| `pubspec.yaml` | 版本号（`1.0.8+8`，唯一版本号来源）、依赖包 |

---

## AI 服务

AI 能力统一通过独立 AI 网关调用（`AppConfig.aiConsultBaseUrl`）：

| 能力 | 端点 | 说明 |
|------|------|------|
| 语音情绪分析 | `POST /voice/analyze` | 物种（猫/狗）+ 情绪识别，传 OSS 音频 URL |
| 图像情绪分析 | `POST /image/analyze` | 物种 + 品种 + 情绪识别，传 OSS 图片 URL |
| AI 问诊（宠小伊） | `/session/*`、`/messages/stream` 等 | 流式问诊 + 诊断报告 |

调用链：`业务后端 /sdkapi/upload/sign 获取 OSS 预签名地址 → 直传 OSS → AI 网关分析`。

接口字段与响应结构详见 `AI_MODEL_API.md`。

---

## 文档导航

| 文档 | 用途 | 状态 |
|------|------|------|
| `AGENTS.md` / `CLAUDE.md` | 开发指导（架构分层、约定、常用命令） | ✅ 现行（两者内容重复，分别面向 Codex / Claude） |
| `APP_IDENTITY.md` | 包名 / 签名 / 版本号（身份配置权威来源） | ✅ 现行 |
| `AUTH_LOGIN_REFERENCE.md` | uCloudlink OAuth2 + `/uclgwapp/` 登录认证流程 | ✅ 现行参考 |
| `HARDWARE_API_REFERENCE.md` | iPet 硬件 API 约定 | ✅ 现行参考 |
| `PeerApi.md` | iPet 网关 `/uclgwapp/` 端点目录 | ✅ 现行（端点权威来源） |
| `PeerApiMedia.md` | Agora RTC 通话接入 | ✅ 现行参考 |
| `PeerApiSpeed.md` | 速度控制端点 | ✅ 参考 |
| `PeerPet.md` | 宠物分享 App 端接入 | ✅ 参考 |
| `AI_MODEL_API.md` | iPet-AI 服务接口与响应结构 | ⚠️ 地址已由 `ai.jxpetai.com` 取代，接口结构仍有效 |
| `device_share_api_doc.md` | 设备口令分享 API | ✅ 参考 |
| `implementation_plan.md` | 宠小伊 AI 问诊实施方案 | 📦 历史（已落地） |
| `PET_FEATURE_UPDATE.md` | 宠物功能更新总结 | 📦 历史变更记录 |
| `PET_SHARE_USAGE.md` | 宠物分享功能使用指南 | ✅ 参考 |
| `PET_SHARE_API_ALIGNMENT.md` | 宠物分享 API 对齐说明 | 📦 历史变更记录 |
| `DEVICE_UNBIND_FIX.md` | 设备解绑流程优化 | 📦 历史修复记录 |
| `docs/ble-provision-protocol.md` | WiFi 项圈蓝牙配网协议 | ⚠️ 与 `openspec/changes/collar-wifi-ble-provision/` 方案存在冲突，需对齐 |
| `openspec/` | 规格化变更管理（spec-driven） | ✅ 现行变更管理 |
