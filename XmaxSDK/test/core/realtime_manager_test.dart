import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/core/realtime/realtime_configuration.dart';
import 'package:xmax_sdk/src/core/realtime/realtime_error_handler.dart';
import 'package:xmax_sdk/src/core/realtime/realtime_model.dart';
import 'package:xmax_sdk/src/core/realtime/xmax_realtime_connection_manager.dart';
import 'package:xmax_sdk/src/core/realtime/xmax_realtime_generation_manager.dart';
import 'package:xmax_sdk/src/core/realtime/xmax_realtime_manager.dart';
import 'package:xmax_sdk/src/foundation/errors/xmax_error.dart';
import 'package:xmax_sdk/src/foundation/media/camera/camera_position.dart';
import 'package:xmax_sdk/src/foundation/rtc/rtc_models.dart';
import 'package:xmax_sdk/src/media/interaction/interaction_frame.dart';
import 'package:xmax_sdk/src/media/media_controlling.dart';
import 'package:xmax_sdk/src/render/render_controlling.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_context.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_media_stream.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_network_quality.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_performance_alarm.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_point.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_session.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_session_servicing.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_state.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_video_format.dart';
import 'package:xmax_sdk/src/service/realtime/realtime_video_track.dart';
import 'package:xmax_sdk/src/stream/stream_controlling.dart';

void main() {
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
      RealtimeConnectionState.disconnected,
    );
    expect(dependencies.media.stopCount, 0);
    await manager.close();
    expect(dependencies.media.stopCount, 1);
  });

  test('audio volume validation reports the same public error', () async {
    final manager = _Dependencies().manager;
    XmaxError? reported;
    await manager.setErrorListener((error) => reported = error);

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
    expect(reported?.code, XmaxErrorCode.invalidConfiguration);
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
      renderController: render,
      streamController: stream,
      connectionManager: connection,
      generationManager: generation,
      errorHandler: RealtimeErrorHandler(),
    );
  }

  static const format = RealtimeVideoFormat(width: 832, height: 1472, fps: 24);
  final media = _FakeMedia();
  final stream = _FakeStream();
  final render = _FakeRender();
  final sessions = _FakeSessions();
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
  int stopCount = 0;

  @override
  RealtimeVideoFormat? get currentVideoFormat => track.videoFormat;
  @override
  RealtimeVideoTrack? get currentTrack => track;
  @override
  bool get hasAudio => false;
  @override
  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    required CameraPosition position,
  }) async => stream;
  @override
  bool owns(RealtimeMediaStream stream) => identical(this.stream, stream);
  @override
  Future<void> setLocalAudioVolume(double volume) async {}
  @override
  void setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  ) {}
  @override
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  }) {}
  @override
  void stopInteraction() {}
  @override
  Future<void> stopLocalCameraStream() async => stopCount += 1;
  @override
  Future<void> stopLocalStream() async => stopCount += 1;
  @override
  void submitInteraction(InteractionFrame frame) {}
  @override
  Future<RealtimeMediaStream> switchCamera() async => stream;
}

final class _FakeStream implements StreamControlling {
  bool generation = false;
  @override
  bool get hasGenerationTask => generation;
  @override
  Future<void> activateRemoteAudio() async {}
  @override
  Future<void> beginGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) async => generation = true;
  @override
  Future<void> connect({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  }) async => ensureActive();
  @override
  Future<void> disconnect() async => generation = false;
  @override
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  }) async {}
  @override
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener) {}
  @override
  void setPerformanceAlarmListener(
    RealtimePerformanceAlarmListener? listener,
  ) {}
  @override
  Future<void> setRemoteAudioVolume(double volume) async {}
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
  }) async {}
}

final class _FakeRender implements RenderControlling {
  @override
  void notifyRemoteFrameReady(RemoteStream stream) {}
  @override
  void registerRemoteTrack(
    RealtimeVideoTrack track, {
    required void Function(InteractionFrame frame) interactionListener,
  }) {}
  @override
  void resetRemoteTrack(RealtimeVideoTrack? track) {}
  @override
  void setRemoteStream(RemoteStream? stream) {}
  @override
  Future<void> waitUntilRemoteFrameReady() async {}
}

final class _FakeSessions implements RealtimeSessionServicing {
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
  }) {}
  @override
  void stopHeartbeat() {}
}
