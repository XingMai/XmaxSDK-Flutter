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
  });

  /// 本地摄像头轨道，作为远端生成画面出现前和停止后的默认预览。
  final RealtimeVideoTrack? localTrack;

  /// 远端生成轨道。SDK 在 SEI 选中对应的远端流后自动显示。
  final RealtimeVideoTrack? remoteTrack;

  /// 本地和远端视频共同使用的内容缩放模式。
  final VideoContentMode videoContentMode;

  /// 是否允许在可见的远端生成画面上提交交互轨迹。
  final bool isInteractionEnabled;

  /// 自定义远端交互轨迹渲染器。
  final TrajectoryEffectRendering? trajectoryRenderer;

  @override
  State<XmaxRealtimeVideoView> createState() => _XmaxRealtimeVideoViewState();
}

final class _XmaxRealtimeVideoViewState extends State<XmaxRealtimeVideoView> {
  VideoRenderHandle? _remoteHandle;
  bool _isRemoteVisible = false;

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
      _attachRemoteTrack();
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
          child: Opacity(
            opacity: _isRemoteVisible ? 1 : 0,
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
    _isRemoteVisible = _hasRemoteBinding;
  }

  void _detachRemoteTrack() {
    _remoteHandle?.removeListener(_remoteBindingDidChange);
    _remoteHandle = null;
  }

  void _remoteBindingDidChange() {
    final isVisible = _hasRemoteBinding;
    if (mounted && isVisible != _isRemoteVisible) {
      setState(() => _isRemoteVisible = isVisible);
    }
  }

  bool get _hasRemoteBinding {
    final binding = _remoteHandle?.value;
    return binding is RemoteVideoRenderBinding;
  }
}
