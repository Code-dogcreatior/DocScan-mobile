import 'package:flutter/material.dart';

import '../models/camera_capture_mode.dart';
import 'camera_scan_page.dart';
import '../theme/app_tokens.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openCamera(
    BuildContext context, {
    CameraCaptureMode mode = CameraCaptureMode.scan,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraScanPage(initialMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.06),
              cs.surface,
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DocScan',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '智能文档扫描 · 随手即用',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Quick Action Card ──
                      Material(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(20),
                        elevation: 2,
                        shadowColor: cs.primary.withValues(alpha: 0.4),
                        child: InkWell(
                          onTap: () => _openCamera(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '开始扫描',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '实时检测边缘 · 自动透视裁剪',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Section Title ──
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '全部功能',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // ── Feature Grid ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  delegate: SliverChildListDelegate(
                    _featureItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _FeatureTile(
                        icon: item.icon,
                        label: item.label,
                        color: AppTokens.featurePalette[index],
                        enabled: item.enabled,
                        onTap: item.enabled
                            ? () => _openCamera(context, mode: item.initialMode)
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Footer ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            '建议在光线充足的环境下使用以获得最佳效果',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature items data ──

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.label,
    required this.initialMode,
  });
  final IconData icon;
  final String label;
  final CameraCaptureMode initialMode;
  bool get enabled => true;
}

const _featureItems = <_FeatureData>[
  _FeatureData(
    icon: Icons.document_scanner_rounded,
    label: '文档扫描',
    initialMode: CameraCaptureMode.scan,
  ),
  _FeatureData(
    icon: Icons.auto_awesome_rounded,
    label: 'AI 抠图',
    initialMode: CameraCaptureMode.aiCutout,
  ),
  _FeatureData(
    icon: Icons.draw_rounded,
    label: '电子签名',
    initialMode: CameraCaptureMode.eSignatureScan,
  ),
  _FeatureData(
    icon: Icons.functions_rounded,
    label: '公式识别',
    initialMode: CameraCaptureMode.formulaRecognition,
  ),
  _FeatureData(
    icon: Icons.badge_rounded,
    label: '证件照',
    initialMode: CameraCaptureMode.idPhoto,
  ),
  _FeatureData(
    icon: Icons.text_fields_rounded,
    label: '文字识别',
    initialMode: CameraCaptureMode.textRecognition,
  ),
  _FeatureData(
    icon: Icons.translate_rounded,
    label: '翻译',
    initialMode: CameraCaptureMode.translate,
  ),
  _FeatureData(
    icon: Icons.search_rounded,
    label: '物体识别',
    initialMode: CameraCaptureMode.objectRecognition,
  ),
  _FeatureData(
    icon: Icons.auto_fix_high_rounded,
    label: 'AI 擦除',
    initialMode: CameraCaptureMode.aiErase,
  ),
];

// ── Feature tile widget ──

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.35);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!enabled) ...[
                const SizedBox(height: 2),
                Text(
                  '即将上线',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
