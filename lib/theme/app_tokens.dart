import 'package:flutter/material.dart';

/// Cross-page visual tokens for keeping UI language consistent.
class AppTokens {
  // ── Brand ──
  static const brandBlue = Color(0xFF1565C0);
  static const brandBlueSoft = Color(0xFFE3F0FB);
  static const brandBlueDeep = Color(0xFF0D47A1);

  // ── Camera / overlay (unchanged — used by camera UI) ──
  static const cameraForeground = Colors.white;
  static const cameraForegroundMuted = Colors.white70;
  static const cameraForegroundDisabled = Colors.white38;
  static const cameraSurface = Color(0xB3000000);
  static const cameraSurfaceBusy = Color(0xCC1565C0);
  static const cameraAccent = Color(0xFFFFD54F);
  static const overlayAccent = Color(0xFF42A5F5);
  static const overlayFillTop = Color(0x3042A5F5);
  static const overlayFillBottom = Color(0x1842A5F5);

  /// Editor canvas background (inpaint/matting). Slightly lifted off pure
  /// black so the blue stroke preview and UI chrome stay readable.
  static const editorCanvasBg = Color(0xFF141417);
  static const editorCanvasBgDark = Color(0xFF0A0A0C);

  // ── Feature tile palette (home grid) ──
  static const featurePalette = <Color>[
    Color(0xFF1565C0),
    Color(0xFF7B1FA2),
    Color(0xFF00838F),
    Color(0xFFEF6C00),
    Color(0xFF2E7D32),
    Color(0xFF5D4037),
    Color(0xFFC62828),
    Color(0xFF37474F),
    Color(0xFF6A1B9A),
  ];

  // ── Spacing scale (multiples of 4) ──
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // ── Radius scale ──
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  // ── Elevation presets (manual shadows — avoid M3 tint-on-elevation) ──
  static const List<BoxShadow> elev0 = <BoxShadow>[];
  static const elev1 = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const elev2 = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const elev3 = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 28, offset: Offset(0, 10)),
  ];

  // ── Semantic colors (Light) ──
  static const successLight = _Semantic(
    color: Color(0xFF16A34A),
    onColor: Colors.white,
    container: Color(0xFFDCFCE7),
    onContainer: Color(0xFF064E2B),
  );
  static const warningLight = _Semantic(
    color: Color(0xFFF59E0B),
    onColor: Colors.white,
    container: Color(0xFFFEF3C7),
    onContainer: Color(0xFF78350F),
  );
  static const dangerLight = _Semantic(
    color: Color(0xFFDC2626),
    onColor: Colors.white,
    container: Color(0xFFFEE2E2),
    onContainer: Color(0xFF7F1D1D),
  );
  static const infoLight = _Semantic(
    color: Color(0xFF0EA5E9),
    onColor: Colors.white,
    container: Color(0xFFE0F2FE),
    onContainer: Color(0xFF075985),
  );

  // ── Semantic colors (Dark) ──
  static const successDark = _Semantic(
    color: Color(0xFF4ADE80),
    onColor: Color(0xFF052E14),
    container: Color(0xFF14532D),
    onContainer: Color(0xFFBBF7D0),
  );
  static const warningDark = _Semantic(
    color: Color(0xFFFBBF24),
    onColor: Color(0xFF3F2600),
    container: Color(0xFF78350F),
    onContainer: Color(0xFFFEF3C7),
  );
  static const dangerDark = _Semantic(
    color: Color(0xFFF87171),
    onColor: Color(0xFF450A0A),
    container: Color(0xFF7F1D1D),
    onContainer: Color(0xFFFEE2E2),
  );
  static const infoDark = _Semantic(
    color: Color(0xFF38BDF8),
    onColor: Color(0xFF082F49),
    container: Color(0xFF075985),
    onContainer: Color(0xFFE0F2FE),
  );

  // ── Gradient presets ──
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E88E5), Color(0xFF1565C0), Color(0xFF0D47A1)],
    stops: [0.0, 0.55, 1.0],
  );
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
  );
  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
  );
}

class _Semantic {
  const _Semantic({
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });
  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;
}

/// Theme extension exposing semantic colors + spacing in a type-safe, mode-aware way.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.editorCanvas,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color editorCanvas;

  factory AppPalette.light() => AppPalette(
        success: AppTokens.successLight.color,
        onSuccess: AppTokens.successLight.onColor,
        successContainer: AppTokens.successLight.container,
        onSuccessContainer: AppTokens.successLight.onContainer,
        warning: AppTokens.warningLight.color,
        onWarning: AppTokens.warningLight.onColor,
        warningContainer: AppTokens.warningLight.container,
        onWarningContainer: AppTokens.warningLight.onContainer,
        danger: AppTokens.dangerLight.color,
        onDanger: AppTokens.dangerLight.onColor,
        dangerContainer: AppTokens.dangerLight.container,
        onDangerContainer: AppTokens.dangerLight.onContainer,
        info: AppTokens.infoLight.color,
        onInfo: AppTokens.infoLight.onColor,
        infoContainer: AppTokens.infoLight.container,
        onInfoContainer: AppTokens.infoLight.onContainer,
        editorCanvas: AppTokens.editorCanvasBg,
      );

  factory AppPalette.dark() => AppPalette(
        success: AppTokens.successDark.color,
        onSuccess: AppTokens.successDark.onColor,
        successContainer: AppTokens.successDark.container,
        onSuccessContainer: AppTokens.successDark.onContainer,
        warning: AppTokens.warningDark.color,
        onWarning: AppTokens.warningDark.onColor,
        warningContainer: AppTokens.warningDark.container,
        onWarningContainer: AppTokens.warningDark.onContainer,
        danger: AppTokens.dangerDark.color,
        onDanger: AppTokens.dangerDark.onColor,
        dangerContainer: AppTokens.dangerDark.container,
        onDangerContainer: AppTokens.dangerDark.onContainer,
        info: AppTokens.infoDark.color,
        onInfo: AppTokens.infoDark.onColor,
        infoContainer: AppTokens.infoDark.container,
        onInfoContainer: AppTokens.infoDark.onContainer,
        editorCanvas: AppTokens.editorCanvasBgDark,
      );

  @override
  AppPalette copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? editorCanvas,
  }) {
    return AppPalette(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      editorCanvas: editorCanvas ?? this.editorCanvas,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      editorCanvas: Color.lerp(editorCanvas, other.editorCanvas, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light();
}
