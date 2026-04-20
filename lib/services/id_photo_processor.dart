import 'dart:typed_data';

import 'package:image/image.dart' as img;

class IdPhotoSizePreset {
  const IdPhotoSizePreset({
    required this.id,
    required this.label,
    required this.widthPx,
    required this.heightPx,
  });

  final String id;
  final String label;
  final int widthPx;
  final int heightPx;
}

class IdPhotoLayoutPreset {
  const IdPhotoLayoutPreset({
    required this.id,
    required this.label,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.columns,
    required this.rows,
    this.spacing = 24,
    this.padding = 28,
  });

  final String id;
  final String label;
  final int canvasWidth;
  final int canvasHeight;
  final int columns;
  final int rows;
  final int spacing;
  final int padding;
}

class IdPhotoProcessor {
  static const presets = <IdPhotoSizePreset>[
    IdPhotoSizePreset(
      id: 'one_inch',
      label: '一寸 (295×413)',
      widthPx: 295,
      heightPx: 413,
    ),
    IdPhotoSizePreset(
      id: 'small_one_inch',
      label: '小一寸 (260×378)',
      widthPx: 260,
      heightPx: 378,
    ),
    IdPhotoSizePreset(
      id: 'two_inch',
      label: '二寸 (413×579)',
      widthPx: 413,
      heightPx: 579,
    ),
  ];

  static const layoutPresets = <IdPhotoLayoutPreset>[
    IdPhotoLayoutPreset(
      id: 'none',
      label: '不排版',
      canvasWidth: 0,
      canvasHeight: 0,
      columns: 0,
      rows: 0,
    ),
    IdPhotoLayoutPreset(
      id: 'six_inch_8',
      label: '6寸排版 (8张)',
      canvasWidth: 1800,
      canvasHeight: 1200,
      columns: 4,
      rows: 2,
    ),
    IdPhotoLayoutPreset(
      id: 'six_inch_6',
      label: '6寸排版 (6张)',
      canvasWidth: 1800,
      canvasHeight: 1200,
      columns: 3,
      rows: 2,
    ),
  ];

  Uint8List composeSolidBackgroundJpeg({
    required Uint8List foregroundPng,
    required int outWidth,
    required int outHeight,
    required int bgR,
    required int bgG,
    required int bgB,
    int quality = 95,
  }) {
    final fg = img.decodeImage(foregroundPng);
    if (fg == null) {
      throw StateError('证件照合成失败：无法解码前景图');
    }

    final canvas = img.Image(width: outWidth, height: outHeight, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(bgR, bgG, bgB));

    final scale = (outWidth / fg.width < outHeight / fg.height
            ? outWidth / fg.width
            : outHeight / fg.height) *
        0.92;
    final drawW = (fg.width * scale).round().clamp(1, outWidth);
    final drawH = (fg.height * scale).round().clamp(1, outHeight);
    final resized = img.copyResize(
      fg,
      width: drawW,
      height: drawH,
      interpolation: img.Interpolation.cubic,
    );
    final dx = ((outWidth - drawW) / 2).round();
    final dy = ((outHeight - drawH) / 2 - (outHeight * 0.06)).round();
    _drawWithAlpha(canvas, resized, dx, dy);
    return Uint8List.fromList(img.encodeJpg(canvas, quality: quality));
  }

  Uint8List composeLayoutJpeg({
    required Uint8List singlePhotoJpeg,
    required IdPhotoLayoutPreset layout,
    int quality = 95,
  }) {
    final cellImg = img.decodeImage(singlePhotoJpeg);
    if (cellImg == null) {
      throw StateError('排版失败：无法解码证件照');
    }
    if (layout.columns <= 0 || layout.rows <= 0) return singlePhotoJpeg;

    final canvas = img.Image(
      width: layout.canvasWidth,
      height: layout.canvasHeight,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final usableW =
        layout.canvasWidth - layout.padding * 2 - (layout.columns - 1) * layout.spacing;
    final usableH =
        layout.canvasHeight - layout.padding * 2 - (layout.rows - 1) * layout.spacing;
    final slotW = (usableW / layout.columns).floor();
    final slotH = (usableH / layout.rows).floor();

    final fitScale = (slotW / cellImg.width < slotH / cellImg.height
            ? slotW / cellImg.width
            : slotH / cellImg.height) *
        0.98;
    final drawW = (cellImg.width * fitScale).round().clamp(1, slotW);
    final drawH = (cellImg.height * fitScale).round().clamp(1, slotH);
    final resized = img.copyResize(
      cellImg,
      width: drawW,
      height: drawH,
      interpolation: img.Interpolation.cubic,
    );

    for (var r = 0; r < layout.rows; r++) {
      for (var c = 0; c < layout.columns; c++) {
        final slotX = layout.padding + c * (slotW + layout.spacing);
        final slotY = layout.padding + r * (slotH + layout.spacing);
        final dx = slotX + ((slotW - drawW) / 2).round();
        final dy = slotY + ((slotH - drawH) / 2).round();
        img.compositeImage(canvas, resized, dstX: dx, dstY: dy);
      }
    }
    return Uint8List.fromList(img.encodeJpg(canvas, quality: quality));
  }

  void _drawWithAlpha(img.Image dst, img.Image src, int dstX, int dstY) {
    for (var y = 0; y < src.height; y++) {
      final ty = y + dstY;
      if (ty < 0 || ty >= dst.height) continue;
      for (var x = 0; x < src.width; x++) {
        final tx = x + dstX;
        if (tx < 0 || tx >= dst.width) continue;
        final s = src.getPixel(x, y);
        final alpha = s.a.toDouble() / 255.0;
        if (alpha <= 0) continue;
        final d = dst.getPixel(tx, ty);
        final r = (s.r * alpha + d.r * (1 - alpha)).round().clamp(0, 255);
        final g = (s.g * alpha + d.g * (1 - alpha)).round().clamp(0, 255);
        final b = (s.b * alpha + d.b * (1 - alpha)).round().clamp(0, 255);
        dst.setPixelRgb(tx, ty, r, g, b);
      }
    }
  }
}
