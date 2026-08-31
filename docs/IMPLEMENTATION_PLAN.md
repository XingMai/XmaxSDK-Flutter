# XmaxSDK Flutter 摄像头版执行方案

## 1. 文档目的

本文档定义 XmaxSDK Flutter 摄像头版的实现范围、架构、依赖、执行顺序和验收标准。

现有 iOS SDK 是公开 API、架构分层、业务状态和错误语义的唯一基准。Flutter 版本不重新设计公开 SDK，仅在内部使用适合 Dart/Flutter 的并发、状态管理和 Widget 实现。

配套的公开 API 契约见 [API_PARITY.md](API_PARITY.md)。当本文档与 API 对照文档发生冲突时，以 `API_PARITY.md` 和 iOS 源码为准。

本地环境、Package 初始化和 Example 工程的详细方案见 [BOOTSTRAP_AND_EXAMPLE.md](BOOTSTRAP_AND_EXAMPLE.md)。

基准源码：

- `../../iOS/XmaxSDK/Sources/XmaxSDK`
- iOS SDK 版本：`1.0.1`
- Flutter 摄像头版版本：`1.0.1`

## 2. 已确认决策

1. XmaxSDK Flutter 自身全部使用 Dart/Flutter 实现。
2. 不复用或包装 iOS、Android XmaxSDK。
3. 不编写 Xmax 自有 Swift、Objective-C、Java 或 Kotlin 媒体实现。
4. RTC 直接依赖火山引擎官方 Flutter SDK。
5. COS 直接依赖腾讯云官方 Flutter SDK。
6. 首版实时输入只支持 RTC 内部摄像头采集；与 iOS 当前相机流一致，不采集或发布本地麦克风音频。
7. 首版不实现图片、本地视频作为 RTC 输入源。
8. 首版不实现远端解码帧回调和视频插帧。
9. COS Storage 仍然保留，用于参考图片、业务素材和独立文件管理，不属于 RTC 本地媒体管线。
10. 公开 API、类名、方法名、状态和行为严格对齐 iOS 的已支持子集。
11. 内部目录继续使用 iOS 的 `Core / Foundation / Media / Render / Service / Stream` 分层。

## 3. 首版范围

### 3.1 包含

- SDK 全局配置、API Key 校验和日志选项。
- Xmax HTTP API 请求和统一错误映射。
- 创建、维持和关闭实时 Session。
- 10 秒 Session 心跳及失败清理。
- 火山 RTC Engine 和 Room 生命周期。
- 摄像头权限。
- 前置或后置摄像头启动。
- 摄像头切换。
- 本地摄像头预览。
- RTC 视频编码配置。
- 本地视频发布、取消发布。
- 远端音视频订阅、取消订阅。
- 远端生成画面和音频播放。
- 开始、更新、停止生成。
- 房间消息和 SEI 接收。
- 网络质量、性能告警和 RTC 统计。
- Flutter 轨迹采集、坐标转换、信令发送和效果渲染。
- COS 临时凭证、上传、下载和进度。
- Example App、单元测试和 iOS/Android 真机集成测试。

### 3.2 不包含

- `createLocalImageStream`
- `stopLocalImageStream`
- `createLocalVideoStream`
- `stopLocalVideoStream`
- `isFrameInterpolationEnabled`
- `setFrameInterpolationEnabled`
- 外部视频帧推送。
- 外部 PCM 音频帧推送。
- 图片解码和循环视频帧生成。
- 本地视频文件解码、播放和音视频同步。
- NV12、BGRA、CVPixelBuffer 等原始视频格式转换。
- 远端原始解码帧监听。
- VideoToolbox 或 Android 原生插帧。
- Web、macOS、Windows、Linux 和 HarmonyOS 支持。

不支持的公开方法不得以空实现、固定返回值或 `UnsupportedError` 形式占位。首版直接不暴露这些成员。

## 4. 平台和依赖基线

### 4.1 Flutter

- 开发和 CI：Flutter `3.47.1`
- Package 最低 Flutter：`3.35.0`
- Package 最低 Dart：`3.9.0`
- Dart 上限：`<4.0.0`

### 4.2 移动平台

- iOS：15.0+
- Android：minSdk 26+
- Android Java：17
- Android compileSdk：采用项目创建时 Flutter stable 推荐版本

### 4.3 首轮依赖锁定

```yaml
dependencies:
  flutter:
    sdk: flutter
  permission_handler: 12.0.3
  volc_engine_rtc: 3.60.6
  tencentcloud_cos_sdk_plugin_nobeacon: 1.2.9
```

