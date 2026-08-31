final class XmaxStorageProgress {
  const XmaxStorageProgress({
    required this.completedBytes,
    required this.totalBytes,
  }) : assert(completedBytes >= 0),
       assert(totalBytes >= 0),
       assert(completedBytes <= totalBytes);

  final int completedBytes;
  final int totalBytes;

  double get fractionCompleted =>
      totalBytes > 0 ? completedBytes / totalBytes : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmaxStorageProgress &&
          completedBytes == other.completedBytes &&
          totalBytes == other.totalBytes;

  @override
  int get hashCode => Object.hash(completedBytes, totalBytes);
}

typedef XmaxStorageProgressHandler =
    void Function(XmaxStorageProgress progress);
