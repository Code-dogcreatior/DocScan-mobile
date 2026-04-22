import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/camera_capture_mode.dart';
import '../models/recent_document.dart';
import '../services/pdf_export_service.dart';
import '../services/recent_documents_service.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import 'camera_scan_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.doc});

  final RecentDocument doc;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  late RecentDocument _doc;
  late Future<List<Uint8List>> _pagesFuture;
  final _pageController = PageController();
  int _currentPage = 0;
  bool _busy = false;

  final _pdfService = PdfExportService();
  final _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
    _pagesFuture = RecentDocumentsService.loadPages(_doc.id);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reloadPages() async {
    setState(() {
      _pagesFuture = RecentDocumentsService.loadPages(_doc.id);
    });
  }

  Future<void> _sharePdf(List<Uint8List> pages) async {
    if (_busy || pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final file = await _pdfService.exportJpegPages(
        pages: pages,
        fileNamePrefix: _doc.title,
      );
      if (!mounted) return;
      await _shareService.shareFile(file, text: _doc.title, subject: _doc.title);
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '分享失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueCapture() async {
    if (_busy) return;
    final captured = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute<Uint8List?>(
        builder: (_) => const CameraScanPage(
          initialMode: CameraCaptureMode.scan,
          returnScanResult: true,
        ),
      ),
    );
    if (!mounted || captured == null || captured.isEmpty) return;
    final updated = await RecentDocumentsService.appendPages(
      id: _doc.id,
      pages: [captured],
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _doc = updated);
      await _reloadPages();
      if (!mounted) return;
      showAppSnackBar(context, message: '已添加第 ${updated.pageCount} 页');
    }
  }

  Future<void> _renameDocument() async {
    final ctrl = TextEditingController(text: _doc.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新的文档名称'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (next != null && next.isNotEmpty && next != _doc.title) {
      await RecentDocumentsService.rename(_doc.id, next);
      if (!mounted) return;
      setState(() => _doc = _doc.copyWith(title: next));
    }
  }

  Future<void> _deleteDocument() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定删除「${_doc.title}」？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('删除', style: TextStyle(color: context.palette.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RecentDocumentsService.delete(_doc.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.title, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'rename':
                  _renameDocument();
                  break;
                case 'delete':
                  _deleteDocument();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              const PopupMenuItem(value: 'delete', child: Text('删除文档')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final pages = snapshot.data ?? const <Uint8List>[];
          if (pages.isEmpty) {
            return EmptyState(
              icon: Icons.image_not_supported_outlined,
              title: '无法打开该文档',
              subtitle: _doc.hasFullPages
                  ? '页面文件可能被清理，请删除后重新扫描'
                  : '此文档为旧版本条目，仅有缩略图。请重新扫描生成完整文档。',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currentPage + 1} / ${pages.length} 页',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _doc.sizeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        boxShadow: AppTokens.elev1,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.memory(
                            pages[i],
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<Uint8List>>(
        future: _pagesFuture,
        builder: (context, snap) {
          final pages = snap.data ?? const <Uint8List>[];
          final canAct = pages.isNotEmpty;
          return BottomActionBar(
            children: [
              SecondaryActionButton(
                label: '继续拍摄',
                icon: Icons.photo_camera_rounded,
                onPressed: (_busy || !_doc.hasFullPages) ? null : _continueCapture,
              ),
              PrimaryActionButton(
                label: '导出并分享',
                icon: Icons.ios_share_rounded,
                loading: _busy,
                onPressed: (_busy || !canAct) ? null : () => _sharePdf(pages),
              ),
            ],
          );
        },
      ),
    );
  }
}
