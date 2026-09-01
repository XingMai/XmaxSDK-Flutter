# XmaxSDK iOS → Flutter 公开 API 对照

## 1. 契约原则

本文档固定 XmaxSDK Flutter 摄像头版的公开 API。现有 iOS SDK 是唯一命名和语义基准。

规则：

1. 公开类名、协议名、属性名、方法名、参数名和枚举 case 优先与 iOS 一致。
2. 不为了 Dart 习惯重新命名公开 API。
3. iOS listener API 在 Flutter 中仍然使用 listener，不替换为公开 Stream。
4. iOS `async throws` 在 Flutter 中映射为 `Future<T>`；失败抛出 `XmaxError`。
5. 公开 API 不包含火山 RTC、腾讯 COS 或权限插件类型。
6. Dart 无法表达 Swift 重载时，保留原方法名和参数名，通过可选命名参数折叠为一个方法。
7. 首版不支持的图片 RTC 输入、本地视频 RTC 输入和插帧 API 不提供占位实现。
8. 除本文档列出的语言映射和首版范围裁剪外，行为、默认值、状态迁移和错误语义与 iOS 一致。

## 2. 语言类型映射

| iOS | Flutter | 说明 |
|---|---|---|
| `String` | `String` | 语义不变 |
| `Int` / `Int64` / `UInt` | `int` | Dart 整数 |
| `Float` / `Double` / `TimeInterval` | `double` | Dart 浮点数 |
| `Bool` | `bool` | 语义不变 |
| `Data` | `Uint8List` | 二进制数据 |
| `URL` | `Uri` | 本地文件只接受 `file` URI |
| `CGPoint` / `CGSize` | `Offset` / `Size` | Flutter UI 几何类型 |
| `Progress` | `XmaxStorageProgress` | Dart 无 Foundation Progress |
| `UUID` | `String` | 内部生成的规范 UUID 字符串 |
| Swift `struct` | Dart immutable `final class` | 实现 `==`/`hashCode` |
| Swift `enum: String` | Dart `enum` + `value` | value 必须与 raw value 一致 |
| Swift `OptionSet` | Dart immutable value class | 保留位掩码和静态成员 |
| Swift protocol | `abstract interface class` | 公开能力接口 |
| Swift typealias closure | Dart `typedef` | listener 名称不变 |
| `async throws -> Void` | `Future<void>` | 抛出 `XmaxError` |
| `async throws -> T` | `Future<T>` | 抛出 `XmaxError` |
| `@MainActor` | Flutter UI isolate | listener 和渲染回调 |
| UIKit UIView | Flutter StatefulWidget | `XmaxVideoView` |

## 3. 首版公开入口

`lib/XmaxSDK.dart` 只导出本文件列出的公开类型。`lib/src` 下的 Controller、Service、Foundation adapter 和第三方类型默认不导出。

## 4. SDK 信息

### XmaxSDKInfo

iOS：`XmaxSDKInfo`

Flutter：

```dart
abstract final class XmaxSDKInfo {
  static const String version = '1.0.0';
}
```

## 5. 配置和入口

### XmaxConfiguration

保留：

- `apiKey`
- `loggerOptions`
- `validate()`

Flutter 契约：

```dart
final class XmaxConfiguration {
  XmaxConfiguration({
    required String apiKey,
    XmaxLoggerOption loggerOptions =
        const XmaxLoggerOption(rawValue: 0),
  });

  final String apiKey;
  final XmaxLoggerOption loggerOptions;

  void validate();
}
```

行为：

- 构造时 trim `apiKey`。
- 空 API Key 在 `validate()` 抛出 `invalidAPIKey`。
- 本地摄像头预览不提前调用 `validate()`。

### XmaxLoggerOption

保留成员：

- `rawValue`
- `business`
- `performance`
- `all`

位值与 iOS 一致：

- business：`1 << 0`
- performance：`1 << 1`
- all：business + performance

### XmaxClient

Flutter 契约：

```dart
final class XmaxClient {
  XmaxClient({required XmaxConfiguration configuration});

  final XmaxConfiguration configuration;

  XmaxRealtimeManaging createRealtimeManager({
    required RealtimeConfiguration options,
  });

  XmaxStorageManaging createStorageManager();

  MediaServicing createMediaService();
}
```

语义与 iOS 一致：

- `createRealtimeManager` 不因 API Key 为空立即失败。
- `createStorageManager` 创建前校验全局配置。
- `createMediaService` 返回平台无关的业务能力查询 Service。

## 6. Realtime 配置

### RealtimeModel

| case | value |
|---|---|
| `x2_0` | `x2.0` |

### RealtimeConfiguration

摄像头首版保留：

