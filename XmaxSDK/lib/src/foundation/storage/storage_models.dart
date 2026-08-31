import 'dart:typed_data';

typedef StorageProgressListener =
    void Function(int completedBytes, int totalBytes);

final class StorageCredential {
  const StorageCredential({
    required this.accessKeyID,
    required this.secretAccessKey,
    required this.sessionToken,
  });

  final String accessKeyID;
  final String secretAccessKey;
  final String sessionToken;
}

final class StorageConfiguration {
  const StorageConfiguration({
    required this.bucket,
    required this.region,
    required this.endpoint,
    required this.credential,
  });

  final String bucket;
  final String region;
  final String endpoint;
  final StorageCredential credential;
}

sealed class StorageUploadSource {
  const StorageUploadSource();
}

final class StorageDataUploadSource extends StorageUploadSource {
  const StorageDataUploadSource(this.data);

  final Uint8List data;
}

final class StorageFileUploadSource extends StorageUploadSource {
  const StorageFileUploadSource(this.fileURL);

  final Uri fileURL;
}

final class StoredFile {
  const StoredFile({required this.url, required this.objectKey, this.etag});

  final Uri url;
  final String objectKey;
  final String? etag;
}

final class DownloadedFile {
  const DownloadedFile({required this.fileURL, required this.byteCount});

  final Uri fileURL;
  final int byteCount;
}
