/// 控制 XmaxSDK 输出的日志类型。
final class XmaxLoggerOption {
  const XmaxLoggerOption({required this.rawValue});

  final int rawValue;

  static const business = XmaxLoggerOption(rawValue: 1 << 0);
  static const performance = XmaxLoggerOption(rawValue: 1 << 1);
  static const all = XmaxLoggerOption(rawValue: 3);

  bool contains(XmaxLoggerOption option) =>
      option.rawValue != 0 && (rawValue & option.rawValue) == option.rawValue;

  XmaxLoggerOption operator |(XmaxLoggerOption other) =>
      XmaxLoggerOption(rawValue: rawValue | other.rawValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmaxLoggerOption && rawValue == other.rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}
