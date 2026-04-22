import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/corner_point.dart';
import '../services/perspective_cropper.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';

/// 手动调整四角的裁剪页。入参是 `bakeOrientation` 后的原图 JPEG；
/// 确认后返回透视裁剪出的 JPEG，取消返回 `null`。
///
/// 与矩形 [FormulaManualCropPage] 不同，此页四角可独立拖动、产生任意四边形。
class ManualCropPage extends StatefulWidget {
  const ManualCropPage({
    super.key,
    required this.imageBytes,
    this.initialCorners,
  });

  final Uint8List imageBytes;

  /// 初始四角，像素坐标与原图（bake 后）对齐。数量 != 4 时回退到四角内缩 10%。
  final List<CornerPoint>? initialCorners;

  @override
  State<ManualCropPage> createState() => _ManualCropPageState();
}

class _ManualCropPageState extends State<ManualCropPage> {
  bool _loading = true;
  String? _loadError;
  int _iw = 0;
  int _ih = 0;
  Uint8List? _previewJpeg;

  /// 四角的归一化坐标，顺序 [tl, tr, br, bl]。
  List<Offset> _corners = const [];

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await compute(_decodePreview, widget.imageBytes);
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
        _iw = r.width;
        _ih = r.height;
        _previewJpeg = r.previewJpeg;
        _corners = _seedCorners(widget.initialCorners, r.width, r.height);
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

  static List<Offset> _seedCorners(List<CornerPoint>? seed, int iw, int ih) {
    if (seed != null && seed.length == 4 && iw > 0 && ih > 0) {
      return [
        for (final p in seed)
          Offset(
            (p.x / iw).clamp(0.0, 1.0),
            (p.y / ih).clamp(0.0, 1.0),
          ),
      ];
    }
    const m = 0.1;
    return const [
      Offset(m, m),
      Offset(1 - m, m),
      Offset(1 - m, 1 - m),
      Offset(m, 1 - m),
    ];
  }

