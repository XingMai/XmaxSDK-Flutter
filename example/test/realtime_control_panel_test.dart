import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/features/realtime/realtime_control_panel.dart';

void main() {
  testWidgets('shows an uploaded category reference first with loading state', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final uploading = _reference(
      id: 'custom-uploading',
      uploadState: XLabRealtimeReferenceUploadState.uploading,
    );
    final ready = _reference(id: 'catalog-ready', referencePath: '/ready.png');

    await tester.pumpWidget(
      _TestApp(
        child: XLabRealtimeControlPanel(
          mode: XLabRealtimePanelMode.character,
          generating: false,
          busy: false,
          promptController: controller,
          references: <XLabRealtimeReference>[uploading, ready],
          selectedReference: uploading,
          onModeChanged: (_) {},
          onStop: () {},
          onReferenceChanged: (_) {},
          onAddReference: () {},
          onTouchStart: () {},
          onPromptSubmit: () {},
          onPromptReference: () {},
        ),
      ),
    );

    final addX = tester
        .getTopLeft(find.byKey(const ValueKey('add-reference')))
        .dx;
    final uploadingX = tester
        .getTopLeft(find.byKey(const ValueKey('reference-custom-uploading')))
        .dx;
    final readyX = tester
        .getTopLeft(find.byKey(const ValueKey('reference-catalog-ready')))
        .dx;

    expect(addX, lessThan(uploadingX));
    expect(uploadingX, lessThan(readyX));
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('reference-upload-state-custom-uploading'),
        ),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('free reference replaces add button and taps to remove', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'custom effect');
    addTearDown(controller.dispose);
    var referenceActions = 0;

    await tester.pumpWidget(
      _TestApp(
        child: XLabRealtimeControlPanel(
          mode: XLabRealtimePanelMode.free,
          generating: false,
          busy: false,
          promptController: controller,
          references: const <XLabRealtimeReference>[],
          selectedReference: null,
          promptReference: _reference(
            id: 'prompt-ready',
            referencePath: '/prompt.png',
          ),
          onModeChanged: (_) {},
          onStop: () {},
          onReferenceChanged: (_) {},
          onAddReference: () {},
          onTouchStart: () {},
          onPromptSubmit: () {},
          onPromptReference: () => referenceActions += 1,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('prompt-reference-preview')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.add), findsNothing);

    await tester.tap(find.byKey(const ValueKey('prompt-reference-preview')));
    expect(referenceActions, 1);
  });

  testWidgets('free reference blocks removal and submission while uploading', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'custom effect');
    addTearDown(controller.dispose);
    var referenceActions = 0;
    var submissions = 0;

    await tester.pumpWidget(
      _TestApp(
        child: XLabRealtimeControlPanel(
          mode: XLabRealtimePanelMode.free,
          generating: false,
          busy: false,
          promptController: controller,
          references: const <XLabRealtimeReference>[],
          selectedReference: null,
          promptReference: _reference(
            id: 'prompt-uploading',
            uploadState: XLabRealtimeReferenceUploadState.uploading,
          ),
          onModeChanged: (_) {},
          onStop: () {},
          onReferenceChanged: (_) {},
          onAddReference: () {},
          onTouchStart: () {},
          onPromptSubmit: () => submissions += 1,
          onPromptReference: () => referenceActions += 1,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final previewOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('prompt-reference-preview')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    final submitOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byIcon(Icons.arrow_upward_rounded),
            matching: find.byType(Opacity),
          )
          .first,
    );

    expect(previewOpacity.opacity, 1);
    expect(submitOpacity.opacity, 0.2);

    await tester.tap(find.byKey(const ValueKey('prompt-reference-preview')));
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));

    expect(referenceActions, 0);
    expect(submissions, 0);
  });
}

XLabRealtimeReference _reference({
  required String id,
  String? referencePath,
  XLabRealtimeReferenceUploadState uploadState =
      XLabRealtimeReferenceUploadState.ready,
}) => XLabRealtimeReference(
  id: id,
  categoryID: XLabRealtimePanelMode.character.id,
  title: id,
  referencePath: referencePath,
  sourceURL: Uri.file('/tmp/$id.png'),
  uploadState: uploadState,
);

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );
}
