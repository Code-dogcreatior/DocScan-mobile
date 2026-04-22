import 'dart:io';

import 'package:flutter/material.dart';

import '../models/recent_document.dart';
import '../services/pdf_export_service.dart';
import '../services/recent_documents_service.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import 'document_detail_page.dart';

class TabAllDocumentsPage extends StatefulWidget {
  const TabAllDocumentsPage({super.key});

  @override
  State<TabAllDocumentsPage> createState() => _TabAllDocumentsPageState();
}

class _TabAllDocumentsPageState extends State<TabAllDocumentsPage> {
  late Future<List<RecentDocument>> _docsFuture;
  final _searchCtrl = TextEditingController();
  String _query = '';

  final _pdfService = PdfExportService();
  final _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _docsFuture = RecentDocumentsService.list();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _docsFuture = RecentDocumentsService.list());
  }

  Future<void> _openDoc(RecentDocument doc) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DocumentDetailPage(doc: doc),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _share(RecentDocument doc) async {
    if (!doc.hasFullPages) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '此条目仅有缩略图，无法分享',
          tone: AppFeedbackTone.warning,
        );
      }
      return;
    }
    try {
      final pages = await RecentDocumentsService.loadPages(doc.id);
      if (!mounted || pages.isEmpty) return;
      final file = await _pdfService.exportJpegPages(
        pages: pages,
        fileNamePrefix: doc.title,
      );
      if (!mounted) return;
      await _shareService.shareFile(file, text: doc.title, subject: doc.title);
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '分享失败：$e');
    }
  }

  Future<void> _rename(RecentDocument doc) async {
    final ctrl = TextEditingController(text: doc.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
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
    if (next != null && next.isNotEmpty && next != doc.title) {
      await RecentDocumentsService.rename(doc.id, next);
      if (mounted) _refresh();
    }
  }

  Future<void> _confirmDelete(RecentDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定删除「${doc.title}」？'),
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
      await RecentDocumentsService.delete(doc.id);
      if (mounted) _refresh();
    }
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部文档'),
        content: const Text('将删除全部扫描记录与页面文件，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('清空', style: TextStyle(color: context.palette.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RecentDocumentsService.clearAll();
      if (mounted) _refresh();
    }
  }

  void _showActions(RecentDocument doc) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.of(ctx).pop();
                _rename(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('分享 PDF'),
              onTap: () {
                Navigator.of(ctx).pop();
                _share(doc);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.palette.danger),
              title: Text('删除',
                  style: TextStyle(color: context.palette.danger)),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(doc);
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<RecentDocument>> _groupByMonth(List<RecentDocument> docs) {
    final map = <String, List<RecentDocument>>{};
    for (final d in docs) {
      final key =
          '${d.createdAt.year} 年 ${d.createdAt.month.toString().padLeft(2, '0')} 月';
      map.putIfAbsent(key, () => []).add(d);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('全部文档'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: '搜索文档标题',
                  prefixIcon:
                      Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<RecentDocument>>(
                future: _docsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? const <RecentDocument>[];
                  final filtered = _query.isEmpty
                      ? all
                      : all
                          .where((d) => d.title
                              .toLowerCase()
                              .contains(_query.toLowerCase()))
                          .toList();
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.folder_open_rounded,
                          title: all.isEmpty ? '还没有文档' : '没有匹配结果',
                          subtitle:
                              all.isEmpty ? '点击下方相机按钮开始扫描' : '换个关键词试试',
                        ),
                      ],
                    );
                  }
                  final grouped = _groupByMonth(filtered);
                  final keys = grouped.keys.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: keys.length,
                    itemBuilder: (_, gi) {
                      final key = keys[gi];
                      final items = grouped[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          ...items.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DocumentRow(
                                  doc: d,
                                  onTap: () => _openDoc(d),
                                  onMenu: () => _showActions(d),
                                ),
                              )),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.doc,
    required this.onTap,
    required this.onMenu,
  });
  final RecentDocument doc;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final thumbFile = File(doc.thumbnailPath);
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                child: thumbFile.existsSync()
                    ? Image.file(
                        thumbFile,
                        width: 64,
                        height: 80,
                        fit: BoxFit.cover,
                        cacheWidth: 128,
                      )
                    : Container(
                        width: 64,
                        height: 80,
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.description_outlined,
                            color: cs.onSurfaceVariant, size: 28),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc.pageCount} 页 · ${doc.sizeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(doc.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
