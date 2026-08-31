import 'dart:typed_data';

import '../../foundation/errors/xmax_error.dart';
import '../../foundation/storage/storage_models.dart';
import '../../service/storage/storage_servicing.dart';
import 'xmax_downloaded_file.dart';
import 'xmax_storage_managing.dart';
import 'xmax_storage_progress_handler.dart';
import 'xmax_uploaded_file.dart';

final class XmaxStorageManager implements XmaxStorageManaging {
  XmaxStorageManager({required StorageServicing storageService})
    : _storageService = storageService;

  final StorageServicing _storageService;

  @override
  Future<XmaxUploadedFile> uploadImage({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  }) => _upload(
    data: data,
    at: at,
    fileName: fileName,
    contentType: contentType,
    progress: progress,
    dataOperation: _storageService.uploadImage,
    fileOperation: _storageService.uploadImageFile,
  );

  @override
  Future<XmaxUploadedFile> uploadImageWithSafetyCheck({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  }) => _upload(
    data: data,
    at: at,
    fileName: fileName,
    contentType: contentType,
    progress: progress,
    dataOperation: _storageService.uploadImageWithSafetyCheck,
    fileOperation: _storageService.uploadImageFileWithSafetyCheck,
  );

  @override
  Future<XmaxUploadedFile> uploadVideo({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  }) => _upload(
    data: data,
    at: at,
    fileName: fileName,
    contentType: contentType,
    progress: progress,
    dataOperation: _storageService.uploadVideo,
    fileOperation: _storageService.uploadVideoFile,
  );

  @override
  Future<XmaxDownloadedFile> downloadImage({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  }) async => _downloadedFile(
    await _storageService.downloadImage(
      remoteURL: from,
      destinationURL: to,
      progress: _progressListener(progress),
    ),
  );

  @override
  Future<XmaxDownloadedFile> downloadVideo({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  }) async => _downloadedFile(
    await _storageService.downloadVideo(
      remoteURL: from,
      destinationURL: to,
      progress: _progressListener(progress),
    ),
  );

  Future<XmaxUploadedFile> _upload({
    required Uint8List? data,
    required Uri? at,
    required String? fileName,
    required String? contentType,
    required XmaxStorageProgressHandler? progress,
    required Future<StoredFile> Function({
      required Uint8List data,
      required String fileName,
      required String contentType,
      StorageProgressListener? progress,
    })
    dataOperation,
    required Future<StoredFile> Function({
      required Uri fileURL,
      String? contentType,
      StorageProgressListener? progress,
    })
    fileOperation,
  }) async {
    if ((data == null) == (at == null)) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Exactly one of data or at must be provided',
      );
    }
    final StoredFile stored;
    if (data != null) {
      final resolvedFileName = fileName?.trim() ?? '';
      final resolvedContentType = contentType?.trim() ?? '';
      if (resolvedFileName.isEmpty || resolvedContentType.isEmpty) {
        throw const XmaxError(
          code: XmaxErrorCode.invalidConfiguration,
          message: 'Data uploads require fileName and contentType',
        );
      }
      stored = await dataOperation(
        data: data,
        fileName: resolvedFileName,
        contentType: resolvedContentType,
        progress: _progressListener(progress),
      );
    } else {
      stored = await fileOperation(
        fileURL: at!,
        contentType: contentType,
        progress: _progressListener(progress),
      );
    }
    return createXmaxUploadedFile(
      url: stored.url,
      objectKey: stored.objectKey,
      etag: stored.etag,
    );
  }

  StorageProgressListener? _progressListener(
    XmaxStorageProgressHandler? handler,
  ) => handler == null
      ? null
      : (completedBytes, totalBytes) => handler(
          XmaxStorageProgress(
            completedBytes: completedBytes.clamp(0, totalBytes),
            totalBytes: totalBytes,
          ),
        );

  XmaxDownloadedFile _downloadedFile(DownloadedFile file) =>
      createXmaxDownloadedFile(
        fileURL: file.fileURL,
        byteCount: file.byteCount,
      );
}
