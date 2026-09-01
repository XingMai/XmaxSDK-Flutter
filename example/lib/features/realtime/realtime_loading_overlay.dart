import 'package:flutter/material.dart';

/// Covers the realtime preview while local or generated video is loading.
final class RealtimeLoadingOverlay extends StatefulWidget {
  const RealtimeLoadingOverlay({required this.isLoading, super.key});

  final bool isLoading;

  @override
  State<RealtimeLoadingOverlay> createState() => _RealtimeLoadingOverlayState();
}

final class _RealtimeLoadingOverlayState extends State<RealtimeLoadingOverlay>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 300);

  late final AnimationController _controller = AnimationController(
    duration: _transitionDuration,
    value: 0,
    vsync: this,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late bool _isVisible = widget.isLoading;
  int _transitionVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading == oldWidget.isLoading) return;

    if (widget.isLoading) {
      _show();
    } else {
      _hide();
    }
  }

  void _show() {
    _transitionVersion += 1;
    if (!_isVisible) {
      setState(() => _isVisible = true);
    }
    _controller.forward();
  }

  Future<void> _hide() async {
    final version = ++_transitionVersion;
    await _controller.reverse();

    if (!mounted || widget.isLoading || version != _transitionVersion) return;
    setState(() => _isVisible = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: Semantics(
              label: '正在加载实时画面',
              child: Image.asset(
                'assets/realtime_loading.gif',
                width: 54,
                height: 50,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xDBFFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
