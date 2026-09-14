import 'dart:async';

import '../foundation/errors/XmaxError.dart';
import '../foundation/logging/XmaxLogger.dart';
import '../foundation/media/camera/CameraPosition.dart';
import '../foundation/rtc/RtcManaging.dart';
import '../service/realtime/RealtimeMediaStream.dart';
import '../service/realtime/RealtimeVideoFormat.dart';
import '../service/realtime/RealtimeVideoTrack.dart';
import 'camera/CameraController.dart';
import 'interaction/InteractionController.dart';
import 'interaction/InteractionFrame.dart';
import 'MediaControlling.dart';

final class MediaController implements MediaControlling {
  MediaController({
    required RtcManaging rtcManager,
    CameraController? cameraController,
    required InteractionListener interactionListener,
  }) : _rtcManager = rtcManager,
       _cameraController =
           cameraController ?? CameraController(rtcManager: rtcManager),
       _interactionController = InteractionController(
         listener: interactionListener,
       );

  final RtcManaging _rtcManager;
  final CameraController _cameraController;
  final InteractionController _interactionController;
  bool _hasActiveSource = false;
  bool _operationInProgress = false;
  Completer<void>? _operationCompletion;
  Future<void>? _stopFuture;

  @override
  RealtimeVideoTrack? get currentTrack =>
      _hasActiveSource ? _cameraController.currentTrack : null;

  @override
  RealtimeVideoFormat? get currentVideoFormat => currentTrack?.videoFormat;

  @override
  bool get hasAudio => false;

  // Default preview volume when no local file player exists.
  @override
  Future<double> get localAudioVolume async => 0.45;

  @override
  void setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  ) {
    _cameraController.setPreviewReadyListener(listener);
  }

  @override
  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    required CameraPosition position,
  }) async {
    if (_hasActiveSource) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Stop the current local media stream before creating another one',
      );
    }

    _ensureNoOperation();

    // Reserve the source before awaiting RTC initialization to prevent races.
    _operationInProgress = true;
    final completion = _operationCompletion = Completer<void>();
    _hasActiveSource = true;

    try {
      await _rtcManager.initialize();
      return await _cameraController.createLocalCameraStream(
        videoFormat: videoFormat,
        position: position,
      );
    } catch (error) {
      _hasActiveSource = false;
      await _releaseEngine();
      throw XmaxError.from(error);
    } finally {
      _operationInProgress = false;
      completion.complete();
    }
  }

  @override
  Future<void> stopLocalCameraStream() async {
    if (!_hasActiveSource) {
      return;
    }

    await _stopCurrentSource();
  }

  @override
  Future<void> stopLocalStream() => stopLocalCameraStream();

  Future<void> _stopCurrentSource() {
    final active = _stopFuture;
    if (active != null) return active;
    final future = _performStopCurrentSource();
    _stopFuture = future;
    return future.whenComplete(() => _stopFuture = null);
  }

  Future<void> _performStopCurrentSource() async {
    // Finish an in-flight capture/switch before destroying its shared engine.
    await _operationCompletion?.future;
    _operationInProgress = true;

    try {
      try {
        await _cameraController.stopLocalCameraStream();
      } catch (error) {
        _logCleanupFailure('停止相机采集失败 (Failed to Stop Camera Capture)', error);
      }
      await _releaseEngine();
    } finally {
      _hasActiveSource = false;
      _operationInProgress = false;
    }
  }

  Future<void> _releaseEngine() async {
    try {
      await _rtcManager.destroy();
    } catch (error) {
      _logCleanupFailure('释放 RTC 引擎失败 (Failed to Release RTC Engine)', error);
    }
  }

  void _logCleanupFailure(String title, Object error) {
    try {
      XmaxLogger.error(
        category: XmaxLoggerCategory.realtime,
        message: '$title\n└─ ${XmaxLogger.localized('原因：', 'Reason: ')}$error',
      );
    } catch (_) {
      // Diagnostics must not interrupt resource cleanup.
    }
  }

  @override
  Future<RealtimeMediaStream> switchCamera() async {
    if (!_hasActiveSource) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Local camera preview is not started',
      );
    }

    _ensureNoOperation();
    _operationInProgress = true;
    final completion = _operationCompletion = Completer<void>();

    try {
      return await _cameraController.switchCamera();
    } finally {
      _operationInProgress = false;
      completion.complete();
    }
  }

  @override
  Future<void> setLocalAudioVolume(double volume) async {
    // Camera input has no local file player, so validated calls are a no-op.
  }

  @override
  bool owns(RealtimeMediaStream stream) {
    final track = stream.videoTrack;
    return track != null && identical(track, currentTrack);
  }

  @override
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  }) {
    _interactionController.startInteraction(
      taskID: taskID,
      videoFormat: videoFormat,
    );
  }

  @override
  void stopInteraction() {
    _interactionController.stopInteraction();
  }

  @override
  void submitInteraction(InteractionFrame frame) {
    _interactionController.submitInteraction(frame);
  }

  void _ensureNoOperation() {
    if (_operationInProgress) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'A local media operation is already in progress',
      );
    }
  }
}
