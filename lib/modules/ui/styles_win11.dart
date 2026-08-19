// lib/modules/ui/styles_win11.dart

import 'package:flutter/material.dart';

class StylesWin11 {
  static const Color scaffoldBackgroundColor = Colors.transparent;

  // Dark theme colors (Windows 11)
  static final Color sidebarBgDark = const Color(0xFF1C1C1C).withOpacity(0.20); // Acrylic transparent
  static final Color cardBgDark = const Color(0xFF2D2D2D).withOpacity(0.35);
  static final Color mainBgDark = const Color(0xFF000000).withOpacity(0.10);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFCCCCCC);

  // Light theme colors (Windows 11)
  static final Color sidebarBgLight = const Color(0xFFE5E5E5).withOpacity(0.20);
  static final Color cardBgLight = const Color(0xFFFFFFFF).withOpacity(0.35);
  static final Color mainBgLight = const Color(0xFFFAFAFA).withOpacity(0.10);
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF555555);
}