```dart
final class RealtimeConfiguration {
  const RealtimeConfiguration({required this.model});

  final RealtimeModel model;
}
```

iOS 的 `isFrameInterpolationEnabled` 不进入首版，因为 Flutter 首版明确不实现插帧。不得保留一个无效或被忽略的配置项。

## 7. Realtime 公开模型

### RealtimeContext

```dart
final class RealtimeContext {
  RealtimeContext({
    required String prompt,
    String? referencePath,
  });

  final String prompt;
  final String? referencePath;
}
```

行为：

- trim `prompt`。
- trim `referencePath`。
- 空 `referencePath` 规范化为 null。

### RealtimeVideoFormat

```dart
final class RealtimeVideoFormat {
  const RealtimeVideoFormat({
    required this.width,
    required this.height,
    required this.fps,
  });

  final int width;
  final int height;
  final int fps;

  void validate();
}
```

校验语义与 iOS 一致：

- width > 0
- height > 0
- fps > 0
- width 为偶数
- height 为偶数

失败抛出 `invalidConfiguration`。

### RealtimeVideoTrack

```dart
final class RealtimeVideoTrack {
  String get id;
  RealtimeVideoFormat? get videoFormat;
  CameraPosition? get position;
}
```

构造和元数据更新方法不公开。`switchCamera()` 必须更新原 track 的 `position`，不能替换 track 实例。

### RealtimeMediaStream

```dart
final class RealtimeMediaStream {
  String get id;
  RealtimeVideoTrack? get videoTrack;
}
```

构造方法不公开。

### CameraPosition

| case | value |
|---|---|
| `front` | `front` |
| `back` | `back` |

### VideoContentMode

| case | value |
|---|---|
| `fit` | `fit` |
| `fill` | `fill` |

## 8. Realtime 状态

### RealtimeConnectionState

case 和 value 必须与 iOS 完全一致：

| case | value |
|---|---|
| `idle` | `Idle` |
| `connecting` | `Connecting` |
| `connected` | `Connected` |
| `generating` | `Generating` |
| `disconnecting` | `Disconnecting` |
| `disconnected` | `Disconnected` |
| `error` | `Error` |

不得增加 `previewing`、`reconnecting`、`closed` 等公开状态。内部可以有更细状态，但不能泄漏。

### RealtimeState

```dart
final class RealtimeState {
  const RealtimeState({
    required this.connectionState,
    this.sessionID,
    this.taskID,
  });

  final RealtimeConnectionState connectionState;
  final String? sessionID;
  final String? taskID;
}
```

### Listener typedef

```dart
typedef RealtimeStateListener = void Function(RealtimeState state);
typedef RealtimeErrorListener = void Function(XmaxError error);
typedef RealtimeCameraPreviewReadyListener = void Function();
typedef RealtimeNetworkQualityListener = void Function(
  RealtimeNetworkQuality quality,
);
typedef RealtimePerformanceAlarmListener = void Function(
  RealtimePerformanceAlarm alarm,
);
```

listener 接受 null 时清除。回调必须在 Flutter UI isolate 执行。

## 9. 网络质量和性能告警

### RealtimeNetworkQualityLevel

| case | value |
|---|---|
| `unknown` | `Unknown` |
| `excellent` | `Excellent` |
| `good` | `Good` |
| `poor` | `Poor` |
| `bad` | `Bad` |
| `veryBad` | `VeryBad` |
| `down` | `Down` |

### RealtimeNetworkQuality

保留：

- `uplink`
- `downlink`

### RealtimePerformanceStatus

| case | value |
|---|---|
| `limited` | `Limited` |
| `recovered` | `Recovered` |

### RealtimePerformanceAlarm

保留：

- `status`
- `suggestedVideoFormat`

## 10. XmaxRealtimeManaging

使用 Dart `abstract interface class`，名称保持不变。

### 10.1 属性

```dart
RealtimeConfiguration get options;
Future<RealtimeState> get currentState;
```

首版不提供 `isFrameInterpolationEnabled`。

### 10.2 Listener

```dart
Future<void> setStateListener(RealtimeStateListener? listener);
Future<void> setErrorListener(RealtimeErrorListener? listener);
Future<void> setCameraPreviewReadyListener(
  RealtimeCameraPreviewReadyListener? listener,
);
Future<void> setNetworkQualityListener(
  RealtimeNetworkQualityListener? listener,
);
Future<void> setPerformanceAlarmListener(
  RealtimePerformanceAlarmListener? listener,
);
```

### 10.3 音量

```dart
Future<void> setLocalAudioVolume(double volume);
Future<void> setRemoteAudioVolume(double volume);
```

语义：

