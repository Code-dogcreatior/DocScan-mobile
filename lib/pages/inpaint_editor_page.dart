import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../services/inpaint_service.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';

class _MaskStroke {
  _MaskStroke({required this.points, required this.size});
  final List<Offset> points;
  final double size;
}

class InpaintEditorPage extends StatefulWidget {
  const InpaintEditorPage({
    super.key,
    required this.imageJpegBytes,
  });

  final Uint8List imageJpegBytes;

  @override
  State<InpaintEditorPage> createState() => _InpaintEditorPageState();
}

class _InpaintEditorPageState extends State<InpaintEditorPage> {
  final TransformationController _transform = TransformationController();
  final GlobalKey _paintAreaKey = GlobalKey();
  final InpaintService _inpaintService = InpaintService();
  final ShareService _shareService = ShareService();
  final List<_MaskStroke> _strokes = <_MaskStroke>[];
  _MaskStroke? _activeStroke;
  bool _moveMode = false;
  double _brushSize = 24;
  bool _submitting = false;
  bool _saving = false;
  Uint8List? _currentImageBytes;
  bool _hasResult = false;
  InpaintDebugInfo? _lastDebugInfo;
  late ui.Image _canvasImage;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _decodeSource();
  }

  @override
  void dispose() {
    _inpaintService.close();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _decodeSource() async {
    final prepared = await _preparePng(widget.imageJpegBytes);
    if (!mounted) return;
    _canvasImage = prepared.$1;
    _currentImageBytes = prepared.$2;
    setState(() => _ready = true);
  }

  Future<(ui.Image, Uint8List)> _preparePng(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final pngData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) {
      throw StateError('图片 PNG 编码失败');
    }
    return (frame.image, pngData.buffer.asUint8List());
  }

  Size get _sourceImageSize =>
      Size(_canvasImage.width.toDouble(), _canvasImage.height.toDouble());

  Rect _imageRectInBox(Size boxSize) {
    final fitted = applyBoxFit(BoxFit.contain, _sourceImageSize, boxSize);
    return Alignment.center.inscribe(fitted.destination, Offset.zero & boxSize);
  }

  void _showDebugSheet() {
    final info = _lastDebugInfo;
    if (info == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发送 Mask 预览',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '白色区域 = 实际发给后端的待擦除区域',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    child: Image.memory(
                      info.binaryMaskPreviewBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DebugStat(label: '尺寸', value: '${info.uploadMaskWidth} × ${info.uploadMaskHeight}'),
                  _DebugStat(label: '有效像素', value: '${info.maskActivePixels}'),
                  _DebugStat(label: '范围', value: info.maskBounds),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Offset _toScenePoint(Offset global) {
    final box = _paintAreaKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(global);
    final imageRect = _imageRectInBox(box.size);
    final dx = ((local.dx - imageRect.left) / imageRect.width)
        .clamp(0.0, 1.0)
        .toDouble();
    final dy = ((local.dy - imageRect.top) / imageRect.height)
        .clamp(0.0, 1.0)
        .toDouble();
    final x = dx * _sourceImageSize.width;
    final y = dy * _sourceImageSize.height;
    return Offset(x, y);
  }

  Future<Uint8List> _buildMaskPng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(
        0,
        0,
        _canvasImage.width.toDouble(),
        _canvasImage.height.toDouble(),
      ),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        _canvasImage.width.toDouble(),
        _canvasImage.height.toDouble(),
      ),
      Paint()..color = Colors.black,
    );
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in _strokes) {
      paint.strokeWidth = s.size;
      if (s.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, s.points, paint);
      } else {
        final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
        for (var i = 1; i < s.points.length; i++) {
          path.lineTo(s.points[i].dx, s.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(_canvasImage.width, _canvasImage.height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('蒙版生成失败');
    return byteData.buffer.asUint8List();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_strokes.isEmpty) {
      showAppSnackBar(context, message: '请先在图上涂抹需要消除的区域');
      return;
    }
    setState(() => _submitting = true);
    try {
      final maskPng = await _buildMaskPng();
      final out = await _inpaintService.process(
        imageBytes: _currentImageBytes ?? widget.imageJpegBytes,
        maskBytes: maskPng,
      );
      final prepared = await _preparePng(out);
      if (!mounted) return;
      setState(() {
        _lastDebugInfo = _inpaintService.lastDebugInfo;
        _canvasImage = prepared.$1;
        _currentImageBytes = prepared.$2;
        _hasResult = true;
        _strokes.clear();
        _activeStroke = null;
      });
      showAppSnackBar(context, message: 'AI 擦除完成');
    } on InpaintException catch (e) {
      if (!mounted) return;
      setState(() {
        _lastDebugInfo = e.debugInfo ?? _inpaintService.lastDebugInfo;
      });
      showAppSnackBar(context, message: e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastDebugInfo = _inpaintService.lastDebugInfo;
      });
      showAppSnackBar(context, message: 'AI 擦除失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveResult() async {
    if (_saving || _currentImageBytes == null) return;
    setState(() => _saving = true);
    try {
      final ok = await Gal.requestAccess();
      if (!ok) {
        if (mounted) showAppSnackBar(context, message: '需要相册权限才能保存');
        return;
      }
      await Gal.putImageBytes(
        _currentImageBytes!,
        name: 'DocScan-AI擦除-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (mounted) showAppSnackBar(context, message: '已保存到相册');
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareResult() async {
    if (_currentImageBytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/DocScan-inpaint-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(_currentImageBytes!, flush: true);
    await _shareService.shareFile(file, text: 'DocScan AI 擦除结果');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final showBytes = _currentImageBytes ?? widget.imageJpegBytes;
    final canvasBg = context.palette.editorCanvas;
    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        title: const Text('AI 擦除'),
        actions: [
          IconButton(
            tooltip: _moveMode ? '切换到绘制模式' : '切换到移动模式',
            onPressed: () => setState(() => _moveMode = !_moveMode),
            icon: Icon(_moveMode ? Icons.brush_rounded : Icons.pan_tool_rounded),
          ),
          IconButton(
            tooltip: '清除标记',
            onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
            icon: const Icon(Icons.clear_all_rounded),
          ),
          IconButton(
            tooltip: '查看调试信息',
            onPressed: _lastDebugInfo == null ? null : _showDebugSheet,
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: _BrushSlider(
              value: _brushSize,
              onChanged: (v) => setState(() => _brushSize = v),
            ),
          ),
          Expanded(
            child: Container(
              color: canvasBg,
              child: InteractiveViewer(
                transformationController: _transform,
                panEnabled: _moveMode,
                minScale: 0.4,
                maxScale: 6,
                child: GestureDetector(
                  onPanStart: _moveMode
                      ? null
                      : (details) {
                          final p = _toScenePoint(details.globalPosition);
                          setState(() {
                            _activeStroke =
                                _MaskStroke(points: [p], size: _brushSize);
                            _strokes.add(_activeStroke!);
                          });
                        },
                  onPanUpdate: _moveMode
                      ? null
                      : (details) {
                          final p = _toScenePoint(details.globalPosition);
                          setState(() {
                            _activeStroke?.points.add(p);
                          });
                        },
                  onPanEnd: _moveMode
                      ? null
                      : (_) {
                          _activeStroke = null;
                        },
                  child: SizedBox(
                    key: _paintAreaKey,
                    width: _canvasImage.width.toDouble(),
                    height: _canvasImage.height.toDouble(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(showBytes, fit: BoxFit.contain),
                        CustomPaint(
                          painter: _MaskOverlayPainter(
                            strokes: _strokes,
                            imageSize: _sourceImageSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: canvasBg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _hasResult
                ? Row(
                    children: [
                      Expanded(
                        child: _DarkSecondaryButton(
                          label: _saving ? '保存中…' : '保存到相册',
                          icon: Icons.save_alt_rounded,
                          onPressed: _saving ? null : _saveResult,
                          loading: _saving,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryActionButton(
                          label: '分享',
                          icon: Icons.ios_share_rounded,
                          onPressed: _shareResult,
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: PrimaryActionButton(
                      label: _submitting ? '处理中…' : '开始擦除',
                      icon: Icons.auto_fix_high_rounded,
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BrushSlider extends StatelessWidget {
  const _BrushSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.brush_rounded, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.12),
                trackHeight: 3,
              ),
              child: Slider(
                min: 6,
                max: 80,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '${value.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined secondary button on a dark canvas — OutlinedButton alone picks up
/// light theme defaults that read badly against the editor background.
class _DarkSecondaryButton extends StatelessWidget {
  const _DarkSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          backgroundColor: Colors.white.withValues(alpha: 0.06),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class _DebugStat extends StatelessWidget {
  const _DebugStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MaskOverlayPainter extends CustomPainter {
  _MaskOverlayPainter({
    required this.strokes,
    required this.imageSize,
  });
  final List<_MaskStroke> strokes;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final imageRect = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final scale = imageRect.width / imageSize.width;

    Offset mapPoint(Offset p) => Offset(
      imageRect.left + p.dx * scale,
      imageRect.top + p.dy * scale,
    );

    final paint = Paint()
      ..color = const Color(0xAA4F96FF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      paint.strokeWidth = s.size * scale;
      if (s.points.length == 1) {
        canvas.drawPoints(
          ui.PointMode.points,
          s.points.map(mapPoint).toList(),
          paint,
        );
      } else {
        final first = mapPoint(s.points.first);
        final path = Path()..moveTo(first.dx, first.dy);
        for (var i = 1; i < s.points.length; i++) {
          final point = mapPoint(s.points[i]);
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MaskOverlayPainter oldDelegate) {
    // 手势绘制时会原地追加 points，列表引用不变；始终重绘以保证笔迹实时跟手。
    return true;
  }
}
