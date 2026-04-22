import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class TabProfilePage extends StatelessWidget {
  const TabProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: const EmptyState(
        icon: Icons.person_outline_rounded,
        title: '我的',
        subtitle: '即将开放，敬请期待',
      ),
    );
  }
}
