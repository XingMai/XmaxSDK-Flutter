import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/media/camera/CameraPosition.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcEventListener.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcManaging.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/foundation/runtime/RuntimeInfo.dart';
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
  test(
    'SEI replays an early first frame and retains it until unpublish',
    () async {
      final rtc = _FakeRtc();
      final renderedStreams = <RemoteStream?>[];
      final renderedFrames = <RemoteStream>[];
      final controller = StreamController(
        rtcManager: rtc,
        roomController: _FakeRoom(),
        encodingController: _FakeEncoding(),
        qualityController: _FakeQuality(),
        remoteStreamListener: renderedStreams.add,
        remoteFrameRenderedListener: renderedFrames.add,
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
      rtc.listener!.onFirstRemoteVideoFrameRendered!(remote);

      expect(renderedStreams, isEmpty);
      expect(renderedFrames, isEmpty);

      final generation = await controller.beginGeneration(
        taskID: 'task-1',
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 24,
        ),
        context: RealtimeContext(prompt: 'animate'),
      );
      rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-1'));
      await generation.value;

      // RTC can render before the generation SEI arrives. Replaying that first
      // frame must reveal the selected stream without waiting for a second event.
      expect(renderedStreams, <RemoteStream?>[remote]);
      expect(renderedFrames, <RemoteStream>[remote]);

      // A new task in the same subscription does not trigger another RTC first
      // frame callback, but must still wait for its own SEI before being shown.
      await controller.stopGeneration(taskID: 'task-1');
      final next = await controller.beginGeneration(
        taskID: 'task-2',
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 30,
        ),
        context: RealtimeContext(prompt: 'next'),
      );
      expect(renderedFrames, hasLength(1));
      rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-2'));
      await next.value;
      expect(renderedFrames, <RemoteStream>[remote, remote]);

      // Once unpublished, the stream must prove it has a new rendered frame.
      rtc.listener!.onRemoteVideoPublished!(remote, false);
      await controller.stopGeneration(taskID: 'task-2');
      rtc.listener!.onRemoteVideoPublished!(remote, true);
      final republished = await controller.beginGeneration(
        taskID: 'task-3',
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 30,
        ),
        context: RealtimeContext(prompt: 'republished'),
      );
      rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-3'));
      await republished.value;
      expect(renderedFrames, hasLength(2));
      rtc.listener!.onFirstRemoteVideoFrameRendered!(remote);
      expect(renderedFrames, <RemoteStream>[remote, remote, remote]);
      await controller.disconnect();
    },
  );

  for (final taskID in <String>[
    'task-1',
    'task-1?os=ios',
    'task-1?os=flutter-ios',
    'task-1?os=flutter-android',
  ]) {
    for (final message in <String>[
      'task-1',
      ' task-1?os=ios&index=0 ',
      'task-1?index=12',
      'task-1?os=flutter-ios&index=0',
      'task-1?os=flutter-android&index=12',
    ]) {
      test('generation matches base task ID: $taskID / $message', () async {
        final rtc = _FakeRtc();
        final renderedStreams = <RemoteStream?>[];
        final controller = StreamController(
          rtcManager: rtc,
          roomController: _FakeRoom(),
          remoteStreamListener: renderedStreams.add,
        );
        addTearDown(controller.disconnect);
        await controller.connect(
          connection: const RealtimeSessionConnection(
            roomID: 'room',
            userID: 'local-user',
            token: 'token',
            botName: 'bot',
          ),
          ensureActive: () {},
        );
        final generation = await controller.beginGeneration(
          taskID: taskID,
          videoFormat: const RealtimeVideoFormat(
            width: 832,
            height: 1472,
            fps: 30,
          ),
          context: RealtimeContext(prompt: 'animate'),
        );
        const remote = RemoteStream(
          roomID: 'room',
          userID: 'bot',
          streamID: 'bot-stream',
        );

        // Query compatibility must not accept another task, room or publisher.
        for (final invalid in <String>['task-10?index=0', '?index=0']) {
          rtc.listener!.onSEIMessageReceived!(remote, utf8.encode(invalid));
        }
        for (final unrelated in <RemoteStream>[
          const RemoteStream(
            roomID: 'other-room',
            userID: 'bot',
            streamID: 'bot-stream',
          ),
          const RemoteStream(
            roomID: 'room',
            userID: 'other-user',
            streamID: 'other-stream',
          ),
        ]) {
          rtc.listener!.onSEIMessageReceived!(unrelated, utf8.encode(message));
        }
        expect(renderedStreams, isEmpty);

        rtc.listener!.onSEIMessageReceived!(remote, utf8.encode(message));
        await generation.value;
        expect(renderedStreams, <RemoteStream?>[remote]);
      });
    }
  }

  test('remote audio uses the saved volume and unsubscribes on stop', () async {
    final rtc = _FakeRtc();
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );

    expect(controller.remoteAudioVolume, 1);
    await controller.setRemoteAudioVolume(0.634);
    expect(controller.remoteAudioVolume, 0.63);
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
    expect(controller.remoteAudioVolume, 0.4);
    rtc.audioVolumeError = StateError('native volume failed');
    await expectLater(controller.setRemoteAudioVolume(0.8), throwsStateError);
    expect(
      controller.remoteAudioVolume,
      0.4,
      reason: 'Failed native calls do not commit volume',
    );
    rtc.audioVolumeError = null;

    await controller.stopGeneration(taskID: 'task-1');
    expect(rtc.audioSubscriptions.last, ('bot-audio', false));
    expect(controller.remoteAudioVolume, 0.4);
  });

  test('camera audio starts muted and is unsubscribed on disconnect', () async {
    final rtc = _FakeRtc();
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
    );
    // The realtime Manager applies the camera-source default after creation.
    expect(controller.remoteAudioVolume, 1);
    await controller.setRemoteAudioVolume(0);
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

  test('target size change reaches the joined RTC room', () async {
    final rtc = _FakeRtc();
    final controller = StreamController(rtcManager: rtc);
    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
      ),
      ensureActive: () {},
    );

    await controller.changeTargetSize(
      taskID: 'task-1',
      targetSize: const Size(1280, 720),
      ensureActive: () {},
    );
    final event = jsonDecode(rtc.roomMessages.single) as Map<String, dynamic>;
    expect(event['event'], 'change_target_size');
    expect(event['params'], <String, Object?>{
      'target_size': <int>[1280, 720],
    });
    expect(event['user_id'], 'local-user');
    expect(event['uid'], 'task-1');
    expect(event['runtime'], isA<Map<String, dynamic>>());
    expect(event['runtime'], (await RuntimeInfo.resolve()).toJson());

    await expectLater(
      () => controller.changeTargetSize(
        taskID: 'task-1',
        targetSize: const Size(1920, 1080),
        ensureActive: () => throw StateError('stale operation'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(rtc.roomMessages, hasLength(1));
    await controller.disconnect();
  });

  test('RTC room signaling failure is normalized like iOS', () async {
    final rtc = _FakeRtc(roomMessageError: StateError('send failed'));
    final controller = StreamController(rtcManager: rtc);
    await controller.connect(
      connection: const RealtimeSessionConnection(
        roomID: 'room',
        userID: 'local-user',
        token: 'token',
      ),
      ensureActive: () {},
    );

    await expectLater(
      controller.changeTargetSize(
        taskID: 'task-1',
        targetSize: const Size(1280, 720),
        ensureActive: () {},
      ),
      throwsA(isA<XmaxError>()),
    );
    await controller.disconnect();
  });
}

final class _FakeRtc implements RtcManaging {
  _FakeRtc({this.subscribeRemoteVideoError, this.roomMessageError});

  final Object? subscribeRemoteVideoError;
  final Object? roomMessageError;
  RtcEventListener? listener;
  Completer<void>? audioSubscribeGate;
  Object? audioVolumeError;
  final List<(String, bool)> audioSubscriptions = <(String, bool)>[];
  final List<(String, int)> audioVolumes = <(String, int)>[];
  final List<String> roomMessages = <String>[];

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
    final error = audioVolumeError;
    if (error != null) throw error;
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
  Future<void> sendRoomMessage(String message) async {
    if (roomMessageError case final error?) throw error;
    roomMessages.add(message);
  }

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
    Size? targetSize,
  }) async {}

  @override
  Future<void> changeTargetSize({
    required String taskID,
    required Size targetSize,
    required void Function() ensureActive,
  }) async => ensureActive();

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
    Size? targetSize,
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
