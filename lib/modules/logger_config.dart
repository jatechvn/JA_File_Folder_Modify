// lib/modules/logger_config.dart

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';

final Logger logger = Logger(appName);

Future<void> initLogger() async {
  // Set default level
  Logger.root.level = Level.ALL;

  Directory? logDir;
  File? logFile;

  try {
    // 1. Try to write in logs/ directory adjacent to the executable
    final exeFile = File(Platform.resolvedExecutable);
    final exeDir = exeFile.parent;
    logDir = Directory('${exeDir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    logFile = File('${logDir.path}/$dateStr.log');
  } catch (e) {
    // 2. Fallback to AppData / system local support path
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      logDir = Directory('${appSupportDir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      logFile = File('${logDir.path}/$dateStr.log');
    } catch (e2) {
      // 3. Fallback to current working directory
      try {
        logDir = Directory('logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        logFile = File('logs/$dateStr.log');
      } catch (_) {}
    }
  }

  Logger.root.onRecord.listen((record) {
    final logMessage = '${record.time} [${record.level.name}] [${record.loggerName}]: ${record.message}${record.error != null ? '\nError: ${record.error}' : ''}${record.stackTrace != null ? '\nStacktrace: ${record.stackTrace}' : ''}';
    
    // Print to stdout
    print(logMessage);

    // Append to file
    if (logFile != null) {
      try {
        logFile.writeAsStringSync('$logMessage\n', mode: FileMode.append);
      } catch (_) {}
    }
  });

  logger.info('Logger initialized. Saving logs to: ${logFile?.path}');
}
