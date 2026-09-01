import '../../foundation/errors/XmaxError.dart';
import '../../foundation/media/camera/CameraPosition.dart';
import '../../foundation/rtc/RtcManager.dart';
import '../../media/MediaController.dart';
import '../../media/MediaControlling.dart';
import '../../render/RenderController.dart';
import '../../render/RenderControlling.dart';
import '../../service/network/ApiServicing.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimeError.dart';
import '../../service/realtime/RealtimeMediaStream.dart';
import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import '../../service/realtime/RealtimeSessionService.dart';
import '../../service/realtime/RealtimeState.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import '../../stream/StreamController.dart';
import '../../stream/StreamControlling.dart';
import 'RealtimeConfiguration.dart';
import 'RealtimeErrorHandler.dart';
import 'XmaxRealtimeConnectionManager.dart';
import 'XmaxRealtimeGenerationManager.dart';
import 'XmaxRealtimeManaging.dart';

final class XmaxRealtimeManager implements XmaxRealtimeManaging {
  factory XmaxRealtimeManager({
    required RealtimeConfiguration options,
    required ApiServicing apiService,
  }) {
    final errorHandler = RealtimeErrorHandler();
    final rtcManager = RtcManager();
    final renderController = RenderController();
    late final StreamController streamController;
    streamController = StreamController(
      rtcManager: rtcManager,
      errorListener: errorHandler.forward,
      remoteStreamListener: renderController.setRemoteStream,
      remoteFrameReadyListener: renderController.notifyRemoteFrameReady,
    );
    final mediaController = MediaController(
      rtcManager: rtcManager,
      interactionListener: (taskID, points) =>
          streamController.sendTracks(taskID: taskID, points: points),
    );
    final connectionManager = XmaxRealtimeConnectionManager(
      sessionService: RealtimeSessionService(apiService: apiService),
      interactionController: mediaController,
      renderController: renderController,
      streamController: streamController,
    );
    final generationManager = XmaxRealtimeGenerationManager(
      interactionController: mediaController,
      streamController: streamController,
    );
    return XmaxRealtimeManager.internal(
      options: options,
      mediaController: mediaController,
      renderController: renderController,
      streamController: streamController,
      connectionManager: connectionManager,
      generationManager: generationManager,
      errorHandler: errorHandler,
    );
  }

  XmaxRealtimeManager.internal({
    required this.options,
    required MediaControlling mediaController,
    required RenderControlling renderController,
    required StreamControlling streamController,
    required XmaxRealtimeConnectionManager connectionManager,
    required XmaxRealtimeGenerationManager generationManager,
    required RealtimeErrorHandler errorHandler,
  }) : _mediaController = mediaController,
       _renderController = renderController,
       _streamController = streamController,
       _connectionManager = connectionManager,
       _generationManager = generationManager,
       _errorHandler = errorHandler;

  @override
  final RealtimeConfiguration options;
  final MediaControlling _mediaController;
  final RenderControlling _renderController;
  final StreamControlling _streamController;
  final XmaxRealtimeConnectionManager _connectionManager;
  final XmaxRealtimeGenerationManager _generationManager;
  final RealtimeErrorHandler _errorHandler;

  RealtimeState _state = const RealtimeState(
    connectionState: RealtimeConnectionState.idle,
  );
  RealtimeStateListener? _stateListener;
  int _operationVersion = 0;
  Future<void>? _closeFuture;
  Future<void>? _disconnectFuture;

  @override
  Future<RealtimeState> get currentState async => _state;

  @override
  Future<void> setStateListener(RealtimeStateListener? listener) async {
    _stateListener = listener;
    listener?.call(_state);
  }

  @override
  Future<void> setErrorListener(RealtimeErrorListener? listener) async {
    _errorHandler.setListener(listener);
  }

