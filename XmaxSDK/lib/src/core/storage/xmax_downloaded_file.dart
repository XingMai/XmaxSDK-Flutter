final class XmaxDownloadedFile {
  const XmaxDownloadedFile._({required this.fileURL, required this.byteCount});

  final Uri fileURL;
  final int byteCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmaxDownloadedFile &&
          fileURL == other.fileURL &&
          byteCount == other.byteCount;

  @override
  int get hashCode => Object.hash(fileURL, byteCount);
}

XmaxDownloadedFile createXmaxDownloadedFile({
  required Uri fileURL,
  required int byteCount,
}) => XmaxDownloadedFile._(fileURL: fileURL, byteCount: byteCount);
