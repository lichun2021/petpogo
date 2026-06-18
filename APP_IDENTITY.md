# PetPogo App 身份标识 & 签名配置

## 包名 / Bundle ID

| 平台 | 标识符 |
|------|--------|
| **Android** package name | `com.junxin.petpogo_and` |
| **iOS** Bundle ID | `com.jxpetai.furwhisper` |

---

## Android 签名

### 证书指纹（Release Keystore）

| 算法 | 值 |
|------|-----|
| **MD5**（微信开放平台「应用签名」填此值）| `3b89c9f7263279e4b9d0f89fe9240fa0` |
| SHA1 | `1D:C0:2C:FA:37:AD:61:CA:CA:7D:76:D1:29:12:A0:13:A8:A0:DC:90` |
| SHA256 | `EB:B2:1E:08:F8:D9:33:18:5A:6F:60:96:52:38:0A:8E:AD:C4:CD:72:EB:87:70:A4:A3:CC:9A:C2:EC:27:D1:08` |

签名配置通过 `android/key.properties`（不提交到 Git）注入到 `android/app/build.gradle.kts`。

### key.properties 格式

```properties
storeFile=petpogo_release.keystore
storePassword=Petpogo@2026
keyAlias=petpogo
keyPassword=Petpogo@2026
```

Keystore 文件路径：`android/app/petpogo_release.keystore`（相对于 `android/app/` 目录）。

### build.gradle.kts 签名配置片段

```kotlin
signingConfigs {
    create("release") {
        keyAlias     = keyProperties["keyAlias"]     as String? ?: ""
        keyPassword  = keyProperties["keyPassword"]  as String? ?: ""
        storeFile    = file(keyProperties["storeFile"] as String? ?: "petpogo_release.keystore")
        storePassword = keyProperties["storePassword"] as String? ?: ""
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false
        isShrinkResources = false
    }
    debug {
        // 使用 Android 默认 debug 签名（自动生成，无需配置）
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

### Debug 签名

Debug 包使用 Android SDK 自动生成的默认 debug keystore：

| 项目 | 值 |
|------|-----|
| 文件路径 | `~/.android/debug.keystore` |
| 密码 | `android` |
| Key alias | `androiddebugkey` |
| Key 密码 | `android` |

---

## iOS 签名（Xcode 管理）

iOS 签名通过 Xcode 的 **Signing & Capabilities** 配置，不在代码中硬编码。

| 环境 | Team | Profile |
|------|------|---------|
| Debug | 开发者账号（Automatically manage signing） | 自动 |
| Release | 开发者账号（Automatically manage signing） | 自动 |

配置文件位置：`ios/Runner.xcodeproj/project.pbxproj`（`DEVELOPMENT_TEAM` 字段）

---

## 版本号

在 `pubspec.yaml` 中统一管理：

```yaml
version: 1.0.8+8
#         ^   ^
#         |   build number (versionCode on Android, CFBundleVersion on iOS)
#         versionName (versionCode on Android, CFBundleShortVersionString on iOS)
```
