import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/camera_capture_mode.dart';
import '../models/recent_document.dart';
import '../services/pdf_export_service.dart';
import '../services/recent_documents_service.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';
import 'camera_scan_page.dart';
import 'document_detail_page.dart';
import 'main_shell_page.dart';
import 'scan_document_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  late Future<List<RecentDocument>> _docsFuture;
  final _picker = ImagePicker();
  final _pdfService = PdfExportService();
  final _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _docsFuture = RecentDocumentsService.list();
  }

  void _refresh() {
    setState(() => _docsFuture = RecentDocumentsService.list());
  }

  Future<void> _openDocument(RecentDocument doc) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DocumentDetailPage(doc: doc),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _shareDocument(RecentDocument doc) async {
    if (!doc.hasFullPages) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '此条目为旧版本，只有缩略图，无法分享',
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

  Future<void> _renameDocument(RecentDocument doc) async {
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

  void _onDocLongPress(RecentDocument doc) {
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
                _renameDocument(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('分享 PDF'),
              onTap: () {
                Navigator.of(ctx).pop();
                _shareDocument(doc);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.palette.danger),
              title: Text('删除',
                  style: TextStyle(color: context.palette.danger)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await RecentDocumentsService.delete(doc.id);
                if (mounted) _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFFFA000), size: 28),
                    const SizedBox(width: 12),
                    Text('DocScan Pro',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                ..._kProFeatures.map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: cs.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.$1,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(f.$2,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('敬请期待'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCamera(CameraCaptureMode mode) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => CameraScanPage(initialMode: mode),
          ),
        )
        .then((_) => _refresh());
  }

  Future<void> _importFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanDocumentPage(initialPageJpegBytes: bytes),
      ),
    ).then((_) => _refresh());
  }

  // ── Tool definitions ────────────────────────────────────────────

  void _onToolTap(int index) {
    switch (index) {
      case 0:
        _openCamera(CameraCaptureMode.scan);
      case 1:
        _importFromGallery();
      case 2:
        _openCamera(CameraCaptureMode.idPhoto);
      case 3:
        _openCamera(CameraCaptureMode.textRecognition);
      case 4:
        _openCamera(CameraCaptureMode.formulaRecognition);
      case 5:
        _openCamera(CameraCaptureMode.translate);
      case 6:
        _openCamera(CameraCaptureMode.aiCutout);
      case 7:
        _openCamera(CameraCaptureMode.aiErase);
    }
  }

  static const _tools = [
    _Tool(Icons.document_scanner_rounded, '智能扫描', 0),
    _Tool(Icons.photo_library_rounded, '导入图片', 1),
    _Tool(Icons.badge_rounded, '证件照', 2),
    _Tool(Icons.text_fields_rounded, '文字识别', 3),
    _Tool(Icons.functions_rounded, '公式识别', 4),
    _Tool(Icons.translate_rounded, '翻译', 5),
    _Tool(Icons.auto_awesome_rounded, 'AI 抠图', 6),
    _Tool(Icons.healing_rounded, 'AI 擦除', 7),
  ];

  /// (标题, 副文) —— Pro 特性展示。
  static const List<(String, String)> _kProFeatures = [
    ('去广告 · 无打扰', '全局移除插入广告与引导弹窗'),
    ('去水印导出', '导出 PDF / 分享图片不带品牌水印'),
    ('批量 OCR', '一次处理整本多页扫描件，导出可复制文字'),
    ('云同步（规划中）', '跨设备同步最近文档与设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── 品牌 Header ───────────────────────────────────────
            _BrandHeader(onProTap: _showProSheet),

            // ── 统计条 ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: FutureBuilder<List<RecentDocument>>(
                future: _docsFuture,
                builder: (_, snap) => _StatsStrip(docs: snap.data ?? const []),
              ),
            ),

            // ── 搜索栏 (pinned) ────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                onTap: () => MainShellPage.jumpToTab(1),
              ),
            ),

            // ── 快捷工具 ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionLabel(
                title: '快捷工具',
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ToolTile(
                    tool: _tools[i],
                    onTap: () => _onToolTap(i),
                  ),
                  childCount: _tools.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
              ),
            ),

            // ── 推广横幅 ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _PromoBanner(onTap: _showProSheet),
              ),
            ),

            // ── 最近文档 ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionLabel(
                title: '最近文档',
                trailing: '查看全部',
                onTrailingTap: () => MainShellPage.jumpToTab(1),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<RecentDocument>>(
                future: _docsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final docs = snap.data ?? [];
                  if (docs.isEmpty) {
                    return _EmptyRecentDocs();
                  }
                  return _RecentDocsList(
                    docs: docs.take(5).toList(),
                    onTap: _openDocument,
                    onLongPress: _onDocLongPress,
                    onShare: _shareDocument,
                    onDeleted: (id) async {
                      await RecentDocumentsService.delete(id);
                      _refresh();
                    },
                  );
                },
              ),
            ),

            // ── 底部留白（BottomAppBar + FAB）──────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Brand header ─────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onProTap});
  final VoidCallback onProTap;
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTokens.heroGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
            child: Row(
              children: [
                // 品牌图标
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'DocScan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '智能文档扫描 · AI 增强',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pro 胶囊
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onProTap,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA000),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusPill),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFFA000).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// ── Search bar (pinned persistent header) ────────────────────────────────────

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  _SearchBarDelegate({required this.onTap});
  final VoidCallback onTap;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '搜索功能：扫描 · 翻译 · 证件照 · 抠图',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchBarDelegate old) => false;
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 8),
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trailingWidget = trailing == null
        ? null
        : (onTrailingTap != null
            ? InkWell(
                onTap: onTrailingTap,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trailing!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: cs.primary),
                    ],
                  ),
                ),
              )
            : Text(
                trailing!,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ));
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppTokens.heroGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (trailingWidget != null) ...[
            const Spacer(),
            trailingWidget,
          ],
        ],
      ),
    );
  }
}