生产依赖使用精确版本，不使用 `^`。新增网络、权限等依赖前需要记录选择原因、原生传递依赖和最低平台变化。

当前已知约束：

- 火山 Flutter `3.60.6` 内置的原生 RTC 版本低于现有 iOS/Android XmaxSDK 使用的补丁版本，必须进行协议和真机回归。
- 实际解析版本为 Android `3.60.105.1900`、iOS `3.60.105.2300`。
- 火山 Flutter `3.60.6` 的 Podspec 排除了 iOS Simulator arm64。RTC 验收以 iOS 真机为准；模拟器仅用于非 RTC 开发和 Dart 测试。
- 火山 RTC 与 COS 插件当前均不支持 Swift Package Manager，iOS 宿主必须保留 CocoaPods 接入。
- 火山 Android AAR 仍依赖 Support Library 28，并且 Flutter 插件仍自行应用旧式 Kotlin Gradle Plugin；需要 Jetifier，未来 Flutter 升级前必须重新验证。
- COS `1.2.9` Android plugin module 将 compileSdk 固定为 31；Flutter 3.47.1/AGP 9.1 宿主需要在 Variant API `finalizeDsl` 阶段统一提高到 36。
- 腾讯 COS 默认使用无 Beacon 包，与现有 Android XmaxSDK 的隐私策略保持一致。

## 5. 架构

### 5.1 目录

Dart 文件使用 `lower_snake_case`，层级、类型职责和 iOS 保持一致。

```text
lib/
├── xmax_sdk.dart
└── src/
    ├── core/
    │   ├── xmax_client.dart
    │   ├── xmax_configuration.dart
    │   ├── realtime/
    │   └── storage/
    ├── foundation/
    │   ├── errors/
    │   ├── logging/
    │   ├── media/
    │   │   ├── camera/
    │   │   └── video/
    │   ├── permissions/
    │   ├── rtc/
    │   └── storage/
    ├── media/
    │   ├── camera/
    │   ├── interaction/
    │   ├── media_controller.dart
    │   └── media_controlling.dart
    ├── render/
    │   ├── trajectory/
    │   ├── video/
    │   ├── render_controller.dart
    │   └── render_controlling.dart
    ├── service/
    │   ├── media/
    │   ├── network/
    │   ├── realtime/
    │   └── storage/
    ├── stream/
    │   ├── encoding/
    │   ├── quality/
    │   ├── room/
    │   ├── stream_controller.dart
    │   ├── stream_controlling.dart
    │   └── stream_id.dart
    └── xmax_sdk_info.dart
```

### 5.2 分层职责

#### Core

公开入口和业务编排层，对齐 iOS：

- `XmaxClient`
- `XmaxConfiguration`
- `XmaxRealtimeManager`
- `XmaxRealtimeConnectionManager`
- `XmaxRealtimeGenerationManager`
- `XmaxStorageManager`

Core 只协调下层组件，不直接调用火山或腾讯 SDK。

#### Service

服务端协议和公开业务模型层，对齐 iOS：

- `ApiService`
- `RealtimeSessionService`
- Realtime DTO 和公开状态模型。
- `StorageService`
- `MediaService`

Service 不持有 Widget、RTC View 或移动平台 UI 对象。

#### Foundation

平台和第三方 SDK 适配层，对齐 iOS：

- 统一错误和日志。
- 权限检查。
- 火山 RTC Engine、Room、事件和类型转换。
- 腾讯 COS 上传下载适配。
- 公共相机方向和视频显示模式。

火山和腾讯类型不得越过 Foundation 暴露到公开 API。

#### Media

本地媒体所有权和交互输入层，对齐 iOS：

- `MediaController`
- `CameraController`
- `InteractionController`

首版 `MediaController` 只有 `.camera` 一种本地来源，不保留 image/video 分支。

#### Stream

RTC 房间和流协调层，对齐 iOS：

- `StreamController`
- `RoomController`
- `EncodingController`
- `QualityController`

负责房间配置、发布订阅、生成消息、远端音量、质量事件和流状态。

#### Render

视频轨道、RTC View 和轨迹层，对齐 iOS：

- `RenderController`
- `VideoRenderRegistry`
- `VideoRenderBinding`
- `XmaxVideoView`
- Trajectory 相关类型。

首版远端画面直接使用火山 RTC View。`RenderController` 通过 RTC 首帧事件完成生成画面就绪判断，不获取原始远端视频帧。

### 5.3 依赖方向

```text
Core
├── Media
├── Stream
├── Render
└── Service
     │
     ▼
Foundation
```

