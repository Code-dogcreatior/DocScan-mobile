import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Visual variant of a primary action.
enum PrimaryActionTone { brand, success, danger }

/// Primary filled action button with built-in loading state, optional icon,
/// and semantic tone (brand / success / danger).
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.tone = PrimaryActionTone.brand,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final PrimaryActionTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final (bg, fg) = switch (tone) {
      PrimaryActionTone.brand => (cs.primary, cs.onPrimary),
      PrimaryActionTone.success => (palette.success, palette.onSuccess),
      PrimaryActionTone.danger => (palette.danger, palette.onDanger),
    };

    final disabled = loading || onPressed == null;
    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = FilledButton(
      onPressed: disabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.4),
        disabledForegroundColor: fg.withValues(alpha: 0.85),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Outlined secondary action. Same dimensions as [PrimaryActionButton] so they
/// align cleanly in a row.
class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = loading || onPressed == null;
    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = OutlinedButton(
      onPressed: disabled ? null : onPressed,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Sticky bottom action bar with SafeArea + soft top divider. Pass any widgets;
/// typical use is one or two [PrimaryActionButton] / [SecondaryActionButton].
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.gap = 12,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) entries.add(SizedBox(width: gap));
      entries.add(Expanded(child: children[i]));
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Row(children: entries),
        ),
      ),
    );
  }
}

/// Compact "hero" gradient button — used for marquee CTAs like "Save to PDF".
class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gradient = AppTokens.heroGradient,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
          ],
          if (!loading)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
    final decorated = Container(
      decoration: BoxDecoration(
        gradient: disabled
            ? const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFF757575)])
            : gradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        boxShadow: disabled ? const [] : AppTokens.elev2,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: content,
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: decorated) : decorated;
  }
}
