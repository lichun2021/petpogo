// ── 华为 AGConnect Gradle 插件（agcp）
// 用于自动读取 android/app/agconnect-services.json，支持华为推送通道
buildscript {
    repositories {
        maven { url = uri("https://developer.huawei.com/repo/") }
        google()
        mavenCentral()
    }
    dependencies {
        // agcp 插件要求 AGP 必须在此处声明
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("com.huawei.agconnect:agcp:1.9.1.301")
    }
}

allprojects {
    repositories {
        // ── 国内镜像（优先，避免 dl.google.com TLS 问题）────────────────────────────────────
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/jcenter") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // 腾讯云 Maven 镜像（tencent_cloud_chat_sdk 的 AGP 依赖在这里有）
        maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }
        // ── 华为 AGConnect（接入华为推送通道必需）──────────────────────────────────────────
        maven { url = uri("https://developer.huawei.com/repo/") }
        // ── 荣耀 Honor 推送 SDK Maven 仓库 ─────────────────────────────────────────────────
        maven { url = uri("https://developer.hihonor.com/repo") }
        // 备选原始源
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
