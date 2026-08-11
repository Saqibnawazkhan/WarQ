import 'package:flutter/widgets.dart';

/// 4pt spacing scale used across the app.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal padding used by every scrollable page body.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: lg);

  /// Padding for the content of a page that also needs vertical breathing room.
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(lg, lg, lg, xxxl);

  /// Cards and rows carry the larger type scale, so they were given room to
  /// hold it. A tile is now comfortably past the 48dp minimum touch target
  /// without anything having to be measured per screen.
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  static const EdgeInsets tilePadding = EdgeInsets.symmetric(horizontal: lg, vertical: lg);

  /// Extra bottom padding so floating action buttons never cover content.
  static const double fabClearance = 88;
}

/// Corner radii.
class AppRadii {
  const AppRadii._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(xl));
  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(sm));
}

/// Responsive breakpoints. The app targets phones first but must stay usable on
/// tablets and foldables, so layouts widen instead of stretching.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;

  /// Maximum readable content width on large screens.
  static const double maxContentWidth = 720;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;

  /// Number of grid columns appropriate for [width].
  static int gridColumns(double width) {
    if (width >= medium) return 4;
    if (width >= compact) return 3;
    return 2;
  }
}
