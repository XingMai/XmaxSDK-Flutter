import 'dart:typed_data';

import 'XmaxDownloadedFile.dart';
import 'XmaxStorageProgressHandler.dart';
import 'XmaxUploadedFile.dart';

/// 定义 SDK 对接入方提供的文件上传和下载能力。
///
/// 上传时必须在 `data` 和 `at` 中且只提供一个：
///
/// - 使用 `data` 上传内存数据时，`fileName` 和 `contentType` 必填。
/// - 使用 `at` 上传本地文件时，SDK 使用路径中的文件名，
///   `contentType` 可省略并由文件扩展名推断。
abstract interface class XmaxStorageManaging {
  /// 上传图片。
  ///
  /// [data] 是待上传的图片字节；[at] 是待上传的本地 `file` URI。
  /// [fileName] 是 [data] 对应的文件名，应包含正确的扩展名。
  /// [contentType] 是图片的 MIME 类型，例如 `image/jpeg`，并会作为
  /// COS 对象的 HTTP `Content-Type` 保存。
  /// [progress] 在上传进度变化时回调。
  Future<XmaxUploadedFile> uploadImage({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  /// 上传图片，并在上传成功后执行内容安全检查。
  ///
  /// 参数规则与 [uploadImage] 相同。未通过安全检查时，Future 会以
  /// `XmaxErrorCode.unsafeImage` 失败。
  Future<XmaxUploadedFile> uploadImageWithSafetyCheck({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  /// 上传视频。
  ///
  /// [data] 是待上传的视频字节；[at] 是待上传的本地 `file` URI。
  /// [fileName] 是 [data] 对应的文件名，应包含正确的扩展名。
  /// [contentType] 是视频的 MIME 类型，例如 `video/mp4`，并会作为
  /// COS 对象的 HTTP `Content-Type` 保存。
  /// [progress] 在上传进度变化时回调。
  Future<XmaxUploadedFile> uploadVideo({
    Uint8List? data,
    Uri? at,
    String? fileName,
    String? contentType,
    XmaxStorageProgressHandler? progress,
  });

  /// 从远程 [from] URL 下载图片到本地 [to] `file` URI。
  ///
  /// [progress] 在下载进度变化时回调。
  Future<XmaxDownloadedFile> downloadImage({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  });

  /// 从远程 [from] URL 下载视频到本地 [to] `file` URI。
  ///
  /// [progress] 在下载进度变化时回调。
  Future<XmaxDownloadedFile> downloadVideo({
    required Uri from,
    required Uri to,
    XmaxStorageProgressHandler? progress,
  });
}
