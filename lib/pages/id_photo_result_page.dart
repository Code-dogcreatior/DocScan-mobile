import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../services/id_photo_processor.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';

enum _IdBackground {
  white(255, 255, 255, '白色', Color(0xFFFFFFFF)),
  blue(67, 142, 219, '蓝色', Color(0xFF438EDB)),
  red(210, 60, 60, '红色', Color(0xFFD23C3C));

  const _IdBackground(this.r, this.g, this.b, this.label, this.color);
  final int r;
  final int g;
  final int b;
  final String label;
  final Color color;
}

class IdPhotoResultPage extends StatefulWidget {
  const IdPhotoResultPage({
    super.key,
    required this.foregroundPngBytes,
  });

  final Uint8List foregroundPngBytes;

  @override
  State<IdPhotoResultPage> createState() => _IdPhotoResultPageState();
}

class _IdPhotoResultPageState extends State<IdPhotoResultPage> {
  final IdPhotoProcessor _processor = IdPhotoProcessor();
  final ShareService _shareService = ShareService();
  _IdBackground _background = _IdBackground.white;
  IdPhotoSizePreset _size = IdPhotoProcessor.presets.first;
  IdPhotoLayoutPreset _layout = IdPhotoProcessor.layoutPresets.first;
  bool _customSize = false;
  final TextEditingController _wCtrl = TextEditingController(text: '295');
  final TextEditingController _hCtrl = TextEditingController(text: '413');
  bool _rendering = false;
  bool _saving = false;
  Uint8List? _singleJpeg;
  Uint8List? _layoutJpeg;

  @override
  void initState() {
    super.initState();
    _rebuildOutputs();
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  Future<void> _rebuildOutputs() async {
    setState(() => _rendering = true);
    try {
      var w = _size.widthPx;
      var h = _size.heightPx;
      if (_customSize) {
        w = int.tryParse(_wCtrl.text.trim()) ?? w;
        h = int.tryParse(_hCtrl.text.trim()) ?? h;
      }
      w = w.clamp(100, 4000);
      h = h.clamp(100, 4000);
      final single = _processor.composeSolidBackgroundJpeg(
        foregroundPng: widget.foregroundPngBytes,
        outWidth: w,
        outHeight: h,
        bgR: _background.r,
        bgG: _background.g,
        bgB: _background.b,
      );
      Uint8List? layoutBytes;
      if (_layout.id != 'none') {
        layoutBytes = _processor.composeLayoutJpeg(
          singlePhotoJpeg: single,
          layout: _layout,
        );
      }
      if (!mounted) return;
      setState(() {
        _singleJpeg = single;
        _layoutJpeg = layoutBytes;
      });
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '证件照生成失败：$e');
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  Future<void> _saveToGallery(Uint8List bytes, String prefix) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await Gal.requestAccess();
      if (!ok) {
        if (mounted) showAppSnackBar(context, message: '需要相册权限才能保存');
        return;
      }
      final name = '$prefix-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Gal.putImageBytes(bytes, name: name);
      if (mounted) showAppSnackBar(context, message: '已保存到相册');
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(Uint8List bytes, String prefix) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$prefix-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    await _shareService.shareFile(file, text: 'DocScan 证件照');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final preview = _layout.id == 'none' ? _singleJpeg : (_layoutJpeg ?? _singleJpeg);
    return Scaffold(
      appBar: AppBar(title: const Text('证件照')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ControlLabel(text: '背景色'),
                  const SizedBox(height: 10),
                  Row(
                    children: _IdBackground.values
                        .map((bg) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _ColorSwatch(
                                color: bg.color,
                                label: bg.label,
                                selected: _background == bg,
                                onTap: () {
                                  setState(() => _background = bg);
                                  _rebuildOutputs();
                                },
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  _ControlLabel(text: '证件照尺寸'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: IdPhotoProcessor.presets
                        .map((e) => _PillChip(
                              label: e.label,
                              selected: _size == e,
                              onTap: () {
                                setState(() {
                                  _size = e;
                                  _customSize = false;
                                });
                                _rebuildOutputs();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _CustomSizeRow(
                    enabled: _customSize,
                    onToggle: (v) {
                      setState(() => _customSize = v);
                      _rebuildOutputs();
                    },
                    wCtrl: _wCtrl,
                    hCtrl: _hCtrl,
                    onCommit: _rebuildOutputs,
                  ),
                  const SizedBox(height: 18),
                  _ControlLabel(text: '排版导出'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: IdPhotoProcessor.layoutPresets
                        .map((e) => _PillChip(
                              label: e.label,
                              selected: _layout == e,
                              onTap: () {
                                setState(() => _layout = e);
                                _rebuildOutputs();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  _ControlLabel(text: '预览'),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: AppTokens.elev1,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _rendering || preview == null
                          ? Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: cs.primary,
                                ),
                              ),
                            )
                          : InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 5,
                              child: Image.memory(preview, fit: BoxFit.contain),
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
            label: _saving ? '保存中…' : '保存到相册',
            icon: Icons.save_alt_rounded,
            loading: _saving,
            onPressed: preview == null
                ? null
                : () => _saveToGallery(
                      preview,
                      _layout.id == 'none' ? 'DocScan-证件照' : 'DocScan-证件照排版',
                    ),
          ),
          PrimaryActionButton(
            label: '分享',
            icon: Icons.ios_share_rounded,
            onPressed:
                preview == null ? null : () => _share(preview, 'DocScan-id-photo'),
          ),
        ],
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : AppTokens.elev1,
              ),
              child: selected
                  ? Icon(Icons.check_rounded, color: _contrast(color), size: 20)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _contrast(Color c) {
    final luminance = c.computeLuminance();
    return luminance > 0.6 ? Colors.black87 : Colors.white;
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomSizeRow extends StatelessWidget {
  const _CustomSizeRow({
    required this.enabled,
    required this.onToggle,
    required this.wCtrl,
    required this.hCtrl,
    required this.onCommit,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController wCtrl;
  final TextEditingController hCtrl;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '自定义像素尺寸',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '宽 (px)',
                      isDense: true,
                    ),
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: hCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '高 (px)',
                      isDense: true,
                    ),
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
