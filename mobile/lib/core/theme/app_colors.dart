import 'package:flutter/material.dart';

/// Brand palette for WarQ.
///
/// Colours are defined once here and consumed through [ThemeData] so screens
/// never hardcode hex values. Semantic colours (success / warning / danger)
/// live on [AppSemanticColors] which is registered as a [ThemeExtension] and is
/// therefore available in both light and dark mode.
class AppColors {
  const AppColors._();

  // The indigo from the prototype, not the blue the app was built with. It
  // carries the sign-in button, the selected tab, the compose button and the
  // filled statistic card, so changing it here changes the app's colour.
  static const Color brand = Color(0xFF4A2FD0);
  static const Color brandDark = Color(0xFF3A22A8);
  static const Color brandLight = Color(0xFFECE9FB);

  static const Color accent = Color(0xFF00B894);
  static const Color accentLight = Color(0xFFE1F7F1);

  static const Color success = Color(0xFF1EA97C);
  static const Color successLight = Color(0xFFE3F6EF);
  static const Color warning = Color(0xFFF2A93B);
  static const Color warningLight = Color(0xFFFDF2E0);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerLight = Color(0xFFFDECEC);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFE8F1FE);

  static const Color neutral900 = Color(0xFF0F1729);
  static const Color neutral800 = Color(0xFF1C2434);
  static const Color neutral700 = Color(0xFF344054);
  static const Color neutral600 = Color(0xFF475467);
  static const Color neutral500 = Color(0xFF667085);
  static const Color neutral400 = Color(0xFF98A2B3);
  static const Color neutral300 = Color(0xFFD0D5DD);
  static const Color neutral200 = Color(0xFFE4E7EC);
  static const Color neutral100 = Color(0xFFF2F4F7);
  static const Color neutral50 = Color(0xFFF9FAFB);

  static const Color darkSurface = Color(0xFF151B27);
  static const Color darkSurfaceElevated = Color(0xFF1D2534);
  static const Color darkBackground = Color(0xFF0D121C);

  /// Deterministic avatar tints, indexed by a hash of the entity name.
  static const List<Color> avatarPalette = <Color>[
    Color(0xFF2E5BFF),
    Color(0xFF00B894),
    Color(0xFFF2A93B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFEF6C3B),
    Color(0xFF10B981),
  ];

  /// The colours a class card is painted in.
  ///
  /// Six, because the database hands every new class a `color_index` from 0 to
  /// 5 as it is created, so a teacher's classes come out visually distinct
  /// without anyone choosing. Each entry is a pair: the gradient runs from the
  /// first towards the second, top-left to bottom-right.
  ///
  /// Deep enough that white text sits on them at full contrast — these carry
  /// the class name, so legibility decides the shade, not the other way round.
  static const List<List<Color>> classPalette = <List<Color>>[
    <Color>[Color(0xFF7C5CFC), Color(0xFF6338F0)], // violet
    <Color>[Color(0xFF16C0A4), Color(0xFF06A88C)], // teal
    <Color>[Color(0xFFFF8A1E), Color(0xFFF56A00)], // orange
    <Color>[Color(0xFFEC2E70), Color(0xFFD11557)], // pink
    <Color>[Color(0xFF2E7DFF), Color(0xFF1259E0)], // blue
    <Color>[Color(0xFF9B4DE0), Color(0xFF7A2FC4)], // purple
  ];

  /// The pair for a class, from whatever seed it carries.
  ///
  /// The seed is normally the `color_index` the database assigned, so it just
  /// indexes the list. Anything else is hashed, which keeps a class the same
  /// colour on every device rather than shifting between sessions.
  static List<Color> classColors(String? seed) {
    if (seed == null || seed.isEmpty) return classPalette.first;

    final int? index = int.tryParse(seed);
    if (index != null) return classPalette[index.abs() % classPalette.length];

    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return classPalette[hash % classPalette.length];
  }

  /// Colour cycle used by charts with multiple series or categories.
  static const List<Color> chartPalette = <Color>[
    Color(0xFF2E5BFF),
    Color(0xFF00B894),
    Color(0xFFF2A93B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  static Color avatarColor(String seed) {
    if (seed.isEmpty) return avatarPalette.first;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return avatarPalette[hash % avatarPalette.length];
  }
}

/// Semantic colours that adapt to the active brightness.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.onWarningContainer,
    required this.warningContainer,
    required this.danger,
    required this.onDangerContainer,
    required this.dangerContainer,
    required this.info,
    required this.onInfoContainer,
    required this.infoContainer,
    required this.subtleBorder,
    required this.mutedText,
    required this.canvas,
  });

  final Color success;
  final Color onSuccessContainer;
  final Color successContainer;
  final Color warning;
  final Color onWarningContainer;
  final Color warningContainer;
  final Color danger;
  final Color onDangerContainer;
  final Color dangerContainer;
  final Color info;
  final Color onInfoContainer;
  final Color infoContainer;
  final Color subtleBorder;
  final Color mutedText;
  final Color canvas;

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColors.success,
    onSuccessContainer: Color(0xFF0B5C43),
    successContainer: AppColors.successLight,
    warning: AppColors.warning,
    onWarningContainer: Color(0xFF7A4B06),
    warningContainer: AppColors.warningLight,
    danger: AppColors.danger,
    onDangerContainer: Color(0xFF8E1F22),
    dangerContainer: AppColors.dangerLight,
    info: AppColors.info,
    onInfoContainer: Color(0xFF17418F),
    infoContainer: AppColors.infoLight,
    subtleBorder: AppColors.neutral200,
    mutedText: AppColors.neutral500,
    canvas: AppColors.neutral50,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF3DD9A4),
    onSuccessContainer: Color(0xFFB8F5E0),
    successContainer: Color(0xFF10362B),
    warning: Color(0xFFF6C167),
    onWarningContainer: Color(0xFFFCE7C0),
    warningContainer: Color(0xFF3A2C11),
    danger: Color(0xFFFF7B7F),
    onDangerContainer: Color(0xFFFFD3D4),
    dangerContainer: Color(0xFF3D1A1C),
    info: Color(0xFF6BA5FA),
    onInfoContainer: Color(0xFFD3E4FE),
    infoContainer: Color(0xFF152A47),
    subtleBorder: Color(0xFF2A3444),
    mutedText: Color(0xFF98A2B3),
    canvas: AppColors.darkBackground,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccessContainer,
    Color? successContainer,
    Color? warning,
    Color? onWarningContainer,
    Color? warningContainer,
    Color? danger,
    Color? onDangerContainer,
    Color? dangerContainer,
    Color? info,
    Color? onInfoContainer,
    Color? infoContainer,
    Color? subtleBorder,
    Color? mutedText,
    Color? canvas,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      mutedText: mutedText ?? this.mutedText,
      canvas: canvas ?? this.canvas,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDangerContainer: Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
    );
  }
}
