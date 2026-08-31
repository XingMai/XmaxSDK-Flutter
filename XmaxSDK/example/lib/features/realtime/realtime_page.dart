import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

import '../../ui/xlab_theme.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({
    required this.apiKey,
    this.customTrajectory = false,
    super.key,
  });

  final String apiKey;
  final bool customTrajectory;

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage>
    with WidgetsBindingObserver {
  static const _cameraFormat = RealtimeVideoFormat(
    width: 832,
    height: 1472,
    fps: 24,
  );

  late XmaxRealtimeManaging _manager;
  final _promptController = TextEditingController(text: '让画面自然动起来');
  RealtimeMediaStream? _localStream;
  RealtimeMediaStream? _remoteStream;
  RealtimeState _state = const RealtimeState(
    connectionState: RealtimeConnectionState.idle,
  );
  XmaxError? _lastError;
  RealtimeNetworkQuality? _networkQuality;
  bool _cameraReady = false;
  bool _busy = false;
  late final _XLabTrajectoryRenderer? _customRenderer = widget.customTrajectory
      ? _XLabTrajectoryRenderer()
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureManager();
    unawaited(_startCamera());
  }

  void _configureManager() {
    final client = XmaxClient(
      configuration: XmaxConfiguration(
        apiKey: widget.apiKey,
        loggerOptions: XmaxLoggerOption.all,
      ),
    );
    _manager = client.createRealtimeManager(
      options: const RealtimeConfiguration(model: RealtimeModel.x2_0),
    );
    _manager.setStateListener((state) {
      if (!mounted) return;
      setState(() {
        _state = state;
        if (state.connectionState == RealtimeConnectionState.connected &&
            state.taskID == null) {
          _lastError = null;
        }
      });
    });
    _manager.setErrorListener((error) {
      if (!mounted) return;
      setState(() => _lastError = error);
    });
    _manager.setCameraPreviewReadyListener(() {
      if (mounted) setState(() => _cameraReady = true);
    });
    _manager.setNetworkQualityListener((quality) {
      if (mounted) setState(() => _networkQuality = quality);
    });
    _manager.setPerformanceAlarmListener((alarm) {
      if (mounted && alarm.status == RealtimePerformanceStatus.limited) {
        setState(() {
          _lastError = const XmaxError(
            code: XmaxErrorCode.mediaError,
            message: '设备性能受限，实时画质可能下降',
          );
        });
      }
    });
  }

  Future<void> _startCamera() async {
    if (_busy || _localStream != null) return;
    setState(() {
      _busy = true;
      _cameraReady = false;
      _lastError = null;
    });
    try {
      final stream = await _manager.createLocalCameraStream(
        videoFormat: _cameraFormat,
      );
      if (mounted) setState(() => _localStream = stream);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleGeneration() async {
    if (_busy) return;
    if (_state.connectionState == RealtimeConnectionState.generating) {
      setState(() => _busy = true);
      await _manager.stopGeneration();
      if (mounted) {
        setState(() {
          _busy = false;
          _remoteStream = null;
        });
      }
      return;
    }
    final localStream = _localStream;
    if (localStream == null) return;
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      final remote = await _manager.startGeneration(
        localStream: localStream,
        context: RealtimeContext(prompt: _promptController.text),
      );
      if (mounted) setState(() => _remoteStream = remote);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updatePrompt() async {
    if (_state.connectionState != RealtimeConnectionState.generating) {
      await _toggleGeneration();
      return;
    }
    setState(() => _busy = true);
    try {
      await _manager.startGeneration(
        context: RealtimeContext(prompt: _promptController.text),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_busy || _localStream == null) return;
    setState(() => _busy = true);
    try {
      final stream = await _manager.switchCamera();
      if (mounted) setState(() => _localStream = stream);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    final xmaxError = XmaxError.from(error);
    if (mounted) setState(() => _lastError = xmaxError);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_suspend());
    } else if (state == AppLifecycleState.resumed && _localStream == null) {
      unawaited(_startCamera());
    }
  }

  Future<void> _suspend() async {
    await _manager.close();
    if (mounted) {
      setState(() {
        _localStream = null;
        _remoteStream = null;
        _cameraReady = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manager.setStateListener(null);
    _manager.setErrorListener(null);
    _manager.setCameraPreviewReadyListener(null);
    _manager.setNetworkQualityListener(null);
    _manager.setPerformanceAlarmListener(null);
    unawaited(_manager.close());
    _promptController.dispose();
    _customRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generating =
        _state.connectionState == RealtimeConnectionState.generating;
    final displayed = generating ? _remoteStream : _localStream;
    final accent = widget.customTrajectory
        ? XLabPalette.pink
        : XLabPalette.mint;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: XLabBackground(
        accent: accent,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: XLabTopBar(
                  title: widget.customTrajectory ? '自定义轨迹' : '摄像头实时流',
                  accent: accent,
                  version: XmaxSDKInfo.version,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const ColoredBox(color: Color(0xFF101010)),
                        if (displayed?.videoTrack != null)
                          XmaxVideoView(
                            track: displayed!.videoTrack,
                            videoContentMode: VideoContentMode.fill,
                            isInteractionEnabled: generating,
                            trajectoryRenderer: _customRenderer,
                          )
                        else
                          const Center(
                            child: Icon(
                              Icons.videocam_off_outlined,
                              color: Color(0x55FFFFFF),
                              size: 44,
                            ),
                          ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _StatusPill(text: _statusText, color: accent),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: IconButton.filledTonal(
                            tooltip: '翻转摄像头',
                            onPressed: _busy ? null : _switchCamera,
                            icon: const Icon(Icons.cameraswitch_outlined),
                          ),
                        ),
                        if (_busy ||
                            _state.connectionState ==
                                RealtimeConnectionState.connecting)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.62),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  CircularProgressIndicator(color: accent),
                                  const SizedBox(height: 14),
                                  Text(
                                    _loadingText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              _controlPanel(accent, generating),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlPanel(Color accent, bool generating) => Container(
    margin: const EdgeInsets.fromLTRB(18, 12, 18, 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xF0101010),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_lastError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x29FF5F68),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _lastError!.message,
              style: const TextStyle(color: Color(0xFFFFB5B5), fontSize: 11),
            ),
          ),
        Row(
          children: <Widget>[
            _StatusPill(
              text: widget.customTrajectory ? 'CUSTOM EFFECT' : 'CAMERA',
              color: accent,
            ),
            const Spacer(),
            Text(
              _networkQuality == null
                  ? 'NETWORK —'
                  : 'UP ${_networkQuality!.uplink.value} / DOWN ${_networkQuality!.downlink.value}',
              style: const TextStyle(color: Color(0x667F8C9D), fontSize: 8),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _promptController,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => unawaited(_updatePrompt()),
          decoration: InputDecoration(
            hintText: '输入生成提示词',
            filled: true,
            fillColor: const Color(0xFF252525),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              onPressed: _busy ? null : _updatePrompt,
              icon: Icon(Icons.arrow_upward_rounded, color: accent),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: generating
                  ? Colors.white.withValues(alpha: 0.12)
                  : accent,
              foregroundColor: generating
                  ? Colors.white
                  : const Color(0xFF07110D),
            ),
            onPressed: _busy || _localStream == null ? null : _toggleGeneration,
            child: Text(
              generating ? '停止生成' : '点击开始生成',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (generating) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            '在画面上拖拽，用轨迹控制角色',
            style: TextStyle(color: Color(0x70FFFFFF), fontSize: 11),
          ),
        ],
      ],
    ),
  );

  String get _statusText {
    if (!_cameraReady && _localStream != null) return 'CAMERA STARTING';
    return _state.connectionState.value.toUpperCase();
  }

  String get _loadingText => switch (_state.connectionState) {
    RealtimeConnectionState.connecting => '正在建立实时连接…',
    _ => _localStream == null ? '正在启动摄像头…' : '正在等待生成画面…',
  };
}

final class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    ),
  );
}

final class _XLabTrajectoryRenderer extends ChangeNotifier
    implements TrajectoryEffectRendering {
  final Map<TrajectoryID, List<Offset>> _trails =
      <TrajectoryID, List<Offset>>{};

  @override
  Widget get view =>
      CustomPaint(size: Size.infinite, painter: _XLabTrajectoryPainter(this));

  @override
  void renderBegan(List<TrajectoryPoint> points) {
    for (final point in points) {
      _trails[point.id] = <Offset>[point.location];
    }
    notifyListeners();
  }

  @override
  void renderMoved(List<TrajectoryPoint> points) {
    for (final point in points) {
      final trail = _trails.putIfAbsent(point.id, () => <Offset>[]);
      trail.add(point.location);
      if (trail.length > 28) trail.removeAt(0);
    }
    notifyListeners();
  }

  @override
  void renderEnded(List<TrajectoryID> identifiers) {
    for (final id in identifiers) {
      _trails.remove(id);
    }
    notifyListeners();
  }

  @override
  void reset() {
    _trails.clear();
    notifyListeners();
  }
}

final class _XLabTrajectoryPainter extends CustomPainter {
  _XLabTrajectoryPainter(this.renderer) : super(repaint: renderer);
  final _XLabTrajectoryRenderer renderer;

  @override
  void paint(Canvas canvas, Size size) {
    for (final trail in renderer._trails.values) {
      if (trail.isEmpty) continue;
      final path = Path()..moveTo(trail.first.dx, trail.first.dy);
      for (final point in trail.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = XLabPalette.pink.withValues(alpha: 0.32)
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[Color(0xFFFF8FD8), Color(0xFF78A9FF)],
          ).createShader(Offset.zero & size)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(trail.last, 7, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _XLabTrajectoryPainter oldDelegate) => false;
}