// ── Tool data & tile ──────────────────────────────────────────────────────────

class _Tool {
  const _Tool(this.icon, this.label, this.colorIndex);
  final IconData icon;
  final String label;
  final int colorIndex;
}

class _ToolTile extends StatefulWidget {
  const _ToolTile({required this.tool, required this.onTap});
  final _Tool tool;
  final VoidCallback onTap;

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.featurePalette[widget.tool.colorIndex];
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.93),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(widget.tool.icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              widget.tool.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Promo banner ──────────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: _buildInner(),
      ),
    );
  }

  Widget _buildInner() {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        gradient: AppTokens.accentGradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        boxShadow: AppTokens.elev2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 右侧装饰圆
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFA000),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pro 会员限时优惠',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '去广告 · 无水印 · 批量 OCR · 云同步',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: const Text(
                    '了解更多',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF512DA8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent docs list ──────────────────────────────────────────────────────────

class _EmptyRecentDocs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTokens.heroGradient,
                shape: BoxShape.circle,
                boxShadow: AppTokens.elev2,
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '开始你的第一次扫描',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击下方相机按钮，或从相册导入',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 28, color: cs.primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _RecentDocsList extends StatelessWidget {
  const _RecentDocsList({
    required this.docs,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onDeleted,
  });
  final List<RecentDocument> docs;
  final void Function(RecentDocument doc) onTap;
  final void Function(RecentDocument doc) onLongPress;
  final Future<void> Function(RecentDocument doc) onShare;
  final void Function(String id) onDeleted;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _RecentDocCard(
        doc: docs[i],
        onTap: () => onTap(docs[i]),
        onLongPress: () => onLongPress(docs[i]),
        onShare: () => onShare(docs[i]),
        onDelete: () => onDeleted(docs[i].id),
      ),
    );
  }
}

class _RecentDocCard extends StatelessWidget {
  const _RecentDocCard({
    required this.doc,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onDelete,
  });
  final RecentDocument doc;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final thumbFile = File(doc.thumbnailPath);

    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                child: thumbFile.existsSync()
                    ? Image.file(
                        thumbFile,
                        width: 52,
                        height: 66,
                        fit: BoxFit.cover,
                        cacheWidth: 104,
                      )
                    : Container(
                        width: 52,
                        height: 66,
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.description_outlined,
                            color: cs.onSurfaceVariant, size: 24),
                      ),
              ),
              const SizedBox(width: 14),
              // 文字区
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doc.pageCount} 页 · ${doc.sizeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 操作 chips
                    Row(
                      children: [
                        _DocChip(
                          label: '分享',
                          icon: Icons.ios_share_rounded,
                          onTap: onShare,
                        ),
                        const SizedBox(width: 6),
                        _DocChip(
                          label: '删除',
                          icon: Icons.delete_outline_rounded,
                          danger: true,
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.docs});
  final List<RecentDocument> docs;

  @override
  Widget build(BuildContext context) {
    final totalDocs = docs.length;
    final totalPages = docs.fold<int>(0, (s, d) => s + d.pageCount);
    final totalBytes = docs.fold<int>(0, (s, d) => s + d.sizeBytes);
    final sizeLabel = totalBytes < 1024 * 1024
        ? '${(totalBytes / 1024).toStringAsFixed(0)} KB'
        : '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(child: _StatCard(value: '$totalDocs', label: '份文档', icon: Icons.folder_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$totalPages', label: '页扫描', icon: Icons.auto_stories_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: sizeLabel, label: '已占用', icon: Icons.storage_rounded)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: cs.primary.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final color = danger ? palette.danger : cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
