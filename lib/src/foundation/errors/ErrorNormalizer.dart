import 'dart:async';
import 'dart:io';

/// 将 Dart 和平台异常归一化为适合 SDK 对外暴露的稳定信息。
abstract final class ErrorNormalizer {
  static String description(Object error) {
    final description = switch (error) {
      HttpException(:final message) => message,
      SocketException(:final message) => message,
      FileSystemException(:final message) => message,
      FormatException(:final message) => message,
      TimeoutException(:final message?) => message,
      _ => error.toString(),
    }.trim();

    return description.isEmpty ? error.runtimeType.toString() : description;
  }

  static int? platformErrorCode(Object error) => switch (error) {
    SocketException(:final osError?) => osError.errorCode,
    FileSystemException(:final osError?) => osError.errorCode,
    OSError(:final errorCode) => errorCode,
    _ => null,
  };

  /// Dart 没有通用的任务取消异常；HttpClient 主动终止请求时会抛出该异常。
  static bool isCancellation(Object error) =>
      error is HttpException &&
      error.message.trim().toLowerCase() == 'request has been aborted';
}
