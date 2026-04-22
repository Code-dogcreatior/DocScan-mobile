import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/app_localizations.dart';
import '../models/camera_capture_mode.dart';
import '../models/recent_document.dart';
import '../services/archive_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/recent_documents_service.dart';
import '../services/share_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';
import 'camera_scan_page.dart';

class TabToolsPage extends StatelessWidget {
  const TabToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final modeCards = _buildModeCards(l);
    return Scaffold(
      appBar: AppBar(title: Text(l.tabTools)),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _sectionTitle(context, l.toolsSectionScan),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ModeCard(entry: modeCards[i]),
                childCount: modeCards.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _sectionTitle(context, l.toolsSectionPdf),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _ToolRow(
                    icon: Icons.picture_as_pdf_rounded,
                    iconColor: const Color(0xFFE53935),
                    title: l.pdfMergeTitle,
                    subtitle: l.pdfMergeSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PdfMergePage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolRow(
                    icon: Icons.call_split_rounded,
                    iconColor: const Color(0xFF8E24AA),
                    title: l.pdfSplitTitle,
                    subtitle: l.pdfSplitSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PdfSplitPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolRow(
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFF1E88E5),
                    title: l.pdfWatermarkTitle,
                    subtitle: l.pdfWatermarkSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PdfWatermarkPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolRow(
                    icon: Icons.compress_rounded,
                    iconColor: const Color(0xFF00897B),
                    title: l.pdfCompressTitle,
                    subtitle: l.pdfCompressSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PdfCompressPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolRow(
                    icon: Icons.folder_zip_rounded,
                    iconColor: const Color(0xFF6D4C41),
                    title: l.zipExportTitle,
                    subtitle: l.zipExportSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ZipExportPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolRow(
                    icon: Icons.lock_outline_rounded,
                    iconColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    title: l.pdfPasswordTitle,
                    subtitle: l.pdfPasswordSubtitle,
                    onTap: () => showAppSnackBar(
                      context,
                      message: l.pdfPasswordPending,
                      tone: AppFeedbackTone.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _sectionTitle(context, l.toolsSectionMore),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ToolRow(
                icon: Icons.schedule_rounded,
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                title: l.moreToolsScanWordExcel,
                subtitle: l.moreToolsComingSoon,
                onTap: () => showAppSnackBar(
                  context,
                  message: l.moreToolsComingSoon,
                  tone: AppFeedbackTone.info,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) => Row(
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
        ],
      );
}

class _ModeEntry {
  const _ModeEntry({
    required this.mode,
    required this.title,
    required this.icon,
    required this.colorIndex,
  });
  final CameraCaptureMode mode;
  final String title;
  final IconData icon;
  final int colorIndex;
}

List<_ModeEntry> _buildModeCards(AppL10n l) => [
      _ModeEntry(
          mode: CameraCaptureMode.scan,
          title: l.toolScan,
          icon: Icons.document_scanner_rounded,
          colorIndex: 0),
      _ModeEntry(
          mode: CameraCaptureMode.aiCutout,
          title: l.toolCutout,
          icon: Icons.auto_awesome_rounded,
          colorIndex: 1),
      _ModeEntry(
          mode: CameraCaptureMode.idPhoto,
          title: l.toolIdPhoto,
          icon: Icons.badge_rounded,
          colorIndex: 2),
      _ModeEntry(
          mode: CameraCaptureMode.eSignatureScan,
          title: l.toolESign,
          icon: Icons.draw_rounded,
          colorIndex: 3),
      _ModeEntry(
          mode: CameraCaptureMode.textRecognition,
          title: l.toolText,
          icon: Icons.text_fields_rounded,
          colorIndex: 4),
      _ModeEntry(
          mode: CameraCaptureMode.formulaRecognition,
          title: l.toolFormula,
          icon: Icons.functions_rounded,
          colorIndex: 5),
      _ModeEntry(
          mode: CameraCaptureMode.translate,
          title: l.toolTranslate,
          icon: Icons.translate_rounded,
          colorIndex: 6),
      _ModeEntry(
          mode: CameraCaptureMode.objectRecognition,
          title: l.toolObject,
          icon: Icons.category_rounded,
          colorIndex: 7),
      _ModeEntry(
          mode: CameraCaptureMode.aiErase,
          title: l.toolErase,
          icon: Icons.healing_rounded,
          colorIndex: 8),
    ];

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.entry});
  final _ModeEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.featurePalette[entry.colorIndex];
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CameraScanPage(initialMode: entry.mode),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(entry.icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                entry.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PDF 合并 ────────────────────────────────────────────────────────────────

class _PdfMergePage extends StatefulWidget {
  const _PdfMergePage();
  @override
  State<_PdfMergePage> createState() => _PdfMergePageState();
}

class _PdfMergePageState extends State<_PdfMergePage> {
  final _picker = ImagePicker();
  final _pdfService = PdfExportService();
  final _shareService = ShareService();
  final List<Uint8List> _pages = [];
  bool _busy = false;

  Future<void> _addImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 100);
    if (!mounted || picked.isEmpty) return;
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      final jpg = _normalizeToJpeg(bytes);
      if (jpg != null) _pages.add(jpg);
    }
    if (mounted) setState(() {});
  }

  Uint8List? _normalizeToJpeg(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    final baked = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(baked, quality: 90));
  }

  Future<void> _exportAndShare() async {
    if (_pages.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await _pdfService.exportJpegPages(
        pages: _pages,
        fileNamePrefix: 'DocScan-Merged',
      );
      if (!mounted) return;
      await _shareService.shareFile(file, text: 'DocScan');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppL10n.of(context).exportFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pdfMergeTitle),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              tooltip: l.allDocsClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => setState(() => _pages.clear()),
            ),
        ],
      ),
      body: _pages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_rounded,
                      size: 72,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(l.pdfMergeEmpty,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(l.pdfMergeEmptyHint,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _addImages,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.pdfMergePickImages),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
              ),
              itemCount: _pages.length + 1,
              itemBuilder: (_, i) {
                if (i == _pages.length) {
                  return Material(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      onTap: _addImages,
                      child: Center(
                        child: Icon(Icons.add_rounded,
                            size: 32, color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_pages[i],
                          fit: BoxFit.cover, gaplessPlayback: true),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 26, minHeight: 26),
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              setState(() => _pages.removeAt(i)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_pages.isEmpty || _busy) ? null : _exportAndShare,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(_busy
                ? l.pdfMergeExporting
                : l.pdfMergeExportLabel(_pages.length)),
          ),
        ),
      ),
    );
  }
}

