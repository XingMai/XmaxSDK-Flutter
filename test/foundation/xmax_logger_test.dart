import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLogger.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLoggerOption.dart';

void main() {
  late List<({XmaxLogLevel level, String message})> records;

  setUp(() {
    XmaxLogger.reset();
    records = <({XmaxLogLevel level, String message})>[];
    XmaxLogger.setSink((level, message) {
      records.add((level: level, message: message));
    });
  });

  tearDown(XmaxLogger.reset);

  test('formattedMessage prefixes every line with category', () {
    expect(
      XmaxLogger.formattedMessage('Line 1\nLine 2', category: ' RTC '),
      '[Xmax][RTC] Line 1\n[Xmax][RTC] Line 2',
    );
    expect(
      XmaxLogger.formattedMessage('Ready', category: '  '),
      '[Xmax] Ready',
    );
  });

  test('logging is disabled by default', () {
    XmaxLogger.error('Hidden', category: 'API');

    expect(records, isEmpty);
  });

  test('business and performance options filter independently', () {
    XmaxLogger.configure(options: XmaxLoggerOption.business);

    XmaxLogger.info('Business', category: 'Room');
    XmaxLogger.debug(
      'Performance',
      category: 'RTC',
      option: XmaxLoggerOption.performance,
    );

    expect(records, <({XmaxLogLevel level, String message})>[
      (level: XmaxLogLevel.info, message: '[Xmax][Room] Business'),
    ]);
  });

  test('logger preserves all output levels', () {
    XmaxLogger.configure(options: XmaxLoggerOption.all);

    XmaxLogger.debug('Debug');
    XmaxLogger.info('Info');
    XmaxLogger.warn('Warning');
    XmaxLogger.error('Error');

    expect(records.map((record) => record.level), XmaxLogLevel.values);
  });
}