  @override
  Future<void> setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  ) async {
    _mediaController.setCameraPreviewReadyListener(listener);
  }

  @override
  Future<void> setNetworkQualityListener(
    RealtimeNetworkQualityListener? listener,
  ) async {
    _streamController.setNetworkQualityListener(listener);
  }

  @override
  Future<void> setPerformanceAlarmListener(
    RealtimePerformanceAlarmListener? listener,
  ) async {
    _streamController.setPerformanceAlarmListener(listener);
  }

  @override
  Future<void> setLocalAudioVolume(double volume) async {
    try {
      _validateAudioVolume(volume);
      await _mediaController.setLocalAudioVolume(volume);
    } catch (error) {
      throw _errorHandler.report(error);
    }
  }

  @override
  Future<void> setRemoteAudioVolume(double volume) async {
    try {
      _validateAudioVolume(volume);
      await _streamController.setRemoteAudioVolume(volume);
    } catch (error) {
      throw _errorHandler.report(error);
    }
  }

  @override
  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    CameraPosition position = CameraPosition.front,
  }) async {
    if (_connectionManager.currentSessionID.isNotEmpty ||
        _state.connectionState == RealtimeConnectionState.connecting ||
        _state.connectionState == RealtimeConnectionState.disconnecting) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message:
              'Local camera stream is unavailable during a realtime connection',
        ),
      );
    }
    try {
      return await _mediaController.createLocalCameraStream(
        videoFormat: videoFormat,
        position: position,
      );
    } catch (error) {
      throw _report(error);
    }
  }

  @override
  Future<void> stopLocalCameraStream() async {
    if (_connectionManager.currentSessionID.isNotEmpty ||
        _state.connectionState == RealtimeConnectionState.connecting ||
        _state.connectionState == RealtimeConnectionState.disconnecting) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message:
              'Disconnect realtime before stopping the local camera stream',
        ),
      );
    }
    try {
      await _mediaController.stopLocalCameraStream();
    } catch (error) {
      throw _report(error);
    }
  }

  @override
  Future<RealtimeMediaStream> switchCamera() async {
    if (_state.connectionState == RealtimeConnectionState.connecting ||
        _state.connectionState == RealtimeConnectionState.disconnecting) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message:
              'Camera switching is unavailable while realtime is transitioning',
        ),
      );
    }
    final wasGenerating =
        _state.connectionState == RealtimeConnectionState.generating;
    if (!wasGenerating && _streamController.hasGenerationTask) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message:
              'Camera switching is unavailable while realtime generation is starting',
        ),
      );
    }
    if (wasGenerating) {
      await stopGeneration();
    }
    try {
      final stream = await _mediaController.switchCamera();
      if (wasGenerating) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await startGeneration();
      }
      return stream;
    } catch (error) {
      throw _report(error);
    }
  }

  @override
  Future<RealtimeMediaStream> connect({
    required RealtimeMediaStream localStream,
  }) async {
    if (_connectionManager.currentSessionID.isNotEmpty ||
        _state.connectionState == RealtimeConnectionState.connecting ||
        _state.connectionState == RealtimeConnectionState.disconnecting) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message: 'Realtime connection is already open',
        ),
      );
    }
    final videoFormat = localStream.videoTrack?.videoFormat;
    if (videoFormat == null || !_mediaController.owns(localStream)) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message:
              'The local stream must be created and started by this realtime manager',
        ),
      );
    }
    await _generationManager.reset();
    final version = ++_operationVersion;
    _emit(
      const RealtimeState(connectionState: RealtimeConnectionState.connecting),
    );
    try {
      await _streamController.setVideoEncoderConfig(videoFormat);
      final remoteStream = await _connectionManager.connect(
        model: options.model,
        videoFormat: videoFormat,
        isCurrent: () => version == _operationVersion,
        onHeartbeatFailure: _handleHeartbeatFailure,
      );
      _ensureCurrent(version);
      final sessionID = _connectionManager.currentSessionID;
      if (sessionID.isEmpty) {
        throw const XmaxError(
          code: XmaxErrorCode.cancelled,
          message: 'Realtime connection was cancelled',
        );
      }
      _emit(
        RealtimeState(
          connectionState: RealtimeConnectionState.connected,
          sessionID: sessionID,
        ),
      );
      return remoteStream;
    } catch (error) {
      if (version != _operationVersion) {
        throw const XmaxError(
          code: XmaxErrorCode.cancelled,
          message: 'Realtime connection was cancelled',
        );
      }
      final xmaxError = _report(error);
      _emit(
        const RealtimeState(connectionState: RealtimeConnectionState.error),
      );
      throw xmaxError;
    }
  }

  @override
  Future<void> disconnect() {
    final active = _disconnectFuture;
    if (active != null) {
      return active;
    }
    if (_state.connectionState == RealtimeConnectionState.idle ||
        _state.connectionState == RealtimeConnectionState.disconnected) {
      return Future<void>.value();
    }
    final future = _performDisconnect(
      finalState: RealtimeConnectionState.disconnected,
    );
    _disconnectFuture = future;
    return future.whenComplete(() => _disconnectFuture = null);
  }

  Future<void> _performDisconnect({
    required RealtimeConnectionState finalState,
  }) async {
    _operationVersion += 1;
    final taskID = _state.taskID ?? '';
    _emit(
      const RealtimeState(
        connectionState: RealtimeConnectionState.disconnecting,
      ),
    );
    try {
      await _generationManager.reset(taskID: taskID);
    } catch (error) {
      _report(error);
    }
    String? sessionID;
    try {
      sessionID = await _connectionManager.disconnect();
    } catch (error) {
      _report(error);
    }
    _emit(RealtimeState(connectionState: finalState, sessionID: sessionID));
  }

  @override
  Future<void> close() {
    final active = _closeFuture;
    if (active != null) {
      return active;
    }
    final future = _performClose();
    _closeFuture = future;
    return future.whenComplete(() => _closeFuture = null);
  }

  Future<void> _performClose() async {
    _operationVersion += 1;
    await disconnect();
    try {
      await _mediaController.stopLocalStream();
    } catch (error) {
      _report(error);
    }
  }

  @override
  Future<RealtimeMediaStream?> startGeneration({
    RealtimeMediaStream? localStream,
    RealtimeContext? context,
  }) async {
    if (localStream != null && !_mediaController.owns(localStream)) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message:
              'The local stream must be created and started by this realtime manager',
        ),
      );
    }
    RealtimeMediaStream? remoteStream;
    if (localStream != null) {
      if (_state.connectionState == RealtimeConnectionState.connected ||
          _state.connectionState == RealtimeConnectionState.generating) {
        remoteStream = _connectionManager.currentRemoteStream;
      } else {
        remoteStream = await connect(localStream: localStream);
      }
    }
    await _performStartGeneration(context);
    return remoteStream;
  }

  Future<void> _performStartGeneration(RealtimeContext? context) async {
    final sessionID = _connectionManager.currentSessionID;
    final videoFormat = _mediaController.currentVideoFormat;
    if (sessionID.isEmpty ||
        videoFormat == null ||
        (_state.connectionState != RealtimeConnectionState.connected &&
            _state.connectionState != RealtimeConnectionState.generating)) {
      throw _report(
        const XmaxError(
          code: XmaxErrorCode.rtcError,
          message: 'Realtime connection is not open',
        ),
      );
    }
    if (_state.connectionState == RealtimeConnectionState.generating &&
        _state.taskID != null) {
      try {
        await _generationManager.update(
          taskID: _state.taskID!,
          videoFormat: videoFormat,
          context: context,
        );
        return;
      } catch (error) {
        throw _report(error);
      }
    }
    final version = _operationVersion;
    String? taskID;
    try {
      taskID = await _generationManager.start(
        videoFormat: videoFormat,
        context: context,
        ensureCurrent: () => _ensureCurrent(version),
      );
      await _renderController.waitUntilRemoteFrameReady();
      await _streamController.activateRemoteAudio();
      _ensureCurrent(version);
      if (_connectionManager.currentSessionID != sessionID) {
        throw const XmaxError(
          code: XmaxErrorCode.cancelled,
          message: 'Realtime connection was cancelled',
        );
      }
      _emit(
        RealtimeState(
          connectionState: RealtimeConnectionState.generating,
          sessionID: sessionID,
          taskID: taskID,
        ),
      );
    } catch (error) {
      if (taskID != null) {
        await _generationManager.stop(taskID: taskID);
      }
      throw _report(error);
    }
  }

  @override
  Future<void> stopGeneration() async {
    final sessionID = _connectionManager.currentSessionID;
    if (sessionID.isEmpty ||
        (_state.connectionState != RealtimeConnectionState.connected &&
            _state.connectionState != RealtimeConnectionState.generating)) {
      return;
    }
    final wasGenerating =
        _state.connectionState == RealtimeConnectionState.generating;
    try {
      await _generationManager.stop(taskID: _state.taskID ?? '');
    } catch (error) {
      _report(error);
    }
    if (wasGenerating) {
      _emit(
        RealtimeState(
          connectionState: RealtimeConnectionState.connected,
          sessionID: sessionID,
        ),
      );
    }
  }

  Future<void> _handleHeartbeatFailure(String sessionID, Object error) async {
    if (_connectionManager.currentSessionID != sessionID) {
      return;
    }
    _report(error);
    await _performDisconnect(finalState: RealtimeConnectionState.error);
  }

  void _emit(RealtimeState state) {
    _state = state;
    _stateListener?.call(state);
  }

  XmaxError _report(Object error) => _errorHandler.report(error);

  void _ensureCurrent(int version) {
    if (version != _operationVersion) {
      throw const XmaxError(
        code: XmaxErrorCode.cancelled,
        message: 'Realtime connection was cancelled',
      );
    }
  }

  static void _validateAudioVolume(double volume) {
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Audio volume must be between 0 and 1',
      );
    }
  }
}
