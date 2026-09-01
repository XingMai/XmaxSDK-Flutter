import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
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

  test('decoded frame received before SEI remains ready', () async {
    final controller = RenderController();

    controller.notifyRemoteFrameReady(stream);
    controller.setRemoteStream(stream);

    await controller.waitUntilRemoteFrameReady();
  });

  test('decoded frame resolves a pending readiness waiter', () async {
    final controller = RenderController();
    final track = createRealtimeVideoTrack(id: 'remote-track');
    controller.registerRemoteTrack(track, interactionListener: (_) {});
    addTearDown(() => controller.resetRemoteTrack(track));
    controller.setRemoteStream(stream);

    final readiness = controller.waitUntilRemoteFrameReady();
    controller.notifyRemoteFrameReady(stream);

    await readiness;
    final binding = VideoRenderRegistry.handleFor(track)?.value;
    expect(binding, isA<RemoteVideoRenderBinding>());
    expect((binding as RemoteVideoRenderBinding).isFrameReady, isTrue);
  });

  test('waiting without a selected remote stream fails', () async {
    final controller = RenderController();

    await expectLater(
      controller.waitUntilRemoteFrameReady(),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.rtcError,
        ),
      ),
    );
  });
}
