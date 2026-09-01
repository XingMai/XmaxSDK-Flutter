import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
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
        isFrameReady: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_remoteOpacity(tester), 1);

    VideoRenderRegistry.register(remoteTrack, null);
    await tester.pump();

    expect(_remoteOpacity(tester), 0);
  });
}

double _remoteOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
