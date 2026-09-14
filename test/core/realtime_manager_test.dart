import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/core/realtime/RealtimeConfiguration.dart';
import 'package:xmax_sdk/src/core/realtime/RealtimeErrorHandler.dart';
import 'package:xmax_sdk/src/core/realtime/RealtimeModel.dart';
import 'package:xmax_sdk/src/core/realtime/XmaxRealtimeConnectionManager.dart';
import 'package:xmax_sdk/src/core/realtime/XmaxRealtimeGenerationManager.dart';
import 'package:xmax_sdk/src/core/realtime/XmaxRealtimeManager.dart';
import 'package:xmax_sdk/src/core/XmaxClient.dart';
import 'package:xmax_sdk/src/core/XmaxConfiguration.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/media/camera/CameraPosition.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/media/interaction/InteractionFrame.dart';
import 'package:xmax_sdk/src/media/MediaControlling.dart';
import 'package:xmax_sdk/src/render/RenderControlling.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeContext.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeMediaStream.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeNetworkQuality.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimePerformanceAlarm.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimePoint.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeSession.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeSessionServicing.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeState.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoFormat.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoTrack.dart';
import 'package:xmax_sdk/src/stream/StreamControlling.dart';

void main() {
  for (final connected in <bool>[false, true]) {
    test(
      'runtime failure reaches state listener (connected=$connected)',
      () async {
        final dependencies = _Dependencies();
        final manager = dependencies.manager;
        final stream = await manager.createLocalCameraStream(
          videoFormat: _Dependencies.format,
        );
        dependencies.media.notifyPreviewReady();
        if (connected) await manager.connect(localStream: stream);
        const error = XmaxError(
          code: XmaxErrorCode.rtcError,
          message: 'RTC failed',
        );
        final failed = Completer<RealtimeState>();
        await manager.setStateListener((state) {
          if (state.reason?.error == error && !failed.isCompleted) {
            failed.complete(state);
          }
        });
        dependencies.errors.forward(error);
        final state = await failed.future;
        expect(
          state.connectionState,
          connected
              ? RealtimeConnectionState.ready
              : RealtimeConnectionState.idle,
        );
        expect(state.reason?.error, same(error));
        expect(dependencies.media.stopCount, connected ? 0 : 1);
        await manager.close();
      },
    );
  }

  test('method errors do not invoke the internal runtime failure handler', () {
    final handler = RealtimeErrorHandler();
    handler.setFailureHandler((_) => fail('Unexpected runtime failure'));
    const error = XmaxError(
      code: XmaxErrorCode.rtcError,
      message: 'RTC failed',
    );

    expect(handler.report(error), same(error));
  });

  test('realtime manager follows iOS camera generation lifecycle', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final states = <RealtimeConnectionState>[];
    await manager.setStateListener(
      (state) => states.add(state.connectionState),
    );

    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.preparing,
    );
    dependencies.media.notifyPreviewReady();
    final remoteStream = await manager.startGeneration(
      localStream: localStream,
      context: RealtimeContext(prompt: 'animate naturally'),
    );

    expect(remoteStream?.id, 'stream-remote');
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.generating,
    );
    expect(states, <RealtimeConnectionState>[
      RealtimeConnectionState.idle,
      RealtimeConnectionState.preparing,
      RealtimeConnectionState.ready,
      RealtimeConnectionState.connecting,
      RealtimeConnectionState.connected,
      RealtimeConnectionState.generating,
    ]);

    await manager.stopGeneration();
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.connected,
    );
    await manager.disconnect();
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.ready,
    );
    expect(states.skip(6), <RealtimeConnectionState>[
      RealtimeConnectionState.connected,
      RealtimeConnectionState.disconnecting,
      RealtimeConnectionState.ready,
    ]);
    expect((await manager.currentState).reason, RealtimeReason.normal);
    expect(dependencies.media.stopCount, 0);
    await manager.close();
    expect(dependencies.media.stopCount, 1);
    expect(
      await manager.currentState,
      const RealtimeState(
        connectionState: RealtimeConnectionState.idle,
        reason: RealtimeReason.normal,
      ),
    );
  });

  test('audio volume validation reports the same public error', () async {
    final manager = _Dependencies().manager;
    final states = <RealtimeState>[];
    await manager.setStateListener(states.add);

    await expectLater(
      manager.setRemoteAudioVolume(double.nan),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.invalidConfiguration,
        ),
      ),
    );
    expect(states.every((state) => state.reason == null), isTrue);
  });

  test(
    'camera preparation waits for preview and disconnect preserves it',
    () async {
      final dependencies = _Dependencies();
      final manager = dependencies.manager;
      final localStream = await manager.createLocalCameraStream(
        videoFormat: _Dependencies.format,
      );

      expect(
        (await manager.currentState).connectionState,
        RealtimeConnectionState.preparing,
      );
      await manager.disconnect();
      expect(
        (await manager.currentState).connectionState,
        RealtimeConnectionState.preparing,
      );

      dependencies.media.notifyPreviewReady();
      expect(
        (await manager.currentState).connectionState,
        RealtimeConnectionState.ready,
      );
      var lateReadyNotifications = 0;
      await manager.setStateListener((state) {
        if (state.connectionState == RealtimeConnectionState.ready) {
          lateReadyNotifications += 1;
        }
      });
      expect(lateReadyNotifications, 1);

      await manager.connect(localStream: localStream);
      await manager.disconnect();
      expect((await manager.currentState).reason, RealtimeReason.normal);
      expect(
        (await manager.currentState).connectionState,
        RealtimeConnectionState.ready,
      );

      await manager.stopLocalCameraStream();
      expect(
        await manager.currentState,
        const RealtimeState(connectionState: RealtimeConnectionState.idle),
      );
      dependencies.media.notifyPreviewReady();
      expect(
        (await manager.currentState).connectionState,
        RealtimeConnectionState.idle,
      );
    },
  );

  test('camera creation failure returns idle with a failure reason', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    dependencies.media.createError = StateError('camera unavailable');
    final states = <RealtimeState>[];
    await manager.setStateListener(states.add);

    await expectLater(
      manager.createLocalCameraStream(videoFormat: _Dependencies.format),
      throwsA(isA<XmaxError>()),
    );

    expect(
      states.map((state) => state.connectionState),
      <RealtimeConnectionState>[
        RealtimeConnectionState.idle,
        RealtimeConnectionState.preparing,
        RealtimeConnectionState.idle,
      ],
    );
    expect(states.last.reason?.error?.message, contains('camera unavailable'));
    expect(states.last.reason, isNot(RealtimeReason.normal));
  });

  test('late preview callback never regresses a connected state', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    await manager.connect(localStream: localStream);

    dependencies.media.notifyPreviewReady();
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.connected,
    );
  });

  test(
    'connection failure retains camera and reports the failure reason',
    () async {
      final dependencies = _Dependencies();
      final manager = dependencies.manager;
      final localStream = await manager.createLocalCameraStream(
        videoFormat: _Dependencies.format,
      );
      dependencies.media.notifyPreviewReady();
      dependencies.stream.connectError = StateError('room join failed');

      await expectLater(
        manager.connect(localStream: localStream),
        throwsA(isA<XmaxError>()),
      );

      final state = await manager.currentState;
      expect(state.connectionState, RealtimeConnectionState.ready);
      expect(state.reason?.error?.message, contains('room join failed'));
      expect(dependencies.media.currentTrack, isNotNull);
    },
  );

  test('heartbeat failure returns to ready with the failure reason', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    dependencies.media.notifyPreviewReady();
    await manager.connect(localStream: localStream);

    await dependencies.sessions.failHeartbeat(StateError('heartbeat stopped'));

    final state = await manager.currentState;
    expect(state.connectionState, RealtimeConnectionState.ready);
    expect(state.reason?.error?.message, contains('heartbeat stopped'));
    expect(dependencies.media.currentTrack, isNotNull);
  });

  test(
    'explicit disconnect reason is retained until the next operation',
    () async {
      final dependencies = _Dependencies();
      final manager = dependencies.manager;
      final localStream = await manager.createLocalCameraStream(
        videoFormat: _Dependencies.format,
      );
      dependencies.media.notifyPreviewReady();
      await manager.connect(localStream: localStream);

      await manager.disconnect(reason: RealtimeReason.orientationChanged);
      expect(
        (await manager.currentState).reason,
        RealtimeReason.orientationChanged,
      );
      expect(
        (await manager.currentState).connectionState,
        RealtimeConnectionState.ready,
      );

      await manager.connect(localStream: localStream);
      expect((await manager.currentState).reason, isNull);
    },
  );

  test('close cancels and cleans up an in-flight camera creation', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final gate = Completer<void>();
    dependencies.media.createGate = gate;

    final creation = manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    final creationExpectation = expectLater(
      creation,
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.cancelled,
        ),
      ),
    );
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.preparing,
    );

    final closing = manager.close();
    gate.complete();
    await Future.wait(<Future<void>>[creationExpectation, closing]);

    expect(dependencies.media.stopCount, 1);
    expect(dependencies.media.currentTrack, isNull);
    expect(
      await manager.currentState,
      const RealtimeState(
        connectionState: RealtimeConnectionState.idle,
        reason: RealtimeReason.normal,
      ),
    );
  });

  test(
    'camera-only local audio volume matches the iOS no-player contract',
    () async {
      final manager =
          XmaxClient(
            configuration: XmaxConfiguration(apiKey: 'test-key'),
          ).createRealtimeManager(
            options: const RealtimeConfiguration(model: RealtimeModel.x2_0),
          );

      expect(await manager.localAudioVolume, 0.45);
      expect(await manager.remoteAudioVolume, 1.0);
      for (final value in <double>[0, 0.5, 1]) {
        await manager.setLocalAudioVolume(value);
        expect(await manager.localAudioVolume, 0.45);
      }
      for (final value in <double>[
        -0.01,
        1.01,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        await expectLater(
          manager.setLocalAudioVolume(value),
          throwsA(isA<XmaxError>()),
        );
        await expectLater(
          manager.setRemoteAudioVolume(value),
          throwsA(isA<XmaxError>()),
        );
      }
      expect(await manager.localAudioVolume, 0.45);
      expect(await manager.remoteAudioVolume, 1.0);
    },
  );

  test('camera switch stops and restores an active generation', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    await manager.startGeneration(
      localStream: localStream,
      context: RealtimeContext(prompt: 'cached condition'),
    );

    final switchedStream = await manager.switchCamera();

    expect(switchedStream, same(localStream));
    expect(dependencies.media.switchCount, 1);
    expect(dependencies.stream.startedPrompts, <String>[
      'cached condition',
      'cached condition',
    ]);
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.generating,
    );
  });

  test(
    'remote volume resets on camera creation, not stop or disconnect',
    () async {
      final dependencies = _Dependencies();
      final manager = dependencies.manager;
      expect(await manager.remoteAudioVolume, 1);
      await manager.setRemoteAudioVolume(0.83);
      final local = await manager.createLocalCameraStream(
        videoFormat: _Dependencies.format,
      );
      expect(await manager.remoteAudioVolume, 0);
      expect(await manager.localAudioVolume, 0.45);
      await manager.setLocalAudioVolume(0.9);
      expect(await manager.localAudioVolume, 0.45);
      await manager.setRemoteAudioVolume(0.634);
      expect(await manager.remoteAudioVolume, 0.63);
      await manager.startGeneration(
        localStream: local,
        context: RealtimeContext(prompt: 'test'),
      );
      await manager.stopGeneration();
      expect(await manager.remoteAudioVolume, 0.63);
      await manager.switchCamera();
      expect(await manager.remoteAudioVolume, 0.63);
      await manager.disconnect();
      expect(await manager.remoteAudioVolume, 0.63);
      await manager.stopLocalCameraStream();
      expect(await manager.remoteAudioVolume, 0.63);
      await manager.createLocalCameraStream(videoFormat: _Dependencies.format);
      expect(await manager.remoteAudioVolume, 0);
      await manager.setRemoteAudioVolume(0.75);
      await manager.close();
      expect(await manager.remoteAudioVolume, 0.75);
      await manager.createLocalCameraStream(videoFormat: _Dependencies.format);
      expect(await manager.remoteAudioVolume, 0);
      await manager.close();
    },
  );

  test(
    'failed camera creation preserves previously configured volume',
    () async {
      final dependencies = _Dependencies();
      final manager = dependencies.manager;
      await manager.setRemoteAudioVolume(0.8);
      dependencies.media.createError = StateError('camera failed');
      await expectLater(
        manager.createLocalCameraStream(videoFormat: _Dependencies.format),
        throwsA(isA<XmaxError>()),
      );
      expect(await manager.remoteAudioVolume, 0.8);
      await manager.close();
    },
  );

  test('generation restore failure is returned to the caller', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    await manager.startGeneration(
      localStream: localStream,
      context: RealtimeContext(prompt: 'cached condition'),
    );
    dependencies.stream.generationStartError = StateError('restore failed');

    await expectLater(
      manager.switchCamera(),
      throwsA(
        isA<XmaxError>()
            .having((error) => error.code, 'code', XmaxErrorCode.internalError)
            .having(
              (error) => error.message,
              'message',
              contains('restore failed'),
            ),
      ),
    );
  });

  test('serializes generation updates without disconnecting', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final reportedErrors = <XmaxError>[];
    await manager.setStateListener((state) {
      final error = state.reason?.error;
      if (error != null) reportedErrors.add(error);
    });
    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );

    await manager.startGeneration(
      localStream: localStream,
      context: RealtimeContext(prompt: 'initial'),
    );

    final firstUpdateStarted = Completer<void>();
    final releaseFirstUpdate = Completer<void>();
    dependencies.stream
      ..firstUpdateStarted = firstUpdateStarted
      ..updateGate = releaseFirstUpdate;

    final firstUpdate = manager.startGeneration(
      context: RealtimeContext(prompt: 'reference-a'),
    );
    await firstUpdateStarted.future;

    final secondUpdate = manager.startGeneration(
      context: RealtimeContext(prompt: 'reference-b'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(dependencies.stream.updatedPrompts, <String>['reference-a']);

    releaseFirstUpdate.complete();
    await Future.wait(<Future<RealtimeMediaStream?>>[
      firstUpdate,
      secondUpdate,
    ]);

    expect(dependencies.stream.updatedPrompts, <String>[
      'reference-a',
      'reference-b',
    ]);
    expect(dependencies.stream.disconnectCount, 0);
    expect(reportedErrors, isEmpty);
    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.generating,
    );
  });

  test('a newer request supersedes a generation waiting for SEI', () async {
    final dependencies = _Dependencies();
    final manager = dependencies.manager;
    final reportedErrors = <XmaxError>[];
    await manager.setStateListener((state) {
      final error = state.reason?.error;
      if (error != null) reportedErrors.add(error);
    });
    final localStream = await manager.createLocalCameraStream(
      videoFormat: _Dependencies.format,
    );
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    dependencies.stream
      ..autoConfirmGeneration = false
      ..firstGenerationStarted = firstStarted
      ..secondGenerationStarted = secondStarted;

    final firstGeneration = manager.startGeneration(
      localStream: localStream,
      context: RealtimeContext(prompt: 'reference-a'),
    );
    final firstExpectation = expectLater(
      firstGeneration,
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.cancelled,
        ),
      ),
    );
    await firstStarted.future;

    final secondGeneration = manager.startGeneration(
      context: RealtimeContext(prompt: 'reference-b'),
    );
    await secondStarted.future;

    expect(dependencies.stream.startedPrompts, <String>[
      'reference-a',
      'reference-b',
    ]);
    expect(dependencies.stream.disconnectCount, 0);
    expect(reportedErrors, isEmpty);

    dependencies.stream.confirmGeneration();
    await secondGeneration;
    await firstExpectation;

    expect(
      (await manager.currentState).connectionState,
      RealtimeConnectionState.generating,
    );
  });
}