  Future<void> _confirm() async {
    if (_previewJpeg == null || _processing) return;
    setState(() => _processing = true);
    try {
      final out = await compute(
        _cropWithPolygon,
        _CropArgs(bytes: widget.imageBytes, norms: _corners),
      );
      if (!mounted) return;
      if (out == null) {
        showAppSnackBar(
          context,
          message: '裁剪失败，请调整四角位置',
          tone: AppFeedbackTone.warning,
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
          tone: AppFeedbackTone.danger,
        );
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('手动调整四角'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: null,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _loadError != null
              ? Center(
                  child: Text(
                    _loadError!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Text(
                        '拖动任意角点到文档的实际边缘，完成后点"使用此区域"',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        child: _PolygonCropView(
                          previewJpeg: _previewJpeg!,
                          imageWidth: _iw,
                          imageHeight: _ih,
                          corners: _corners,
                          onChanged: (next) =>
                              setState(() => _corners = next),
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : BottomActionBar(
              children: [
                SecondaryActionButton(
                  label: '取消',
                  icon: Icons.close_rounded,
                  onPressed: _processing
                      ? null
                      : () => Navigator.of(context).pop<Uint8List?>(null),
                ),
                PrimaryActionButton(
                  label: _processing ? '正在裁剪…' : '使用此区域',
                  icon: Icons.check_rounded,
                  loading: _processing,
                  onPressed: _processing ? null : _confirm,
                ),
              ],
            ),
    );
  }
}

// ── Isolate tasks ────────────────────────────────────────────────────────────

class _DecodeResult {
  const _DecodeResult({
    required this.width,
    required this.height,
    required this.previewJpeg,
  });
  final int width;
  final int height;
  final Uint8List previewJpeg;
}

Future<_DecodeResult?> _decodePreview(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final baked = img.bakeOrientation(decoded);
  final jpg = Uint8List.fromList(img.encodeJpg(baked, quality: 85));
  return _DecodeResult(
    width: baked.width,
    height: baked.height,
    previewJpeg: jpg,
  );
}

class _CropArgs {
  const _CropArgs({required this.bytes, required this.norms});
  final Uint8List bytes;
  final List<Offset> norms;
}

Future<Uint8List?> _cropWithPolygon(_CropArgs args) async {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;
  final baked = img.bakeOrientation(decoded);
  final poly = <CornerPoint>[
    for (final o in args.norms)
      CornerPoint(o.dx * baked.width, o.dy * baked.height),
  ];
  return PerspectiveCropper().cropDecoded(baked, poly);
}

// ── Polygon view + painter ───────────────────────────────────────────────────

class _PolygonCropView extends StatefulWidget {
  const _PolygonCropView({
    required this.previewJpeg,
    required this.imageWidth,
    required this.imageHeight,
    required this.corners,
    required this.onChanged,
  });

  final Uint8List previewJpeg;
  final int imageWidth;
  final int imageHeight;
  final List<Offset> corners;
  final ValueChanged<List<Offset>> onChanged;

  @override
  State<_PolygonCropView> createState() => _PolygonCropViewState();
}

class _PolygonCropViewState extends State<_PolygonCropView> {
  int? _activeIndex;

  int? _hitTest(Offset local, Size box) {
    const hitRadius = 36.0;
    int? best;
    double bestD = hitRadius;
    for (var i = 0; i < widget.corners.length; i++) {
      final c = widget.corners[i];
      final p = Offset(c.dx * box.width, c.dy * box.height);
      final d = (local - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _onPanStart(DragStartDetails d, Size box) {
    setState(() {
      _activeIndex = _hitTest(d.localPosition, box);
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size box) {
    final i = _activeIndex;
    if (i == null) return;
    final next = List<Offset>.from(widget.corners);
    final nx = (next[i].dx + d.delta.dx / box.width).clamp(0.0, 1.0);
    final ny = (next[i].dy + d.delta.dy / box.height).clamp(0.0, 1.0);
    next[i] = Offset(nx, ny);
    widget.onChanged(next);
  }

  void _onPanEnd() {
    setState(() => _activeIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iw = widget.imageWidth.toDouble();
        final ih = widget.imageHeight.toDouble();
        if (iw <= 0 || ih <= 0) return const SizedBox.shrink();
        final scale = math.min(
          constraints.maxWidth / iw,
          constraints.maxHeight / ih,
        );
        final w = iw * scale;
        final h = ih * scale;
        final box = Size(w, h);
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: SizedBox(
              width: w,
              height: h,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _onPanStart(d, box),
                onPanUpdate: (d) => _onPanUpdate(d, box),
                onPanEnd: (_) => _onPanEnd(),
                onPanCancel: _onPanEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      widget.previewJpeg,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                    CustomPaint(
                      painter: _PolygonPainter(
                        corners: widget.corners,
                        activeIndex: _activeIndex,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PolygonPainter extends CustomPainter {
  _PolygonPainter({required this.corners, required this.activeIndex});
  final List<Offset> corners;
  final int? activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;
    final pts = [
      for (final c in corners) Offset(c.dx * size.width, c.dy * size.height),
    ];
    final poly = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < 4; i++) {
      poly.lineTo(pts[i].dx, pts[i].dy);
    }
    poly.close();

    // 多边形外的暗色遮罩
    final shade = Paint()..color = const Color(0x99000000);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        poly,
      ),
      shade,
    );

    // 边线
    final stroke = Paint()
      ..color = AppTokens.overlayAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;
    canvas.drawPath(poly, stroke);

    // 四角：外环（品牌色） + 内环（白）；当前拖动的点放大
    final ring = Paint()..color = AppTokens.overlayAccent;
    final core = Paint()..color = Colors.white;
    for (var i = 0; i < 4; i++) {
      final r = activeIndex == i ? 14.0 : 10.0;
      canvas.drawCircle(pts[i], r, ring);
      canvas.drawCircle(pts[i], r - 3, core);
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter old) =>
      !listEquals(old.corners, corners) || old.activeIndex != activeIndex;
}