不允许形成以下依赖：

- Foundation 依赖 Core。
- Service 依赖 Render 或 Widget。
- 公开模型引用火山、腾讯或权限插件类型。
- Render 直接发送服务端请求。

## 6. 核心运行流程

### 6.1 创建客户端

```text
XmaxConfiguration
  → 规范化 apiKey
  → XmaxClient
  → 配置 XmaxLogger
  → 创建 ApiService
```

与 iOS 一致，本地相机预览不要求先验证 API Key。需要访问 Xmax API 的操作再调用 `configuration.validate()`。

### 6.2 创建本地摄像头流

```text
createLocalCameraStream
  → MediaController 获得本地媒体所有权
  → RtcEngineManager 获取/创建 RTC Engine
  → CameraController 检查相机权限
  → 规范化模型输入尺寸
  → 配置前/后摄像头
  → 配置视频采集和编码参数
  → startVideoCapture
  → 注册本地 RealtimeVideoTrack 渲染绑定
  → 返回 RealtimeMediaStream
```

约束：

- 同一 Manager 同时只允许一个本地媒体流。
- 创建失败必须回滚采集、渲染绑定和 Engine 引用。
- `stopLocalCameraStream` 和 `close` 必须幂等。

### 6.3 建立连接

```text
connect(localStream:)
  → 验证本地流属于当前 Manager
  → 校验 XmaxConfiguration
  → POST /session
  → 解析 sessionUid、room_id、room_token、user_id、bot_name
  → createRTCRoom
  → joinRoom
  → 配置 Room 和远端目标
  → 发布本地视频；相机来源不发布本地音频
  → 等待目标远端视频流
  → 订阅远端视频
  → 注册远端 RealtimeVideoTrack
  → 启动 Session 心跳
  → 状态变为 connected
```

连接失败时必须按相反顺序清理已创建资源，并进入 `error` 状态。

### 6.4 开始和更新生成

```text
startGeneration(context:)
  → 验证 connected/generating
  → 首次调用要求 context 非空
  → 生成中再次调用视为更新条件
  → 发送 start/change generation Room 消息
  → 等待确认事件和远端首帧
  → 订阅并启用远端音频
  → 状态变为 generating
```

带 `localStream` 的调用在尚未连接时先执行 `connect`，然后开始生成；已连接时复用当前连接。

### 6.5 切换摄像头

```text
switchCamera
  → 验证当前来源为 camera
  → 若正在生成，停止当前生成并保留 context
  → 调用火山 switchCamera
  → 更新原 RealtimeVideoTrack.position
  → 等待新摄像头首帧
  → 使用缓存 context 恢复生成
```

RTC Room 和 `RealtimeVideoTrack` 对象身份保持不变。

### 6.6 停止与关闭

`stopGeneration`：

```text
停止 Interaction
  → 发送 stop generation
  → 关闭生成任务确认
  → 保留 RTC 连接
  → 状态回到 connected
```

`disconnect`：

```text
停止生成
  → 取消订阅和发布
  → leaveRoom
  → 停止心跳
  → DELETE /session/{id}
  → 保留本地摄像头预览
  → 状态变为 disconnected
```

`close`：

```text
disconnect
  → stopLocalCameraStream
  → 解绑全部渲染资源
  → 释放 RTC Engine 引用
```

关闭期间重复调用等待同一清理任务；关闭完成后允许重新创建本地摄像头流。

## 7. 状态和并发

公开状态严格使用 iOS 的状态集合：

```text
idle
  → connecting
  → connected
  → generating
  → connected
  → disconnecting
  → disconnected

不可恢复失败 → error
```

实现要求：

- 所有改变生命周期的公开异步操作必须串行化。
- 使用私有 operation version/token 丢弃迟到结果。
- `connect`、`disconnect`、`close`、`switchCamera` 和 generation 操作不得交错破坏状态。
- listener 在 Flutter UI isolate 调用。
- listener 中抛出的异常不得破坏 SDK 内部状态。
- Engine/Room 销毁后的迟到 RTC 回调必须被忽略。
- 不增加公开 lifecycle API。

Flutter `AppLifecycleState` 只作为内部资源保护信号，不改变 iOS 已定义的公开状态语义。首版不得因页面短暂 `inactive` 自动关闭 Session；Widget dispose 只解绑视图，不等同于 `disconnect`。

## 8. 渲染和交互

### 8.1 Widget

- `XmaxVideoView`：绑定视频轨道和轨迹层的 StatefulWidget。

