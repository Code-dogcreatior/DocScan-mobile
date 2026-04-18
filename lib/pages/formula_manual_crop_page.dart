import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../widgets/app_feedback.dart';

/// 解码并生成与 [img.bakeOrientation] 后一致的预览 JPEG（用于手动框选坐标系）。
class _FormulaCropPreviewLoadArgs {
  const _FormulaCropPreviewLoadArgs(this.bytes);
  final Uint8List bytes;
}

class _FormulaCropPreviewLoadResult {
  const _FormulaCropPreviewLoadResult({
    required this.width,
    required this.height,
    required this.previewJpeg,
  });
  final int width;
  final int height;
  final Uint8List previewJpeg;
}

Future<_FormulaCropPreviewLoadResult?> _loadPreviewForManualCrop(
  _FormulaCropPreviewLoadArgs args,
) async {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;
  final baked = img.bakeOrientation(decoded);
  return _FormulaCropPreviewLoadResult(
    width: baked.width,
    height: baked.height,
    previewJpeg: Uint8List.fromList(img.encodeJpg(baked, quality: 92)),
  );
}

/// 按归一化矩形裁剪 → 灰度 → 亮度二值 → JPEG，供 [LatexOcrService.recognizeJpeg]。
class FormulaManualCropBinarizeArgs {
  const FormulaManualCropBinarizeArgs({
    required this.bytes,
    required this.normLeft,
    required this.normTop,
    required this.normWidth,
    required this.normHeight,
  });
  final Uint8List bytes;
  final double normLeft;
  final double normTop;
  final double normWidth;
  final double normHeight;
}

Future<Uint8List?> formulaManualCropBinarizeTask(
  FormulaManualCropBinarizeArgs a,
) async {
  final decoded = img.decodeImage(a.bytes);
  if (decoded == null) return null;
  final baked = img.bakeOrientation(decoded);
  final iw = baked.width;
  final ih = baked.height;
  final x = (a.normLeft * iw).round().clamp(0, math.max(0, iw - 1)).toInt();
  final y = (a.normTop * ih).round().clamp(0, math.max(0, ih - 1)).toInt();
  var cw = (a.normWidth * iw).round().clamp(1, iw).toInt();
  var ch = (a.normHeight * ih).round().clamp(1, ih).toInt();
  if (x + cw > iw) cw = (iw - x).toInt();
  if (y + ch > ih) ch = (ih - y).toInt();
  if (cw < 1 || ch < 1) return null;

  // 给公式外围留一点边，减少紧贴边缘导致的符号截断。
  final padX = math.max(4, (cw * 0.06).round());
  final padY = math.max(4, (ch * 0.10).round());
  final cx = (x - padX).clamp(0, iw - 1);
  final cy = (y - padY).clamp(0, ih - 1);
  final cRight = (x + cw + padX).clamp(1, iw);
  final cBottom = (y + ch + padY).clamp(1, ih);
  final finalW = math.max(1, cRight - cx);
  final finalH = math.max(1, cBottom - cy);

  var cropped = img.copyCrop(
    baked,
    x: cx,
    y: cy,
    width: finalW,
    height: finalH,
  );
  cropped = img.grayscale(cropped);
  final t = _otsuThreshold(cropped).clamp(0.22, 0.78);
  img.luminanceThreshold(cropped, threshold: t);

  // 极端分布兜底：避免整图几乎全黑/全白。
  final blackRatio = _binaryBlackRatio(cropped);
  if (blackRatio < 0.01 || blackRatio > 0.92) {
    img.luminanceThreshold(cropped, threshold: 0.5);
  }
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
}

double _otsuThreshold(img.Image gray) {
  final hist = List<int>.filled(256, 0);
  final total = gray.width * gray.height;
  if (total <= 0) return 0.5;

  for (var y = 0; y < gray.height; y++) {
    for (var x = 0; x < gray.width; x++) {
      final v = gray.getPixel(x, y).r.toInt().clamp(0, 255);
      hist[v]++;
    }
  }

  double sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }

  var wB = 0;
  double sumB = 0;
  var maxVar = -1.0;
  var threshold = 127;

  for (var i = 0; i < 256; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;

    sumB += i * hist[i];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      threshold = i;
    }
  }
  return threshold / 255.0;
}

