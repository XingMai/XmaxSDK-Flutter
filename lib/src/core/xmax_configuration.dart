import '../foundation/errors/xmax_error.dart';
import '../foundation/logging/xmax_logger_option.dart';

/// SDK 全局配置。
final class XmaxConfiguration {
  XmaxConfiguration({
    required String apiKey,
    this.loggerOptions = const XmaxLoggerOption(rawValue: 0),
  }) : apiKey = apiKey.trim();

  final String apiKey;
  final XmaxLoggerOption loggerOptions;

  void validate() {
    if (apiKey.isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidAPIKey,
        message: 'API key cannot be empty',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmaxConfiguration &&
          apiKey == other.apiKey &&
          loggerOptions == other.loggerOptions;

  @override
  int get hashCode => Object.hash(apiKey, loggerOptions);
}
