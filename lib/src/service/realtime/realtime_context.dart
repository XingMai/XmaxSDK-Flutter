/// 一次实时生成使用的提示词和可选参考图路径。
final class RealtimeContext {
  RealtimeContext({required String prompt, String? referencePath})
    : prompt = prompt.trim(),
      referencePath = _normalizedReferencePath(referencePath);

  final String prompt;
  final String? referencePath;

  static String? _normalizedReferencePath(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeContext &&
          prompt == other.prompt &&
          referencePath == other.referencePath;

  @override
  int get hashCode => Object.hash(prompt, referencePath);
}
