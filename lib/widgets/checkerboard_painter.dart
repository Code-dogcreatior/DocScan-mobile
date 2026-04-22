import 'package:flutter/material.dart';

/// Shared checkerboard background — used behind PNGs with transparency so that
/// transparent pixels are distinguishable from white background.
class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter({
    required this.lightColor,
    required this.darkColor,
    this.cellSize = 12,
  });

  final Color lightColor;
  final Color darkColor;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()..color = lightColor;
    final darkPaint = Paint()..color = darkColor;
    canvas.drawRect(Offset.zero & size, lightPaint);
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if ((x + y).isEven) continue;
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect, darkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter old) {
    return old.lightColor != lightColor ||
        old.darkColor != darkColor ||
        old.cellSize != cellSize;
  }
}

/// Convenience widget wrapping [CheckerboardPainter] pulling colors from the
/// current [ColorScheme] surface variants (adapts to dark mode).
class CheckerboardBackground extends StatelessWidget {
  const CheckerboardBackground({super.key, this.cellSize = 12});

  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: CheckerboardPainter(
        lightColor: cs.surfaceContainerHighest,
        darkColor: cs.surfaceContainerHigh,
        cellSize: cellSize,
      ),
      size: Size.infinite,
    );
  }
}
