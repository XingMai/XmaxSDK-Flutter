import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/media/interaction/InteractionFrame.dart';
import 'package:xmax_sdk/src/render/trajectory/TrajectoryBinding.dart';
import 'package:xmax_sdk/src/render/trajectory/TrajectoryRegistry.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderBinding.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderRegistry.dart';
import 'package:xmax_sdk/src/render/video/XmaxRealtimeVideoView.dart';
import 'package:xmax_sdk/src/render/video/XmaxVideoView.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoTrack.dart';

void main() {
  testWidgets('mounted local preview reports its attachment once', (
    tester,
  ) async {
    final localTrack = createRealtimeVideoTrack(id: 'local');
    var attachments = 0;
    VideoRenderRegistry.register(
      localTrack,
      LocalVideoRenderBinding(onPreviewAttached: () => attachments += 1),
    );
    addTearDown(() => VideoRenderRegistry.unregister(localTrack));

    await tester.pumpWidget(
      MaterialApp(home: XmaxVideoView(track: localTrack)),
    );
    expect(attachments, 1);

    await tester.pump();
    expect(attachments, 1);
  });

  testWidgets('remote fades in only after its first rendered frame', (
    tester,
  ) async {
    final remoteTrack = createRealtimeVideoTrack(id: 'remote');
    VideoRenderRegistry.register(remoteTrack, null);
    addTearDown(() => VideoRenderRegistry.unregister(remoteTrack));

    await tester.pumpWidget(
      MaterialApp(home: XmaxRealtimeVideoView(remoteTrack: remoteTrack)),
    );

    expect(_remoteOpacity(tester), lessThan(0.01));

    VideoRenderRegistry.register(
      remoteTrack,
      const RemoteVideoRenderBinding(
        RemoteStream(roomID: 'room', userID: 'bot', streamID: 'stream'),
      ),
    );
    await tester.pump();
    expect(_remoteOpacity(tester), lessThan(0.01));
    final opacity = tester.renderObject<RenderOpacity>(find.byType(Opacity));
    // A nonzero double can still round to alpha=0 and suppress platform-view
    // painting. Verify the render object's behavior, not only the widget value.
    expect(opacity.paintsChild(opacity.child!), isTrue);

    VideoRenderRegistry.register(
      remoteTrack,
      const RemoteVideoRenderBinding(
        RemoteStream(roomID: 'room', userID: 'bot', streamID: 'stream'),
        firstFrameRendered: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_remoteOpacity(tester), greaterThan(0.01));
    expect(_remoteOpacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_remoteOpacity(tester), 1);

    VideoRenderRegistry.register(remoteTrack, null);
    await tester.pump();

    expect(_remoteOpacity(tester), lessThan(0.01));
  });

  testWidgets('removing remote track keeps the local preview mounted', (
    tester,
  ) async {
    final localTrack = createRealtimeVideoTrack(id: 'local-preview');
    final remoteTrack = createRealtimeVideoTrack(id: 'remote-result');
    VideoRenderRegistry.register(localTrack, const LocalVideoRenderBinding());
    VideoRenderRegistry.register(
      remoteTrack,
      const RemoteVideoRenderBinding(
        RemoteStream(roomID: 'room', userID: 'bot', streamID: 'stream'),
        firstFrameRendered: true,
      ),
    );
    addTearDown(() {
      VideoRenderRegistry.unregister(localTrack);
      VideoRenderRegistry.unregister(remoteTrack);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: XmaxRealtimeVideoView(
          localTrack: localTrack,
          remoteTrack: remoteTrack,
        ),
      ),
    );
    final localElement = tester.element(find.byType(XmaxVideoView).first);

    await tester.pumpWidget(
      MaterialApp(home: XmaxRealtimeVideoView(localTrack: localTrack)),
    );

    expect(tester.element(find.byType(XmaxVideoView)), same(localElement));
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
          firstFrameRendered: true,
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
