import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../services/id_photo_processor.dart';
import '../services/share_service.dart';
import '../widgets/app_feedback.dart';

enum _IdBackground {
  white(255, 255, 255, '白色'),
  blue(67, 142, 219, '蓝色'),
  red(210, 60, 60, '红色');

  const _IdBackground(this.r, this.g, this.b, this.label);
  final int r;
  final int g;
  final int b;
  final String label;
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
    final preview = _layout.id == 'none' ? _singleJpeg : (_layoutJpeg ?? _singleJpeg);
    return Scaffold(
      appBar: AppBar(title: const Text('证件照')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _IdBackground.values
                      .map(
                        (e) => ChoiceChip(
                          label: Text(e.label),
                          selected: _background == e,
                          onSelected: (_) {
                            setState(() => _background = e);
                            _rebuildOutputs();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IdPhotoSizePreset>(
                  value: _size,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: '证件照尺寸',
                  ),
                  items: IdPhotoProcessor.presets
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _size = v);
                    _rebuildOutputs();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自定义像素尺寸'),
                        value: _customSize,
                        onChanged: (v) {
                          setState(() => _customSize = v ?? false);
                          _rebuildOutputs();
                        },
                      ),
                    ),
                    if (_customSize) ...[
                      SizedBox(
                        width: 86,
                        child: TextField(
                          controller: _wCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '宽'),
                          onSubmitted: (_) => _rebuildOutputs(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 86,
                        child: TextField(
                          controller: _hCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '高'),
                          onSubmitted: (_) => _rebuildOutputs(),
                        ),
                      ),
                    ],
                  ],
                ),
                DropdownButtonFormField<IdPhotoLayoutPreset>(
                  value: _layout,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: '排版导出',
                  ),
                  items: IdPhotoProcessor.layoutPresets
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _layout = v);
                    _rebuildOutputs();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _rendering || preview == null
                  ? const CircularProgressIndicator()
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Image.memory(preview, fit: BoxFit.contain),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving || preview == null
                          ? null
                          : () => _saveToGallery(
                                preview,
                                _layout.id == 'none' ? 'DocScan-证件照' : 'DocScan-证件照排版',
                              ),
                      icon: const Icon(Icons.save_alt_rounded),
                      label: Text(_saving ? '保存中…' : '保存到相册'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: preview == null ? null : () => _share(preview, 'DocScan-id-photo'),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('分享'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
