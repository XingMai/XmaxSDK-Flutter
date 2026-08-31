# XmaxSDK Flutter

XmaxSDK 的 Flutter 摄像头版本，公开 API、分层架构、实时状态和服务端协议以 iOS XmaxSDK 1.0.1 为基准。

支持 iOS 15+ 和 Android API 26+，包含：

- 摄像头本地预览和前后摄像头切换
- Xmax 实时 Session、火山 RTC 房间和生成生命周期
- 远端生成视频、音频、网络质量和性能告警
- 默认及自定义多点轨迹效果与 `tracks` 信令
- 腾讯 COS 图片/视频上传、图片安全检测和文件下载
- 与 iOS XLab 对齐的 Flutter Example

当前约定的摄像头版本不包含本地图片 RTC 输入、本地视频文件 RTC 输入、视频插帧和 SwiftUI API。

## 接入

从 Git 或本地路径加入 Package 后：

```dart
import 'package:xmax_sdk/xmax_sdk.dart';

final client = XmaxClient(
  configuration: XmaxConfiguration(apiKey: 'YOUR_API_KEY'),
);
final realtime = client.createRealtimeManager(
  options: const RealtimeConfiguration(model: RealtimeModel.x2_0),
);

final localStream = await realtime.createLocalCameraStream(
  videoFormat: const RealtimeVideoFormat(
    width: 832,
    height: 1472,
    fps: 24,
  ),
);

final remoteStream = await realtime.startGeneration(
  localStream: localStream,
  context: RealtimeContext(prompt: '让画面自然动起来'),
);
```

本地和远端轨道使用同一个视图：

```dart
XmaxVideoView(
  track: remoteStream?.videoTrack ?? localStream.videoTrack,
  videoContentMode: VideoContentMode.fill,
)
```

页面退出或 App 进入后台时释放实时资源：

```dart
await realtime.close();
```

完整调用流程见 [`example/lib/features/realtime/realtime_page.dart`](example/lib/features/realtime/realtime_page.dart)。

## 宿主配置

iOS 宿主需要：

- Deployment Target 15.0+
- `NSCameraUsageDescription`
- CocoaPods 源 `https://github.com/volcengine/volcengine-specs.git`
- `PERMISSION_CAMERA=1`

Android 宿主需要：

- minSdk 26+
- Java 17、AndroidX、Jetifier
- 火山 Maven 仓库 `https://artifact.bytedance.com/repository/Volcengine/`
- `INTERNET`、`CAMERA`、`MODIFY_AUDIO_SETTINGS` 权限

Camera-only 宿主应移除火山完整 AAR 合并进来的麦克风、屏幕投影、旧存储和悬浮窗权限。可直接参考 [`example/ios/Podfile`](example/ios/Podfile) 和 [`example/android/app/src/main/AndroidManifest.xml`](example/android/app/src/main/AndroidManifest.xml)。

## 开发与验证

```shell
fvm flutter pub get
fvm flutter analyze
fvm flutter test

cd example
fvm flutter build apk --debug
fvm flutter build ios --debug --no-codesign
```

架构和公开 API 契约：

- [`docs/API_PARITY.md`](docs/API_PARITY.md)
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md)
- [`docs/BOOTSTRAP_AND_EXAMPLE.md`](docs/BOOTSTRAP_AND_EXAMPLE.md)