final class _Dependencies {
  _Dependencies() {
    connection = XmaxRealtimeConnectionManager(
      sessionService: sessions,
      interactionController: media,
      renderController: render,
      streamController: stream,
    );
    generation = XmaxRealtimeGenerationManager(
      interactionController: media,
      streamController: stream,
      taskIDGenerator: () => 'task-test',
    );
    manager = XmaxRealtimeManager.internal(
      options: const RealtimeConfiguration(model: RealtimeModel.x2_0),
      mediaController: media,
      streamController: stream,
      connectionManager: connection,
      generationManager: generation,
      errorHandler: errors,
    );
  }

  static const format = RealtimeVideoFormat(width: 832, height: 1472, fps: 24);
  final media = _FakeMedia();
  final stream = _FakeStream();
  final render = _FakeRender();
  final sessions = _FakeSessions();
  final errors = RealtimeErrorHandler();
  late final XmaxRealtimeConnectionManager connection;
  late final XmaxRealtimeGenerationManager generation;
  late final XmaxRealtimeManager manager;
}

final class _FakeMedia implements MediaControlling {
  _FakeMedia() {
    track = createRealtimeVideoTrack(
      id: 'video0',
      videoFormat: _Dependencies.format,
      position: CameraPosition.front,
    );
    stream = createRealtimeMediaStream(id: 'stream-local', videoTrack: track);
  }