double _binaryBlackRatio(img.Image binary) {
  final total = binary.width * binary.height;
  if (total <= 0) return 0;
  var black = 0;
  for (var y = 0; y < binary.height; y++) {
    for (var x = 0; x < binary.width; x++) {
      if (binary.getPixel(x, y).r.toInt() < 128) {
        black++;
      }
    }
  }
  return black / total;
}

/// 手动框选公式区域；确认后返回裁剪并二值化后的 JPEG，取消返回 `null`。
class FormulaManualCropPage extends StatefulWidget {
  const FormulaManualCropPage({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<FormulaManualCropPage> createState() => _FormulaManualCropPageState();
}

class _FormulaManualCropPageState extends State<FormulaManualCropPage> {
  static const double _minNorm = 0.06;

  bool _loading = true;
  String? _loadError;
  Uint8List? _previewJpeg;
  int _iw = 0;
  int _ih = 0;

  /// 相对整图 [0,1] 的裁剪矩形（与 bake 后像素对齐）。
  double _nl = 0.12;
  double _nt = 0.18;
  double _nw = 0.76;
  double _nh = 0.52;

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await compute(
        _loadPreviewForManualCrop,
        _FormulaCropPreviewLoadArgs(widget.imageBytes),
      );
      if (!mounted) return;
      if (r == null) {
        setState(() {
          _loading = false;
          _loadError = '无法解码图片';
        });
        return;
      }
      setState(() {
        _loading = false;
        _previewJpeg = r.previewJpeg;
        _iw = r.width;
        _ih = r.height;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _confirm() async {
    if (_previewJpeg == null || _processing) return;
    setState(() => _processing = true);
    try {
      final out = await compute(
        formulaManualCropBinarizeTask,
        FormulaManualCropBinarizeArgs(
          bytes: widget.imageBytes,
          normLeft: _nl,
          normTop: _nt,
          normWidth: _nw,
          normHeight: _nh,
        ),
      );
      if (!mounted) return;
      if (out == null) {
        showAppSnackBar(
          context,
          message: '裁剪处理失败，请调整选区',
          icon: Icons.error_outline,
        );
        setState(() => _processing = false);
        return;
      }
      Navigator.of(context).pop<Uint8List>(out);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '处理失败: $e',
          icon: Icons.error_outline,
        );
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('框选公式区域'),
        actions: [
          TextButton(
            onPressed: _loading || _loadError != null || _processing
                ? null
                : _confirm,
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('识别'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!, style: TextStyle(color: theme.colorScheme.error)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        '拖动四角调整选区，中间区域可平移。确认后将进行自适应黑白二值化再识别。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _ManualCropView(
                          imageWidth: _iw,
                          imageHeight: _ih,
                          previewJpeg: _previewJpeg!,
                          normLeft: _nl,
                          normTop: _nt,
                          normWidth: _nw,
                          normHeight: _nh,
                          minNorm: _minNorm,
                          onChanged: (nl, nt, nw, nh) {
                            setState(() {
                              _nl = nl;
                              _nt = nt;
                              _nw = nw;
                              _nh = nh;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

enum _CropDragKind { none, move, tl, tr, br, bl }

class _ManualCropView extends StatefulWidget {
  const _ManualCropView({
    required this.imageWidth,
    required this.imageHeight,
    required this.previewJpeg,
    required this.normLeft,
    required this.normTop,
    required this.normWidth,
    required this.normHeight,
    required this.minNorm,
    required this.onChanged,
  });

  final int imageWidth;
  final int imageHeight;
  final Uint8List previewJpeg;
  final double normLeft;
  final double normTop;
  final double normWidth;
  final double normHeight;
  final double minNorm;
  final void Function(double nl, double nt, double nw, double nh) onChanged;

  @override
  State<_ManualCropView> createState() => _ManualCropViewState();
}

class _ManualCropViewState extends State<_ManualCropView> {
  _CropDragKind _kind = _CropDragKind.none;

  void _apply(double nl, double nt, double nw, double nh) {
    final minN = widget.minNorm;
    var w = nw.clamp(minN, 1.0);
    var h = nh.clamp(minN, 1.0);
    var l = nl.clamp(0.0, 1.0 - w);
    var t = nt.clamp(0.0, 1.0 - h);
    if (l + w > 1.0) w = (1.0 - l).clamp(minN, 1.0);
    if (t + h > 1.0) h = (1.0 - t).clamp(minN, 1.0);
    widget.onChanged(l, t, w, h);
  }

  _CropDragKind _hitTest(Offset local, Size box) {
    const hit = 26.0;
    final r = Rect.fromLTWH(
      widget.normLeft * box.width,
      widget.normTop * box.height,
      widget.normWidth * box.width,
      widget.normHeight * box.height,
    );
    if ((local - r.topLeft).distance <= hit) return _CropDragKind.tl;
    if ((local - r.topRight).distance <= hit) return _CropDragKind.tr;
    if ((local - r.bottomRight).distance <= hit) return _CropDragKind.br;
    if ((local - r.bottomLeft).distance <= hit) return _CropDragKind.bl;
    if (r.contains(local)) return _CropDragKind.move;
    return _CropDragKind.none;
  }

  void _onPanStart(DragStartDetails d, Size box) {
    _kind = _hitTest(d.localPosition, box);
  }

  void _onPanUpdate(DragUpdateDetails d, Size box) {
    if (_kind == _CropDragKind.none) return;
    final dx = d.delta.dx / box.width;
    final dy = d.delta.dy / box.height;
    final brx = widget.normLeft + widget.normWidth;
    final bry = widget.normTop + widget.normHeight;

    switch (_kind) {
      case _CropDragKind.move:
        _apply(
          widget.normLeft + dx,
          widget.normTop + dy,
          widget.normWidth,
          widget.normHeight,
        );
      case _CropDragKind.tl:
        var nl = widget.normLeft + dx;
        var nt = widget.normTop + dy;
        nl = nl.clamp(0.0, brx - widget.minNorm);
        nt = nt.clamp(0.0, bry - widget.minNorm);
        _apply(nl, nt, brx - nl, bry - nt);
      case _CropDragKind.tr:
        // 固定左下角 (nl, nt+nh)
        final bly = widget.normTop + widget.normHeight;
        var nt = widget.normTop + dy;
        var nw = widget.normWidth + dx;
        nw = nw.clamp(widget.minNorm, 1.0 - widget.normLeft);
        nt = nt.clamp(0.0, bly - widget.minNorm);
        _apply(widget.normLeft, nt, nw, bly - nt);
      case _CropDragKind.br:
        _apply(
          widget.normLeft,
          widget.normTop,
          widget.normWidth + dx,
          widget.normHeight + dy,
        );
      case _CropDragKind.bl:
        // 固定右上角 (nl+nw, nt)
        final trx = widget.normLeft + widget.normWidth;
        final trY = widget.normTop;
        var nl = widget.normLeft + dx;
        var nh = widget.normHeight + dy;
        nl = nl.clamp(0.0, trx - widget.minNorm);
        nh = nh.clamp(widget.minNorm, 1.0 - trY);
        _apply(nl, trY, trx - nl, nh);
      case _CropDragKind.none:
        break;
    }
  }

  void _onPanEnd(_) => _kind = _CropDragKind.none;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final iw = widget.imageWidth;
        final ih = widget.imageHeight;
        if (iw <= 0 || ih <= 0) {
          return const SizedBox.shrink();
        }
        final s = math.min(maxW / iw, maxH / ih);
        final w = iw * s;
        final h = ih * s;
        final box = Size(w, h);

        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: w,
                height: h,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _onPanStart(d, box),
                  onPanUpdate: (d) => _onPanUpdate(d, box),
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        widget.previewJpeg,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                      CustomPaint(
                        painter: _CropOverlayPainter(
                          normLeft: widget.normLeft,
                          normTop: widget.normTop,
                          normWidth: widget.normWidth,
                          normHeight: widget.normHeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.normLeft,
    required this.normTop,
    required this.normWidth,
    required this.normHeight,
  });

  final double normLeft;
  final double normTop;
  final double normWidth;
  final double normHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = Rect.fromLTWH(
      normLeft * size.width,
      normTop * size.height,
      normWidth * size.width,
      normHeight * size.height,
    );
    final shade = Paint()..color = const Color(0x99000000);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(crop, const Radius.circular(2))),
      ),
      shade,
    );
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(crop, const Radius.circular(2)), border);
    final handle = Paint()..color = Colors.white;
    const hr = 5.0;
    for (final c in [
      crop.topLeft,
      crop.topRight,
      crop.bottomRight,
      crop.bottomLeft,
    ]) {
      canvas.drawCircle(c, hr, handle);
      canvas.drawCircle(c, hr, border);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.normLeft != normLeft ||
        oldDelegate.normTop != normTop ||
        oldDelegate.normWidth != normWidth ||
        oldDelegate.normHeight != normHeight;
  }
}
