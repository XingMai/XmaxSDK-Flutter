import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/features/realtime/realtime_loading_overlay.dart';

void main() {
  testWidgets('matches the iOS realtime loading overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(child: RealtimeLoadingOverlay(isLoading: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final overlay = find.byType(RealtimeLoadingOverlay);
    final imageFinder = find.descendant(
      of: overlay,
      matching: find.byType(Image),
    );
    final image = tester.widget<Image>(imageFinder);
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/realtime_loading.gif',
    );
    expect(image.width, 54);
    expect(image.height, 50);

    final background = tester.widget<ColoredBox>(
      find.descendant(of: overlay, matching: find.byType(ColoredBox)),
    );
    expect(background.color.a, closeTo(0.72, 0.001));
    expect(
      tester
          .widget<IgnorePointer>(
            find.descendant(of: overlay, matching: find.byType(IgnorePointer)),
          )
          .ignoring,
      isTrue,
    );
  });

  testWidgets('keeps the GIF mounted until the fade-out finishes', (
    tester,
  ) async {
    var isLoading = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RealtimeLoadingOverlay(isLoading: isLoading);
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    update(() => isLoading = false);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 299));
    expect(find.byType(Image), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
