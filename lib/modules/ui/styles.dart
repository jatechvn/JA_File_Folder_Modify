// lib/modules/ui/styles.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'styles_win10.dart';
import 'styles_win11.dart';

class ThemeProvider extends ChangeNotifier {
  static const _channel = MethodChannel('ja_route/theme');
  
  bool _isDark = true;
  bool get isDark => _isDark;

  bool _isWin11 = false;
  bool get isWin11 => _isWin11;

  ThemeProvider() {
    _detectWindowsVersion();
    _applyNativeTheme();
  }

  void _detectWindowsVersion() {
    if (!Platform.isWindows) return;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        _isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }

  void toggleTheme() {
    _isDark = !_isDark;
    _applyNativeTheme();
    notifyListeners();
  }

  Future<void> _applyNativeTheme() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('updateTheme', {'isDark': _isDark});
    } catch (e) {
      print('Failed to apply native theme: $e');
    }
  }

  Color get scaffoldBg => Colors.transparent;

  Color get sidebarBg {
    if (Platform.isWindows && !_isWin11) {
      return _isDark ? StylesWin10.sidebarBgDark : StylesWin10.sidebarBgLight;
    }
    return _isDark ? StylesWin11.sidebarBgDark : StylesWin11.sidebarBgLight;
  }

  Color get cardBg {
    if (Platform.isWindows && !_isWin11) {
      return _isDark ? StylesWin10.cardBgDark : StylesWin10.cardBgLight;
    }
    return _isDark ? StylesWin11.cardBgDark : StylesWin11.cardBgLight;
  }

  Color get mainBg {
    if (Platform.isWindows && !_isWin11) {
      return _isDark ? StylesWin10.mainBgDark : StylesWin10.mainBgLight;
    }
    return _isDark ? StylesWin11.mainBgDark : StylesWin11.mainBgLight;
  }

  Color get textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get textSecondary => _isDark ? Colors.white70 : Colors.black54;
  Color get borderTheme => _isDark ? Colors.white10 : Colors.black12;
  
  ThemeData get themeData {
    return ThemeData(
      brightness: _isDark ? Brightness.dark : Brightness.light,
      primaryColor: const Color(0xFF00ADB5),
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: cardBg,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Outfit'),
      ),
    );
  }
}
