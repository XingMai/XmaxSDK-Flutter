import '../../foundation/errors/XmaxError.dart';

/// 进入当前实时状态的原因。
final class RealtimeReason {
  const RealtimeReason._(this._kind, this.error);

  /// 主动停止或正常释放资源。
  static const normal = RealtimeReason._('normal', null);

  /// 显示方向变化，需要重新配置生成。
  static const orientationChanged = RealtimeReason._(
    'orientationChanged',
    null,
  );

  /// 操作或运行异常导致当前流程结束。
  factory RealtimeReason.failure(XmaxError error) =>
      RealtimeReason._('failure', error);

  final String _kind;

  /// 失败原因对应的 SDK 错误；其他原因时为 `null`。
  final XmaxError? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeReason && _kind == other._kind && error == other.error;

  @override
  int get hashCode => Object.hash(_kind, error);
}

/// 实时业务连接状态。
enum RealtimeConnectionState {
  /// 没有可用的本地媒体流。
  idle('Idle'),

  /// 正在准备本地媒体流；摄像头需等待首帧和预览视图绑定。
  preparing('Preparing'),

  /// 本地媒体流已就绪，可预览、连接和生成。
  ready('Ready'),

  /// 正在创建 Session、加入 Room 并发布本地流。
  connecting('Connecting'),

  /// 实时连接已建立，当前没有生成任务。
  connected('Connected'),

  /// 实时连接已建立且生成任务正在运行。
  generating('Generating'),

  /// 正在清理生成、Room 和 Session 资源。
  disconnecting('Disconnecting');

  const RealtimeConnectionState(this.value);

  final String value;
}

/// 实时业务当前状态快照。
final class RealtimeState {
  const RealtimeState({
    required this.connectionState,
    this.sessionID,
    this.taskID,
    this.reason,
  });

  /// 当前连接生命周期状态。
  final RealtimeConnectionState connectionState;

  /// 当前或最近一次实时 Session 标识。
  final String? sessionID;

  /// 当前生成任务标识。
  final String? taskID;

  /// 进入当前状态的原因；正常开始新的操作时清空。
  final RealtimeReason? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeState &&
          connectionState == other.connectionState &&
          sessionID == other.sessionID &&
          taskID == other.taskID &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(connectionState, sessionID, taskID, reason);
}

typedef RealtimeStateListener = void Function(RealtimeState state);
