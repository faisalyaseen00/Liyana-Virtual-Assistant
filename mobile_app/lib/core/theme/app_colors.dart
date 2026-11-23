import 'package:flutter/material.dart';

/// Liyana's light colour palette. Screens should use these (or the theme)
/// instead of hard-coded colours, so the look stays consistent.
class AppColors {
  AppColors._();

  // Brand — the violet from the Liyana logo.
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF5544D6);
  static const Color primarySoft = Color(0xFFEFECFF); // tinted backgrounds
  static const Color accent = Color(0xFF8E7CFF);

  // Surfaces
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F2F7); // inputs, chips
  static const Color outline = Color(0xFFE6E8F0);

  // Text
  static const Color textPrimary = Color(0xFF1B1D29);
  static const Color textSecondary = Color(0xFF5E6375);
  static const Color textMuted = Color(0xFF9AA0B2);

  // Status colours, each with a soft background for pills and icons.
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE7F6EC);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3E2);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0xFFE5F3FB);

  /// The brand gradient used on hero cards and the Liyana mark.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B6CF6), Color(0xFF5544D6)],
  );

  /// A soft, modern card shadow.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F1B1D29), blurRadius: 18, offset: Offset(0, 6)),
  ];
}
