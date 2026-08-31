import 'realtime_model.dart';

/// 创建实时 Manager 所需的业务配置。
final class RealtimeConfiguration {
  const RealtimeConfiguration({required this.model});

  final RealtimeModel model;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeConfiguration && model == other.model;

  @override
  int get hashCode => model.hashCode;
}
