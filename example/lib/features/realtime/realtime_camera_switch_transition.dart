import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Runs a fixed camera-switch blur and flip independently of network work.
final class RealtimeCameraSwitchTransition extends StatefulWidget {
  const RealtimeCameraSwitchTransition({
    required this.active,
    required this.child,
    super.key,
  });

  static const blurDuration = Duration(milliseconds: 140);
  static const flipDuration = Duration(milliseconds: 500);
  static const fadeDuration = Duration(milliseconds: 180);

  final bool active;
  final Widget child;

  @override
  State<RealtimeCameraSwitchTransition> createState() =>
      _RealtimeCameraSwitchTransitionState();
}

final class _RealtimeCameraSwitchTransitionState
    extends State<RealtimeCameraSwitchTransition>
    with TickerProviderStateMixin {
  late final AnimationController _transitionController = AnimationController(
    vsync: this,
    duration:
        RealtimeCameraSwitchTransition.blurDuration +
        RealtimeCameraSwitchTransition.flipDuration,
  )..addStatusListener(_transitionStatusDidChange);
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: RealtimeCameraSwitchTransition.fadeDuration,
  );
  late final Listenable _animation = Listenable.merge(<Listenable>[
    _transitionController,
    _fadeController,
  ]);

  bool _isVisible = false;
  bool _hasCompletedFlip = false;
  int _transitionVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _beginTransition();
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeCameraSwitchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;

    if (widget.active) {
      _beginTransition();
    }
  }

  @override
  void dispose() {
    _transitionVersion += 1;
    _transitionController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _beginTransition() {
    _transitionVersion += 1;
    _transitionController
      ..stop()
      ..value = 0;
    _fadeController
      ..stop()
      ..value = 0;

    setState(() {
      _isVisible = true;
      _hasCompletedFlip = false;
    });
    _transitionController.forward();
  }

  void _transitionStatusDidChange(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;

    // A 180-degree transform is visually equivalent after the camera has
    // changed, so return to identity without animating the reset.
    setState(() => _hasCompletedFlip = true);
    unawaited(_finishTransition(_transitionVersion));
  }

  Future<void> _finishTransition(int version) async {
    if (!_isCurrent(version) || !_hasCompletedFlip) return;

    try {
      await _fadeController.forward(from: 0).orCancel;
      if (!_isCurrent(version)) return;

      setState(() {
        _isVisible = false;
        _hasCompletedFlip = false;
      });
      _transitionController.value = 0;
      _fadeController.value = 0;
    } on TickerCanceled {
      // A new transition or disposal owns the controllers now.
    }
  }

  bool _isCurrent(int version) => mounted && version == _transitionVersion;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      final fadeOpacity = 1 - _fadeController.value;
      final transitionDuration = _transitionController.duration!.inMicroseconds;
      final blurEnd =
          RealtimeCameraSwitchTransition.blurDuration.inMicroseconds /
          transitionDuration;
      final blurProgress = Curves.easeIn.transform(
        (_transitionController.value / blurEnd).clamp(0, 1),
      );
      final flipProgress = _hasCompletedFlip
          ? 0.0
          : Curves.easeInOut.transform(
              ((_transitionController.value - blurEnd) / (1 - blurEnd)).clamp(
                0,
                1,
              ),
            );
      final transform = Matrix4.identity()
        ..setEntry(3, 2, -1 / 600)
        ..rotateY(math.pi * flipProgress);

      return Transform(
        key: const ValueKey<String>('camera-switch-flip'),
        alignment: Alignment.center,
        transform: transform,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child!,
            if (_isVisible)
              IgnorePointer(
                child: Opacity(
                  opacity: fadeOpacity,
                  child: ClipRect(
                    child: BackdropFilter(
                      key: const ValueKey<String>('camera-switch-blur'),
                      filter: ui.ImageFilter.blur(
                        sigmaX: 20 * blurProgress,
                        sigmaY: 20 * blurProgress,
                      ),
                      child: ColoredBox(
                        color: const Color(
                          0xFF000000,
                        ).withValues(alpha: 0.18 * blurProgress),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
