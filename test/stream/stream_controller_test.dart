import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/media/camera/CameraPosition.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcEventListener.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcManaging.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeContext.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeNetworkQuality.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimePerformanceAlarm.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimePoint.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeSession.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoFormat.dart';
import 'package:xmax_sdk/src/stream/StreamController.dart';
import 'package:xmax_sdk/src/stream/encoding/EncodingControlling.dart';
import 'package:xmax_sdk/src/stream/quality/QualityControlling.dart';
import 'package:xmax_sdk/src/stream/room/RoomControlling.dart';

void main() {
  test('matching SEI selects the remote renderer', () async {
    final rtc = _FakeRtc();
    final renderedStreams = <RemoteStream?>[];
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
      remoteStreamListener: renderedStreams.add,
    );

    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
        botName: 'bot',
      ),
      ensureActive: () {},
    );

    const remote = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-stream',
    );
    rtc.listener!.onRemoteVideoPublished!(remote, true);

    expect(renderedStreams, isEmpty);

    final generation = await controller.beginGeneration(
      taskID: 'task-1',
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 24),
      context: RealtimeContext(prompt: 'animate'),
    );
    rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-1'));
    await generation.value;

    // Matching SEI selects the renderer and acknowledges generation directly.
    expect(renderedStreams, <RemoteStream?>[remote]);
  });

  test('remote audio uses the saved volume and unsubscribes on stop', () async {
    final rtc = _FakeRtc();
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );

    await controller.setRemoteAudioVolume(0.63);
    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
        botName: 'bot',
      ),
      ensureActive: () {},
    );

    const remote = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-stream',
    );
    const remoteAudio = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-audio',
    );
    rtc.listener!.onRemoteAudioPublished!(remoteAudio, true);
    final generation = await controller.beginGeneration(
      taskID: 'task-1',
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 30),
      context: RealtimeContext(prompt: 'animate'),
    );
    rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-1'));
    await generation.value;

    expect(rtc.audioSubscriptions, isEmpty);
    await controller.activateRemoteAudio();
    expect(rtc.audioVolumes, <(String, int)>[('bot-audio', 63)]);
    expect(rtc.audioSubscriptions, <(String, bool)>[('bot-audio', true)]);

    await controller.setRemoteAudioVolume(0.4);
    expect(rtc.audioVolumes.last, ('bot-audio', 40));

    await controller.stopGeneration(taskID: 'task-1');
    expect(rtc.audioSubscriptions.last, ('bot-audio', false));
  });

  test('camera audio starts muted and is unsubscribed on disconnect', () async {
    final rtc = _FakeRtc();
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );
    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
        botName: 'bot',
      ),
      ensureActive: () {},
    );

    const remote = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-stream',
    );
    const remoteAudio = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-audio',
    );
    rtc.listener!.onRemoteAudioPublished!(remoteAudio, true);
    final generation = await controller.beginGeneration(
      taskID: 'task-1',
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 30),
      context: RealtimeContext(prompt: 'animate'),
    );
    rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-1'));
    await generation.value;
    await controller.activateRemoteAudio();

    expect(rtc.audioVolumes, <(String, int)>[('bot-audio', 0)]);
    await controller.disconnect();
    expect(rtc.audioSubscriptions, <(String, bool)>[
      ('bot-audio', true),
      ('bot-audio', false),
    ]);
  });

  test('late audio publication subscribes the selected generation', () async {
    final rtc = _FakeRtc();
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );
    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
        botName: 'bot',
      ),
      ensureActive: () {},
    );

    const remote = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-video',
    );
    const remoteAudio = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-audio',
    );
    final generation = await controller.beginGeneration(
      taskID: 'task-1',
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 30),
      context: RealtimeContext(prompt: 'animate'),
    );
    rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-1'));
    await generation.value;
    await controller.activateRemoteAudio();
    expect(rtc.audioSubscriptions, isEmpty);

    rtc.listener!.onRemoteAudioPublished!(remoteAudio, true);
    await Future<void>.delayed(Duration.zero);
    expect(rtc.audioSubscriptions, <(String, bool)>[('bot-audio', true)]);

    rtc.listener!.onRemoteAudioPublished!(remoteAudio, false);
    await Future<void>.delayed(Duration.zero);
    expect(rtc.audioSubscriptions.last, ('bot-audio', false));
  });

  test('stopping generation rolls back a pending audio subscription', () async {
    final rtc = _FakeRtc();
    final subscribeGate = Completer<void>();
    rtc.audioSubscribeGate = subscribeGate;
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );
    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
        botName: 'bot',
      ),
      ensureActive: () {},
    );

    const remoteVideo = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-video',
    );
    const remoteAudio = RemoteStream(
      roomID: 'room',
      userID: 'bot',
      streamID: 'bot-audio',
    );
    rtc.listener!.onRemoteAudioPublished!(remoteAudio, true);
    final generation = await controller.beginGeneration(
      taskID: 'task-1',
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 30),
      context: RealtimeContext(prompt: 'animate'),
    );
    rtc.listener!.onSEIMessageReceived!(remoteVideo, utf8.encode('task-1'));
    await generation.value;

    final activation = expectLater(
      controller.activateRemoteAudio(),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.cancelled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rtc.audioSubscriptions, <(String, bool)>[('bot-audio', true)]);

    await controller.stopGeneration(taskID: 'task-1');
    subscribeGate.complete();
    await activation;
    expect(rtc.audioSubscriptions.last, ('bot-audio', false));
  });

  test('generation send failure is reported only once', () async {
    final expectedError = StateError('send failed');
    final controller = StreamController(
      rtcManager: _FakeRtc(),
      roomController: _FakeRoom(startError: expectedError),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );

    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
        botName: 'bot',
      ),
      ensureActive: () {},
    );

    await expectLater(
      controller.beginGeneration(
        taskID: 'task-1',
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 24,
        ),
        context: RealtimeContext(prompt: 'animate'),
      ),
      throwsA(same(expectedError)),
    );

    // Give the zone a turn to surface any duplicate completer error.
    await Future<void>.delayed(Duration.zero);
    expect(controller.hasGenerationTask, isFalse);
  });

  test(
    'pending generation receives subscription failure without forwarding',
    () async {
      final expectedError = StateError('subscribe failed');
      final rtc = _FakeRtc(subscribeRemoteVideoError: expectedError);
      final reportedErrors = <XmaxError>[];
      final controller = StreamController(
        rtcManager: rtc,
        roomController: _FakeRoom(),
        encodingController: _FakeEncoding(),
        qualityController: _FakeQuality(),
        errorListener: reportedErrors.add,
      );

      await controller.connect(
        connection: const RealtimeSessionConnection(
          roomID: 'room',
          userID: 'local-user',
          token: 'token',
          botName: 'bot',
        ),
        ensureActive: () {},
      );
      final confirmation = await controller.beginGeneration(
        taskID: 'task-1',
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 24,
        ),
        context: RealtimeContext(prompt: 'animate'),
      );

      rtc.listener!.onRemoteVideoPublished!(
        const RemoteStream(
          roomID: 'room',
          userID: 'bot',
          streamID: 'bot-stream',
        ),
        true,
      );

      await expectLater(
        confirmation.value,
        throwsA(
          isA<XmaxError>().having(
            (error) => error.message,
            'message',
            expectedError.toString(),
          ),
        ),
      );
      expect(reportedErrors, isEmpty);
    },
  );

  test(
    'subscription failure without pending generation is forwarded',
    () async {
      final rtc = _FakeRtc(
        subscribeRemoteVideoError: StateError('subscribe failed'),
      );
      final reportedErrors = <XmaxError>[];
      final controller = StreamController(
        rtcManager: rtc,
        roomController: _FakeRoom(),
        encodingController: _FakeEncoding(),
        qualityController: _FakeQuality(),
        errorListener: reportedErrors.add,
      );

      await controller.connect(
        connection: const RealtimeSessionConnection(
          roomID: 'room',
          userID: 'local-user',
          token: 'token',
          botName: 'bot',
        ),
        ensureActive: () {},
      );
      rtc.listener!.onRemoteVideoPublished!(
        const RemoteStream(
          roomID: 'room',
          userID: 'bot',
          streamID: 'bot-stream',
        ),
        true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.code, XmaxErrorCode.internalError);
    },
  );
}

