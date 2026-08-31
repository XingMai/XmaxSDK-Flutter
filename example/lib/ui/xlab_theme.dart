import 'package:flutter/material.dart';

abstract final class XLabPalette {
  static const background = Color(0xFF070A0F);
  static const surface = Color(0xFF111820);
  static const mint = Color(0xFF8EF0C8);
  static const blue = Color(0xFF78A9FF);
  static const pink = Color(0xFFFF8FD8);
  static const orange = Color(0xFFF5B86C);
  static const primaryText = Color(0xFFF4F7FB);
  static const secondaryText = Color(0xFF8E9AA9);
}

final class XLabBackground extends StatelessWidget {
  const XLabBackground({
    required this.child,
    this.accent = XLabPalette.mint,
    super.key,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0C121B),
            Color(0xFF070A0F),
            Color(0xFF090D13),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            right: -130,
            top: -90,
            child: _Glow(color: accent.withValues(alpha: 0.17), size: 300),
          ),
          Positioned(
            left: -150,
            top: 350,
            child: _Glow(color: accent.withValues(alpha: 0.10), size: 250),
          ),
          child,
        ],
      ),
    );
  }
}

final class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

final class XLabCard extends StatelessWidget {
  const XLabCard({
    required this.child,
    this.accent = Colors.white,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xF0141B25), Color(0xF00C1118)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x85000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

final class XLabPill extends StatelessWidget {
  const XLabPill(this.text, {required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

final class XLabTopBar extends StatelessWidget {
  const XLabTopBar({
    required this.title,
    required this.accent,
    required this.version,
    this.onBack,
    super.key,
  });

  final String title;
  final Color accent;
  final String version;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: Row(
      children: <Widget>[
        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          )
        else
          const _BrandMark(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: XLabPalette.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'EXAMPLE / FLUTTER',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.72),
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        XLabPill('v$version', color: accent),
      ],
    ),
  );
}

final class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[XLabPalette.mint, Color(0xFF6495FF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const Text(
          'X',
          style: TextStyle(
            color: Color(0xFF07110D),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
