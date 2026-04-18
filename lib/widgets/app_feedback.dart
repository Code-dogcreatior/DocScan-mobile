import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context, {
  required String message,
  IconData icon = Icons.info_outline,
}) {
  if (!context.mounted) return;
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: cs.onInverseSurface, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
