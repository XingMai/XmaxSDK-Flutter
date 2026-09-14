import '../../foundation/media/camera/CameraPosition.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimeMediaStream.dart';
import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import '../../service/realtime/RealtimeState.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import 'RealtimeConfiguration.dart';

/// 定义 SDK 对接入方提供的实时媒体与生成控制能力。
abstract interface class XmaxRealtimeManaging {
  /// 创建当前 Manager 时使用的实时能力配置。
  RealtimeConfiguration get options;

  /// 当前实时连接与生成状态。
  Future<RealtimeState> get currentState;

  /// 当前本地媒体预览音量，范围为 `0...1`。
  /// 摄像头没有本地音频播放器，返回与 iOS 一致的默认值 `0.45`。
  Future<double> get localAudioVolume;

  /// 当前远端音频播放音量，范围为 `0...1`，按百分之一量化。
  /// 新建 Manager 时为 `1.0`；每次成功创建摄像头流后重置为 `0`。
  Future<double> get remoteAudioVolume;

  /// 设置实时状态监听器。
  ///
  /// 设置后会立即回调当前状态；传入 `null` 时清除监听器。
  /// 预览就绪通过 `ready` 通知；运行失败通过 `state.reason?.error` 通知。
  /// 主动调用方法产生的错误仍由对应 Future 抛出。
  Future<void> setStateListener(RealtimeStateListener? listener);

  /// 设置网络质量监听器。
  ///
  /// 监听器接收当前上行和下行网络质量；传入 `null` 时清除监听器。
  Future<void> setNetworkQualityListener(
    RealtimeNetworkQualityListener? listener,
  );

  /// 设置设备性能告警监听器。
  ///
  /// 监听器接收性能受限、恢复及建议视频规格；传入 `null` 时清除监听器。
  Future<void> setPerformanceAlarmListener(
    RealtimePerformanceAlarmListener? listener,
  );

  /// 设置本地媒体预览音量。
  ///
  /// [volume] 必须是 `0...1` 内的有限数值，否则抛出 `invalidConfiguration`。
  /// 摄像头没有本地音频播放器，合法调用不产生效果，也不改变读取值；
  /// 与 iOS 一致。这不是麦克风采集音量控制。
  Future<void> setLocalAudioVolume(double volume);

  /// 设置远端生成音频的播放音量。
  ///
  /// [volume] 的取值范围为 `0...1`。尚未连接或订阅远端流时，
  /// SDK 会保存配置，并在生成流确认后订阅远端音频前应用。
  /// 每次创建摄像头流后默认静音；需要覆盖默认值时，请在创建流后设置。
  /// 停止生成或断开连接保留音量；RTC 设置失败时保留上次成功的值。
  Future<void> setRemoteAudioVolume(double volume);

  /// 创建本地摄像头流并开始预览。
  ///
  /// [videoFormat] 指定摄像头采集规格，[position] 指定初始摄像头，
  /// 默认使用前置摄像头。连接实时会话前必须先创建本地流。
  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    CameraPosition position = CameraPosition.front,
  });

  /// 停止本地摄像头流并释放本地预览与 RTC 资源。
  ///
  /// 实时连接期间不可调用，应先调用 [disconnect]。
  Future<void> stopLocalCameraStream();

  /// 切换前后置摄像头。
  ///
  /// 生成过程中调用时，SDK 会停止当前生成、切换摄像头，并使用
  /// 已缓存的生成条件恢复生成；RTC 连接保持不变。返回更新后的本地流。
  Future<RealtimeMediaStream> switchCamera();

  /// 使用当前 Manager 创建的 [localStream] 建立实时连接。
  ///
  /// 返回用于显示生成结果的远端媒体流。
  Future<RealtimeMediaStream> connect({
    required RealtimeMediaStream localStream,
  });

  /// 断开实时连接并保留当前本地摄像头预览。
  ///
  /// [reason] 会记录在最终的 [RealtimeState] 中，默认是主动断开。
  Future<void> disconnect({RealtimeReason reason = RealtimeReason.normal});

  /// 关闭当前实时生命周期并释放连接、本地媒体和 RTC 资源。
  ///
  /// 关闭期间重复调用会等待同一个释放任务；关闭完成后仍可重新创建本地流。
  Future<void> close();

  /// 开始生成，生成中再次调用时更新当前生成条件。
  ///
  /// 传入 [localStream] 时，SDK 会按需建立连接，并返回当前远端流。
  /// 已连接时可省略 [localStream]，此时返回 `null`。
  /// [context] 是本次生成条件；首次生成时必须提供，后续传入 `null`
  /// 时复用已缓存的生成条件。
  ///
  /// 启动时等待结果流确认及首帧解码就绪，再进入 `generating` 并完成 Future。
  /// 无需提前挂载远端视图；等待期间仍可更新条件或停止生成。
  /// 生成中的条件更新不重新等待首帧。
  Future<RealtimeMediaStream?> startGeneration({
    RealtimeMediaStream? localStream,
    RealtimeContext? context,
  });

  /// 停止当前生成任务并保留实时连接。
  ///
  /// 当前未连接或未生成时调用不会产生副作用。
  Future<void> stopGeneration();
}
