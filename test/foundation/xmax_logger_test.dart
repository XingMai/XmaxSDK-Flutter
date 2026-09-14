import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/XmaxSDK.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLogger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.xmax.sdk/logging');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<({XmaxLogLevel level, String message})> records;

  setUp(() {
    XmaxLogger.reset();
    records = <({XmaxLogLevel level, String message})>[];
    XmaxLogger.setSink((level, message) {
      records.add((level: level, message: message));
    });
  });

  tearDown(XmaxLogger.reset);

  test(
    'client environment selects process-wide details and reset restores Chinese',
    () {
      expect(XmaxLogger.localized('状态：', 'Status: '), '状态：');
      XmaxClient(
        configuration: XmaxConfiguration(
          apiKey: 'test',
          environment: XmaxEnvironment.global,
          loggerOptions: XmaxLoggerOption.all,
        ),
      );
      expect(XmaxLogger.localized('状态：', 'Status: '), 'Status: ');
      XmaxLogger.info(
        message: '标题 (Title)\n${XmaxLogger.localized('状态：', 'Status: ')}ok',
      );
      expect(records.single.message, '[Xmax] 标题 (Title)\n[Xmax] Status: ok');

      XmaxClient(
        configuration: XmaxConfiguration(
          apiKey: 'test',
          environment: XmaxEnvironment.china,
          loggerOptions: XmaxLoggerOption.business,
        ),
      );
      expect(XmaxLogger.localized('状态：', 'Status: '), '状态：');
      expect(XmaxLogger.isEnabled(XmaxLoggerOption.performance), isFalse);
      XmaxLogger.configure(
        options: XmaxLoggerOption.all,
        environment: XmaxEnvironment.global,
      );
      XmaxLogger.reset();
      expect(XmaxLogger.localized('状态：', 'Status: '), '状态：');
    },
  );

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

  test('unsupported platforms retain filtered console logging', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final originalDebugPrint = debugPrint;
    final console = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) => console.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    XmaxLogger.reset();

    XmaxLogger.error(message: 'disabled');
    expect(console, isEmpty);

    XmaxLogger.configure(options: XmaxLoggerOption.business);
    XmaxLogger.error(
      category: XmaxLoggerCategory.realtime,
      message: 'Generation failed\nReason: timeout',
    );
    XmaxLogger.debug(
      message: 'hidden stats',
      option: XmaxLoggerOption.performance,
    );
    expect(console, <String>[
      '[Xmax][Realtime] Generation failed\n[Xmax][Realtime] Reason: timeout',
    ]);

    XmaxLogger.configure(options: XmaxLoggerOption.all);
    XmaxLogger.debug(
      category: XmaxLoggerCategory.rtc,
      message: 'Performance stats',
      option: XmaxLoggerOption.performance,
    );
    expect(console.last, '[Xmax][RTC] Performance stats');
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    test(
      '$platform routes levels to native logs without duplicate stdout',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final originalPrint = debugPrint;
        final console = <String?>[];
        debugPrint = (String? message, {int? wrapWidth}) =>
            console.add(message);
        addTearDown(() => debugPrint = originalPrint);
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        XmaxLogger.reset();

        XmaxLogger.error(message: 'disabled');
        XmaxLogger.configure(options: XmaxLoggerOption.business);
        XmaxLogger.debug(
          message: 'filtered',
          option: XmaxLoggerOption.performance,
        );
        XmaxLogger.debug(category: XmaxLoggerCategory.rtc, message: 'Debug');
        XmaxLogger.info(category: XmaxLoggerCategory.rtc, message: 'Info');
        XmaxLogger.warn(category: XmaxLoggerCategory.rtc, message: 'Warning');
        XmaxLogger.error(
          category: XmaxLoggerCategory.rtc,
          message: 'Error\nDetail',
        );
        await Future<void>.delayed(Duration.zero);

        expect(calls.map((call) => call.method), everyElement('log'));
        expect(calls.map((call) => (call.arguments as Map)['level']), <String>[
          'debug',
          'info',
          'warning',
          'error',
        ]);
        expect(
          (calls.last.arguments as Map)['message'],
          '[Xmax][RTC] Error\n[Xmax][RTC] Detail',
        );
        expect(console, isEmpty);
      },
    );
  }

  for (final failure in <Exception>[
    MissingPluginException('not registered'),
    PlatformException(code: 'logging_failed'),
  ]) {
    test(
      'native logging failure falls back safely: ${failure.runtimeType}',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final originalPrint = debugPrint;
        final console = <String?>[];
        debugPrint = (String? message, {int? wrapWidth}) =>
            console.add(message);
        addTearDown(() => debugPrint = originalPrint);
        messenger.setMockMethodCallHandler(channel, (_) async => throw failure);
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        XmaxLogger.reset();
        XmaxLogger.configure(options: XmaxLoggerOption.all);

        XmaxLogger.error(message: 'Original diagnostic');
        await Future<void>.delayed(Duration.zero);
        expect(console, <String>['[Xmax] Original diagnostic']);
      },
    );
  }
}
