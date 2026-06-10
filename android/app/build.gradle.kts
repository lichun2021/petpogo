import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // 华为 AGConnect 插件（读取 agconnect-services.json，激活 HMS Push 通道）
    id("com.huawei.agconnect")
}

// ── 读取签名配置 ──────────────────────────────────────────
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.junxin.petpogo_and"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.junxin.petpogo_and"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ── 极光推送基础配置 ──────────────────────────────────────────────────────────────
        manifestPlaceholders["JPUSH_PKGNAME"] = "com.junxin.petpogo_and"
        manifestPlaceholders["JPUSH_APPKEY"]  = "bbff354f334f7c5e340b9c38"
        manifestPlaceholders["JPUSH_CHANNEL"] = "developer-default"

        // ── 小米厂商通道（Xiaomi / Redmi / POCO）──────────────────────────────────────────
        // 申请地址：https://dev.mi.com/platform  申请后在极光控制台同步填写
        // 注意：极光插件要求加 MI- 前缀，例如 "MI-2882303761518XXXXX"
        manifestPlaceholders["XIAOMI_APPID"]  = ""   // TODO: 填入 "MI-" + 小米AppID
        manifestPlaceholders["XIAOMI_APPKEY"] = ""   // TODO: 填入 "MI-" + 小米AppKey

        // ── OPPO / OnePlus / Realme 厂商通道 ─────────────────────────────────────────────
        // 申请地址：https://open.oppomobile.com
        // 注意：极光插件要求加 OP- 前缀，例如 "OP-f6b4XXXX"
        manifestPlaceholders["OPPO_APPKEY"]    = ""  // TODO: 填入 "OP-" + OPPO AppKey
        manifestPlaceholders["OPPO_APPID"]     = ""  // TODO: 填入 "OP-" + OPPO AppID
        manifestPlaceholders["OPPO_APPSECRET"] = ""  // TODO: 填入 "OP-" + OPPO AppSecret

        // ── VIVO / iQOO 厂商通道 ──────────────────────────────────────────────────────────
        // 申请地址：https://dev.vivo.com.cn
        manifestPlaceholders["VIVO_APPID"]     = ""  // TODO: 填入 VIVO AppID
        manifestPlaceholders["VIVO_APPKEY"]    = ""  // TODO: 填入 VIVO AppKey

        // ── 荣耀（Honor）厂商通道 ─────────────────────────────────────────────────────────
        // 申请地址：https://developer.hihonor.com
        manifestPlaceholders["HONOR_APPID"]    = ""  // TODO: 填入 Honor AppID

        // ── 华为（Huawei）厂商通道 ────────────────────────────────────────────────────────
        // 额外步骤（华为比较特殊）：
        //   1. 华为开发者联盟申请 Push 服务，下载 agconnect-services.json
        //   2. 将该文件放入 android/app/ 目录
        //   3. 顶层 build.gradle.kts buildscript 加 agcp classpath
        //   4. 本文件 plugins{} 加 id("com.huawei.agconnect")
        // AppID 由 agconnect-services.json 自动提供，无需 manifestPlaceholders
    }

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
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ── 极光推送厂商通道插件（版本号必须与 jpush 主包一致：6.1.0）──────────────────────
    // 每个插件对应一个手机品牌，App 杀后台后由厂商系统级通道保证推送到达
    implementation("cn.jiguang.sdk.plugin:xiaomi:6.1.0")  // 小米/Redmi/POCO
    implementation("cn.jiguang.sdk.plugin:oppo:6.1.0")    // OPPO/OnePlus/Realme
    implementation("cn.jiguang.sdk.plugin:vivo:6.1.0")    // VIVO/iQOO
    implementation("cn.jiguang.sdk.plugin:huawei:6.1.0")  // 华为/鸿蒙（HMS Push）
    implementation("cn.jiguang.sdk.plugin:honor:6.1.0")   // 荣耀（独立生态）
}
