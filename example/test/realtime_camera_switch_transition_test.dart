import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/features/realtime/realtime_camera_switch_transition.dart';
import 'package:xmax_sdk_example/features/realtime/realtime_loading_overlay.dart';

void main() {
  testWidgets('finishes without waiting for the camera operation', (
    tester,
  ) async {
    var active = false;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RealtimeCameraSwitchTransition(
              active: active,
              child: const ColoredBox(color: Colors.pink),
            );
          },
        ),
      ),
    );

    update(() => active = true);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('camera-switch-blur')), findsOne);

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('camera-switch-blur')),
      findsNothing,
    );
    expect(active, isTrue);
  });

  testWidgets('keeps the cover until a slow flip finishes', (tester) async {
    var active = false;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RealtimeCameraSwitchTransition(
              active: active,
              child: const ColoredBox(color: Colors.blue),
            );
          },
        ),
      ),
    );

    update(() => active = true);
    await tester.pump();
    await tester.pump(RealtimeCameraSwitchTransition.blurDuration);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('camera-switch-flip')),
    );
    expect(transform.transform.storage[0].abs(), lessThan(0.01));

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('camera-switch-blur')),
      findsNothing,
    );
  });

  testWidgets('generation resume clears blur before loading disappears', (
    tester,
  ) async {
    var switching = false;
    var loading = false;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RealtimeCameraSwitchTransition(
                  active: switching,
                  child: const ColoredBox(color: Colors.green),
                ),
                RealtimeLoadingOverlay(isLoading: loading),
              ],
            );
          },
        ),
      ),
    );

    update(() {
      switching = true;
      loading = true;
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // The fixed visual transition has ended, but generation is still pending.
    expect(
      find.byKey(const ValueKey<String>('camera-switch-blur')),
      findsNothing,
    );
    expect(find.byType(Image), findsOneWidget);

    // Re-entering `generating` ends only the loading state.
    update(() {
      switching = false;
      loading = false;
    });
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('camera-switch-blur')),
      findsNothing,
    );
    expect(find.byType(Image), findsNothing);
  });
}
