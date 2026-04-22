import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/camera_capture_mode.dart';
import '../models/recent_document.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('工具箱')),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _sectionTitle(context, '智能扫描'),
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
                (_, i) {
                  final m = _modeCards[i];
                  return _ModeCard(
                    mode: m.mode,
                    title: m.title,
                    desc: m.desc,
                    icon: m.icon,
                    colorIndex: m.colorIndex,
                  );
                },
                childCount: _modeCards.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _sectionTitle(context, 'PDF 工具'),
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
                    title: 'PDF 合并',
                    subtitle: '从相册选图 · 一键导出为多页 PDF',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PdfMergePage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolRow(
                    icon: Icons.compress_rounded,
                    iconColor: const Color(0xFF00897B),
                    title: 'PDF 压缩',
                    subtitle: '选择已扫描文档 · 降采样重新导出，体积更小',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PdfCompressPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _sectionTitle(context, '更多'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ToolRow(
                icon: Icons.schedule_rounded,
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                title: '扫描到 Word / Excel',
                subtitle: '即将开放，敬请期待',
                onTap: () => showAppSnackBar(
                  context,
                  message: '功能开发中',
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
  const _ModeEntry(
      this.mode, this.title, this.desc, this.icon, this.colorIndex);
  final CameraCaptureMode mode;
  final String title;
  final String desc;
  final IconData icon;
  final int colorIndex;
}

const _modeCards = <_ModeEntry>[
  _ModeEntry(
      CameraCaptureMode.scan, '智能扫描', '自动裁切 + 去阴影', Icons.document_scanner_rounded, 0),
  _ModeEntry(
      CameraCaptureMode.aiCutout, 'AI 抠图', '一键去背景', Icons.auto_awesome_rounded, 1),
  _ModeEntry(CameraCaptureMode.idPhoto, '证件照', '换底色与尺寸',
      Icons.badge_rounded, 2),
  _ModeEntry(CameraCaptureMode.eSignatureScan, '电子签名',
      '透明背景签名图', Icons.draw_rounded, 3),
  _ModeEntry(CameraCaptureMode.textRecognition, '文字识别',
      'OCR 文字转文本', Icons.text_fields_rounded, 4),
  _ModeEntry(CameraCaptureMode.formulaRecognition, '公式识别',
      '拍数学公式转 LaTeX', Icons.functions_rounded, 5),
  _ModeEntry(CameraCaptureMode.translate, '翻译', '拍什么译什么',
      Icons.translate_rounded, 6),
  _ModeEntry(CameraCaptureMode.objectRecognition, '物体识别',
      '识别图中主体物体', Icons.category_rounded, 7),
  _ModeEntry(CameraCaptureMode.aiErase, 'AI 擦除', '涂抹去除杂物',
      Icons.healing_rounded, 8),
];

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.title,
    required this.desc,
    required this.icon,
    required this.colorIndex,
  });
  final CameraCaptureMode mode;
  final String title;
  final String desc;
  final IconData icon;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.featurePalette[colorIndex];
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CameraScanPage(initialMode: mode),
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
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant),
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
      await _shareService.shareFile(file, text: 'DocScan 合并 PDF');
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '合并失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 合并'),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              tooltip: '清空',
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
                  const Text('从相册选图以开始合并',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('支持多选，按选择顺序排版',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _addImages,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('选择图片'),
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
            onPressed:
                (_pages.isEmpty || _busy) ? null : _exportAndShare,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(_busy ? '处理中…' : '导出并分享 (${_pages.length} 页)'),
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
    if (!doc.hasFullPages) {
      showAppSnackBar(context,
          message: '此条目仅有缩略图，无法压缩', tone: AppFeedbackTone.warning);
      return;
    }
    setState(() => _busyIds.add(doc.id));
    try {
      final pages = await RecentDocumentsService.loadPages(doc.id);
      final compressed = <Uint8List>[];
      for (final p in pages) {
        final decoded = img.decodeImage(p);
        if (decoded == null) continue;
        // 降采样：长边 > 1600 时缩到 1600；再 quality=70 重编码。
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
      await _shareService.shareFile(file,
          text: '${doc.title}（压缩）', subject: doc.title);
    } catch (e) {
      if (mounted) showAppSnackBar(context, message: '压缩失败：$e');
    } finally {
      if (mounted) setState(() => _busyIds.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('PDF 压缩')),
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
                  '暂无可压缩的本地文档。\n请先通过相机扫描生成文档。',
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
                  subtitle: Text('${d.pageCount} 页 · ${d.sizeLabel}'),
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
