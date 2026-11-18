import 'package:flutter/material.dart';

/// Centralized color palette matching the PaySplit Figma Design System.
class AppColors {
  AppColors._();

  // Brand (from Figma Style Guide & Onboarding)
  static const Color primary = Color(0xFF33A7F5);
  static const Color primaryDark = Color(0xFF0F324A);
  static const Color primaryDeep = Color(0xFF17415D);
  static const Color primaryLight = Color(0xFFEBF6FE);
  static const Color primarySoft = Color(0xFFD6EDFD);
  static const Color accent = Color(0xFF34C759);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF7F7F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF8F8F8);
  static const Color border = Color(0xFFEDEDED);
  static const Color divider = Color(0xFFE4E4E4);

  // Text
  static const Color textPrimary = Color(0xFF171918);
  static const Color textLabel = Color(0xFF344054);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF667085);

  // Semantic
  static const Color success = Color(0xFF11B01E);
  static const Color successBg = Color(0xFFEEF5F0);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFC65948);
  static const Color errorBg = Color(0xFFF7EDED);
  static const Color info = Color(0xFF33A7F5);
  static const Color infoBg = Color(0xFFEAF6FF);

  // Wallet accent color mapping from API enum
  static Color walletAccent(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'green':
        return const Color(0xFF34C759);
      case 'orange':
        return const Color(0xFFFF9500);
      case 'purple':
        return const Color(0xFF7C3AED);
      case 'blue':
        return primary;
      case 'red':
        return const Color(0xFFC65948);
      case 'yellow':
        return const Color(0xFFCA8A04);
      case 'teal':
        return const Color(0xFF0D9488);
      case 'pink':
        return const Color(0xFFDB2777);
      default:
        return primary;
    }
  }
}
