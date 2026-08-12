import 'dart:ui';

import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// The frosted-glass surface treatment.
///
/// Glass needs two things: something behind it worth blurring, and a surface
/// that is only partly there. [GlassBackground] paints the first once for the
/// whole app; everything else here is the second.
///
/// ── Why not every surface is blurred ─────────────────────────
///
/// BackdropFilter is the expensive widget in Flutter. Each one forces the
/// compositor to save a layer, read back what has already been painted, blur
/// it, and draw it again — and it does that every frame, whether or not
/// anything moved. One or two on screen is free in practice. Thirty of them,
/// which is what a register of thirty students would be, drops frames on the
/// mid-range Android phones this app is actually used on.
///
/// So the blur goes where it earns its keep: the bars and sheets that content
/// physically slides underneath, where you can see the blur working. A card
/// sitting in a list has nothing passing behind it, so it gets the translucent
/// fill and the hairline edge without the filter. Over the gradient it reads as
/// the same material, and it costs nothing.
class Glass {
  const Glass._();

  /// The fill of a glass surface: the background showing faintly through.
  static Color fill(BuildContext context, {double opacity = 1}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return (dark ? Colors.white : Colors.white).withValues(
      alpha: (dark ? 0.07 : 0.62) * opacity,
    );
  }

  /// A brighter fill, for the surfaces that need to sit forward of the rest —
  /// a sheet over a dimmed page, a dialog.
  static Color raisedFill(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Colors.white.withValues(alpha: dark ? 0.10 : 0.80);
  }

  /// The hairline along the top edge of real glass, where the light catches.
  static Color edge(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Colors.white.withValues(alpha: dark ? 0.12 : 0.70);
  }

  static List<BoxShadow> shadow(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

/// The colour behind the glass.
///
/// Deliberately soft and low-contrast. A vivid background would look
/// spectacular in a screenshot and make a register unreadable in a classroom,
/// which is the opposite of what was asked for a few screens ago.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = context.colors.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0B0B14) : const Color(0xFFF4F3FB),
      ),
      child: Stack(
        children: <Widget>[
          // Two soft pools of colour, off opposite corners. Painted rather than
          // an image so it costs one gradient and no download, and so it takes
          // the brand colour with it if that ever changes.
          Positioned(
            top: -160,
            left: -120,
            child: _Pool(
              color: primary.withValues(alpha: dark ? 0.28 : 0.20),
              size: 420,
            ),
          ),
          Positioned(
            bottom: -180,
            right: -140,
            child: _Pool(
              color: (dark ? const Color(0xFF16C0A4) : const Color(0xFF7C5CFC))
                  .withValues(alpha: dark ? 0.20 : 0.16),
              size: 460,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Pool extends StatelessWidget {
  const _Pool({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// The glass shell every bottom sheet sits in.
///
/// The modal route itself is transparent — see `bottomSheetTheme` — so the
/// panel, its rounded top corners and its drag handle are all drawn here. A
/// sheet is the one place the blur is unmistakable: the page it covers is still
/// visible through it, only softened.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      blur: 26,
      raised: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Drawn here rather than by `showDragHandle`, which paints outside
          // the clip and would have floated above the panel on nothing.
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.semantic.mutedText.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// A surface with the background genuinely blurred behind it.
///
/// For the bars and sheets that content slides underneath. Everywhere else,
/// prefer the translucent fill on its own — see the note on [Glass].
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.blur = 18,
    this.raised = false,
    this.border = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// Brighter fill, for something sitting forward of the page.
  final bool raised;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: raised ? Glass.raisedFill(context) : Glass.fill(context),
            borderRadius: borderRadius,
            border: border
                ? Border.all(color: Glass.edge(context), width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
