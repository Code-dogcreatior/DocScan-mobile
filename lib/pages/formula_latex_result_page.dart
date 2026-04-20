import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../config/app_env.dart';
import '../services/latex_ocr_service.dart';
import '../services/network_reachability.dart';
import '../widgets/app_feedback.dart';

/// 公式识别结果：TeX 预览、LaTeX 源码与复制；联网时可请求「解题 / 公式说明」。
class FormulaLatexResultPage extends StatefulWidget {
  const FormulaLatexResultPage({
    super.key,
    required this.latex,
    this.recognitionImageBytes,
  });

  final String latex;
  final Uint8List? recognitionImageBytes;

  @override
  State<FormulaLatexResultPage> createState() => _FormulaLatexResultPageState();
}

class _FormulaLatexResultPageState extends State<FormulaLatexResultPage> {
  bool _solveLoading = false;
  FormulaSolveResult? _solveResult;
  String? _solveError;

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

  Future<void> _runSolve() async {
    if (!AppEnv.hasOpenRouterKey) {
      showAppSnackBar(
        context,
        message: '未配置 OPENROUTER_API_KEY（见 env/app.example.env）',
        icon: Icons.vpn_key_off_outlined,
      );
      return;
    }
    final online = await NetworkReachability.instance.quickCheck();
    if (!mounted) return;
    if (!online) {
      showAppSnackBar(
        context,
        message: '当前无网络连接，请连接 Wi‑Fi 或蜂窝数据后重试',
        icon: Icons.wifi_off_rounded,
      );
      return;
    }

    setState(() {
      _solveLoading = true;
      _solveError = null;
    });
    try {
      final cleaned =
          LatexOutputSanitizer.stripModelArtifacts(widget.latex.trim());
      final result = await LatexOcrService.instance.solveOrExplainFromHint(
        latexHint: cleaned,
        imageJpegBytes: widget.recognitionImageBytes,
      );
      if (!mounted) return;
      setState(() {
        _solveResult = result;
        _solveLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _solveLoading = false;
        _solveError = e.toString();
      });
    }
  }

  Widget _mathBlock(BuildContext context, String expr) {
    final cs = Theme.of(context).colorScheme;
    final e = _expressionForRender(expr);
    if (e.isEmpty) {
      return Text(
        '（无内容可渲染）',
        style: TextStyle(color: cs.onSurfaceVariant),
      );
    }
    return Math.tex(
      e,
      mathStyle: MathStyle.display,
      textStyle: TextStyle(
        fontSize: 20,
        color: cs.onSurface,
      ),
      onErrorFallback: (err) => Text(
        '渲染失败：${err.messageWithType}',
        style: TextStyle(fontSize: 13, color: cs.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cleaned = LatexOutputSanitizer.stripModelArtifacts(widget.latex);
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

              if (widget.recognitionImageBytes != null &&
                  widget.recognitionImageBytes!.isNotEmpty) ...[
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
                          widget.recognitionImageBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _SectionCard(
                title: '公式预览',
                icon: Icons.functions_rounded,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 100, maxHeight: 260),
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
              const SizedBox(height: 16),

              FilledButton.tonalIcon(
                onPressed: (_solveLoading || cleaned.isEmpty)
                    ? null
                    : _runSolve,
                icon: _solveLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _solveLoading ? '正在请求…' : '智能解题 / 公式说明（联网）',
                ),
              ),
              if (_solveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _solveError!,
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
              ],
              if (_solveResult != null) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: _solveResult!.solvable ? '解题步骤' : '公式说明',
                  subtitle: _solveResult!.solvable
                      ? '由云端模型生成，与 ONNX 独立'
                      : '当前式子不便给出数值解，以下为含义说明',
                  icon: _solveResult!.solvable
                      ? Icons.format_list_numbered_rounded
                      : Icons.info_outline_rounded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_solveResult!.solvable &&
                            _solveResult!.steps.isNotEmpty)
                          ..._solveResult!.steps.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (s.title.trim().isNotEmpty)
                                    Text(
                                      s.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (s.latex.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: _mathBlock(context, s.latex),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        if (_solveResult!.summaryZh.trim().isNotEmpty) ...[
                          if (_solveResult!.solvable &&
                              _solveResult!.steps.isNotEmpty)
                            const Divider(height: 24),
                          Text(
                            _solveResult!.solvable ? '小结' : '说明',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _solveResult!.summaryZh,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                        if (_solveResult!
                            .formulaExplanationLatex
                            .trim()
                            .isNotEmpty) ...[
                          if (_solveResult!.summaryZh.trim().isNotEmpty ||
                              (_solveResult!.solvable &&
                                  _solveResult!.steps.isNotEmpty))
                            const SizedBox(height: 16),
                          Text(
                            '公式辑要',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _mathBlock(
                              context,
                              _solveResult!.formulaExplanationLatex,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    cleaned.isEmpty ? null : () => _copy(context, cleaned),
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
                      maxLines: 2,
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