- 有效范围 `0...1`。
- 越界或非有限数字抛出 `invalidConfiguration`。
- `setRemoteAudioVolume` 在远端流尚未订阅时保存，订阅前应用。
- 摄像头首版没有本地文件音频预览，也不采集麦克风，因此 `setLocalAudioVolume` 校验后不产生音频变化，与 iOS 相机来源行为一致。

### 10.4 摄像头

Swift 默认参数重载折叠为一个 Dart 方法：

```dart
Future<RealtimeMediaStream> createLocalCameraStream({
  required RealtimeVideoFormat videoFormat,
  CameraPosition position = CameraPosition.front,
});

Future<void> stopLocalCameraStream();

Future<RealtimeMediaStream> switchCamera();
```

### 10.5 连接

```dart
Future<RealtimeMediaStream> connect({
  required RealtimeMediaStream localStream,
});

Future<void> disconnect();
Future<void> close();
```

行为：

- `disconnect` 保留当前本地摄像头预览。
- `close` 释放连接、本地媒体和 RTC Engine。
- `close` 完成后允许重新创建本地流。

### 10.6 生成

iOS 存在以下重载：

- `startGeneration(context:) -> Void`
- `startGeneration(localStream:context:) -> RealtimeMediaStream`
- `startGeneration()`
- `startGeneration(localStream:) -> RealtimeMediaStream`

Dart 不支持方法重载，固定折叠为：

```dart
Future<RealtimeMediaStream?> startGeneration({
  RealtimeMediaStream? localStream,
  RealtimeContext? context,
});

Future<void> stopGeneration();
```

调用语义：

```dart
await manager.startGeneration(context: context);

final remoteStream = await manager.startGeneration(
  localStream: localStream,
  context: context,
);

await manager.startGeneration();

final remoteStream = await manager.startGeneration(
  localStream: localStream,
);
```

返回规则：

- 未传 `localStream` 时完成后返回 null，对齐 iOS Void 重载。
- 传入 `localStream` 时返回非空远端流。
- 首次开始生成时 `context` 不得为空。
- 生成中再次调用更新条件。

### 10.7 首版排除成员

以下 iOS 成员不进入 Flutter 摄像头版：

- `isFrameInterpolationEnabled`
- `setFrameInterpolationEnabled`
- `createLocalImageStream` 全部重载
- `stopLocalImageStream`
- `createLocalVideoStream` 全部重载
- `stopLocalVideoStream`

## 11. MediaServicing

Flutter 契约：

```dart
abstract interface class MediaServicing {
  Size resolveModelInputSize(Size size);
}
```

首版不提供 `supportsFrameInterpolation`。

尺寸规范化算法、异常和结果必须与 iOS `MediaService` 一致。

## 12. Storage

Storage 不是 RTC 图片/视频输入管线，首版继续完整保留。

### 12.1 XmaxStorageProgress

Dart 没有 Foundation `Progress`，新增最小平台映射模型：

```dart
final class XmaxStorageProgress {
  const XmaxStorageProgress({
    required this.completedBytes,
    required this.totalBytes,
  });

  final int completedBytes;
  final int totalBytes;
  double get fractionCompleted;
}

typedef XmaxStorageProgressHandler = void Function(
  XmaxStorageProgress progress,
);
```

约束：

- `fractionCompleted` 在 totalBytes > 0 时为 completed/total。
- completedBytes 不得超过 totalBytes。
- 不额外承诺进度回调的调度时机；接入方更新 UI 时自行调度到所需上下文。

### 12.2 XmaxUploadedFile

公开只读属性：

- `Uri url`
- `String objectKey`
- `String? etag`

构造不公开。

### 12.3 XmaxDownloadedFile

公开只读属性：

- `Uri fileURL`
- `int byteCount`

构造不公开。

### 12.4 XmaxStorageManaging

iOS 使用 `Data`/`URL` 重载。Dart 固定通过同名方法的 `data` 和 `at` 参数表达来源，并要求二选一：

```dart
abstract interface class XmaxStorageManaging {
  Future<XmaxUploadedFile> uploadImage({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxUploadedFile> uploadImageWithSafetyCheck({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxUploadedFile> uploadVideo({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxDownloadedFile> downloadImage({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxDownloadedFile> downloadVideo({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  });
}
```

上传参数规则：

- `data` 和 `at` 必须且只能提供一个。
- data 来源必须提供非空 `fileName` 和 `contentType`。
- at 来源必须是 `file` URI。
- at 来源 `contentType` 可空，由 SDK 推断。
- progress 可空。

示例：

```dart
await storage.uploadImage(
  data: bytes,
  fileName: 'reference.png',
  contentType: 'image/png',
);

await storage.uploadImage(
  at: fileUri,
);
```

## 13. 错误

