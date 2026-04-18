import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/scan_style_processor.dart';
import '../widgets/app_feedback.dart';

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
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存至 ${file.path}',
      icon: Icons.check_circle_outline,
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
          // ── Style selector ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '显示风格',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_StyleDisplay>(
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
                    selected: {_mode},
                    onSelectionChanged: _onDisplayModeChanged,
                  ),
                ),
                if (_mode == _StyleDisplay.smartHd) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: cs.primary),
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
            ),
          ),

          // ── Image preview ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '正在处理…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Save button ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _applyingSmartHd ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('保存结果'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
