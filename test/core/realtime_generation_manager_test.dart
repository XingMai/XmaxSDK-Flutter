import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/core/realtime/XmaxRealtimeGenerationManager.dart';

void main() {
  test('task IDs retain random identity and identify the Flutter platform', () {
    final values = List<String>.generate(
      100,
      (_) => XmaxRealtimeGenerationManager.createTaskID(),
    );
    expect(values.toSet(), hasLength(100));
    for (final value in values) {
      final uri = Uri.parse(value);
      expect(uri.path, matches(RegExp(r'^task-[A-Za-z0-9_-]{22}$')));
      expect(uri.queryParameters, <String, String>{
        'os': 'flutter-${Platform.operatingSystem}',
      });
      expect(uri.path, isNot(contains('=')));
    }
  });
}
