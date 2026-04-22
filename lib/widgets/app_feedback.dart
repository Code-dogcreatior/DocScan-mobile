import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppFeedbackTone { info, success, warning, danger }

/// Shows a themed SnackBar. When [icon] is omitted, a default matching the
/// tone is used. When [tone] is supplied (or inferred from [icon]-less calls),
/// the SnackBar background and icon adopt the corresponding semantic colors.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  IconData? icon,
  AppFeedbackTone? tone,
  Duration duration = const Duration(seconds: 3),
}) {
  if (!context.mounted) return;
  final theme = Theme.of(context);
  final palette = context.palette;
  final effectiveTone = tone ?? _inferTone(icon) ?? AppFeedbackTone.info;
  final (bg, fg, defaultIcon) = switch (effectiveTone) {
    AppFeedbackTone.info => (
        palette.infoContainer,
        palette.onInfoContainer,
        Icons.info_outline_rounded,
      ),
    AppFeedbackTone.success => (
        palette.successContainer,
        palette.onSuccessContainer,
        Icons.check_circle_outline_rounded,
      ),
    AppFeedbackTone.warning => (
        palette.warningContainer,
        palette.onWarningContainer,
        Icons.warning_amber_rounded,
      ),
    AppFeedbackTone.danger => (
        palette.dangerContainer,
        palette.onDangerContainer,
        Icons.error_outline_rounded,
      ),
  };
  final effectiveIcon = icon ?? defaultIcon;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: bg,
        duration: duration,
        content: Row(
          children: [
            Icon(effectiveIcon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

AppFeedbackTone? _inferTone(IconData? icon) {
  if (icon == null) return null;
  if (icon == Icons.check_circle_outline ||
      icon == Icons.check_circle_outline_rounded ||
      icon == Icons.check_circle ||
      icon == Icons.check) {
    return AppFeedbackTone.success;
  }
  if (icon == Icons.error_outline ||
      icon == Icons.error_outline_rounded ||
      icon == Icons.error) {
    return AppFeedbackTone.danger;
  }
  if (icon == Icons.warning_amber_rounded ||
      icon == Icons.warning_amber ||
      icon == Icons.warning_rounded ||
      icon == Icons.warning) {
    return AppFeedbackTone.warning;
  }
  return null;
}
