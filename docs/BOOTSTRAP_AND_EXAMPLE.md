# XmaxSDK Flutter 工程初始化与 Example 方案

## 1. 结论

本地 Flutter 环境、XmaxSDK Package、`example/` 工程、RTC、COS 和业务 API 已完成整体建立。

根工程使用 Flutter `package` 模板，不使用 `plugin` 模板。XmaxSDK Flutter 自身不编写 Swift、Objective-C、Java 或 Kotlin 平台实现，只依赖火山 RTC 和腾讯 COS 已提供的 Flutter Plugin；因此没有必要生成 Xmax 自有的 Platform Channel 和空原生插件类。[Flutter 官方文档](https://docs.flutter.dev/packages-and-plugins/developing-packages)也将“仅依赖其他插件并提供 Dart API”的工程归为普通 Package。

Flutter Package 的标准示例目录使用单数 `example/`，不是 `examples/`。它是一套真正运行在 iOS/Android 上的宿主 App，同时承担接入示例和真机集成验收。

## 2. 当前本机环境

检查日期：2026-08-31。

| 项目 | 当前状态 | 阶段 0 要求 |
|---|---|---|
| Flutter | FVM `3.47.1` | 已固定在 `.fvmrc` |
| Dart | `3.13.1` | 由 Flutter SDK 提供 |
| FVM | Homebrew `4.3.0` | 已安装 |
| Xcode | `27.0 (27A5194q)` | iOS device Debug 构建已通过 |
| CocoaPods | `1.17.0` | 火山与 COS Pod 解析已通过 |
| Java | Android Studio JBR 21；工程 target 17 | 保持 Java/Kotlin 编译目标 17 |
| Android SDK | platforms 31、33、35、36、36.1、37 | Example/插件统一 compileSdk 36 |
| Android build-tools | 35.0.1、36.0.0 | 由 Gradle/Flutter 选择兼容版本 |
| Android NDK | r27c、r28c | 使用 Flutter 推荐的 r28c |
| ADB | `1.0.41 / 37.0.0` | 可用；已发现 Android 模拟器 |

Xcode 版本较新，不能仅以命令存在作为可用结论。阶段 0 必须实际完成一次 iOS device build，确认 Flutter、CocoaPods、火山 RTC Pod 与当前 Xcode 组合兼容。

## 3. Flutter 版本管理

开发机使用 FVM 管理 Flutter，仓库提交 `.fvmrc`，版本固定为 `3.47.1`。FVM 只是开发工具，不成为 XmaxSDK 消费方的运行时依赖。

安装完成后的初始化命令：

```shell
fvm install 3.47.1
fvm use 3.47.1 --force
fvm flutter doctor -v
```

SDK 的最低兼容版本仍由根 `pubspec.yaml` 声明：

```yaml
environment:
  sdk: ">=3.9.0 <4.0.0"
  flutter: ">=3.35.0"
```

`3.47.1` 是开发和 CI 版本，不表示接入方必须使用完全相同的版本。最低版本兼容性需要由独立 CI job 或干净宿主工程验证。

## 4. Package 初始化

在当前 `/Users/xmax.ai/dev/Xmax/Flutter/XmaxSDK` Package 根目录执行：

```shell
fvm flutter create \
  --template=package \
  --project-name=xmax_sdk \
  .
```

生成后保留标准 Package 元数据，并将当前 `docs/` 纳入仓库。根工程不生成 `ios/` 和 `android/` 原生实现目录。

根目录目标结构：

```text
Flutter/
├── .fvmrc
├── .gitignore
├── .metadata
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
├── README.md
├── pubspec.yaml
├── lib/
│   ├── xmax_sdk.dart
│   └── src/
│       ├── core/
│       ├── foundation/
│       ├── media/
│       ├── render/
│       ├── service/
│       ├── stream/
│       └── xmax_sdk_info.dart
├── test/
├── example/
└── docs/
```

阶段 0 只创建能够编译的公开 API 骨架和最小内部目录，不提前写 RTC/COS 假实现。尚未实现的公开能力不能返回虚假成功结果。

### 4.1 根 pubspec

根 `pubspec.yaml` 负责 SDK 依赖：

```yaml
name: xmax_sdk
description: Xmax SDK for Flutter.
version: 1.0.0
publish_to: none

environment:
  sdk: ">=3.9.0 <4.0.0"
  flutter: ">=3.35.0"

dependencies:
  flutter:
    sdk: flutter
  permission_handler: 12.0.3
  volc_engine_rtc: 3.60.6
  tencentcloud_cos_sdk_plugin_nobeacon: 1.2.9

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 6.0.0
```

`flutter_lints 6.0.0` 的最低要求是 Flutter 3.32/Dart 3.8，覆盖本项目最低版本。业务依赖不得放入 Example 后再由 SDK 隐式依赖。

### 4.2 锁文件策略

- 根 Package 的 `pubspec.lock` 不提交，以便验证 SDK 声明的版本约束，而不是只验证某次解析结果。
- `example/pubspec.lock` 提交，保证真机演示工程和 CI 构建可复现。
- CI 增加依赖解析和过期依赖报告，但第三方 SDK 升级必须人工完成真机回归。

## 5. Example 工程初始化

Package 创建完成后，单独创建 iOS/Android App：

```shell
fvm flutter create \
  --template=app \
  --platforms=ios,android \
  --org=ai.xmax \
  --project-name=xmax_sdk_example \
  example
```

Example 的 `pubspec.yaml` 使用本地路径依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  xmax_sdk:
    path: ../
```

Example 可以为演示体验增加文件选择、轻量本地配置等依赖，但这些依赖不能泄漏到 XmaxSDK 根 Package。

## 6. Example 的职责

Example 同时承担三种职责：

1. **最小接入示例**：让接入方能看清创建 Client、创建 Manager、预览、连接、生成和释放资源的完整调用顺序。
2. **能力演示**：演示摄像头实时生成、轨迹交互和独立 Storage/COS 能力。
3. **集成测试宿主**：验证火山 RTC、腾讯 COS、权限、前后台和真机生命周期。

Example 不承担以下职责：

- 不复制 SDK 内部状态机。
- 不直接调用火山 RTC 或腾讯 COS API。
- 不导入 `package:xmax_sdk/src/...`。
- 不展示首版未实现的图片 RTC 输入、本地视频 RTC 输入和插帧入口。
- 不把 API Key、RTC Token 或 COS 临时密钥提交到仓库。
- 不引入 Riverpod、Bloc 等状态框架来掩盖 SDK 的基础接入方式。

## 7. Example 信息架构

Flutter Example 对齐 iOS XLab 的用户路径和视觉语义，但只展示 Flutter 首版已经支持的能力。

### 7.1 首页 `HomePage`

- API Key 输入框，默认遮挡内容。
- SDK 版本、Flutter 版本和当前平台信息。
- “摄像头实时流”入口。
- “自定义轨迹渲染”入口，可复用摄像头实时页并注入 Renderer。
- “存储服务”入口。
- 未支持的图片/视频 RTC 管线不显示为可点击卡片。

API Key 通过 Example 层的系统偏好存储保留，行为与 XLab 一致；它不会写入仓库。客户端内的 Key 不能被视作不可提取的生产密钥。

### 7.2 摄像头实时页 `RealtimePage`

页面展示：

- 全屏 `XmaxVideoView`，先显示本地摄像头 track，生成开始后切换远端 track。
- 与 iOS XLab 一致的悬浮返回、前后摄像头切换控件。
- 与 iOS XLab 一致的底部分类栏、停止入口和安全区布局。
- 换形象、换装、换风格、虚拟召唤四种远程参考图模式。
- 自定义参考图通过 `XmaxStorageManaging.uploadImage` 上传 COS，再作为
  `RealtimeContext.referencePath` 使用；它不是本地图片 RTC 输入管线。
- 触控动图模式和自由 Prompt 输入模式。
- 当前 `RealtimeState`、性能告警、最近一次错误和加载状态。
- 可选的默认或自定义轨迹 Renderer。

生命周期必须在代码中清晰可读：

```text
initState
  → XmaxClient
  → createRealtimeManager
  → 注册 listeners
  → createLocalCameraStream
  → XmaxVideoView(local track)

用户生成
  → startGeneration(localStream, context)
  → XmaxVideoView(remote track)

更新生成上下文
  → startGeneration(context)

用户停止
  → disconnect
  → XmaxVideoView(local track)

dispose
  → 移除 listeners
  → stopGeneration（如需要）
  → disconnect
  → stopLocalCameraStream
  → dispose controller
```

页面 Controller 只负责把 UI 操作串成上述公开 API 调用，不得重写 SDK 状态机。重复点击、页面退出和 App 进入后台时要通过同一个串行操作入口清理。

### 7.3 Storage 页 `StoragePage`

- 选择图片或视频文件。
- 展示文件名、大小和 Content-Type。
- 普通上传；图片可演示安全检测上传。
- 展示进度、成功 URL 和错误。
- 使用 URL 下载并展示本地结果。
- 只能通过 `XmaxClient.createStorageManager()` 使用 COS 能力。

Storage 页面不是 RTC 图片/视频输入入口。上传成功的 URL 可用于 `RealtimeContext` 支持的业务参考素材，但不能被 Example 转换为本地 RTC 媒体流。

## 8. Example 内部目录

```text
example/
├── android/
├── ios/
├── integration_test/
│   ├── app_smoke_test.dart
│   ├── realtime_camera_test.dart
│   └── storage_test.dart
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── example_config.dart
│   ├── features/
│   │   ├── home/
│   │   │   └── home_page.dart
│   │   ├── realtime/
│   │   │   ├── realtime_page.dart
│   │   │   └── realtime_page_controller.dart
│   │   └── storage/
│   │       ├── storage_page.dart
│   │       └── storage_page_controller.dart
│   └── shared/
│       ├── example_error_view.dart
│       └── example_status_badge.dart
├── test/
├── pubspec.yaml
└── README.md
```

Example 采用 Flutter 自带 `Navigator`、`StatefulWidget`、`ValueNotifier` 或 `ChangeNotifier` 即可。重点是公开 API 调用清楚、生命周期正确，而不是搭建一套产品级状态管理框架。

## 9. 宿主平台初始化

### 9.1 iOS Example

- Deployment Target 设置为 iOS 15.0。
- `Info.plist` 增加 `NSCameraUsageDescription`。
- `Podfile` 同时声明火山 Specs 源和 CocoaPods CDN。
- 火山 RTC 和 COS 插件当前均不支持 Swift Package Manager，Flutter 会回退到 CocoaPods。
- 不增加麦克风用途说明，因为摄像头首版不采集本地麦克风。
- 使用真机完成首次 RTC 构建和运行；模拟器不作为 RTC 验收环境。
- Bundle ID 使用 Example 专用 ID，不与 SDK 或 XLab 正式 App 共用签名配置。

### 9.2 Android Example

- minSdk 26。
- Java 17。
- Manifest 声明 `INTERNET`、`CAMERA`、`MODIFY_AUDIO_SETTINGS`。
- 火山原生 AAR 会传递合并麦克风、屏幕投影、画中画和旧存储能力；camera-only 宿主必须用 Manifest Merger `tools:node="remove"` 显式移除 `RECORD_AUDIO`、相关前台服务权限、旧外部存储/Phone State/Overlay 权限，以及 `RXScreenCaptureService` 和 `FloatingWindow` 组件。
- Application ID 使用 Example 专用 ID。
- 首次验证至少覆盖 Android API 26 和一台当前系统真机。

火山 Android AAR 位于独立 Maven 仓库，宿主必须在 `settings.gradle.kts` 的 `pluginManagement.repositories` 和根 `build.gradle.kts` 的 `allprojects.repositories` 中加入：

```kotlin
maven(url = "https://artifact.bytedance.com/repository/Volcengine/")
```

火山原生 RTC `3.60.105.1900` 仍传递依赖 Support Library 28。在 AndroidX 宿主中必须启用 Jetifier：

```properties
android.useAndroidX=true
android.enableJetifier=true
```

Flutter 3.47.1 使用 AGP 9.1，而 COS 1.2.9 与火山 Flutter 3.60.6 的插件模块硬编码了旧 compileSdk。Example 使用 AGP Variant API 在 `finalizeDsl` 阶段将所有 Android library module 统一为 compileSdk 36，并把 Jetifier 映射的 vector drawable 强制到具有独立 namespace 的 AndroidX 1.1.0。实现以 `example/android/build.gradle.kts` 和 `example/android/app/build.gradle.kts` 为准。

## 10. 阶段 0 执行顺序

### 0A：环境安装与锁定

1. 安装 FVM。
2. 安装并固定 Flutter 3.47.1。
3. 执行 `fvm flutter doctor -v`。
4. 解决 iOS/Android doctor 阻塞项。
5. 记录 Xcode、CocoaPods、Java、Android SDK 和 Flutter 版本。

### 0B：创建 Package

1. 在当前根目录生成 `xmax_sdk` Package。
2. 合并现有 `docs/`，不覆盖设计文档。
3. 配置 Dart/Flutter SDK 约束和第三方依赖。
4. 创建 `lib/xmax_sdk.dart` 与 iOS 对齐的目录骨架。
5. 配置 format、analyze 和 unit test。

### 0C：创建 Example

1. 创建仅包含 iOS/Android 的 `example/` App。
2. 配置对根 Package 的 path 依赖。
3. 配置 iOS/Android 最低版本和权限。
4. 创建首页、Realtime、Storage 的空路由骨架。
5. 页面显示“能力尚未实现”，但不得在 SDK 公开 API 中提供假实现。

### 0D：空工程验收

```shell
fvm flutter pub get
fvm flutter analyze
fvm flutter test

cd example
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
fvm flutter build ios --debug --no-codesign
```

随后在已签名的 iOS 真机和 Android 真机各运行一次 Example。阶段 0 不要求 RTC 产生画面，但必须证明第三方插件能完成依赖解析、原生编译和插件注册。

## 11. 阶段 0 完成标准

- `.fvmrc` 固定 Flutter 3.47.1。
- `flutter doctor -v` 没有影响 iOS/Android 构建的错误。
- 根 Package 和 Example 均通过 format、analyze、test。
- Example 只能通过 `package:xmax_sdk/xmax_sdk.dart` 引用 SDK。
- Android Debug APK 构建成功。
- iOS 无签名 Debug 构建成功，并完成一次签名真机启动。
- 火山 RTC 和腾讯 COS 插件在两端完成注册，无 `MissingPluginException`。
- Example 不包含密钥和生成产物。
- 文档中的命令能从干净 checkout 重复执行。

满足这些条件后，再进入 `Foundation / Service` 和 RTC/COS 具体实现。

## 12. 当前执行结果

截至 2026-08-31：

- FVM、Flutter 3.47.1、Dart 3.13.1 已安装并绑定项目。
- Android SDK License 已接受，NDK r28c 已完整安装。
- 根 Package 与 `example/` 已生成。
- 火山 RTC 3.60.6 与腾讯 COS nobeacon 1.2.9 已完成 Pub 解析和两端原生插件发现。
- 根 Package 与 Example 的 format、analyze、test 已通过。
- iOS device Debug 无签名构建已通过，产物为 `example/build/ios/iphoneos/Runner.app`。
- Android Debug APK 构建已通过，产物为 `example/build/app/outputs/flutter-apk/app-debug.apk`。
- 最终 Android merged manifest 已验证不包含麦克风、屏幕投影、画中画、旧外部存储、Phone State 和 Overlay 权限/组件。
- Android API 37 模拟器冷启动已通过，火山 RTC 与 COS 均出现在 GeneratedPluginRegistrant，进程日志无插件注册异常。
- Android/iOS 真机启动和实际 RTC/COS 调用仍属于下一轮设备验收，不视为本次空工程编译已覆盖。

已确认的第三方升级风险：

- 火山 Flutter 插件仍自行应用 Kotlin Gradle Plugin；Flutter 已提示未来版本会将其升级为构建错误。
- 火山 Android 原生 SDK 仍依赖 Support Library 28，需要 Jetifier 与 vector drawable 版本协调。
- 火山原生 AAR 默认合并超出 camera-only 范围的权限和组件，宿主必须显式移除并对最终 merged manifest 做测试。
- COS 1.2.9 的 Android plugin module compileSdk 为 31，需要宿主提高到 36。
- 两个 iOS 插件均未支持 Swift Package Manager。
- 火山 iOS 插件排除模拟器 arm64，RTC 只能以真机作为最终验收环境。
