import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/corner_point.dart';

class PerspectiveCropper {
  /// 透视展开时最多采样的像素数（过大时 Dart 双层循环会卡很久）。
  static const int _maxWarpPixels = 2400000;

  Future<Uint8List?> crop(Uint8List bytes, List<CornerPoint> polygon) async {
    final src = img.decodeImage(bytes);
    if (src == null || polygon.length != 4) return null;
    return cropDecoded(src, polygon);
  }

  /// 使用已解码图，避免重复 decode；角点须与 [src] 同一像素坐标系（建议已 bakeOrientation）。
  Future<Uint8List?> cropDecoded(
    img.Image src,
    List<CornerPoint> polygon,
  ) async {
    if (polygon.length != 4) return null;
    final pts = _orderPointsClockwise(polygon);
    final tl = pts[0];
    final tr = pts[1];
    final br = pts[2];
    final bl = pts[3];

    final widthTop = _distance(tl, tr);
    final widthBottom = _distance(bl, br);
    final heightLeft = _distance(tl, bl);
    final heightRight = _distance(tr, br);
    final rawW = (widthTop + widthBottom) / 2;
    final rawH = (heightLeft + heightRight) / 2;
    final rawPixels = rawW * rawH;
    final capScale = rawPixels > _maxWarpPixels
        ? math.sqrt(_maxWarpPixels / rawPixels)
        : 1.0;
    final maxW = math.max(32, (rawW * capScale).round());
    final maxH = math.max(32, (rawH * capScale).round());

    final srcPts = [
      [tl.x, tl.y],
      [tr.x, tr.y],
      [br.x, br.y],
      [bl.x, bl.y],
    ];
    final dstPts = [
      [0.0, 0.0],
      [maxW - 1.0, 0.0],
      [maxW - 1.0, maxH - 1.0],
      [0.0, maxH - 1.0],
    ];
    final h = _computeHomography(dstPts, srcPts);
    if (h == null) return null;

    final out = img.Image(width: maxW, height: maxH);
    for (var y = 0; y < maxH; y++) {
      for (var x = 0; x < maxW; x++) {
        final sx = h[0] * x + h[1] * y + h[2];
        final sy = h[3] * x + h[4] * y + h[5];
        final sw = h[6] * x + h[7] * y + h[8];
        if (sw.abs() < 1e-6) continue;
        final px = sx / sw;
        final py = sy / sw;
        if (px < 0 || px >= src.width - 1 || py < 0 || py >= src.height - 1) {
          continue;
        }
        final rgba = _sampleBilinearRgba(src, px, py);
        out.setPixelRgba(x, y, rgba[0], rgba[1], rgba[2], rgba[3]);
      }
    }
    return Uint8List.fromList(img.encodeJpg(out, quality: 90));
  }

  double _distance(CornerPoint a, CornerPoint b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }

  List<CornerPoint> _orderPointsClockwise(List<CornerPoint> pts) {
    final cx = pts.fold<double>(0, (v, p) => v + p.x) / pts.length;
    final cy = pts.fold<double>(0, (v, p) => v + p.y) / pts.length;
    final sorted = [...pts]
      ..sort(
        (a, b) => math
            .atan2(a.y - cy, a.x - cx)
            .compareTo(math.atan2(b.y - cy, b.x - cx)),
      );
    var start = 0;
    var minSum = sorted[0].x + sorted[0].y;
    for (var i = 1; i < sorted.length; i++) {
      final s = sorted[i].x + sorted[i].y;
      if (s < minSum) {
        minSum = s;
        start = i;
      }
    }
    return [...sorted.sublist(start), ...sorted.sublist(0, start)];
  }

  List<int> _sampleBilinearRgba(img.Image image, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = math.min(x0 + 1, image.width - 1);
    final y1 = math.min(y0 + 1, image.height - 1);
    final dx = x - x0;
    final dy = y - y0;

    final p00 = image.getPixel(x0, y0);
    final p10 = image.getPixel(x1, y0);
    final p01 = image.getPixel(x0, y1);
    final p11 = image.getPixel(x1, y1);

    final r =
        _interp2(
          p00.r.toDouble(),
          p10.r.toDouble(),
          p01.r.toDouble(),
          p11.r.toDouble(),
          dx,
          dy,
        ).round();
    final g =
        _interp2(
          p00.g.toDouble(),
          p10.g.toDouble(),
          p01.g.toDouble(),
          p11.g.toDouble(),
          dx,
          dy,
        ).round();
    final b =
        _interp2(
          p00.b.toDouble(),
          p10.b.toDouble(),
          p01.b.toDouble(),
          p11.b.toDouble(),
          dx,
          dy,
        ).round();
    final a =
        _interp2(
          p00.a.toDouble(),
          p10.a.toDouble(),
          p01.a.toDouble(),
          p11.a.toDouble(),
          dx,
          dy,
        ).round();
    return [r, g, b, a];
  }

  double _interp2(
    double c00,
    double c10,
    double c01,
    double c11,
    double dx,
    double dy,
  ) {
    final c0 = c00 * (1 - dx) + c10 * dx;
    final c1 = c01 * (1 - dx) + c11 * dx;
    return c0 * (1 - dy) + c1 * dy;
  }

  List<double>? _computeHomography(
    List<List<double>> src,
    List<List<double>> dst,
  ) {
    final a = List.generate(8, (_) => List<double>.filled(8, 0));
    final b = List<double>.filled(8, 0);
    for (var i = 0; i < 4; i++) {
      final x = src[i][0];
      final y = src[i][1];
      final u = dst[i][0];
      final v = dst[i][1];
      a[i * 2][0] = x;
      a[i * 2][1] = y;
      a[i * 2][2] = 1;
      a[i * 2][6] = -x * u;
      a[i * 2][7] = -y * u;
      b[i * 2] = u;

      a[i * 2 + 1][3] = x;
      a[i * 2 + 1][4] = y;
      a[i * 2 + 1][5] = 1;
      a[i * 2 + 1][6] = -x * v;
      a[i * 2 + 1][7] = -y * v;
      b[i * 2 + 1] = v;
    }
    final x = _solveLinear(a, b);
    if (x == null) return null;
    return [x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], 1.0];
  }

  List<double>? _solveLinear(List<List<double>> a, List<double> b) {
    final n = b.length;
    for (var i = 0; i < n; i++) {
      var pivot = i;
      for (var r = i + 1; r < n; r++) {
        if (a[r][i].abs() > a[pivot][i].abs()) pivot = r;
      }
      if (a[pivot][i].abs() < 1e-9) return null;
      if (pivot != i) {
        final tmpRow = a[i];
        a[i] = a[pivot];
        a[pivot] = tmpRow;
        final tmpB = b[i];
        b[i] = b[pivot];
        b[pivot] = tmpB;
      }

      final div = a[i][i];
      for (var j = i; j < n; j++) {
        a[i][j] /= div;
      }
      b[i] /= div;

      for (var r = 0; r < n; r++) {
        if (r == i) continue;
        final factor = a[r][i];
        for (var j = i; j < n; j++) {
          a[r][j] -= factor * a[i][j];
        }
        b[r] -= factor * b[i];
      }
    }
    return b;
  }
}
