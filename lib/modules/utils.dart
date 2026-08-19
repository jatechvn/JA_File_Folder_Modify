// lib/modules/utils.dart

import 'dart:io';
import 'package:path/path.dart' as p;

class IniParser {
  final Map<String, Map<String, String>> _sections = {};

  IniParser(String content) {
    String currentSection = '';
    for (var line in content.split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1).trim();
        _sections[currentSection] = {};
      } else if (currentSection.isNotEmpty) {
        final eqIdx = line.indexOf('=');
        if (eqIdx != -1) {
          final key = line.substring(0, eqIdx).trim();
          final val = line.substring(eqIdx + 1).trim();
          _sections[currentSection]![key] = val;
        }
      }
    }
  }

  String? get(String section, String key) {
    return _sections[section]?[key];
  }
  
  String getWithFallback(String section, String key, String fallback) {
    return _sections[section]?[key] ?? fallback;
  }

  int getIntWithFallback(String section, String key, int fallback) {
    final valStr = get(section, key);
    if (valStr == null) return fallback;
    return int.tryParse(valStr) ?? fallback;
  }
}

String getBaseDir() {
  final exePath = Platform.resolvedExecutable;
  final exeName = p.basename(exePath).toLowerCase();
  
  if (exeName.contains('flutter') || exeName.contains('dart')) {
    return Directory.current.path;
  }
  
  return p.dirname(exePath);
}

File getConfigFile() {
  final baseDir = getBaseDir();
  return File(p.join(baseDir, 'config.ini'));
}

IniParser loadConfig() {
  final configFile = getConfigFile();
  if (configFile.existsSync()) {
    try {
      final content = configFile.readAsStringSync();
      return IniParser(content);
    } catch (_) {}
  }
  return IniParser('''
[Settings]
CSV_PATH = ./L10-PC-Name.csv
TEMP_DIR = ./temp_replace_scripts
MAX_THREADS = 50
''');
}

String resolvePath(String path) {
  if (path.startsWith('./') || path.startsWith('.\\')) {
    return p.join(getBaseDir(), path.substring(2));
  }
  if (p.isRelative(path)) {
    return p.join(getBaseDir(), path);
  }
  return path;
}
