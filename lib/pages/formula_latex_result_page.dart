import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../services/latex_ocr_service.dart';
import '../widgets/app_feedback.dart';

/// 公式识别结果：TeX 预览、LaTeX 源码与复制。
class FormulaLatexResultPage extends StatelessWidget {
  const FormulaLatexResultPage({
    super.key,
    required this.latex,
    this.recognitionImageBytes,
  });

  final String latex;
  final Uint8List? recognitionImageBytes;

  static String _expressionForRender(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return t;
    if (t.startsWith(r'$$') && t.endsWith(r'$$') && t.length > 3) {
      t = t.substring(2, t.length - 2).trim();
    } else if (t.startsWith(r'$') && t.endsWith(r'$') && t.length > 1) {
      t = t.substring(1, t.length - 1).trim();
    }
    if (t.startsWith(r'\(') && t.endsWith(r'\)')) {
      t = t.substring(2, t.length - 2).trim();
    }
    if (t.startsWith(r'\[') && t.endsWith(r'\]')) {
      t = t.substring(2, t.length - 2).trim();
    }
    return t;
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: '已复制到剪贴板',
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cleaned = LatexOutputSanitizer.stripModelArtifacts(latex);
    final expr = _expressionForRender(cleaned);

    return Scaffold(
      appBar: AppBar(
        title: const Text('公式识别结果'),
        actions: [
          IconButton(
            tooltip: '复制 LaTeX',
            onPressed: cleaned.isEmpty ? null : () => _copy(context, cleaned),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Debug image (collapsible) ──
              if (recognitionImageBytes != null &&
                  recognitionImageBytes!.isNotEmpty) ...[
                _SectionCard(
                  title: '识别用图像',
                  subtitle: '裁剪并二值化后的输入',
                  icon: Icons.image_outlined,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.memory(
                          recognitionImageBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Formula preview ──
              _SectionCard(
                title: '公式预览',
                icon: Icons.functions_rounded,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 100, maxHeight: 260),
                  child: cleaned.isEmpty || expr.isEmpty
                      ? Center(
                          child: Text(
                            '（无内容可渲染）',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                expr,
                                mathStyle: MathStyle.display,
                                textStyle: TextStyle(
                                  fontSize: 22,
                                  color: cs.onSurface,
                                ),
                                onErrorFallback: (err) => Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    '渲染失败，请参考下方源码\n${err.messageWithType}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: cs.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // ── LaTeX source ──
              _SectionCard(
                title: 'LaTeX 源码',
                icon: Icons.code_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    cleaned.isEmpty ? '（无输出）' : cleaned,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Copy button ──
              FilledButton.icon(
                onPressed: cleaned.isEmpty ? null : () => _copy(context, cleaned),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('复制 LaTeX'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable section card with title row.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
