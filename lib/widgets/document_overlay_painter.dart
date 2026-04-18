import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/corner_point.dart';
import '../theme/app_tokens.dart';

/// Draws a professional document detection overlay with corner handles,
/// gradient fill and a clean border.
class DocumentOverlayPainter extends CustomPainter {
  DocumentOverlayPainter({
    required this.points,
    required this.imageSize,
    required this.quarterTurns,
    this.isMirrored = false,
    this.flipY = false,
    this.flipX = false,
  });

  final List<CornerPoint> points;
  final Size imageSize;
  final int quarterTurns;
  final bool isMirrored;
  final bool flipY;
  final bool flipX;

  static const _accentColor = AppTokens.overlayAccent;
  static const _cornerHandleRadius = 7.0;
  static const _cornerHandleStroke = 2.5;
  static const _edgeLineWidth = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4 || imageSize.width <= 0 || imageSize.height <= 0) {
      return;
    }

    final normalizedTurns = quarterTurns % 4;
    final rotatedImageSize = _rotatedSize(imageSize, normalizedTurns);
    final scaleX = size.width / rotatedImageSize.width;
    final scaleY = size.height / rotatedImageSize.height;

    final transformedPoints = points.map((point) {
      var o = _transformPoint(point, normalizedTurns);
      if (flipY) {
        o = Offset(o.dx, rotatedImageSize.height - o.dy);
      }
      if (flipX) {
        o = Offset(rotatedImageSize.width - o.dx, o.dy);
      }
      var x = o.dx;
      if (isMirrored) {
        x = rotatedImageSize.width - x;
      }
      return Offset(x * scaleX, o.dy * scaleY);
    }).toList(growable: false);

    final path = Path()
      ..moveTo(transformedPoints.first.dx, transformedPoints.first.dy);
    for (var i = 1; i < transformedPoints.length; i++) {
      path.lineTo(transformedPoints[i].dx, transformedPoints[i].dy);
    }
    path.close();

    // ── Gradient fill ──
    final bounds = path.getBounds();
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        bounds.topCenter,
        bounds.bottomCenter,
        [
          AppTokens.overlayFillTop,
          AppTokens.overlayFillBottom,
        ],
      );
    canvas.drawPath(path, fillPaint);

    // ── Edge border ──
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeLineWidth
      ..strokeJoin = StrokeJoin.round
      ..color = _accentColor;
    canvas.drawPath(path, borderPaint);

    // ── Corner handles ──
    final handleFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    final handleStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _cornerHandleStroke
      ..color = _accentColor;

    for (final p in transformedPoints) {
      canvas.drawCircle(p, _cornerHandleRadius, handleFill);
      canvas.drawCircle(p, _cornerHandleRadius, handleStroke);
    }
  }

  Offset _transformPoint(CornerPoint point, int turns) {
    final maxX = imageSize.width;
    final maxY = imageSize.height;
    return switch (turns) {
      0 => Offset(point.x, point.y),
      1 => Offset(point.y, maxX - point.x),
      2 => Offset(maxX - point.x, maxY - point.y),
      3 => Offset(maxY - point.y, point.x),
      int() => Offset(point.x, point.y),
    };
  }

  Size _rotatedSize(Size source, int turns) {
    return turns.isEven ? source : Size(source.height, source.width);
  }

  @override
  bool shouldRepaint(covariant DocumentOverlayPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    if (oldDelegate.imageSize != imageSize) return true;
    if (oldDelegate.quarterTurns != quarterTurns) return true;
    if (oldDelegate.isMirrored != isMirrored) return true;
    if (oldDelegate.flipY != flipY) return true;
    if (oldDelegate.flipX != flipX) return true;
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i].x != points[i].x ||
          oldDelegate.points[i].y != points[i].y) {
        return true;
      }
    }
    return false;
  }
}
