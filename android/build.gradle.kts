allprojects {
    repositories {
        // \u2500\u2500 \u56fd\u5185\u955c\u50cf\uff08\u4f18\u5148\uff0c\u907f\u514d dl.google.com TLS \u95ee\u9898\uff09\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/jcenter") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // \u817e\u8baf\u4e91 Maven \u955c\u50cf\uff08tencent_cloud_chat_sdk \u7684 AGP \u4f9d\u8d56\u5728\u8fd9\u91cc\u6709\uff09
        maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }
        // \u5907\u9009\u539f\u59cb\u6e90
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