  late final RealtimeVideoTrack track;
  late final RealtimeMediaStream stream;
  bool _active = false;
  RealtimeCameraPreviewReadyListener? _previewReadyListener;
  Object? createError;
  Completer<void>? createGate;
  int stopCount = 0;
  int switchCount = 0;

  @override
  RealtimeVideoFormat? get currentVideoFormat =>
      _active ? track.videoFormat : null;
  @override
  RealtimeVideoTrack? get currentTrack => _active ? track : null;
  @override
  bool get hasAudio => false;

  @override
  Future<double> get localAudioVolume async => 0.45;
  @override
  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    required CameraPosition position,
  }) async {
    await createGate?.future;
    if (createError case final error?) throw error;
    _active = true;
    return stream;
  }

  @override
  bool owns(RealtimeMediaStream stream) =>
      _active && identical(this.stream, stream);
  @override
  Future<void> setLocalAudioVolume(double volume) async {}
  @override
  void setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  ) => _previewReadyListener = listener;

  void notifyPreviewReady() => _previewReadyListener?.call();
  @override
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  }) {}
  @override
  void stopInteraction() {}
  @override
  Future<void> stopLocalCameraStream() async {
    stopCount += 1;
    _active = false;
  }

  @override
  Future<void> stopLocalStream() async {
    stopCount += 1;
    _active = false;
  }

  @override
  void submitInteraction(InteractionFrame frame) {}
  @override
  Future<RealtimeMediaStream> switchCamera() async {
    switchCount += 1;
    return stream;
  }
}