公开配置与 iOS UIKit API 一致：

- `track`
- `videoContentMode`
- `isInteractionEnabled`
- `trajectoryRenderer`

### 8.2 视图组成

```text
Stack
├── 火山 RTCSurfaceView
└── Flutter Trajectory Overlay
```

验证重点：

- iOS PlatformView 上层手势命中。
- Android TextureView/PlatformView 上层透明 Widget。
- `fit`/`fill` 的裁剪区域和轨迹坐标映射。
- track 切换时旧绑定完整解除。
- Widget 移出树后不销毁仍在运行的 Manager。
- 横竖屏和安全区变化不改变归一化轨迹。

## 9. Storage/COS

Storage 保持 iOS 的三层结构：

```text
Core/Storage/XmaxStorageManager
  → Service/Storage/StorageService
    → Foundation/Storage/StorageManager
      → Tencent COS Flutter SDK
```

上传流程：

```text
uploadImage/uploadVideo
  → 校验来源、文件名和 Content-Type
  → GET /cos/sts
  → 解析 bucket、region、endpoint、临时凭证
  → 创建单次 COS 任务
  → 上报进度
  → 返回 XmaxUploadedFile
```

安全要求：

- 永久 SecretId/SecretKey 不得进入 SDK、Example 或测试仓库。
- 临时凭证不写日志、不持久化。
- 日志必须脱敏 Authorization、Token、Secret 和完整响应。
- 默认 HTTPS。
- 图片安全检查失败映射为 `unsafeImage`。
- COS 客户端错误和服务端错误统一映射为 `uploadError` 或 `downloadError`。

## 10. 宿主集成要求

### 10.1 iOS

宿主 `Info.plist`：

```xml
<key>NSCameraUsageDescription</key>
<string>用于实时视频生成</string>
```

宿主 `Podfile`：

```ruby
source 'https://github.com/volcengine/volcengine-specs.git'
source 'https://cdn.cocoapods.org/'

platform :ios, '15.0'
```

### 10.2 Android

宿主 Gradle 仓库：

```kotlin
maven(url = "https://artifact.bytedance.com/repository/Volcengine/")
```

该仓库必须同时加入 `settings.gradle.kts` 的 `pluginManagement.repositories` 和根 `build.gradle.kts` 的 `allprojects.repositories`。

宿主 `gradle.properties`：

```properties
android.useAndroidX=true
android.enableJetifier=true
```

宿主 Manifest：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

火山原生 AAR 会额外合并麦克风、屏幕投影、画中画、旧外部存储、Phone State 和 Overlay 能力。camera-only 宿主必须在 Manifest 中通过 `tools:node="remove"` 移除这些权限与 `RXScreenCaptureService`、`FloatingWindow` 组件；最终 merged manifest 才是隐私验收依据。完整声明见 `example/android/app/src/main/AndroidManifest.xml`。

Flutter 3.47.1/AGP 9.1 还需要对旧插件 module 应用 compileSdk 36 和 AndroidX vector drawable 1.1.0 兼容配置。完整可编译示例见 `example/android/build.gradle.kts`、`example/android/app/build.gradle.kts` 和 `example/android/gradle.properties`。

SDK 负责检查和请求运行时权限；宿主负责平台用途说明和最终 Manifest/Info.plist 合并结果。

## 11. 执行阶段

### 阶段 0：工程和契约

- 安装 FVM，并固定本地和 CI 使用 Flutter `3.47.1`。
- 执行 `flutter doctor -v`，验证现有 Xcode、CocoaPods、Java 和 Android SDK。
- 创建普通 Flutter Package；不创建 Xmax 自有原生 Plugin。
- 创建标准单数目录 `example/`，仅生成 iOS 和 Android 宿主。
- Example 通过 `path: ../` 接入根 Package。
- 配置 analyzer、format、test、integration_test。
- 创建公开入口 `lib/xmax_sdk.dart` 和 iOS 对齐的目录骨架。
- 建立公开 API 对照测试/清单。
- 锁定第三方依赖。
- 创建首页、摄像头实时页和 Storage 页的路由骨架。

验收：

- `flutter analyze` 通过。
- 根 Package 和 Example 的测试通过。
- Example 能生成 Android Debug APK 和 iOS 无签名 Debug App。
- Example 在 Android、iOS 真机至少各启动一次，第三方插件完成注册。
- 公开入口不导出 `src/` 内部类型。
- Example 不导入 `package:xmax_sdk/src/...`，也不直接调用火山或 COS API。

