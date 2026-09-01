import 'dart:async';

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
  int _generationRequestVersion = 0;
  int _generationCancellationVersion = 0;
  Future<void> _generationOperation = Future<void>.value();
  String? _startingGenerationTaskID;
  Completer<void>? _startingGenerationCompleter;
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

      // Restart generation only after the new camera has had time to publish.
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

    // A new operation version invalidates every callback from an older connect.
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
      // A newer disconnect/close owns the state when the version has changed.
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
      // A generation request may be queued but not have entered connect yet.
      _generationRequestVersion += 1;
      _generationCancellationVersion += 1;
      _generationManager.cancelPendingStart();
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
    // Invalidate pending connect/generation callbacks before cleanup starts.
    _operationVersion += 1;
    _generationRequestVersion += 1;
    _generationCancellationVersion += 1;
    final taskID = _state.taskID ?? _startingGenerationTaskID ?? '';

    _cancelStartingGeneration();

    _emit(
      const RealtimeState(
        connectionState: RealtimeConnectionState.disconnecting,
      ),
    );

    // Cleanup is best-effort: one failing layer must not retain the others.
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
    // Match iOS Task cancellation: a newer request supersedes an older request
    // that is still connecting or waiting for its generation SEI.
    final requestVersion = ++_generationRequestVersion;
    _generationManager.cancelPendingStart();

    final prepared = await _enqueueGenerationOperation(
      () => _prepareGeneration(
        localStream: localStream,
        context: context,
        requestVersion: requestVersion,
      ),
    );

    // Waiting for the first decoded frame must not block later condition
    // changes. Only the short task mutation above is serialized.
    await prepared.readiness;
    return prepared.remoteStream;
  }

  Future<_PreparedGeneration> _prepareGeneration({
    required RealtimeMediaStream? localStream,
    required RealtimeContext? context,
    required int requestVersion,
  }) async {
    // A selection made during teardown should start after that teardown rather
    // than failing because the previous RTC session is still disconnecting.
    await _disconnectFuture;
    _ensureGenerationRequestCurrent(requestVersion);

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
        _ensureGenerationRequestCurrent(requestVersion);
      }
    }

    final task = await _prepareGenerationTask(
      context,
      requestVersion: requestVersion,
    );
    return _PreparedGeneration(
      remoteStream: remoteStream,
      readiness: task.readiness,
    );
  }

  Future<_PreparedGenerationTask> _prepareGenerationTask(
    RealtimeContext? context, {
    required int requestVersion,
  }) async {
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

    final activeTaskID = _state.taskID ?? _startingGenerationTaskID;
    if (activeTaskID != null) {
      try {
        await _generationManager.update(
          taskID: activeTaskID,
          videoFormat: videoFormat,
          context: context,
        );

        return _PreparedGenerationTask(
          readiness:
              _startingGenerationCompleter?.future ?? Future<void>.value(),
        );
      } catch (error) {
        if (requestVersion != _generationRequestVersion) {
          throw XmaxError.from(error);
        }
        throw _report(error);
      }
    }

    final version = _operationVersion;
    try {
      final taskID = await _generationManager.start(
        videoFormat: videoFormat,
        context: context,
        ensureCurrent: () => _ensureCurrent(version),
      );

      final completer = Completer<void>();
      // Register a handler immediately so a synchronous render failure cannot
      // surface as an unhandled asynchronous error before callers await it.
      completer.future.ignore();

      _startingGenerationTaskID = taskID;
      _startingGenerationCompleter = completer;
      unawaited(
        _completeGenerationStart(
          sessionID: sessionID,
          taskID: taskID,
          operationVersion: version,
          completer: completer,
        ),
      );

      return _PreparedGenerationTask(readiness: completer.future);
    } catch (error) {
      // Supersession is an internal control-flow event, matching a cancelled
      // Swift Task. It must not be surfaced to the SDK error listener.
      if (requestVersion != _generationRequestVersion) {
        throw XmaxError.from(error);
      }
      throw _report(error);
    }
  }

  Future<void> _completeGenerationStart({
    required String sessionID,
    required String taskID,
    required int operationVersion,
    required Completer<void> completer,
  }) async {
    try {
      // Video becomes usable only after both rendering and audio are ready.
      // This phase intentionally runs outside the generation mutation queue.
      await _renderController.waitUntilRemoteFrameReady();
      await _streamController.activateRemoteAudio();

      _ensureCurrent(operationVersion);
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

      if (!completer.isCompleted) {
        completer.complete();
      }
    } catch (error) {
      // If stop/disconnect already completed the waiter, that path also owns
      // task cleanup. Otherwise a render failure must stop the created task.
      if (!completer.isCompleted) {
        try {
          await _generationManager.stop(taskID: taskID);
        } catch (stopError) {
          _report(stopError);
        }

        completer.completeError(_report(error));
      }
    } finally {
      if (identical(_startingGenerationCompleter, completer)) {
        _startingGenerationTaskID = null;
        _startingGenerationCompleter = null;
      }
    }
  }

  @override
  Future<void> stopGeneration() {
    _generationRequestVersion += 1;
    _generationManager.cancelPendingStart();
    return _enqueueGenerationOperation(_performStopGeneration);
  }

  Future<void> _performStopGeneration() async {
    final sessionID = _connectionManager.currentSessionID;
    if (sessionID.isEmpty ||
        (_state.connectionState != RealtimeConnectionState.connected &&
            _state.connectionState != RealtimeConnectionState.generating)) {
      return;
    }

    final taskID = _state.taskID ?? _startingGenerationTaskID ?? '';
    final wasGenerating =
        _state.connectionState == RealtimeConnectionState.generating ||
        _startingGenerationTaskID != null;

    // Prevent an in-flight first-frame waiter from publishing `generating`
    // after this stop has already completed.
    _operationVersion += 1;
    _generationRequestVersion += 1;
    _cancelStartingGeneration();

    try {
      await _generationManager.stop(taskID: taskID);
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

  Future<T> _enqueueGenerationOperation<T>(Future<T> Function() operation) {
    // Dart Futures cannot be cancelled. Run generation mutations in request
    // order, and let disconnect invalidate work that has not completed yet.
    final cancellationVersion = _generationCancellationVersion;
    final previousOperation = _generationOperation;
    final completion = Completer<void>();
    _generationOperation = completion.future;

    return () async {
      await previousOperation;

      try {
        _ensureGenerationOperationCurrent(cancellationVersion);
        final result = await operation();
        _ensureGenerationOperationCurrent(cancellationVersion);
        return result;
      } finally {
        completion.complete();
      }
    }();
  }

  void _cancelStartingGeneration() {
    final completer = _startingGenerationCompleter;
    _startingGenerationTaskID = null;
    _startingGenerationCompleter = null;

    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const XmaxError(
          code: XmaxErrorCode.cancelled,
          message: 'Realtime generation was cancelled',
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

  void _ensureGenerationOperationCurrent(int version) {
    if (version != _generationCancellationVersion) {
      throw const XmaxError(
        code: XmaxErrorCode.cancelled,
        message: 'Realtime generation operation was cancelled',
      );
    }
  }

  void _ensureGenerationRequestCurrent(int version) {
    if (version != _generationRequestVersion) {
      throw const XmaxError(
        code: XmaxErrorCode.cancelled,
        message: 'Realtime generation request was superseded',
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

final class _PreparedGeneration {
  const _PreparedGeneration({
    required this.remoteStream,
    required this.readiness,
  });

  final RealtimeMediaStream? remoteStream;
  final Future<void> readiness;
}

final class _PreparedGenerationTask {
  const _PreparedGenerationTask({required this.readiness});

  final Future<void> readiness;
}
