import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'XmaxLoggerOption.dart';

abstract final class XmaxLogger {
  static XmaxLoggerOption _options = const XmaxLoggerOption(rawValue: 0);
  static XmaxLogSink _sink = _defaultSink;

  static void configure({required XmaxLoggerOption options}) {
    _options = options;
  }

  static bool isEnabled(XmaxLoggerOption option) => _options.contains(option);

  static void debug({
    XmaxLoggerCategory? category,
    required String message,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(XmaxLogLevel.debug, message, category: category, option: option);
  }

  static void info({
    XmaxLoggerCategory? category,
    required String message,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(XmaxLogLevel.info, message, category: category, option: option);
  }

  static void warn({
    XmaxLoggerCategory? category,
    required String message,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(XmaxLogLevel.warning, message, category: category, option: option);
  }

  static void error({
    XmaxLoggerCategory? category,
    required String message,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(XmaxLogLevel.error, message, category: category, option: option);
  }

  static String formattedMessage({
    XmaxLoggerCategory? category,
    required String message,
  }) {
    final prefix = category == null ? '[Xmax]' : '[Xmax][${category.value}]';
    return message.split('\n').map((line) => '$prefix $line').join('\n');
  }

  static void _write(
    XmaxLogLevel level,
    String message, {
    required XmaxLoggerCategory? category,
    required XmaxLoggerOption option,
  }) {
    if (!isEnabled(option)) {
      return;
    }
    _sink(level, formattedMessage(category: category, message: message));
  }

  static void _defaultSink(XmaxLogLevel level, String message) {
    developer.log(message, name: 'ai.xmax.XmaxSDK', level: level.value);
  }

  @visibleForTesting
  static void setSink(XmaxLogSink sink) {
    _sink = sink;
  }

  @visibleForTesting
  static void reset() {
    _options = const XmaxLoggerOption(rawValue: 0);
    _sink = _defaultSink;
  }
}

enum XmaxLoggerCategory {
  api('API'),
  rtc('RTC'),
  room('Room'),
  stream('Stream'),
  storage('Storage'),
  realtime('Realtime'),
  media('Media'),
  render('Render'),
  permission('Permission'),
  interaction('Interaction');

  const XmaxLoggerCategory(this.value);

  final String value;
}

enum XmaxLogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const XmaxLogLevel(this.value);

  final int value;
}

typedef XmaxLogSink = void Function(XmaxLogLevel level, String message);