阶段 0 的命令、目录、页面职责和完成标准以 `BOOTSTRAP_AND_EXAMPLE.md` 为准。

### 阶段 1：Foundation 与 Service

- 错误码、`XmaxError`、日志选项。
- `ApiServicing` 和 `ApiService`。
- Realtime、Storage 公开模型。
- Session 创建、心跳、关闭。
- 模型输入尺寸规则。

验收：

- API Key、错误响应、超时、取消和 JSON 异常测试通过。
- Session DTO 兼容对象形式和 JSON 字符串形式的 `modelExtra`。
- 心跳停止后迟到响应不改变状态。

### 阶段 2：Foundation/RTC

- `RtcManaging`。
- `RtcEngineManager`。
- `RtcManager`。
- Engine/Room event bridge。
- RTC 质量转换和统计日志。

验收：

- 真机创建/销毁 Engine。
- 摄像头首帧回调。
- 创建/加入/离开 Room。
- 连续初始化释放无崩溃和资源占用。

### 阶段 3：Media 与 Stream

- `CameraController`、`MediaController`。
- `EncodingController`。
- `RoomController`。
- `QualityController`。
- `StreamController`。

验收：

- 本地预览和前后摄像头切换。
- 发布本地视频并订阅远端音视频。
- 发现并订阅目标远端流。
- 网络质量和性能告警语义与 iOS 一致。

### 阶段 4：Render 与 Interaction

- `VideoRenderRegistry` 和 binding。
- `XmaxVideoView`。
- Flutter trajectory overlay 和默认效果。
- `RenderController` 远端首帧等待。

验收：

- 本地和远端 track 可使用同一 Widget 显示。
- track 置空显示空白容器并解除 RTC 绑定。
- 轨迹在 fit/fill 下坐标正确。
- 自定义 renderer 不改变采样和发送。

### 阶段 5：Core/Realtime

- `XmaxRealtimeConnectionManager`。
- `XmaxRealtimeGenerationManager`。
- `XmaxRealtimeManager`。
- 完整状态和并发控制。

验收：

- connect、start/update/stopGeneration、disconnect、close 全链路。
- 生成中切换摄像头可停止并恢复生成。
- 重复和交错操作不会留下 Session、Room 或相机资源。

### 阶段 6：Storage

- COS 临时凭证和客户端配置。
- 图片/视频上传下载。
- 进度和安全检查。

验收：

- 字节和本地文件两种上传来源。
- 临时凭证过期、403 和网络中断错误正确。
- 上传结果 URL、objectKey 和 etag 正确。

### 阶段 7：发布准备

- 完善 README、CHANGELOG、Example。
- 平台配置说明。
- API 文档和迁移示例。
- iOS/Android 真机长稳测试。

验收：

- 连续 20 次“预览—连接—生成—停止—断开”成功。
- 无残留音频、摄像头占用或重复回调。
- 内存无持续线性增长。
- Package 能通过 path/git 方式被干净宿主接入。

## 12. 测试矩阵

### 单元测试

- 配置规范化和校验。
- 全部公开枚举 raw value。
- `RealtimeVideoFormat.validate`。
- 状态机合法和非法迁移。
- Session DTO 和心跳。
- Room 消息编码和解析。
- 质量、性能告警和错误映射。
- Storage 来源、Content-Type、进度和错误。
- 轨迹坐标映射。

### Widget 测试

- `XmaxVideoView` 默认参数。
- track 更新和置空。
- `fit`/`fill` 布局。
- interaction 开关。
- 自定义 trajectory renderer。

### 真机集成测试

- iOS 15+ 真机。
- Apple Silicon 开发机上的 iOS device build。
- Android API 26 基线设备/模拟器。
- 当前主流 Android API 设备。
- 前后摄像头。
- 相机权限允许、拒绝和永久拒绝。
- Wi-Fi/蜂窝切换、断网和恢复。
- 前后台切换。
- 页面 push/pop 和 Widget 重建。
- 连接/断开循环和异常清理。

## 13. 完成定义

满足以下全部条件才认为 Flutter 摄像头版完成：

1. `API_PARITY.md` 中所有“首版实现”成员已经实现并测试。
2. 没有对外暴露未计划的第三方类型或新命名体系。
3. iOS/Android 真机 RTC 主流程通过。
4. COS 主流程和异常流程通过。
5. Example 能独立演示配置、预览、连接、生成、切换摄像头、断开和上传。
6. 所有公开类型有 Dart doc。
7. `flutter analyze` 和全部自动化测试通过。
8. 无已知的 P0/P1 生命周期、资源泄漏或安全问题。
