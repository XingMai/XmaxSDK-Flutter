import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/render/RenderController.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderBinding.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderRegistry.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoTrack.dart';

void main() {
  const stream = RemoteStream(
    roomID: 'room-id',
    userID: 'bot-id',
    streamID: 'bot-stream',
  );

  test('a selected remote stream is bound immediately', () {
    final controller = RenderController();
    final track = createRealtimeVideoTrack(id: 'remote-track');
    controller.registerRemoteTrack(track, interactionListener: (_) {});
    addTearDown(() => controller.resetRemoteTrack(track));

    controller.setRemoteStream(stream);

    final binding = VideoRenderRegistry.handleFor(track)?.value;
    expect(binding, isA<RemoteVideoRenderBinding>());
    expect((binding as RemoteVideoRenderBinding).stream, stream);
  });

  test('clearing the selected remote stream clears its binding', () {
    final controller = RenderController();
    final track = createRealtimeVideoTrack(id: 'remote-track');
    controller.registerRemoteTrack(track, interactionListener: (_) {});
    addTearDown(() => controller.resetRemoteTrack(track));
    controller.setRemoteStream(stream);

    controller.setRemoteStream(null);

    expect(VideoRenderRegistry.handleFor(track)?.value, isNull);
  });
}
