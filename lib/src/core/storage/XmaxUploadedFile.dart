final class XmaxUploadedFile {
  const XmaxUploadedFile._({
    required this.url,
    required this.objectKey,
    this.etag,
  });

  final Uri url;
  final String objectKey;
  final String? etag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmaxUploadedFile &&
          url == other.url &&
          objectKey == other.objectKey &&
          etag == other.etag;

  @override
  int get hashCode => Object.hash(url, objectKey, etag);
}

XmaxUploadedFile createXmaxUploadedFile({
  required Uri url,
  required String objectKey,
  String? etag,
}) => XmaxUploadedFile._(url: url, objectKey: objectKey, etag: etag);
