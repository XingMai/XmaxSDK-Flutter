import '../../foundation/media/camera/CameraPosition.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimeError.dart';
import '../../service/realtime/RealtimeMediaStream.dart';
import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import '../../service/realtime/RealtimeState.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import 'RealtimeConfiguration.dart';

/// 定义 SDK 对接入方提供的实时媒体与生成控制能力。
abstract interface class XmaxRealtimeManaging {
  /// 创建当前 Manager 时使用的实时能力配置。
  RealtimeConfiguration get options;

  /// 当前实时连接与生成状态。
  Future<RealtimeState> get currentState;

  /// 设置实时状态监听器。
  ///
  /// 设置后会立即回调当前状态；传入 `null` 时清除监听器。
  Future<void> setStateListener(RealtimeStateListener? listener);

  /// 设置实时错误监听器；传入 `null` 时清除监听器。
  Future<void> setErrorListener(RealtimeErrorListener? listener);

  /// 设置摄像头预览就绪监听器。
  ///
  /// 本地摄像头首帧可用时回调；传入 `null` 时清除监听器。
  Future<void> setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  );

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
  /// [volume] 的取值范围为 `0...1`；超出范围时 Future 会失败。
  Future<void> setLocalAudioVolume(double volume);

  /// 设置远端生成音频的播放音量。
  ///
  /// [volume] 的取值范围为 `0...1`。尚未连接或订阅远端流时，
  /// SDK 会保存配置并在远端音频开始播放前应用。
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
  Future<void> disconnect();

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
  Future<RealtimeMediaStream?> startGeneration({
    RealtimeMediaStream? localStream,
    RealtimeContext? context,
  });

  /// 停止当前生成任务并保留实时连接。
  ///
  /// 当前未连接或未生成时调用不会产生副作用。
  Future<void> stopGeneration();
}
