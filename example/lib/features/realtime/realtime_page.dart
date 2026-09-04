import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

import 'realtime_control_panel.dart';
import 'realtime_camera_switch_transition.dart';
import 'realtime_loading_overlay.dart';
import 'realtime_local_input.dart';
import 'xlab_trajectory_renderer.dart';

/// Resolves the initial generation mode from the media input only.
///
/// Rendering customization is intentionally excluded: changing the trajectory
/// appearance must not change the camera workflow or generation condition.
XLabRealtimePanelMode initialRealtimePanelMode({
  required XLabRealtimeLocalInput? localInput,
}) => localInput is XLabRealtimeImageInput
    ? XLabRealtimePanelMode.touch
    : XLabRealtimePanelMode.character;

class RealtimePage extends StatefulWidget {
  const RealtimePage({
    required this.apiKey,
    this.customTrajectory = false,
    this.localInput,
    super.key,
  });

  final String apiKey;
  final bool customTrajectory;
  final XLabRealtimeLocalInput? localInput;

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage>
    with WidgetsBindingObserver {
  static const _cameraFormat = RealtimeVideoFormat(
    width: 832,
    height: 1472,
    fps: 24,
  );

  late XmaxRealtimeManaging _manager;
  late XmaxStorageManaging _storageManager;
  final _promptController = TextEditingController();
  final _referencesByCategory = <String, List<XLabRealtimeReference>>{
    for (final mode in XLabRealtimePanelMode.values)
      if (mode.usesReferences) mode.id: <XLabRealtimeReference>[],
  };
  RealtimeMediaStream? _localStream;
  RealtimeMediaStream? _remoteStream;
  RealtimeState _state = const RealtimeState(
    connectionState: RealtimeConnectionState.idle,
  );
  XmaxError? _lastError;
  late XLabRealtimePanelMode _panelMode;
  XLabRealtimeReference? _selectedReference;
  XLabRealtimeReference? _promptReference;
  bool _cameraReady = false;
  bool _busy = false;
  bool _isSwitchingCamera = false;
  bool _isCameraSwitchWaitingForGeneration = false;
  bool _isLoading = true;
  bool _isSuspendedForBackground = false;
  bool _isResumingFromBackground = false;
  Future<void> _backgroundCleanup = Future<void>.value();
  Animation<double>? _routeAnimation;
  bool _hasScheduledInitialCameraStart = false;
  int _realtimeOperationVersion = 0;
  final _referenceUploadTokens = <String, Object>{};
  late final XLabTrajectoryRenderer? _customRenderer = widget.customTrajectory
      ? XLabTrajectoryRenderer()
      : null;

  @override
  void initState() {
    super.initState();
    _panelMode = initialRealtimePanelMode(localInput: widget.localInput);
    if (widget.localInput != null) {
      _isLoading = false;
    }
    _promptController.addListener(_promptDidChange);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadReferences());
    _configureManager();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) {
      return;
    }

    _routeAnimation?.removeStatusListener(_routeAnimationDidChange);
    _routeAnimation = animation;
    animation?.addStatusListener(_routeAnimationDidChange);

