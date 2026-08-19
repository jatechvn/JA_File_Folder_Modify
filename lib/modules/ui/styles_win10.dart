// lib/modules/ui/styles_win10.dart

import 'package:flutter/material.dart';

class StylesWin10 {
  static const Color scaffoldBackgroundColor = Colors.transparent;
  
  // Dark theme colors (Windows 10)
  static final Color sidebarBgDark = const Color(0xFF1F1F1F).withOpacity(0.70); // 70% opacity
  static final Color cardBgDark = const Color(0xFF2C2C2C).withOpacity(0.85); // 85% opacity
  static final Color mainBgDark = const Color(0xFF121212).withOpacity(0.50); // 50% opacity
  static const Color textPrimaryDark = Color(0xFFEEEEEE);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  
  // Light theme colors (Windows 10)
  static final Color sidebarBgLight = const Color(0xFFF3F3F3).withOpacity(0.70);
  static final Color cardBgLight = const Color(0xFFFFFFFF).withOpacity(0.85);
  static final Color mainBgLight = const Color(0xFFFAFAFA).withOpacity(0.50);
  static const Color textPrimaryLight = Color(0xFF1F1F1F);
  static const Color textSecondaryLight = Color(0xFF757575);
}