final class _FakeStream implements StreamControlling {
  @override
  double remoteAudioVolume = 1;
  bool generation = false;
  bool autoConfirmGeneration = true;
  int disconnectCount = 0;
  final List<String> startedPrompts = <String>[];
  final List<String> updatedPrompts = <String>[];
  Completer<void>? firstGenerationStarted;
  Completer<void>? secondGenerationStarted;
  Completer<void>? _generationConfirmation;
  Completer<void>? firstUpdateStarted;
  Completer<void>? updateGate;
  Object? generationStartError;
  Object? connectError;
  @override
  bool get hasGenerationTask => generation;
  @override
  Future<void> activateRemoteAudio() async {}
  @override
  Future<GenerationStartConfirmation> beginGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  }) async {
    final startError = generationStartError;
    if (startError != null) throw startError;

    generation = true;
    startedPrompts.add(context.prompt);

    if (startedPrompts.length == 1) {
      firstGenerationStarted?.complete();
    } else if (startedPrompts.length == 2) {
      secondGenerationStarted?.complete();
    }

    final confirmation = Completer<void>();
    _generationConfirmation = confirmation;
    if (autoConfirmGeneration) {
      confirmation.complete();
    }

    return GenerationStartConfirmation(
      value: confirmation.future,
      onCancel: () {
        if (!confirmation.isCompleted) {
          confirmation.completeError(
            const XmaxError(
              code: XmaxErrorCode.cancelled,
              message: 'Realtime generation start cancelled',
            ),
          );
        }
      },
    );
  }

  void confirmGeneration() {
    final confirmation = _generationConfirmation;
    if (confirmation != null && !confirmation.isCompleted) {
      confirmation.complete();
    }
  }

  @override
  Future<void> connect({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  }) async {
    if (connectError case final error?) throw error;
    ensureActive();
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    generation = false;
  }

  @override
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  }) async {}
  @override
  Future<void> changeTargetSize({
    required String taskID,
    required Size targetSize,
    required void Function() ensureActive,
  }) async => ensureActive();
  @override
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener) {}
  @override
  void setPerformanceAlarmListener(
    RealtimePerformanceAlarmListener? listener,
  ) {}
  @override
  Future<void> setRemoteAudioVolume(double volume) async {
    remoteAudioVolume = (volume * 100).round() / 100;
  }

  @override
  Future<void> setVideoEncoderConfig(RealtimeVideoFormat videoFormat) async {}
  @override
  Future<void> stopGeneration({required String taskID}) async =>
      generation = false;
  @override
  Future<void> updateGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  }) async {
    updatedPrompts.add(context.prompt);
    final started = firstUpdateStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    await updateGate?.future;
  }
}

final class _FakeRender implements RenderControlling {
  @override
  void registerRemoteTrack(
    RealtimeVideoTrack track, {
    required void Function(InteractionFrame frame) interactionListener,
  }) {}
  @override
  void resetRemoteTrack(RealtimeVideoTrack? track) {}
  @override
  void setRemoteStream(RemoteStream? stream) {}
}

final class _FakeSessions implements RealtimeSessionServicing {
  RealtimeSessionHeartbeatFailureHandler? _heartbeatFailureHandler;

  Future<void> failHeartbeat(Object error) async =>
      _heartbeatFailureHandler?.call('session-1', error);

  @override
  Future<void> closeSession({required String sessionID}) async {}
  @override
  Future<RealtimeSession> createSession({required RealtimeModel model}) async =>
      const RealtimeSession(
        id: 'session-1',
        connection: RealtimeSessionConnection(
          roomID: 'room-1',
          userID: 'user-1',
          token: 'token-1',
          botName: 'bot-1',
        ),
      );
  @override
  void startHeartbeat({
    required String sessionID,
    required RealtimeSessionHeartbeatFailureHandler onFailure,
  }) => _heartbeatFailureHandler = onFailure;
  @override
  void stopHeartbeat() => _heartbeatFailureHandler = null;
}
