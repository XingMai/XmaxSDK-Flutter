import 'package:flutter/widgets.dart';

import '../../foundation/media/video/VideoContentMode.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import '../trajectory/TrajectoryEffectRendering.dart';
import 'VideoRenderBinding.dart';
import 'VideoRenderRegistry.dart';
import 'XmaxVideoView.dart';

/// Realtime 场景推荐使用的视频视图。
///
/// 本地预览始终保留在底层；当 [remoteTrack] 绑定到远端 RTC 流时，
/// 视图会自动将远端画面显示在本地预览上方。远端流停止或解绑后，会自动
/// 恢复本地预览，从而避免原生视频视图切换过程中的黑帧。
/// SDK 停止生成时先提交隐藏远端图层的一帧，再清理远端画布与连接。
///
/// 画中画或其他自定义布局可直接组合多个 [XmaxVideoView]。
final class XmaxRealtimeVideoView extends StatefulWidget {
  const XmaxRealtimeVideoView({
    super.key,
    this.localTrack,
    this.remoteTrack,
    this.videoContentMode = VideoContentMode.fill,
    this.isInteractionEnabled = true,
    this.trajectoryRenderer,
    this.onRemoteVideoReady,
  });

  /// 本地摄像头轨道，作为远端生成画面出现前和停止后的默认预览。
  final RealtimeVideoTrack? localTrack;

  /// 远端生成轨道。SDK 在匹配远端流并确认首帧已渲染后自动显示。
  final RealtimeVideoTrack? remoteTrack;

  /// 本地和远端视频共同使用的内容缩放模式。
  final VideoContentMode videoContentMode;

  /// 是否允许在可见的远端生成画面上提交交互轨迹。
  final bool isInteractionEnabled;

  /// 自定义远端交互轨迹渲染器。
  final TrajectoryEffectRendering? trajectoryRenderer;

  /// 远端首帧已渲染、视图开始显示远端画面时通知，可用于收起加载遮罩。
  ///
  /// 每次远端流绑定周期仅通知一次；更新生成条件不会重复通知。
  /// 回调在帧末执行，可以安全更新界面；它不表示淡入动画已经结束。
  /// 停止、解绑或替换轨道后，尚未送达的旧通知会被丢弃。
  final VoidCallback? onRemoteVideoReady;

  @override
  State<XmaxRealtimeVideoView> createState() => _XmaxRealtimeVideoViewState();
}

final class _XmaxRealtimeVideoViewState extends State<XmaxRealtimeVideoView> {
  // Flutter quantizes opacity to an 8-bit alpha. Values such as 0.001 round
  // to zero and skip painting the RTC platform view entirely.
  static const _pendingRemoteOpacity = 1 / 255;

  VideoRenderHandle? _remoteHandle;
  bool _isRemoteVisible = false;
  bool _isRemoteSuppressed = false;
  Future<void>? _concealment;
  (String, String, String)? _remoteIdentity;
  int _readyVersion = 0;
  bool _didNotifyReady = false;

  @override
  void initState() {
    super.initState();
    _attachRemoteTrack();
  }

