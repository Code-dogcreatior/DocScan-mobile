import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/recent_documents_service.dart';
import '../services/scan_style_processor.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';
import 'scan_document_page.dart';

enum _StyleDisplay { original, smartHd }

class StylePage extends StatefulWidget {
  const StylePage({required this.croppedBytes, super.key});

  final Uint8List croppedBytes;

  @override
  State<StylePage> createState() => _StylePageState();
}

class _StylePageState extends State<StylePage> {
  final ScanStyleProcessor _processor = ScanStyleProcessor();

  _StyleDisplay _mode = _StyleDisplay.original;
  Uint8List? _smartHdBytes;
  bool _applyingSmartHd = false;

  Uint8List get _bytesToShow => _mode == _StyleDisplay.original
      ? widget.croppedBytes
      : (_smartHdBytes ?? widget.croppedBytes);

  Future<void> _onDisplayModeChanged(Set<_StyleDisplay> selection) async {
    final next = selection.single;
    if (next == _StyleDisplay.original) {
      setState(() => _mode = _StyleDisplay.original);
      return;
    }
    if (_applyingSmartHd) return;
    if (_smartHdBytes != null) {
      setState(() => _mode = _StyleDisplay.smartHd);
      return;
    }
    setState(() {
      _applyingSmartHd = true;
      _mode = _StyleDisplay.smartHd;
    });
    final t0 = DateTime.now();
    final out = await _processor.applySmartStyle(widget.croppedBytes);
    if (!mounted) return;
    debugPrint(
      '[StylePage] smartHd apply ${DateTime.now().difference(t0).inMilliseconds}ms',
    );
    setState(() {
      _smartHdBytes = out ?? widget.croppedBytes;
      _applyingSmartHd = false;
    });
  }

  Future<void> _save() async {
    final bytes = _bytesToShow;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    await RecentDocumentsService.save(pages: [bytes]);
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存至 ${file.path}',
      icon: Icons.check_circle_outline,
    );
  }

  void _openMultiPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanDocumentPage(initialPageJpegBytes: _bytesToShow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('扫描结果')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _StyleSelector(
              mode: _mode,
              onChanged: _onDisplayModeChanged,
              processing: _applyingSmartHd,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        color: cs.surfaceContainerHighest,
                        boxShadow: AppTokens.elev2,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(_bytesToShow, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  if (_applyingSmartHd)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                              boxShadow: AppTokens.elev3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  '智能高清处理中…',
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
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
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryActionButton(
            label: '保存单张',
            icon: Icons.save_rounded,
            onPressed: _applyingSmartHd ? null : _save,
          ),
          PrimaryActionButton(
            label: '多页 PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: _applyingSmartHd ? null : _openMultiPage,
          ),
        ],
      ),
    );
  }
}

class _StyleSelector extends StatelessWidget {
  const _StyleSelector({
    required this.mode,
    required this.onChanged,
    required this.processing,
  });

  final _StyleDisplay mode;
  final ValueChanged<Set<_StyleDisplay>> onChanged;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '显示风格',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_StyleDisplay>(
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
              ),
            ),
            segments: const [
              ButtonSegment<_StyleDisplay>(
                value: _StyleDisplay.original,
                label: Text('原图'),
                icon: Icon(Icons.image_outlined, size: 18),
              ),
              ButtonSegment<_StyleDisplay>(
                value: _StyleDisplay.smartHd,
                label: Text('智能高清'),
                icon: Icon(Icons.auto_fix_high_outlined, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: processing ? null : onChanged,
          ),
        ),
        if (mode == _StyleDisplay.smartHd) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '自适应背景去除 · 智能锐化增强',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
