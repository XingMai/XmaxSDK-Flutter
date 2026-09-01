import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/core/realtime/XmaxRealtimeGenerationManager.dart';

void main() {
  test('task IDs use iOS-compatible base64url UUID representation', () {
    final values = List<String>.generate(
      100,
      (_) => XmaxRealtimeGenerationManager.createTaskID(),
    );
    expect(values.toSet(), hasLength(100));
    for (final value in values) {
      expect(value, matches(RegExp(r'^task-[A-Za-z0-9_-]{22}$')));
      expect(value, isNot(contains('=')));
    }
  });
}