  @override
  void didUpdateWidget(covariant XmaxRealtimeVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.remoteTrack != widget.remoteTrack) {
      _detachRemoteTrack();
      _isRemoteVisible = false;
      _isRemoteSuppressed = false;
      _attachRemoteTrack();
    } else if (oldWidget.onRemoteVideoReady != widget.onRemoteVideoReady) {
      _scheduleRemoteVideoReady();
    }
  }

  @override
  void dispose() {
    _detachRemoteTrack();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      XmaxVideoView(
        track: widget.localTrack,
        videoContentMode: widget.videoContentMode,
        isInteractionEnabled: false,
      ),
      if (widget.remoteTrack != null)
        IgnorePointer(
          ignoring: !_isRemoteVisible,
          child: TweenAnimationBuilder<double>(
            // Keep a nonzero composited alpha while waiting for the native
            // first-frame callback, then fade in over the retained preview.
            tween: Tween<double>(end: _remoteOpacity),
            duration: _isRemoteVisible
                ? const Duration(milliseconds: 300)
                : Duration.zero,
            curve: Curves.easeInOut,
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: XmaxVideoView(
              track: widget.remoteTrack,
              videoContentMode: widget.videoContentMode,
              isInteractionEnabled:
                  _isRemoteVisible && widget.isInteractionEnabled,
              trajectoryRenderer: widget.trajectoryRenderer,
            ),
          ),
        ),
    ],
  );

  void _attachRemoteTrack() {
    final track = widget.remoteTrack;
    if (track == null) {
      return;
    }

    final handle = VideoRenderRegistry.handleFor(track);
    _remoteHandle = handle;
    handle?.addListener(_remoteBindingDidChange);
    handle?.addRemovalListener(_prepareForRemoteRemoval);
    _isRemoteVisible = _hasRemoteBinding;
    _updateRemoteReadiness();
  }

  void _detachRemoteTrack() {
    _remoteHandle?.removeListener(_remoteBindingDidChange);
    _remoteHandle?.removeRemovalListener(_prepareForRemoteRemoval);
    _remoteHandle = null;
    _concealment = null;
    _remoteIdentity = null;
    _invalidateRemoteReadiness();
  }

  void _remoteBindingDidChange() {
    if (_remoteHandle?.value == null) _isRemoteSuppressed = false;
    final isVisible = _hasRemoteBinding;
    if (mounted) {
      setState(() => _isRemoteVisible = isVisible);
    }
    _updateRemoteReadiness();
  }

  void _invalidateRemoteReadiness() {
    _readyVersion += 1;
    _didNotifyReady = false;
  }

  void _updateRemoteReadiness() {
    final binding = _remoteHandle?.value;
    final stream = binding is RemoteVideoRenderBinding ? binding.stream : null;
    final identity = stream == null
        ? null
        : (stream.roomID, stream.userID, stream.streamID);
    if (identity != _remoteIdentity || !_hasRemoteBinding) {
      _invalidateRemoteReadiness();
      _remoteIdentity = identity;
    }
    _scheduleRemoteVideoReady();
  }

  void _scheduleRemoteVideoReady() {
    if (!_hasRemoteBinding ||
        _didNotifyReady ||
        widget.onRemoteVideoReady == null) {
      return;
    }

    final version = _readyVersion;
    // A cached first frame can be present during widget construction. Deliver
    // after the visibility update is built so callers may safely setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          version != _readyVersion ||
          !_hasRemoteBinding ||
          _didNotifyReady) {
        return;
      }
      final callback = widget.onRemoteVideoReady;
      if (callback == null) return;
      _didNotifyReady = true;
      callback();
    });
  }

  double get _remoteOpacity {
    if (_isRemoteSuppressed || _remoteHandle?.value == null) return 0;
    return _isRemoteVisible ? 1 : _pendingRemoteOpacity;
  }

  Future<void> _prepareForRemoteRemoval() {
    final active = _concealment;
    if (active != null) return active;
    if (!mounted || _isRemoteSuppressed || _remoteHandle?.value == null) {
      return Future<void>.value();
    }

    // Keep the native surface alive while submitting the frame that hides it.
    // Clearing its binding first can expose a black canvas at the old opacity.
    setState(() {
      _isRemoteSuppressed = true;
      _isRemoteVisible = false;
    });
    _invalidateRemoteReadiness();
    final binding = WidgetsBinding.instance;
    final lifecycle = binding.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return Future<void>.value();
    }
    final future = binding.endOfFrame.timeout(
      const Duration(milliseconds: 100),
      onTimeout: () {},
    );
    _concealment = future;
    return future.whenComplete(() {
      if (identical(_concealment, future)) _concealment = null;
    });
  }

  bool get _hasRemoteBinding {
    final binding = _remoteHandle?.value;
    return !_isRemoteSuppressed &&
        binding is RemoteVideoRenderBinding &&
        binding.firstFrameRendered;
  }
}