### XmaxErrorCode

即使部分能力首版不实现，为了错误值兼容，完整保留 iOS case 和 value：

| case | value |
|---|---|
| `invalidAPIKey` | `INVALID_API_KEY` |
| `invalidConfiguration` | `INVALID_CONFIGURATION` |
| `internalError` | `INTERNAL_ERROR` |
| `networkError` | `NETWORK_ERROR` |
| `apiError` | `API_ERROR` |
| `sessionError` | `SESSION_ERROR` |
| `rtcError` | `RTC_ERROR` |
| `mediaError` | `MEDIA_ERROR` |
| `frameInterpolationUnsupported` | `FRAME_INTERPOLATION_UNSUPPORTED` |
| `cameraPermissionDenied` | `CAMERA_PERMISSION_DENIED` |
| `microphonePermissionDenied` | `MICROPHONE_PERMISSION_DENIED` |
| `uploadError` | `UPLOAD_ERROR` |
| `downloadError` | `DOWNLOAD_ERROR` |
| `unsafeImage` | `UNSAFE_IMAGE` |
| `cancelled` | `CANCELLED` |
| `timeout` | `TIMEOUT` |

### XmaxError

Flutter 契约：

```dart
final class XmaxError implements Exception {
  const XmaxError({
    required this.code,
    required this.message,
    this.apiCode,
    this.httpStatus,
  });

  final XmaxErrorCode code;
  final String message;
  final int? apiCode;
  final int? httpStatus;

  static XmaxError from(Object error);
}
```

已有 `XmaxError` 原样返回；其他异常默认映射为 `internalError`，已知网络、RTC、权限和 COS 异常在各自边界先映射为对应错误码。

## 14. 视频 Widget

### XmaxVideoView

Flutter 契约：

```dart
class XmaxVideoView extends StatefulWidget {
  const XmaxVideoView({
    super.key,
    this.track,
    this.videoContentMode = VideoContentMode.fill,
    this.isInteractionEnabled = true,
    this.trajectoryRenderer,
  });

  final RealtimeVideoTrack? track;
  final VideoContentMode videoContentMode;
  final bool isInteractionEnabled;
  final TrajectoryEffectRendering? trajectoryRenderer;
}
```

行为对齐：

- track 为空显示黑色空容器。
- track 改变时先解除旧轨道，再绑定新轨道。
- Widget dispose 时解除轨道绑定。
- 默认 content mode 为 fill。
- 默认允许 interaction。
- 自定义 trajectory renderer 只改变视觉效果。

Flutter Widget 属性不可像 UIKit UIView 一样原地赋值；接入方通过 rebuild 传入新值。这是 UI 框架差异，不改变属性名或结果语义。

## 15. Trajectory

### TrajectoryID

公开类型，实例由 SDK 创建；内部 UUID 字符串不公开修改。

### TrajectoryPoint

公开只读属性：

- `id`
- `Offset location`
- `Offset normalizedLocation`
- `double timestamp`

### TrajectoryEffectRendering

```dart
abstract interface class TrajectoryEffectRendering {
  Widget get view;

  void renderBegan(List<TrajectoryPoint> points);
  void renderMoved(List<TrajectoryPoint> points);
  void renderEnded(List<TrajectoryID> identifiers);
  void reset();
}
```

方法名和触发语义与 iOS 一致。回调在 Flutter UI isolate 执行。

### DefaultTrajectoryEffectRenderer

名称和默认行为与 iOS 对齐，作为 SDK 默认视觉实现公开。

## 16. 不得公开的类型

以下类型即使内部存在，也不得从 `XmaxSDK.dart` 导出：

- `RtcManager`
- `RtcManaging`
- `RtcEngineManager`
- `RoomController`
- `StreamController`
- `MediaController`
- `RenderController`
- `ApiService`
- `StorageService`
- 火山 SDK 所有类型。
- 腾讯 COS SDK 所有类型。
- 权限插件类型。
- 内部 Session DTO。
- 内部 operation token、registry 和 binding。

## 17. API 一致性验收

每个版本发布前必须完成：

1. 对照 iOS `public` 声明更新本文档。
2. 检查所有首版实现类型的类名、成员名、参数名和默认值。
3. 检查全部 enum value。
4. 检查 listener 清除语义。
5. 检查 async 取消、错误和幂等语义。
6. 检查 `lib/XmaxSDK.dart` 导出集合。
7. 对 Dart 重载折叠运行全部调用形态测试。
8. 未实现能力不得出现占位公开 API。

任何公开 API 偏差必须先更新本文件并说明是：

- Dart 语言无法表达；
- Flutter UI 模型差异；
- 已确认的首版范围裁剪；
- iOS SDK 已发生正式变更。
