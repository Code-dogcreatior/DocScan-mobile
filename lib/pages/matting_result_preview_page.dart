import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';
import '../widgets/checkerboard_painter.dart';

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
                      strokeWidth: 2.4,
                      color: cs.primary,
                    ),
                  )
                : const Icon(Icons.save_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.palette.infoContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 16, color: context.palette.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '双指缩放查看透明边缘细节',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.onInfoContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: AppTokens.elev1,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const CheckerboardBackground(cellSize: 14),
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          PrimaryActionButton(
            label: _saving ? '保存中…' : '保存到相册',
            icon: Icons.download_rounded,
            loading: _saving,
            onPressed: _saveToGallery,
          ),
        ],
      ),
    );
  }
}