    if (animation == null || animation.status == AnimationStatus.completed) {
      _scheduleInitialCameraStart();
    }
  }

  void _routeAnimationDidChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleInitialCameraStart();
    }
  }

  void _scheduleInitialCameraStart() {
    if (_hasScheduledInitialCameraStart || widget.localInput != null) {
      return;
    }

    _hasScheduledInitialCameraStart = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startCamera());
      }
    });
  }

  Future<void> _loadReferences() async {
    final references = await loadXLabRealtimeReferences();
    if (!mounted) return;
    setState(() {
      for (final reference in references) {
        _referencesByCategory
            .putIfAbsent(reference.categoryID, () => <XLabRealtimeReference>[])
            .add(reference);
      }
    });
  }

  void _configureManager() {
    final client = XmaxClient(
      configuration: XmaxConfiguration(
        apiKey: widget.apiKey,
        loggerOptions: XmaxLoggerOption.all,
      ),
    );
    _storageManager = client.createStorageManager();
    _manager = client.createRealtimeManager(
      options: const RealtimeConfiguration(model: RealtimeModel.x2_0),
    );
    _manager.setStateListener((state) {
      if (!mounted || _isSuspendedForBackground) return;
      setState(() {
        _state = state;
        if (_isCameraSwitchWaitingForGeneration &&
            state.connectionState == RealtimeConnectionState.generating) {
          _isCameraSwitchWaitingForGeneration = false;
          _isSwitchingCamera = false;
          _isLoading = false;
        }
        if (state.connectionState == RealtimeConnectionState.connected &&
            state.taskID == null) {
          _lastError = null;
        }
      });
    });
    _manager.setErrorListener((error) {
      if (!mounted || _isSuspendedForBackground) return;
      setState(() => _lastError = error);
    });
    _manager.setCameraPreviewReadyListener(() {
      if (mounted && !_isSuspendedForBackground) {
        setState(() {
          _cameraReady = true;
          _isLoading = false;
        });
      }
    });
    _manager.setPerformanceAlarmListener((alarm) {
      if (mounted &&
          !_isSuspendedForBackground &&
          alarm.status == RealtimePerformanceStatus.limited) {
        setState(() {
          _lastError = const XmaxError(
            code: XmaxErrorCode.mediaError,
            message: '设备性能受限，实时画质可能下降',
          );
        });
      }
    });
  }

  Future<void> _startCamera() async {
    if (_isSuspendedForBackground || _busy || _localStream != null) return;

    final operation = ++_realtimeOperationVersion;
    setState(() {
      _busy = true;
      _cameraReady = false;
      _isLoading = true;
      _lastError = null;
    });
    try {
      final stream = await _manager.createLocalCameraStream(
        videoFormat: _cameraFormat,
      );
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() => _localStream = stream);
      }
    } catch (error) {
      if (_isCurrentRealtimeOperation(operation)) {
        _showError(error);
        setState(() => _isLoading = false);
      }
    } finally {
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startGeneration(RealtimeContext context) async {
    final localStream = _localStream;
    if (localStream == null) return;

    final connectionState = _state.connectionState;
    final isConditionUpdate =
        connectionState == RealtimeConnectionState.generating;

    // Only the newest UI operation may publish async results back to XLab.
    final operation = ++_realtimeOperationVersion;
    setState(() {
      _busy = true;
      // A change_condition keeps rendering the current remote stream. Loading
      // is reserved for the initial connection/generation transition.
      _isLoading = !isConditionUpdate;
      _lastError = null;
    });
    try {
      final hasOpenConnection =
          connectionState == RealtimeConnectionState.connected ||
          connectionState == RealtimeConnectionState.generating;
      final remote = await _manager.startGeneration(
        localStream: hasOpenConnection ? null : localStream,
        context: context,
      );

      if (!_isCurrentRealtimeOperation(operation)) return;
      setState(() {
        if (remote != null) _remoteStream = remote;
        _isLoading = false;
      });
    } catch (error) {
      if (_isCurrentRealtimeOperation(operation)) {
        _showError(error);
        setState(() => _isLoading = false);
      }
    } finally {
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stopGeneration() async {
    final connectionState = _state.connectionState;
    final canStop =
        _busy ||
        connectionState == RealtimeConnectionState.connecting ||
        connectionState == RealtimeConnectionState.connected ||
        connectionState == RealtimeConnectionState.generating;
    if (!canStop) {
      return;
    }

    final operation = ++_realtimeOperationVersion;
    setState(() {
      _busy = true;
      _isLoading = !_cameraReady;
    });
    try {
      await _manager.disconnect();
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() {
          _remoteStream = null;
          _selectedReference = null;
          _isLoading = !_cameraReady;
        });
      }
    } catch (error) {
      if (_isCurrentRealtimeOperation(operation)) {
        _showError(error);
        setState(() => _isLoading = !_cameraReady);
      }
    } finally {
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() => _busy = false);
      }
    }
  }

  void _selectMode(XLabRealtimePanelMode mode) {
    if (_panelMode == mode) return;
    setState(() => _panelMode = mode);
  }

  Future<void> _selectReference(XLabRealtimeReference reference) async {
    final isCancellingSelection = _selectedReference?.id == reference.id;
    if (isCancellingSelection) {
      setState(() => _selectedReference = null);
      await _stopGeneration();
      return;
    }

    setState(() => _selectedReference = reference);

    switch (reference.uploadState) {
      case XLabRealtimeReferenceUploadState.uploading:
        return;
      case XLabRealtimeReferenceUploadState.failed:
        await _uploadReference(reference);
        return;
      case XLabRealtimeReferenceUploadState.ready:
        break;
    }

    final referencePath = reference.referencePath;
    if (referencePath == null) return;

    await _startGeneration(
      RealtimeContext(prompt: _panelMode.prompt, referencePath: referencePath),
    );
  }

  Future<void> _startTouchGeneration() => _startGeneration(
    RealtimeContext(prompt: XLabRealtimePanelMode.touch.prompt),
  );

  Future<void> _submitPrompt() async {
    final prompt = _promptController.text.trim();
    final promptReference = _promptReference;
    if (prompt.isEmpty ||
        (promptReference != null && !promptReference.isReady)) {
      return;
    }

    await _startGeneration(
      RealtimeContext(
        prompt: prompt,
        referencePath: promptReference?.referencePath,
      ),
    );
  }

  Future<void> _pickReference({required bool forPrompt}) async {
    if (_busy) return;

    if (forPrompt && _handlePromptReferenceAction()) return;

    const images = XTypeGroup(
      label: '参考图',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      uniformTypeIdentifiers: <String>['public.image'],
      mimeTypes: <String>['image/*'],
    );
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[images],
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final reference = XLabRealtimeReference(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        categoryID: forPrompt ? XLabRealtimePanelMode.free.id : _panelMode.id,
        title: file.name,
        referencePath: null,
        iconBytes: bytes,
        sourceURL: Uri.file(file.path),
        uploadState: XLabRealtimeReferenceUploadState.uploading,
      );

      // Match iOS: show and select the local image before COS upload begins.
      setState(() {
        _lastError = null;
        if (forPrompt) {
          _promptReference = reference;
        } else {
          _referencesByCategory
              .putIfAbsent(
                reference.categoryID,
                () => <XLabRealtimeReference>[],
              )
              .insert(0, reference);
          _selectedReference = reference;
        }
      });

      await _uploadReference(reference);
    } catch (error) {
      _showError(error);
    }
  }

  bool _handlePromptReferenceAction() {
    final reference = _promptReference;
    if (reference == null) return false;

    switch (reference.uploadState) {
      case XLabRealtimeReferenceUploadState.uploading:
        return true;
      case XLabRealtimeReferenceUploadState.failed:
        unawaited(_uploadReference(reference));
        return true;
      case XLabRealtimeReferenceUploadState.ready:
        _referenceUploadTokens.remove(reference.id);
        setState(() => _promptReference = null);
    }

    return true;
  }

  Future<void> _uploadReference(XLabRealtimeReference reference) async {
    final sourceURL = reference.sourceURL;
    if (sourceURL == null) return;

    // A token makes late COS results harmless after retry, removal, or dispose.
    final token = Object();
    _referenceUploadTokens[reference.id] = token;
    setState(() {
      reference.referencePath = null;
      reference.uploadState = XLabRealtimeReferenceUploadState.uploading;
      _lastError = null;
    });

    try {
      final uploaded = await _storageManager.uploadImage(at: sourceURL);
      if (!mounted || _referenceUploadTokens[reference.id] != token) return;

      _referenceUploadTokens.remove(reference.id);
      setState(() {
        reference.referencePath = uploaded.url.toString();
        reference.uploadState = XLabRealtimeReferenceUploadState.ready;
      });

      // Prompt references wait for the submit button. Category references
      // generate immediately when the uploaded item is still selected.
      if (identical(reference, _promptReference) ||
          _selectedReference?.id != reference.id ||
          _panelMode.id != reference.categoryID) {
        return;
      }

      await _startGeneration(
        RealtimeContext(
          prompt: XLabRealtimePanelMode.values
              .firstWhere((mode) => mode.id == reference.categoryID)
              .prompt,
          referencePath: reference.referencePath,
        ),
      );
    } catch (error) {
      if (!mounted || _referenceUploadTokens[reference.id] != token) return;

      _referenceUploadTokens.remove(reference.id);
      setState(() {
        reference.uploadState = XLabRealtimeReferenceUploadState.failed;
      });
      _showError(error);
    }
  }

  Future<void> _switchCamera() async {
    if (_busy || _localStream == null) return;

    final operation = ++_realtimeOperationVersion;
    final wasGenerating =
        _state.connectionState == RealtimeConnectionState.generating;
    setState(() {
      _busy = true;
      _isSwitchingCamera = true;
      _isCameraSwitchWaitingForGeneration = wasGenerating;
      if (wasGenerating) {
        _isLoading = true;
      }
    });
    try {
      final stream = await _manager.switchCamera();
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() => _localStream = stream);
      }
    } catch (error) {
      if (_isCurrentRealtimeOperation(operation)) {
        _showError(error);
        setState(() {
          _isCameraSwitchWaitingForGeneration = false;
          _isLoading = !_cameraReady;
        });
      }
    } finally {
      if (_isCurrentRealtimeOperation(operation)) {
        setState(() {
          _busy = false;
          _isSwitchingCamera = false;
        });
      }
    }
  }

  bool _isCurrentRealtimeOperation(int operation) =>
      mounted && operation == _realtimeOperationVersion;

  void _showError(Object error) {
    final xmaxError = XmaxError.from(error);
    if (mounted) setState(() => _lastError = xmaxError);
  }

  void _promptDidChange() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_suspendForBackground());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeAfterBackgroundIfNeeded());
    }
  }

  Future<void> _suspendForBackground() async {
    if (_isSuspendedForBackground) return;

    _isSuspendedForBackground = true;
    _isResumingFromBackground = false;
    _realtimeOperationVersion += 1;
    FocusManager.instance.primaryFocus?.unfocus();

    // Match iOS XLab: clear the active realtime session immediately while
    // preserving the reference catalog, prompt reference, and COS uploads.
    if (mounted) {
      setState(() {
        _localStream = null;
        _remoteStream = null;
        _state = const RealtimeState(
          connectionState: RealtimeConnectionState.idle,
        );
        _selectedReference = null;
        _cameraReady = false;
        _busy = false;
        _isSwitchingCamera = false;
        _isCameraSwitchWaitingForGeneration = false;
        _isLoading = false;
        _lastError = null;
      });
    }

    final cleanup = _closeRealtimeForBackground();
    _backgroundCleanup = cleanup;
    await cleanup;
  }

  Future<void> _closeRealtimeForBackground() async {
    try {
      await _manager.close();
    } catch (_) {
      // Background cleanup must not surface a stale error after the next
      // foreground session starts.
    }
  }

  Future<void> _resumeAfterBackgroundIfNeeded() async {
    if (!_isSuspendedForBackground || _isResumingFromBackground) return;

    _isResumingFromBackground = true;
    if (mounted && widget.localInput == null) {
      setState(() => _isLoading = true);
    }

    await _backgroundCleanup;
    final isActive =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!mounted || !_isSuspendedForBackground || !isActive) {
      _isResumingFromBackground = false;
      return;
    }

    _isSuspendedForBackground = false;
    _isResumingFromBackground = false;

    if (widget.localInput == null) {
      await _startCamera();
    } else {
      // File input is already retained by the page and can be displayed again
      // without reopening the camera.
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _realtimeOperationVersion += 1;
    _routeAnimation?.removeStatusListener(_routeAnimationDidChange);
    WidgetsBinding.instance.removeObserver(this);
    _manager.setStateListener(null);
    _manager.setErrorListener(null);
    _manager.setCameraPreviewReadyListener(null);
    _manager.setPerformanceAlarmListener(null);
    unawaited(_manager.close());
    _promptController.removeListener(_promptDidChange);
    _promptController.dispose();
    _customRenderer?.dispose();
    _referenceUploadTokens.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generating =
        _state.connectionState == RealtimeConnectionState.generating;
    final localImage = switch (widget.localInput) {
      XLabRealtimeImageInput input => input,
      _ => null,
    };
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF101010),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: <double>[0, 0.48, 1],
                          colors: <Color>[
                            Color(0xFF171719),
                            Color(0xFF0D0D0F),
                            Color(0xFF050506),
                          ],
                        ),
                      ),
                    ),
                    if (_localStream == null && localImage != null)
                      Image.file(
                        File(localImage.path),
                        key: const ValueKey<String>(
                          'realtime-local-image-preview',
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0x55FFFFFF),
                            size: 44,
                          ),
                        ),
                      ),
                    RealtimeCameraSwitchTransition(
                      active: _isSwitchingCamera,
                      child: XmaxRealtimeVideoView(
                        localTrack: _localStream?.videoTrack,
                        remoteTrack: _remoteStream?.videoTrack,
                        videoContentMode: VideoContentMode.fill,
                        trajectoryRenderer: _customRenderer,
                      ),
                    ),
                    if (_localStream?.videoTrack == null && localImage == null)
                      const Center(
                        child: Icon(
                          Icons.videocam_off_outlined,
                          color: Color(0x55FFFFFF),
                          size: 44,
                        ),
                      ),
                    RealtimeLoadingOverlay(isLoading: _isLoading),
                  ],
                ),
              ),
              XLabRealtimeControlPanel(
                mode: _panelMode,
                generating: generating,
                busy: _busy,
                enabled: _cameraReady,
                promptController: _promptController,
                referencesByCategory: _referencesByCategory,
                selectedReference: _selectedReference,
                promptReference: _promptReference,
                onModeChanged: _selectMode,
                onStop: () => unawaited(_stopGeneration()),
                onReferenceChanged: (reference) =>
                    unawaited(_selectReference(reference)),
                onAddReference: () =>
                    unawaited(_pickReference(forPrompt: false)),
                onTouchStart: () => unawaited(_startTouchGeneration()),
                onPromptSubmit: () => unawaited(_submitPrompt()),
                onPromptReference: () =>
                    unawaited(_pickReference(forPrompt: true)),
              ),
            ],
          ),
          SafeArea(
            bottom: false,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 12,
                  top: 8,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      tooltip: '返回首页',
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.localInput == null)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: _CameraActionButton(
                      enabled: !_busy && _localStream != null,
                      onPressed: _switchCamera,
                    ),
                  ),
              ],
            ),
          ),
          if (_lastError != null)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(64, 64, 64, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xD9251719),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x55FF6B72)),
                  ),
                  child: Text(
                    _lastError!.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFB5B5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _CameraActionButton extends StatelessWidget {
  const _CameraActionButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    height: 62,
    child: InkResponse(
      onTap: enabled ? onPressed : null,
      radius: 29,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: const Column(
          children: <Widget>[
            SizedBox(height: 9),
            Icon(
              Icons.sync_rounded,
              color: Colors.white,
              size: 22,
              shadows: <Shadow>[
                Shadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            SizedBox(height: 5),
            Text(
              '翻转',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
