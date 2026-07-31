import 'package:flutter/material.dart';

/// NekoCast brand palette inspired by the fox-tail logo:
/// warm amber highlights, deep wooden surfaces and a darker cinema backdrop.
class AppColors {
  AppColors._();

  // Primary colors - orange/amber brand
  static const Color primary = Color(0xFFE67B2D);
  static const Color primaryLight = Color(0xFFF5A34F);
  static const Color primaryDark = Color(0xFFB85B1F);
  static const Color primaryGlow = Color(0xFFFFC36B);

  // Secondary colors - wood/cardboard support
  static const Color secondary = Color(0xFF8B5C38);
  static const Color secondaryLight = Color(0xFFC58D5C);
  static const Color secondaryDark = Color(0xFF5D3922);

  // Accent colors - cream/gold contrast for CTA chips
  static const Color accent = Color(0xFFF4CA78);
  static const Color accentLight = Color(0xFFFFE3AF);
  static const Color accentDark = Color(0xFFD79A3B);

  // Background colors - darker, warmer streaming surfaces
  static const Color background = Color(0xFF120B08);
  static const Color backgroundLight = Color(0xFF1B120D);
  static const Color surface = Color(0xFF241712);
  static const Color surfaceLight = Color(0xFF32211A);
  static const Color surfaceHover = Color(0xFF3E281E);

  // Text colors
  static const Color textPrimary = Color(0xFFFFF8F1);
  static const Color textSecondary = Color(0xFFD8C5B7);
  static const Color textTertiary = Color(0xFFA58B7B);
  static const Color textDisabled = Color(0xFF6F594D);

  // Status Colors
  static const Color success = Color(0xFF4CAF50); // Green 500
  static const Color warning = Color(0xFFFFC107); // Amber 500
  static const Color error = Color(0xFFF44336); // Red 500
  static const Color info = Color(0xFF2196F3); // Blue 500

  // Feature-specific Colors
  static const Color qualityTag = Color(0xFF9E6A33);
  static const Color speedTag = Color(0xFF4B88C7);
  static const Color cloudTag = Color(0xFF5FA56D);
  static const Color liveIndicator = Color(0xFFFF6A4D);

  // Gradient Presets
  static const List<Color> primaryGradient = [
    Color(0xFFF5A34F),
    Color(0xFFE67B2D),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFC58D5C),
    Color(0xFF8B5C38),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFFFE3AF),
    Color(0xFFD79A3B),
  ];

  static const List<Color> heroGradient = [
    Color(0xFFF29D4B),
    Color(0xFF8B4A28),
  ];

  // Utility methods
  static LinearGradient getPrimaryGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: primaryGradient);
  }

  static LinearGradient getSecondaryGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: secondaryGradient);
  }

  static LinearGradient getHeroGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: heroGradient);
  }

  // Shadow colors with opacity
  static Color get primaryShadow => primary.withValues(alpha: 0.3);
  static Color get secondaryShadow => secondary.withValues(alpha: 0.3);
  static Color get accentShadow => accent.withValues(alpha: 0.3);
}
