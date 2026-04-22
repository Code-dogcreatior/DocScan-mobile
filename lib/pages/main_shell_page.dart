import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/camera_capture_mode.dart';
import '../theme/app_tokens.dart';
import 'camera_scan_page.dart';
import 'home_page.dart';
import 'tab_all_documents_page.dart';
import 'tab_profile_page.dart';
import 'tab_tools_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  /// 全局 tab 切换入口：写入目标索引即跳转。
  /// 0=首页 / 1=文档 / 2=工具箱 / 3=我的。
  static final ValueNotifier<int> tabIndexNotifier = ValueNotifier<int>(0);

  /// 便捷包装。
  static void jumpToTab(int index) {
    if (index < 0 || index > 3) return;
    tabIndexNotifier.value = index;
  }

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _tabIndex = 0;

  static final _pages = <Widget>[
    const HomePage(),
    const TabAllDocumentsPage(),
    const TabToolsPage(),
    const TabProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    MainShellPage.tabIndexNotifier.addListener(_onTabNotifierChanged);
  }

  @override
  void dispose() {
    MainShellPage.tabIndexNotifier.removeListener(_onTabNotifierChanged);
    super.dispose();
  }

  void _onTabNotifierChanged() {
    final next = MainShellPage.tabIndexNotifier.value;
    if (next != _tabIndex && mounted) {
      setState(() => _tabIndex = next);
    }
  }

  void _setTab(int index) {
    MainShellPage.tabIndexNotifier.value = index;
    setState(() => _tabIndex = index);
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CameraScanPage(
          initialMode: CameraCaptureMode.scan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: _pages,
      ),
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: () => _openCamera(context),
          tooltip: l.scanDocument,
          elevation: 4,
          shape: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTokens.heroGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
        elevation: 8,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _TabItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: l.tabHome,
              active: _tabIndex == 0,
              onTap: () => _setTab(0),
            ),
            _TabItem(
              icon: Icons.folder_outlined,
              activeIcon: Icons.folder_rounded,
              label: l.tabDocuments,
              active: _tabIndex == 1,
              onTap: () => _setTab(1),
            ),
            // 中间占位，让 FAB notch 有空间
            const SizedBox(width: 60),
            _TabItem(
              icon: Icons.build_outlined,
              activeIcon: Icons.build_rounded,
              label: l.tabTools,
              active: _tabIndex == 2,
              onTap: () => _setTab(2),
            ),
            _TabItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: l.tabProfile,
              active: _tabIndex == 3,
              onTap: () => _setTab(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
