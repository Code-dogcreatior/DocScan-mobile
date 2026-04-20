import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/scan_document_draft.dart';
import 'camera_scan_page.dart';
import '../services/pdf_export_service.dart';
import '../services/share_service.dart';
import '../widgets/app_feedback.dart';

class ScanDocumentPage extends StatefulWidget {
  const ScanDocumentPage({
    super.key,
    required this.initialPageJpegBytes,
  });

  final Uint8List initialPageJpegBytes;

  @override
  State<ScanDocumentPage> createState() => _ScanDocumentPageState();
}

class _ScanDocumentPageState extends State<ScanDocumentPage> {
  final ImagePicker _picker = ImagePicker();
  final PdfExportService _pdfExportService = PdfExportService();
  final ShareService _shareService = ShareService();
  bool _busy = false;
  final ScanDocumentDraft _draft = ScanDocumentDraft(pages: <ScanDocumentPageItem>[]);

  @override
  void initState() {
    super.initState();
    _draft.pages.add(
      ScanDocumentPageItem(
        id: _newPageId(),
        jpegBytes: widget.initialPageJpegBytes,
      ),
    );
  }

  String _newPageId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _addFromGallery() async {
    if (_busy) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (!mounted || picked == null) return;
    final raw = await picked.readAsBytes();
    final jpg = _normalizeToJpeg(raw);
    if (jpg == null) {
      if (mounted) {
        showAppSnackBar(context, message: '无法读取图片，请选择其他图片');
      }
      return;
    }
    setState(() {
      _draft.pages.add(
        ScanDocumentPageItem(id: _newPageId(), jpegBytes: jpg),
      );
    });
  }

  Future<void> _continueCaptureFromCamera() async {
    if (_busy) return;
    final pageBytes = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => const CameraScanPage(
          returnScanResult: true,
        ),
      ),
    );
    if (!mounted || pageBytes == null || pageBytes.isEmpty) return;
    setState(() {
      _draft.pages.add(
        ScanDocumentPageItem(id: _newPageId(), jpegBytes: pageBytes),
      );
    });
    showAppSnackBar(context, message: '已添加新页面');
  }

  Uint8List? _normalizeToJpeg(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    final baked = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(baked, quality: 96));
  }

  Future<void> _exportAndSharePdf() async {
    if (_busy || _draft.pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final file = await _pdfExportService.exportJpegPages(
        pages: _draft.pages.map((e) => e.jpegBytes).toList(),
      );
      if (!mounted) return;
      await _shareService.shareFile(
        file,
        text: 'DocScan 多页扫描 PDF',
        subject: 'DocScan 扫描件',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: 'PDF 导出失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportPdfOnly() async {
    if (_busy || _draft.pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final file = await _pdfExportService.exportJpegPages(
        pages: _draft.pages.map((e) => e.jpegBytes).toList(),
      );
      if (!mounted) return;
      showAppSnackBar(context, message: 'PDF 已生成：${file.path}');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: 'PDF 导出失败：$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('多页文档')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _addFromGallery,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('添加页（相册）'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _continueCaptureFromCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('继续拍摄'),
                ),
                const SizedBox(width: 10),
                Text(
                  '共 ${_draft.pages.length} 页',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: _draft.pages.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _draft.pages.removeAt(oldIndex);
                  _draft.pages.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final p = _draft.pages[index];
                return Card(
                  key: ValueKey(p.id),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        p.jpegBytes,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                    title: Text('第 ${index + 1} 页'),
                    subtitle: Text('拖拽右侧把手可排序'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '删除此页',
                          onPressed: _draft.pages.length <= 1
                              ? null
                              : () {
                                  setState(() => _draft.pages.removeAt(index));
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _exportPdfOnly,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_busy ? '处理中…' : '导出 PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _exportAndSharePdf,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('导出并分享'),
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