final class _FakeRtc implements RtcManaging {
  _FakeRtc({this.subscribeRemoteVideoError});

  final Object? subscribeRemoteVideoError;
  RtcEventListener? listener;
  Completer<void>? audioSubscribeGate;
  final List<(String, bool)> audioSubscriptions = <(String, bool)>[];
  final List<(String, int)> audioVolumes = <(String, int)>[];

  @override
  void setEventListener(RtcEventListener? listener) => this.listener = listener;

  @override
  Future<void> publishLocalVideo({required bool publish}) async {}

  @override
  Future<void> subscribeRemoteVideo({
    required String streamID,
    required bool subscribe,
  }) async {
    final error = subscribeRemoteVideoError;
    if (subscribe && error != null) {
      throw error;
    }
  }

  @override
  Future<void> subscribeRemoteAudio({
    required String streamID,
    required bool subscribe,
  }) async {
    audioSubscriptions.add((streamID, subscribe));
    if (subscribe) await audioSubscribeGate?.future;
  }

  @override
  Future<void> setRemoteAudioVolume({
    required int volume,
    required String streamID,
  }) async {
    audioVolumes.add((streamID, volume));
  }

  @override
  Future<void> configureVideoEncoding(
    VideoEncodingConfiguration configuration,
  ) async {}

  @override
  Future<void> destroy() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> joinRoom({required RoomJoinConfiguration configuration}) async {}

  @override
  Future<void> leaveRoom() async {}

  @override
  Future<void> sendRoomMessage(String message) async {}

  @override
  void setCameraPreviewReadyListener(void Function()? listener) {}

  @override
  Future<void> startVideoCapture({
    required int width,
    required int height,
    required int frameRate,
  }) async {}

  @override
  Future<void> stopVideoCapture() async {}

  @override
  Future<void> switchCamera({required CameraPosition position}) async {}
}

final class _FakeRoom implements RoomControlling {
  _FakeRoom({this.startError});

  final Object? startError;

  @override
  Future<void> changeGenerationCondition({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) async {}

  @override
  Future<void> join({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  }) async => ensureActive();

  @override
  Future<void> leave() async {}

  @override
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  }) async {}

  @override
  Future<void> startGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) async {
    final error = startError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> stopGeneration({required String taskID}) async {}
}

final class _FakeEncoding implements EncodingControlling {
  @override
  Future<void> configure(RealtimeVideoFormat videoFormat) async {}
}

final class _FakeQuality implements QualityControlling {
  @override
  void emitNetworkQuality(RealtimeNetworkQuality quality) {}

  @override
  void emitPerformanceAlarm(RealtimePerformanceAlarm alarm) {}

  @override
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener) {}

  @override
  void setPerformanceAlarmListener(
    RealtimePerformanceAlarmListener? listener,
  ) {}
}
