import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_feedback.dart';

/// 非「扫描」模式拍照后的占位预览（业务处理后续再接）。
class PlainCapturePreviewPage extends StatelessWidget {
  const PlainCapturePreviewPage({
    super.key,
    required this.imageBytes,
    required this.modeTitle,
  });

  final Uint8List imageBytes;
  final String modeTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(modeTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  '当前模式暂提供照片预览，你可以先保存或分享结果。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.memory(imageBytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: modeTitle));
                        showAppSnackBar(
                          context,
                          message: '模式名称已复制',
                          icon: Icons.check_circle_outline,
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('复制模式名'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        showAppSnackBar(
                          context,
                          message: '保存/分享功能即将上线',
                          icon: Icons.info_outline,
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('保存/分享'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
