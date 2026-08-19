// lib/modules/native_bridge.dart
import 'dart:io' show Platform;
import 'package:logging/logging.dart';
import 'native/win_core.dart';
import 'native/mac_core.dart';
import 'native/linux_core.dart';

final _logger = Logger('NativeBridge');

abstract class NativeEngine {
  dynamic heavyCompute(dynamic dataInput);
}

class NativeBridge {
  final String osName;
  NativeEngine? engine;

  NativeBridge() : osName = Platform.operatingSystem {
    _initializeEngine();
  }

  void _initializeEngine() {
    try {
      if (Platform.isWindows) {
        engine = WindowsNativeEngine();
      } else if (Platform.isMacOS) {
        engine = MacNativeEngine();
      } else if (Platform.isLinux) {
        engine = LinuxNativeEngine();
      } else {
        _logger.warning('[BRIDGE] OS $osName is not supported by Hybrid Core. Using fallback.');
      }
    } catch (e) {
      _logger.severe('[BRIDGE] Failed to initialize engine for $osName: $e');
    }
  }

  dynamic executeHeavyTask(dynamic dataInput) {
    if (engine != null) {
      return engine!.heavyCompute(dataInput);
    }
    return _pureDartFallback(dataInput);
  }

  dynamic _pureDartFallback(dynamic dataInput) {
    _logger.info('[BRIDGE] Processing using pure Dart algorithm (slower).');
    return dataInput;
  }
}

final nativeAgent = NativeBridge();
