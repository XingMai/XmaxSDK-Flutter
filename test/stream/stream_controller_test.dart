import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
  test('remote renderer binds on publish before generation SEI', () async {
    final rtc = _FakeRtc();
    final renderedStreams = <RemoteStream?>[];
    final readyStreams = <RemoteStream>[];
    final controller = StreamController(
      rtcManager: rtc,
      roomController: _FakeRoom(),
      encodingController: _FakeEncoding(),
      qualityController: _FakeQuality(),
      remoteStreamListener: renderedStreams.add,
      remoteFrameReadyListener: readyStreams.add,
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

    expect(renderedStreams, <RemoteStream?>[remote]);

    // First-frame readiness must work before SEI so Android can prepare the
    // renderer without racing decoder startup.
    rtc.listener!.onFirstRemoteVideoFrameDecoded!(remote);
    expect(readyStreams, <RemoteStream>[remote]);

    final generation = controller.beginGeneration(
      taskID: 'task-1',
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 24),
      context: RealtimeContext(prompt: 'animate'),
    );
    await Future<void>.delayed(Duration.zero);
    rtc.listener!.onSEIMessageReceived!(remote, utf8.encode('task-1'));
    await generation;

    // Matching SEI acknowledges generation without rebinding the same view.
    expect(renderedStreams, <RemoteStream?>[remote]);
  });
}

final class _FakeRtc implements RtcManaging {
  RtcEventListener? listener;

  @override
  void setEventListener(RtcEventListener? listener) => this.listener = listener;

  @override
  Future<void> publishLocalVideo({required bool publish}) async {}

  @override
  Future<void> subscribeRemoteVideo({
    required String streamID,
    required bool subscribe,
  }) async {}

  @override
  Future<void> subscribeRemoteAudio({
    required String streamID,
    required bool subscribe,
  }) async {}

  @override
  Future<void> setRemoteAudioVolume({
    required int volume,
    required String streamID,
  }) async {}

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
  }) async {}

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
