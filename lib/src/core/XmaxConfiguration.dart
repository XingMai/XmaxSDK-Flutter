import '../foundation/errors/XmaxError.dart';
import '../foundation/logging/XmaxLoggerOption.dart';
import 'XmaxEnvironment.dart';

/// SDK 全局配置。
final class XmaxConfiguration {
  XmaxConfiguration({
    required String apiKey,
    this.environment = XmaxEnvironment.china,
    this.loggerOptions = const XmaxLoggerOption(rawValue: 0),
  }) : apiKey = apiKey.trim();

  final String apiKey;
  final XmaxEnvironment environment;
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
          environment == other.environment &&
          loggerOptions == other.loggerOptions;

  @override
  int get hashCode => Object.hash(apiKey, environment, loggerOptions);
}
