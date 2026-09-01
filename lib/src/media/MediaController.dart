import '../foundation/errors/XmaxError.dart';
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

  @override
  RealtimeVideoTrack? get currentTrack =>
      _hasActiveSource ? _cameraController.currentTrack : null;

  @override
  RealtimeVideoFormat? get currentVideoFormat => currentTrack?.videoFormat;

  @override
  bool get hasAudio => false;

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
    _operationInProgress = true;
    _hasActiveSource = true;
    try {
      await _rtcManager.initialize();
      return await _cameraController.createLocalCameraStream(
        videoFormat: videoFormat,
        position: position,
      );
    } catch (error) {
      _hasActiveSource = false;
      await _rtcManager.destroy();
      throw XmaxError.from(error);
    } finally {
      _operationInProgress = false;
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

  Future<void> _stopCurrentSource() async {
    if (_operationInProgress) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'A local media operation is already in progress',
      );
    }
    _operationInProgress = true;
    try {
      await _cameraController.stopLocalCameraStream();
      await _rtcManager.destroy();
      _hasActiveSource = false;
    } finally {
      _operationInProgress = false;
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
    try {
      return await _cameraController.switchCamera();
    } finally {
      _operationInProgress = false;
    }
  }

  @override
  Future<void> setLocalAudioVolume(double volume) async {}

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
