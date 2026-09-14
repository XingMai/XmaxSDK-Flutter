import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

import '../../localization/xlab_localization.dart';
import '../../ui/xlab_theme.dart';

const _orange = XLabPalette.orange;

class StoragePage extends StatefulWidget {
  const StoragePage({
    required this.apiKey,
    this.environment = XmaxEnvironment.china,
    super.key,
  });

  final String apiKey;
  final XmaxEnvironment environment;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  late final XmaxStorageManaging _storageManager = XmaxClient(
    configuration: XmaxConfiguration(
      apiKey: widget.apiKey,
      environment: widget.environment,
    ),
  ).createStorageManager();
  final _scrollController = ScrollController();

  XFile? _file;
  VideoPlayerController? _videoController;
  int _selectionVersion = 0;
  bool _isImage = true;
  bool _picking = false;
  bool _uploading = false;
  bool _safetyCheck = false;
  double _progress = 0;
  int _fileBytes = 0;
  String _resolution = '--';
  Uri? _uploadedURL;
  String? _error;
  Duration? _elapsed;

  Future<void> _pick() async {
    if (_picking || _uploading) return;

    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickMedia(requestFullMetadata: false);
      if (file == null || !mounted) return;

      final extension = file.name.split('.').last.toLowerCase();
      final isImage =
          file.mimeType?.startsWith('image/') ??
          <String>{
            'jpg',
            'jpeg',
            'png',
            'webp',
            'gif',
            'heic',
            'heif',
            'avif',
            'bmp',
            'tif',
            'tiff',
          }.contains(extension);
      final selectionVersion = ++_selectionVersion;

      if (isImage) {
        await _selectImage(file, selectionVersion: selectionVersion);
      } else {
        await _selectVideo(file, selectionVersion: selectionVersion);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = XLabLocalization.shared.text('storage.file.error'),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _selectImage(XFile file, {required int selectionVersion}) async {
    final previousVideoController = _videoController;

    // Render from the local file immediately. Metadata can arrive later.
    setState(() {
      _file = file;
      _videoController = null;
      _isImage = true;
      _picking = false;
      _fileBytes = 0;
      _resolution = '--';
      _progress = 0;
      _uploadedURL = null;
      _elapsed = null;
      _error = null;
    });
    await previousVideoController?.dispose();

    try {
      final fileBytesFuture = file.length();
      final resolution = await _imageResolution(file.path);
      final fileBytes = await fileBytesFuture;
      if (!mounted || selectionVersion != _selectionVersion) return;

      setState(() {
        _fileBytes = fileBytes;
        _resolution = resolution;
      });
    } catch (_) {
      // Preview loading reports its own error; metadata is non-blocking.
    }
  }

  Future<void> _selectVideo(XFile file, {required int selectionVersion}) async {
    final previousVideoController = _videoController;
    setState(() {
      _file = file;
      _videoController = null;
      _isImage = false;
      _picking = true;
      _fileBytes = 0;
      _resolution = '--';
      _progress = 0;
      _uploadedURL = null;
      _elapsed = null;
      _error = null;
    });
    await previousVideoController?.dispose();

    final controller = VideoPlayerController.file(
      File(file.path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      final fileBytesFuture = file.length();
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      final fileBytes = await fileBytesFuture;

      if (!mounted || selectionVersion != _selectionVersion) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _picking = false;
        _fileBytes = fileBytes;
        _resolution = _formatResolution(controller.value.size);
      });
    } catch (_) {
      await controller.dispose();
      if (mounted && selectionVersion == _selectionVersion) {
        setState(() {
          _picking = false;
          _error = XLabLocalization.shared.text('storage.video.error');
        });
      }
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
      if (!mounted) return;

      setState(() {
        _uploadedURL = uploaded.url;
        _elapsed = stopwatch.elapsed;
        _progress = 1;
      });
      _scrollToResult();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is XmaxError
              ? error.message
              : XLabLocalization.shared.text('storage.upload.error');
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onProgress(XmaxStorageProgress progress) {
    if (mounted) setState(() => _progress = progress.fractionCompleted);
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<void> _copyURL() async {
    final url = _uploadedURL;
    if (url == null) return;

    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(XLabLocalization.shared.text('storage.copied'))),
      );
    }
  }

  @override
  void dispose() {
    _selectionVersion += 1;
    _scrollController.dispose();
    unawaited(_videoController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      body: XLabBackground(
        accent: _orange,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: XLabTopBar(
                  title: XLabLocalization.shared.text('feed.storage.title'),
                  accent: _orange,
                  version: XmaxSDKInfo.version,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: <Widget>[
                    _overview(),
                    const SizedBox(height: 14),
                    _fileCard(),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _errorView(),
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
    accent: _orange,
    padding: const EdgeInsets.all(17),
    gradient: const LinearGradient(
      colors: <Color>[Color(0xF01D1711), Color(0xE80F1115)],
    ),
    borderColor: _orange.withValues(alpha: 0.24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.circle, color: _orange, size: 6),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                XLabLocalization.shared.text('storage.pipeline'),
                style: const TextStyle(
                  color: _orange,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            XLabPill(
              XLabLocalization.shared.text('feed.ready'),
              color: _orange,
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          XLabLocalization.shared.text('storage.hero.title'),
          style: const TextStyle(
            color: Color(0xFFF4EEE6),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          XLabLocalization.shared.text('storage.hero.subtitle'),
          style: const TextStyle(
            color: Color(0xFF8E8377),
            fontSize: 10,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 15),
        const _PipelineLabels(),
      ],
    ),
  );

  Widget _fileCard() => XLabCard(
    accent: _orange,
    padding: const EdgeInsets.all(17),
    gradient: const LinearGradient(
      colors: <Color>[Color(0xED1B1712), Color(0xE8111216)],
    ),
    borderColor: _orange.withValues(alpha: 0.18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _StepPill('01'),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                XLabLocalization.shared.text('storage.preview'),
                style: const TextStyle(
                  color: Color(0xFFF2ECE4),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_file != null)
              _CompactOutlineButton(
                label: XLabLocalization.shared.text('storage.reselect'),
                enabled: !_picking && !_uploading,
                onPressed: _pick,
              ),
          ],
        ),
        if (_file != null && !_isImage) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            XLabLocalization.shared.text('storage.safety.unsupported'),
            style: const TextStyle(color: Color(0xFF596678), fontSize: 9),
          ),
        ],
        const SizedBox(height: 10),
        _preview(),
        if (_file != null) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetadataTile(
                  label: XLabLocalization.shared.text('storage.type'),
                  value: _mediaTitle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetadataTile(
                  label: XLabLocalization.shared.text('storage.resolution'),
                  value: _resolution,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetadataTile(
                  label: XLabLocalization.shared.text('storage.size'),
                  value: _fileBytes == 0 ? '--' : _formatBytes(_fileBytes),
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_uploading) _uploadProgress() else _uploadActions(),
        ],
      ],
    ),
  );

  Widget _preview() => GestureDetector(
    key: const ValueKey<String>('storage-media-preview'),
    behavior: HitTestBehavior.opaque,
    onTap: _file == null && !_picking && !_uploading ? _pick : null,
    child: Container(
      width: double.infinity,
      height: 176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x8F0B0C0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withValues(alpha: 0.15)),
      ),
      child: switch ((_file, _isImage)) {
        (null, _) => const _EmptyPickerContent(),
        (final file?, true) => Image.file(
          File(file.path),
          key: const ValueKey<String>('storage-image-preview'),
          fit: BoxFit.contain,
          cacheWidth:
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, synchronouslyLoaded) {
            if (synchronouslyLoaded || frame != null) return child;
            return const Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _orange,
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) =>
              const _PreviewErrorIcon(icon: Icons.image_outlined),
        ),
        (_, false) =>
          _videoController == null
              ? _picking
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _orange,
                          ),
                        ),
                      )
                    : const _PreviewErrorIcon(icon: Icons.movie_outlined)
              : _LocalVideoPreview(controller: _videoController!),
      },
    ),
  );

  Widget _uploadProgress() => Column(
    children: <Widget>[
      Row(
        children: <Widget>[
          Text(
            XLabLocalization.shared.formatCount(
              'storage.upload.progress',
              (_progress * 100).round(),
            ),
            style: const TextStyle(
              color: _orange,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _uploadMode,
            style: const TextStyle(color: Color(0xFF657386), fontSize: 9),
          ),
        ],
      ),
      const SizedBox(height: 7),
      LinearProgressIndicator(
        value: _progress,
        color: _orange,
        backgroundColor: _orange.withValues(alpha: 0.14),
        minHeight: 5,
        borderRadius: BorderRadius.circular(3),
      ),
    ],
  );

  Widget _uploadActions() {
    if (_isImage) {
      return Row(
        children: <Widget>[
          Expanded(
            child: _StorageOutlineButton(
              label: XLabLocalization.shared.text('storage.upload.safe'),
              onPressed: () => _upload(safetyCheck: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StorageOutlineButton(
              label: XLabLocalization.shared.text('storage.upload.normal'),
              onPressed: () => _upload(safetyCheck: false),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: _StorageOutlineButton(
        label: XLabLocalization.shared.text('storage.upload.getURL'),
        onPressed: () => _upload(safetyCheck: false),
      ),
    );
  }

  Widget _errorView() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0x29FF5F68),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0x38FF6B72)),
    ),
    child: Text(
      _error!,
      style: const TextStyle(
        color: Color(0xFFFFB5B5),
        fontSize: 10,
        height: 1.6,
      ),
    ),
  );

  Widget _resultCard() => XLabCard(
    accent: _orange,
    padding: const EdgeInsets.all(17),
    gradient: const LinearGradient(
      colors: <Color>[Color(0xED1B1712), Color(0xE8111216)],
    ),
    borderColor: _orange.withValues(alpha: 0.35),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _StepPill('02'),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                XLabLocalization.shared.text('storage.result'),
                style: const TextStyle(
                  color: Color(0xFFF2ECE4),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const _SuccessPill(),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: <Widget>[
            Text(
              XLabLocalization.shared.text('storage.elapsed'),
              style: const TextStyle(color: Color(0xFF718095), fontSize: 11),
            ),
            const Spacer(),
            Text(
              _formatElapsed(_elapsed),
              style: const TextStyle(
                color: _orange,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          XLabLocalization.shared.text('storage.remoteURL'),
          style: const TextStyle(
            color: Color(0xFF667589),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x940B0C0F),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _orange.withValues(alpha: 0.13)),
          ),
          child: Text(
            _uploadedURL.toString(),
            style: const TextStyle(
              color: Color(0xFFCDBEAF),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _StorageOutlineButton(
            label: XLabLocalization.shared.text('storage.copy'),
            onPressed: _copyURL,
          ),
        ),
      ],
    ),
  );

  String get _mediaTitle =>
      XLabLocalization.shared.text(_isImage ? 'media.image' : 'media.video');

  String get _uploadMode {
    if (!_isImage) return XLabLocalization.shared.text('storage.upload.video');
    if (_safetyCheck) {
      return XLabLocalization.shared.text('storage.upload.safety');
    }
    return XLabLocalization.shared.text('storage.upload.image');
  }

  static Future<String> _imageResolution(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return '${descriptor.width} × ${descriptor.height}';
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  static String _formatResolution(Size size) {
    if (size.isEmpty) return '--';
    return '${size.width.round()} × ${size.height.round()}';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  static String _formatElapsed(Duration? elapsed) {
    if (elapsed == null) return '0 ms';
    if (elapsed.inMilliseconds < 1000) return '${elapsed.inMilliseconds} ms';
    return '${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s';
  }
}

final class _PipelineLabels extends StatelessWidget {
  const _PipelineLabels();

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text(
        XLabLocalization.shared.text('storage.localFile'),
        style: const TextStyle(
          color: Color(0xFF9A8B7A),
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('—', style: TextStyle(color: Color(0xFF66513A))),
      ),
      const Text(
        'XMAX SDK',
        style: TextStyle(
          color: _orange,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('—', style: TextStyle(color: Color(0xFF66513A))),
      ),
      Text(
        XLabLocalization.shared.text('storage.remoteURL'),
        style: const TextStyle(
          color: Color(0xFF9A8B7A),
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

final class _EmptyPickerContent extends StatelessWidget {
  const _EmptyPickerContent();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const _PickerPlus(),
      const SizedBox(height: 11),
      Text(
        XLabLocalization.shared.text('storage.select.hint'),
        style: const TextStyle(
          color: Color(0xFF9D9185),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        XLabLocalization.shared.text('storage.mediaTypes'),
        style: const TextStyle(
          color: Color(0xFF62584E),
          fontSize: 9,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

final class _PickerPlus extends StatelessWidget {
  const _PickerPlus();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _orange.withValues(alpha: 0.09),
      border: Border.all(color: _orange.withValues(alpha: 0.24)),
    ),
    child: const Icon(Icons.add, color: _orange, size: 22),
  );
}

final class _LocalVideoPreview extends StatelessWidget {
  const _LocalVideoPreview({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      key: const ValueKey<String>('storage-video-preview'),
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    ),
  );
}

final class _PreviewErrorIcon extends StatelessWidget {
  const _PreviewErrorIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(icon, color: _orange.withValues(alpha: 0.6), size: 42),
  );
}

final class _MetadataTile extends StatelessWidget {
  const _MetadataTile({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    height: 51,
    padding: const EdgeInsets.only(left: 11, right: 6),
    decoration: BoxDecoration(
      color: const Color(0x8A0C0D10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6E6257), fontSize: 9),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: const Color(0xFFB9AA9B),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

final class _StepPill extends StatelessWidget {
  const _StepPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _orange.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _orange.withValues(alpha: 0.27)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _orange,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

final class _SuccessPill extends StatelessWidget {
  const _SuccessPill();

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _orange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _orange.withValues(alpha: 0.28)),
    ),
    child: Text(
      XLabLocalization.shared.text('storage.success'),
      style: const TextStyle(
        color: _orange,
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

final class _CompactOutlineButton extends StatelessWidget {
  const _CompactOutlineButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.6,
    child: SizedBox(
      height: 22,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: _orange,
          backgroundColor: _orange.withValues(alpha: 0.08),
          disabledForegroundColor: _orange,
          disabledBackgroundColor: _orange.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
            side: BorderSide(color: _orange.withValues(alpha: 0.28)),
          ),
          textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    ),
  );
}

final class _StorageOutlineButton extends StatelessWidget {
  const _StorageOutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _orange,
        backgroundColor: _orange.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _orange.withValues(alpha: 0.28)),
        ),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}
