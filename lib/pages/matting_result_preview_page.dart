import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../widgets/app_feedback.dart';

/// AI 抠图结果预览（PNG 含 alpha，底层棋盘格便于查看透明区域）。
class MattingResultPreviewPage extends StatefulWidget {
  const MattingResultPreviewPage({
    super.key,
    required this.pngBytes,
  });

  final Uint8List pngBytes;

  @override
  State<MattingResultPreviewPage> createState() =>
      _MattingResultPreviewPageState();
}

class _MattingResultPreviewPageState extends State<MattingResultPreviewPage> {
  bool _saving = false;

  Future<void> _saveToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await Gal.requestAccess();
      if (!ok) {
        if (mounted) {
          showAppSnackBar(
            context,
            message: '需要相册权限才能保存',
            icon: Icons.lock_outline,
          );
        }
        return;
      }
      final name = 'DocScan_抠图_${DateTime.now().millisecondsSinceEpoch}.png';
      await Gal.putImageBytes(widget.pngBytes, name: name);
      if (mounted) {
        showAppSnackBar(
          context,
          message: '已保存到相册',
          icon: Icons.check_circle_outline,
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '保存失败：${e.type}',
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '保存失败：$e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 抠图结果'),
        actions: [
          IconButton(
            tooltip: '保存到相册',
            onPressed: _saving ? null : _saveToGallery,
            icon: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Icon(Icons.save_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Hint ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '双指缩放查看透明边缘细节',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Preview ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          size: Size(
                              constraints.maxWidth, constraints.maxHeight),
                          painter: const _CheckerboardPainter(cell: 14),
                        ),
                        Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Image.memory(
                              widget.pngBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Save button ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveToGallery,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_saving ? '保存中…' : '保存到相册'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({this.cell = 10});

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFF0F0F0);
    final dark = Paint()..color = const Color(0xFFDCDCDC);
    var y = 0.0;
    while (y < size.height) {
      var x = 0.0;
      while (x < size.width) {
        final ix = (x / cell).floor();
        final iy = (y / cell).floor();
        final paint = (ix + iy).isEven ? light : dark;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
        x += cell;
      }
      y += cell;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
