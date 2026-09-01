import 'package:flutter/foundation.dart';

import 'XmaxLoggerOption.dart';

abstract final class XmaxLogger {
  static XmaxLoggerOption _options = const XmaxLoggerOption(rawValue: 0);

  static void configure({required XmaxLoggerOption options}) {
    _options = options;
  }

  static void debug(
    String message, {
    String? category,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(message, category: category, option: option);
  }

  static void info(
    String message, {
    String? category,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(message, category: category, option: option);
  }

  static void warn(
    String message, {
    String? category,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(message, category: category, option: option);
  }

  static void error(
    String message, {
    String? category,
    XmaxLoggerOption option = XmaxLoggerOption.business,
  }) {
    _write(message, category: category, option: option);
  }

  static String formattedMessage(String message, {String? category}) {
    final normalizedCategory = category?.trim();
    final prefix = normalizedCategory == null || normalizedCategory.isEmpty
        ? '[Xmax]'
        : '[Xmax][$normalizedCategory]';
    return message.split('\n').map((line) => '$prefix $line').join('\n');
  }

  static void _write(
    String message, {
    required String? category,
    required XmaxLoggerOption option,
  }) {
    if (!_options.contains(option)) {
      return;
    }
    debugPrint(formattedMessage(message, category: category));
  }
}
