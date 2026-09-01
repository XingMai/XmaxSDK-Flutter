import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/render/RenderController.dart';

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
    controller.setRemoteStream(stream);

    final readiness = controller.waitUntilRemoteFrameReady();
    controller.notifyRemoteFrameReady(stream);

    await readiness;
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
