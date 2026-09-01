import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmax_sdk/XmaxSDK.dart';

import '../../ui/xlab_theme.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({required this.apiKey, super.key});

  final String apiKey;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  late final XmaxStorageManaging _storageManager = XmaxClient(
    configuration: XmaxConfiguration(apiKey: widget.apiKey),
  ).createStorageManager();
  XFile? _file;
  bool _isImage = true;
  bool _uploading = false;
  bool _safetyCheck = false;
  double _progress = 0;
  int _fileBytes = 0;
  Uri? _uploadedURL;
  String? _error;
  Duration? _elapsed;

  Future<void> _pick() async {
    const mediaTypes = XTypeGroup(
      label: '图片或视频',
      extensions: <String>[
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'm4v',
      ],
      uniformTypeIdentifiers: <String>['public.image', 'public.movie'],
      mimeTypes: <String>['image/*', 'video/*'],
    );
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[mediaTypes],
      );
      if (file == null) return;
      final extension = file.name.split('.').last.toLowerCase();
      final image = <String>{
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
      }.contains(extension);
      final bytes = await file.length();
      if (!mounted) return;
      setState(() {
        _file = file;
        _isImage = image;
        _fileBytes = bytes;
        _progress = 0;
        _uploadedURL = null;
        _elapsed = null;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _upload({required bool safetyCheck}) async {
    final file = _file;
    if (file == null || _uploading) return;
    setState(() {
      _uploading = true;
      _safetyCheck = safetyCheck;
      _progress = 0;
      _error = null;
      _uploadedURL = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final source = Uri.file(file.path);
      final XmaxUploadedFile uploaded;
      if (_isImage && safetyCheck) {
        uploaded = await _storageManager.uploadImageWithSafetyCheck(
          at: source,
          progress: _onProgress,
        );
      } else if (_isImage) {
        uploaded = await _storageManager.uploadImage(
          at: source,
          progress: _onProgress,
        );
      } else {
        uploaded = await _storageManager.uploadVideo(
          at: source,
          progress: _onProgress,
        );
      }
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _uploadedURL = uploaded.url;
          _elapsed = stopwatch.elapsed;
          _progress = 1;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is XmaxError ? error.message : error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onProgress(XmaxStorageProgress progress) {
    if (mounted) setState(() => _progress = progress.fractionCompleted);
  }

  Future<void> _copyURL() async {
    final url = _uploadedURL;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地址已复制')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: XLabBackground(
        accent: XLabPalette.orange,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: XLabTopBar(
                  title: '存储服务',
                  accent: XLabPalette.orange,
                  version: XmaxSDKInfo.version,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: <Widget>[
                    _overview(),
                    const SizedBox(height: 14),
                    _fileCard(),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x29FF5F68),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0x38FF6B72)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFFB5B5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    if (_uploadedURL != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _resultCard(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview() => XLabCard(
    accent: XLabPalette.orange,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.circle, color: XLabPalette.orange, size: 7),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'STORAGE PIPELINE',
                style: TextStyle(
                  color: XLabPalette.orange,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            XLabPill('READY', color: XLabPalette.orange),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '把本地媒体交给 XmaxSDK',
          style: TextStyle(
            color: Color(0xFFF4EEE6),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          '选择图片或视频，上传后获取可直接使用的远程地址。',
          style: TextStyle(color: Color(0xFF8E8377), fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 15),
        const Row(
          children: <Widget>[
            Text(
              'LOCAL FILE',
              style: TextStyle(
                color: Color(0xFF9A8B7A),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—', style: TextStyle(color: Color(0xFF66513A))),
            ),
            Text(
              'XMAX SDK',
              style: TextStyle(
                color: XLabPalette.orange,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—', style: TextStyle(color: Color(0xFF66513A))),
            ),
            Text(
              'REMOTE URL',
              style: TextStyle(
                color: Color(0xFF9A8B7A),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _fileCard() => XLabCard(
    accent: XLabPalette.orange,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '选择本地文件',
          style: TextStyle(
            color: XLabPalette.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _uploading ? null : _pick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 176,
            decoration: BoxDecoration(
              color: const Color(0x8F0B0C0F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: XLabPalette.orange.withValues(alpha: 0.18),
              ),
            ),
            child: _file == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: XLabPalette.orange,
                        size: 38,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '点击选择图片或视频',
                        style: TextStyle(
                          color: Color(0xFFD6C5B2),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          _isImage
                              ? Icons.image_outlined
                              : Icons.movie_outlined,
                          color: XLabPalette.orange,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _file!.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE8DDD0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_isImage ? '图片' : '视频'} · ${_formatBytes(_fileBytes)}',
                          style: const TextStyle(
                            color: Color(0xFF817363),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (_file != null) ...<Widget>[
          const SizedBox(height: 14),
          if (_uploading) ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${(_progress * 100).round()}%',
                  style: const TextStyle(
                    color: XLabPalette.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _safetyCheck ? '安全检测上传' : '普通上传',
                  style: const TextStyle(color: Color(0xFF657386), fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress,
              color: XLabPalette.orange,
              backgroundColor: const Color(0x24F5B86C),
              minHeight: 5,
            ),
          ] else if (_isImage)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _upload(safetyCheck: true),
                    child: const Text('安全检测上传'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _upload(safetyCheck: false),
                    child: const Text('普通上传'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _upload(safetyCheck: false),
                child: const Text('上传并获取地址'),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _uploading ? null : _pick,
              child: const Text('重新选择'),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _resultCard() => XLabCard(
    accent: XLabPalette.orange,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, color: XLabPalette.orange),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '上传完成',
                style: TextStyle(
                  color: Color(0xFFF4EEE6),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_elapsed?.inMilliseconds ?? 0} ms',
              style: const TextStyle(
                color: XLabPalette.orange,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x950B0C0F),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            _uploadedURL.toString(),
            style: const TextStyle(color: Color(0xFFCDBEAF), fontSize: 10),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _copyURL,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('复制地址'),
          ),
        ),
      ],
    ),
  );

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
