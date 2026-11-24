# Android 构建与打包

## 前置条件

- Flutter：使用仓库内 `.tooling/flutter`
- JDK：Android Gradle Plugin 8.x 建议使用 JDK 17
- Android SDK：需要 `cmdline-tools`、`platform-tools`、`build-tools`、对应 `platforms;android-XX`

## 初始化

```bash
cd QYBFConfig

# 依赖
bash ../scripts/flutterw pub get

# 接受 SDK licenses（需要 sdkmanager 可用）
flutter doctor --android-licenses
```

## 打包

```bash
cd QYBFConfig

# Debug APK
bash ../scripts/flutterw build apk --debug

# Release AAB（上架 Google Play 推荐）
bash ../scripts/flutterw build appbundle --release
```

## 国内网络加速

Android 工程已在 `android/settings.gradle.kts` 与 `android/build.gradle.kts` 中增加了阿里云 Maven 镜像源，
用于降低 `maven.google.com` 访问不稳定导致的构建失败概率。