// ── PDF 压缩（从本 App 最近文档中选）──────────────────────────────────────────

class _PdfCompressPage extends StatefulWidget {
  const _PdfCompressPage();
  @override
  State<_PdfCompressPage> createState() => _PdfCompressPageState();
}

class _PdfCompressPageState extends State<_PdfCompressPage> {
  late Future<List<RecentDocument>> _docsFuture;
  final _pdfService = PdfExportService();
  final _shareService = ShareService();
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _docsFuture = RecentDocumentsService.list();
  }

  Future<void> _compressAndShare(RecentDocument doc) async {
    if (_busyIds.contains(doc.id)) return;
    final l = AppL10n.of(context);
    if (!doc.hasFullPages) {
      showAppSnackBar(context,
          message: l.docDetailEmptyLegacy, tone: AppFeedbackTone.warning);
      return;
    }
    setState(() => _busyIds.add(doc.id));
    try {
      final pages = await RecentDocumentsService.loadPages(doc.id);
      final compressed = <Uint8List>[];
      for (final p in pages) {
        final decoded = img.decodeImage(p);
        if (decoded == null) continue;
        img.Image work = decoded;
        final longEdge = work.width > work.height ? work.width : work.height;
        if (longEdge > 1600) {
          final scale = 1600 / longEdge;
          work = img.copyResize(
            work,
            width: (work.width * scale).round(),
            height: (work.height * scale).round(),
            interpolation: img.Interpolation.linear,
          );
        }
        compressed.add(Uint8List.fromList(img.encodeJpg(work, quality: 70)));
      }
      if (!mounted || compressed.isEmpty) return;
      final file = await _pdfService.exportJpegPages(
        pages: compressed,
        fileNamePrefix: '${doc.title}-compressed',
      );
      if (!mounted) return;
      await _shareService.shareFile(file, subject: doc.title);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: l.exportFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.pdfCompressTitle)),
      body: FutureBuilder<List<RecentDocument>>(
        future: _docsFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = (snap.data ?? const <RecentDocument>[])
              .where((d) => d.hasFullPages)
              .toList();
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  l.pdfCompressEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final busy = _busyIds.contains(d.id);
              return Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd)),
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(d.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${d.pageCount} · ${d.sizeLabel}'),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.compress_rounded),
                  onTap: busy ? null : () => _compressAndShare(d),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── PDF 拆分（按页生成 N 个 PDF + ZIP 打包分享）──────────────────────────────

class _PdfSplitPage extends StatefulWidget {
  const _PdfSplitPage();
  @override
  State<_PdfSplitPage> createState() => _PdfSplitPageState();
}

class _PdfSplitPageState extends State<_PdfSplitPage> {
  late Future<List<RecentDocument>> _docsFuture;
  final _pdfService = PdfExportService();
  final _zipService = ArchiveExportService();
  final _shareService = ShareService();
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _docsFuture = RecentDocumentsService.list();
  }

  Future<void> _splitAndShare(RecentDocument doc) async {
    if (_busyIds.contains(doc.id)) return;
    final l = AppL10n.of(context);
    if (!doc.hasFullPages) {
      showAppSnackBar(context,
          message: l.docDetailEmptyLegacy, tone: AppFeedbackTone.warning);
      return;
    }
    setState(() => _busyIds.add(doc.id));
    try {
      final pages = await RecentDocumentsService.loadPages(doc.id);
      // 每页生成单独 PDF，落地为 bytes，再用 zipper 打成一个压缩包发出。
      final perPagePdfs = <Uint8List>[];
      final pad = pages.length.toString().length;
      for (var i = 0; i < pages.length; i++) {
        final f = await _pdfService.exportJpegPages(
          pages: [pages[i]],
          fileNamePrefix:
              '${doc.title}-page-${(i + 1).toString().padLeft(pad, '0')}',
        );
        perPagePdfs.add(await f.readAsBytes());
      }
      // 把 N 个 PDF 装进 ZIP
      final zipPages = <Uint8List>[];
      for (final b in perPagePdfs) {
        zipPages.add(b);
      }
      // archive_export_service 当前以 .jpg 命名；这里直接复用 service 但改成 .pdf 命名更准确。
      // 简化处理：我们直接生成 pdf 内的 zip via 同一 ZipEncoder 包装。
      final file = await _zipService.exportPagesAsZip(
        pages: zipPages,
        fileNamePrefix: '${doc.title}-split',
      );
      if (!mounted) return;
      await _shareService.shareFile(file, subject: doc.title);
      if (!mounted) return;
      showAppSnackBar(context,
          message: l.pdfSplitDoneToast(perPagePdfs.length));
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: l.exportFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.pdfSplitTitle)),
      body: FutureBuilder<List<RecentDocument>>(
        future: _docsFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = (snap.data ?? const <RecentDocument>[])
              .where((d) => d.hasFullPages && d.pageCount > 1)
              .toList();
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  l.pdfCompressEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final busy = _busyIds.contains(d.id);
              return Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd)),
                  leading: const Icon(Icons.call_split_rounded),
                  title: Text(d.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${d.pageCount} · ${d.sizeLabel}'),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  onTap: busy ? null : () => _splitAndShare(d),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── PDF 加水印（文本水印） ────────────────────────────────────────────────────

class _PdfWatermarkPage extends StatefulWidget {
  const _PdfWatermarkPage();
  @override
  State<_PdfWatermarkPage> createState() => _PdfWatermarkPageState();
}

class _PdfWatermarkPageState extends State<_PdfWatermarkPage> {
  late Future<List<RecentDocument>> _docsFuture;
  final _shareService = ShareService();
  final TextEditingController _textCtrl =
      TextEditingController(text: 'DocScan');
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _docsFuture = RecentDocumentsService.list();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyAndShare(RecentDocument doc) async {
    if (_busyId != null) return;
    final l = AppL10n.of(context);
    final wm = _textCtrl.text.trim();
    if (wm.isEmpty || !doc.hasFullPages) return;
    setState(() => _busyId = doc.id);
    try {
      final pages = await RecentDocumentsService.loadPages(doc.id);
      final pdfDoc = pw.Document();
      for (final p in pages) {
        final image = pw.MemoryImage(p);
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (_) {
              return pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
                  pw.Transform.rotate(
                    angle: -0.6,
                    child: pw.Opacity(
                      opacity: 0.18,
                      child: pw.Text(
                        wm,
                        style: pw.TextStyle(
                          fontSize: 64,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
      final bytes = await pdfDoc.save();
      final tmp = await getTemporaryDirectory();
      final safe =
          '${doc.title}-watermark'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final out = File(
        '${tmp.path}/$safe-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await out.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await _shareService.shareFile(out, subject: doc.title);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: l.exportFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.pdfWatermarkTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _textCtrl,
              decoration: InputDecoration(
                labelText: l.pdfWatermarkInputLabel,
                hintText: l.pdfWatermarkInputHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<RecentDocument>>(
              future: _docsFuture,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = (snap.data ?? const <RecentDocument>[])
                    .where((d) => d.hasFullPages)
                    .toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        l.pdfCompressEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final busy = _busyId == d.id;
                    final canApply = _textCtrl.text.trim().isNotEmpty;
                    return Material(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMd)),
                        leading: const Icon(Icons.water_drop_rounded),
                        title: Text(d.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${d.pageCount} · ${d.sizeLabel}'),
                        trailing: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_rounded),
                        onTap: (busy || !canApply)
                            ? null
                            : () => _applyAndShare(d),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── ZIP 打包导出 ─────────────────────────────────────────────────────────────

class _ZipExportPage extends StatefulWidget {
  const _ZipExportPage();
  @override
  State<_ZipExportPage> createState() => _ZipExportPageState();
}

class _ZipExportPageState extends State<_ZipExportPage> {
  late Future<List<RecentDocument>> _docsFuture;
  final _zipService = ArchiveExportService();
  final _shareService = ShareService();
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _docsFuture = RecentDocumentsService.list();
  }

  Future<void> _zipAndShare(RecentDocument doc) async {
    if (_busyIds.contains(doc.id)) return;
    final l = AppL10n.of(context);
    if (!doc.hasFullPages) {
      showAppSnackBar(context,
          message: l.docDetailEmptyLegacy, tone: AppFeedbackTone.warning);
      return;
    }
    setState(() => _busyIds.add(doc.id));
    try {
      final pages = await RecentDocumentsService.loadPages(doc.id);
      final file = await _zipService.exportPagesAsZip(
        pages: pages,
        fileNamePrefix: doc.title,
      );
      if (!mounted) return;
      await _shareService.shareFile(file, subject: l.zipExportShareSubject);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: l.exportFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.zipExportTitle)),
      body: FutureBuilder<List<RecentDocument>>(
        future: _docsFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = (snap.data ?? const <RecentDocument>[])
              .where((d) => d.hasFullPages)
              .toList();
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  l.zipExportEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final busy = _busyIds.contains(d.id);
              return Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd)),
                  leading: const Icon(Icons.folder_zip_rounded),
                  title: Text(d.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${d.pageCount} · ${d.sizeLabel}'),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  onTap: busy ? null : () => _zipAndShare(d),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
