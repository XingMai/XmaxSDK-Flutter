import 'dart:typed_data';

import 'XmaxDownloadedFile.dart';
import 'XmaxStorageProgressHandler.dart';
import 'XmaxUploadedFile.dart';

abstract interface class XmaxStorageManaging {
  Future<XmaxUploadedFile> uploadImage({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxUploadedFile> uploadImageWithSafetyCheck({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxUploadedFile> uploadVideo({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxDownloadedFile> downloadImage({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  });

  Future<XmaxDownloadedFile> downloadVideo({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  });
}
