import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

class TabProfilePage extends StatelessWidget {
  const TabProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.tabProfile)),
      body: EmptyState(
        icon: Icons.person_outline_rounded,
        title: l.tabProfile,
        subtitle: l.tabComingSoon,
      ),
    );
  }
}
