import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/scan_document_draft.dart';
import '../services/pdf_export_service.dart';
import '../services/recent_documents_service.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import 'camera_scan_page.dart';

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
      final pages = _draft.pages.map((e) => e.jpegBytes).toList();
      final file = await _pdfExportService.exportJpegPages(pages: pages);
      if (!mounted) return;
      await RecentDocumentsService.save(pages: pages);
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
      final pages = _draft.pages.map((e) => e.jpegBytes).toList();
      final file = await _pdfExportService.exportJpegPages(pages: pages);
      if (!mounted) return;
      await RecentDocumentsService.save(pages: pages);
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
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('多页文档'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Text(
                  '${_draft.pages.length} 页',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _AddPageButton(
                    icon: Icons.photo_library_rounded,
                    label: '从相册添加',
                    onPressed: _busy ? null : _addFromGallery,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AddPageButton(
                    icon: Icons.photo_camera_rounded,
                    label: '继续拍摄',
                    onPressed: _busy ? null : _continueCaptureFromCamera,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _draft.pages.isEmpty
                ? const EmptyState(
                    icon: Icons.description_outlined,
                    title: '还没有页面',
                    subtitle: '点击上方按钮添加第一页',
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: _draft.pages.length,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 6,
                        color: Colors.transparent,
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd),
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _draft.pages.removeAt(oldIndex);
                        _draft.pages.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final p = _draft.pages[index];
                      return _PageCard(
                        key: ValueKey(p.id),
                        index: index,
                        reorderIndex: index,
                        bytes: p.jpegBytes,
                        canDelete: _draft.pages.length > 1,
                        onDelete: () =>
                            setState(() => _draft.pages.removeAt(index)),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryActionButton(
            label: _busy ? '处理中…' : '导出 PDF',
            icon: Icons.picture_as_pdf_rounded,
            loading: _busy,
            onPressed: _busy ? null : _exportPdfOnly,
          ),
          PrimaryActionButton(
            label: '导出并分享',
            icon: Icons.ios_share_rounded,
            onPressed: _busy ? null : _exportAndSharePdf,
          ),
        ],
      ),
    );
  }
}

class _AddPageButton extends StatelessWidget {
  const _AddPageButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: enabled
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.index,
    required this.reorderIndex,
    required this.bytes,
    required this.canDelete,
    required this.onDelete,
  });

  final int index;
  final int reorderIndex;
  final Uint8List bytes;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: Image.memory(
                bytes,
                width: 56,
                height: 72,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '第 ${index + 1} 页',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.drag_handle_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '长按拖拽排序',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '删除此页',
              onPressed: canDelete ? onDelete : null,
              icon: Icon(Icons.delete_outline_rounded,
                  color: canDelete ? context.palette.danger : cs.outline),
            ),
            ReorderableDragStartListener(
              index: reorderIndex,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator_rounded,
                    color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
