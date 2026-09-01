import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/media/interaction/InteractionFrame.dart';
import 'package:xmax_sdk/src/render/trajectory/TrajectoryBinding.dart';
import 'package:xmax_sdk/src/render/trajectory/TrajectoryRegistry.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderBinding.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderRegistry.dart';
import 'package:xmax_sdk/src/render/video/XmaxRealtimeVideoView.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoTrack.dart';

void main() {
  testWidgets('remote layer follows its RTC binding automatically', (
    tester,
  ) async {
    final remoteTrack = createRealtimeVideoTrack(id: 'remote');
    VideoRenderRegistry.register(remoteTrack, null);
    addTearDown(() => VideoRenderRegistry.unregister(remoteTrack));

    await tester.pumpWidget(
      MaterialApp(home: XmaxRealtimeVideoView(remoteTrack: remoteTrack)),
    );

    expect(_remoteOpacity(tester), 0);

    VideoRenderRegistry.register(
      remoteTrack,
      const RemoteVideoRenderBinding(
        RemoteStream(roomID: 'room', userID: 'bot', streamID: 'stream'),
      ),
    );
    await tester.pump();
    expect(_remoteOpacity(tester), 1);

    VideoRenderRegistry.register(remoteTrack, null);
    await tester.pump();

    expect(_remoteOpacity(tester), 0);
  });

  testWidgets(
    'remote interaction continuously samples active touches at 30Hz',
    (tester) async {
      final remoteTrack = createRealtimeVideoTrack(id: 'interactive-remote');
      final frames = <InteractionFrame>[];

      VideoRenderRegistry.register(
        remoteTrack,
        const RemoteVideoRenderBinding(
          RemoteStream(roomID: 'room', userID: 'bot', streamID: 'stream'),
        ),
      );
      TrajectoryRegistry.register(
        remoteTrack,
        TrajectoryBinding(interactionListener: frames.add),
      );
      addTearDown(() {
        VideoRenderRegistry.unregister(remoteTrack);
        TrajectoryRegistry.unregister(remoteTrack);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: XmaxRealtimeVideoView(remoteTrack: remoteTrack),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(XmaxRealtimeVideoView)),
      );

      // Touch-down is sent immediately, even before the first sampling tick.
      expect(frames, hasLength(1));
      expect(frames.single.points, hasLength(1));

      // The ticker follows screen refreshes but throttles outbound tracks to
      // 30 Hz, including while the finger remains stationary.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(frames, hasLength(1));
      await tester.pump(const Duration(milliseconds: 18));
      expect(frames, hasLength(2));

      await gesture.up();
      final countAfterUp = frames.length;
      await tester.pump(const Duration(milliseconds: 100));
      expect(frames, hasLength(countAfterUp));
    },
  );
}

double _remoteOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;
