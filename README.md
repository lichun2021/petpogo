# PetPogo App

宠物 AI 语音翻译 & 硬件管理移动应用（Flutter）

- **包名 Android**：`com.junxin.petpogo_and`
- **包名 iOS**：`com.junxin.petpogo`
- **当前版本**：`1.0.4 (Build 5)`

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
flutter build apk --release --build-name=1.0.4 --build-number=5

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
  --build-name=1.0.4 \
  --build-number=5

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
| `android/app/build.gradle.kts` | Android 包名、版本 |
| `ios/Runner/Info.plist` | iOS 包名、权限说明 |
| `pubspec.yaml` | 版本号、依赖包 |

---

## AI 语音服务

- **接口地址**：`http://49.234.39.11:8002`
- **支持物种**：猫、狗
- **支持情绪**：放松 / 兴奋 / 焦虑 / 警觉 / 攻击性 / 疼痛
- **录音要求**：WAV 格式，至少 2 秒，建议 3~5 秒
