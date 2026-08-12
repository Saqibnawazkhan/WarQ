import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds the light and dark Material 3 themes.
///
/// Everything visual is centralised here: screens read from `Theme.of(context)`
/// and never construct their own colours or text styles.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF7D9BFF) : AppColors.brand,
          onPrimary: isDark ? const Color(0xFF06122F) : Colors.white,
          secondary: isDark ? const Color(0xFF4FD1B0) : AppColors.accent,
          surface: isDark ? AppColors.darkSurface : Colors.white,
          onSurface: isDark ? const Color(0xFFE7EAF0) : AppColors.neutral900,
          surfaceContainerLowest: isDark
              ? AppColors.darkBackground
              : AppColors.neutral50,
          surfaceContainerLow: isDark ? const Color(0xFF121824) : Colors.white,
          surfaceContainer: isDark
              ? AppColors.darkSurface
              : AppColors.neutral50,
          surfaceContainerHigh: isDark
              ? AppColors.darkSurfaceElevated
              : AppColors.neutral100,
          surfaceContainerHighest: isDark
              ? const Color(0xFF232D3E)
              : AppColors.neutral100,
          outline: isDark ? const Color(0xFF3A4557) : AppColors.neutral300,
          outlineVariant: isDark
              ? const Color(0xFF2A3444)
              : AppColors.neutral200,
          error: isDark ? const Color(0xFFFF7B7F) : AppColors.danger,
        );

    final AppSemanticColors semantic = isDark
        ? AppSemanticColors.dark
        : AppSemanticColors.light;

    final TextTheme textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Transparent so the app's one painted background shows through every
      // screen. Without this each Scaffold would cover it with a flat colour
      // and the glass above would have nothing to blur.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[semantic],
      appBarTheme: AppBarTheme(
        // Fully transparent, so the background runs unbroken from the status
        // bar down. A tinted bar was tried first and read as a grey slab pasted
        // over the gradient — the seam along its bottom edge was the giveaway.
        // Nothing scrolls behind an ordinary AppBar (the body starts below it),
        // so there is nothing here for a BackdropFilter to blur either.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.62),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: semantic.subtleBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: semantic.subtleBorder,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // The same translucent white as [Glass.fill], written literally
        // because a theme is built without a BuildContext. Kept a little
        // brighter than a card so a field still reads as somewhere to type.
        fillColor: Colors.white.withValues(alpha: isDark ? 0.06 : 0.70),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: semantic.mutedText),
        labelStyle: textTheme.bodyMedium?.copyWith(color: semantic.mutedText),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
        ),
        prefixIconColor: semantic.mutedText,
        suffixIconColor: semantic.mutedText,
        border: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide(color: semantic.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide(color: semantic.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.fieldRadius,
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.fieldRadius,
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: semantic.subtleBorder),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.fieldRadius,
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: isDark ? 0.08 : 0.55),
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.12),
        labelStyle: textTheme.labelLarge,
        side: BorderSide(color: semantic.subtleBorder),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: semantic.mutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        // Room for the larger label beneath a 24dp icon, including when the
        // system text size is turned up. The bar clips rather than grows, so
        // this has to lead the type scale rather than follow it.
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : semantic.mutedText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : semantic.mutedText,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: semantic.mutedText,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: semantic.subtleBorder,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.titleSmall,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      // Transparent, because the sheet's own panel is the glass: `GlassSheet`
      // draws the fill, the rounded top and the drag handle inside the clip so
      // the blur reaches the corners. A background here would sit behind that
      // and there would be nothing left to see through.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF2A3444)
            : AppColors.neutral900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: isDark
            ? const Color(0xFF9FB6FF)
            : const Color(0xFFA8BEFF),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.fieldRadius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: semantic.mutedText,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantic.subtleBorder,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : semantic.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : semantic.subtleBorder,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// The one place text size is decided.
  ///
  /// Every screen styles itself from this theme rather than hard-coding sizes,
  /// so the whole app moves together and no screen drifts smaller than the
  /// rest. The scale below is roughly a tenth larger than it was: the previous
  /// one was legible on a desk and tiring in a classroom, which is where this
  /// is actually used — often at arm's length, often standing up.
  ///
  /// Nothing here goes below 13. That is the point at which a number on a
  /// register stops being readable at a glance, and a register that has to be
  /// squinted at gets marked wrong.
  static TextTheme _textTheme(ColorScheme scheme) {
    final Color primary = scheme.onSurface;
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Carries most of the names in the app - a student on a register, a class
      // on the hub - so it is deliberately close to titleMedium rather than
      // being a step down towards a caption.
      titleSmall: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: primary),
      bodyMedium: TextStyle(fontSize: 15.5, height: 1.45, color: primary),
      bodySmall: TextStyle(fontSize: 14, height: 1.4, color: primary),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 13.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primary,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primary,
      ),
    );
  }
}
