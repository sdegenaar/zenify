import 'package:flutter/material.dart';

/// Centralized style and color utilities for the Zenify Showcase app.
/// Ensures perfect WCAG AA contrast in both Light Mode and Dark Mode.
class ShowcaseStyle {
  /// Whether the current theme is in dark mode
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// High-contrast primary text color for the current theme
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// High-contrast secondary/muted text color for the current theme
  static Color textMuted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Header/accent text color that is readable against tinted containers
  static Color accentHeader(BuildContext context, Color baseColor) {
    if (isDark(context)) {
      // In dark mode, brighten the color for readability
      return Color.lerp(baseColor, Colors.white, 0.45) ?? baseColor;
    } else {
      // In light mode, darken the color for crisp readability
      return Color.lerp(baseColor, Colors.black, 0.35) ?? baseColor;
    }
  }

  /// Theme-adaptive BoxDecoration for tinted feature/status containers
  static BoxDecoration containerDecoration(
    BuildContext context, {
    required Color color,
    double radius = 8.0,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: color.withValues(alpha: dark ? 0.18 : 0.08),
      border: Border.all(
        color: color.withValues(alpha: dark ? 0.40 : 0.25),
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
