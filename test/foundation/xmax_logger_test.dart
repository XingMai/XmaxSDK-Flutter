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
      XmaxLogger.formattedMessage(
        category: XmaxLoggerCategory.rtc,
        message: 'Line 1\nLine 2',
      ),
      '[Xmax][RTC] Line 1\n[Xmax][RTC] Line 2',
    );
    expect(XmaxLogger.formattedMessage(message: 'Ready'), '[Xmax] Ready');
  });

  test('logging is disabled by default', () {
    XmaxLogger.error(category: XmaxLoggerCategory.api, message: 'Hidden');

    expect(records, isEmpty);
  });

  test('business and performance options filter independently', () {
    XmaxLogger.configure(options: XmaxLoggerOption.business);

    XmaxLogger.info(category: XmaxLoggerCategory.room, message: 'Business');
    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message: 'Performance',
      option: XmaxLoggerOption.performance,
    );

    expect(records, <({XmaxLogLevel level, String message})>[
      (level: XmaxLogLevel.info, message: '[Xmax][Room] Business'),
    ]);
  });

  test('logger preserves all output levels', () {
    XmaxLogger.configure(options: XmaxLoggerOption.all);

    XmaxLogger.debug(message: 'Debug');
    XmaxLogger.info(message: 'Info');
    XmaxLogger.warn(message: 'Warning');
    XmaxLogger.error(message: 'Error');

    expect(records.map((record) => record.level), XmaxLogLevel.values);
  });
}
