import 'package:flutter/services.dart';

import '../storage/StorageModels.dart';

/// Reads file headers for diagnostics only, without decoding full video frames
/// or creating an RTC media source. Unsupported files must still be uploadable.
final class MediaFileMetadataManager {
  const MediaFileMetadataManager();

  static const _channel = MethodChannel('ai.xmax.sdk/media');

  Future<String> readResolution(
    StorageUploadSource source, {
    required bool isVideo,
  }) async {
    // Like iOS StorageService, in-memory videos do not need a temporary file
    // merely to populate a log field. File-backed videos use display dimensions.
    if (isVideo && source is StorageDataUploadSource) return '--';

    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('readResolution', <String, Object>{
            'mediaType': isVideo ? 'video' : 'image',
            ...switch (source) {
              StorageDataUploadSource(:final data) => {'data': data},
              StorageFileUploadSource(:final fileURL) => {
                'filePath': fileURL.toFilePath(),
              },
            },
          })
          .timeout(const Duration(seconds: 2));
      final width = result?['width'];
      final height = result?['height'];
      if (width is int && height is int && width > 0 && height > 0) {
        return '$width × $height';
      }
    } catch (_) {
      // Metadata is optional: missing plugins, corrupt files, and slow readers
      // must never fail an upload or leave it indefinitely waiting on logging.
    }
    return '--';
  }
}
