// lib/modules/logic.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'logger_config.dart';
import 'utils.dart';

class DeployStatus {
  final int id;
  final String pcName;
  String status;
  String targetPath;

  DeployStatus({
    required this.id,
    required this.pcName,
    this.status = 'Đang chạy…',
    this.targetPath = 'Đang khởi tạo…',
  });
}

class ConsoleStatus {
  final int id;
  final String pcName;
  String status;
  String output;

  ConsoleStatus({
    required this.id,
    required this.pcName,
    this.status = 'Đang chạy…',
    this.output = '',
  });
}

class AppLogic extends ChangeNotifier {
  // Deploy State
  List<DeployStatus> deployStatuses = [];
  String deployLog = '';
  bool isDeploying = false;

  // Console State
  List<ConsoleStatus> consoleStatuses = [];
  String consoleLog = '';
  bool isExecutingConsole = false;
  int consolePcCount = 0;

  void appendDeployLog(String msg) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    deployLog += '[$timeStr] $msg\n';
    logger.info('[UI] $msg');
    notifyListeners();
  }

  void appendConsoleLog(String msg) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    consoleLog += '[$timeStr] $msg\n';
    logger.info('[Console][UI] $msg');
    notifyListeners();
  }

  void clearConsoleLog() {
    consoleStatuses.clear();
    consoleLog = '';
    notifyListeners();
  }

  void updateConsolePcCount(String filterOption) {
    final config = loadConfig();
    final csvPath = config.getWithFallback('Settings', 'CSV_PATH', './L10-PC-Name.csv');
    final pcList = _getPcListFromCsv(csvPath, filterOption);
    consolePcCount = pcList.length;
    notifyListeners();
  }

  List<String> _getPcListFromCsv(String csvPath, String filterStr) {
    final file = File(resolvePath(csvPath));
    if (!file.existsSync()) {
      logger.warning('CSV file does not exist: ${file.path}');
      return [];
    }
    try {
      final lines = file.readAsLinesSync();
      if (lines.isEmpty) return [];

      final pcList = <String>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length > 1) {
          final pc = parts[1].trim();
          if (pc.isNotEmpty && pc.toLowerCase() != 'nan') {
            if (filterStr.isEmpty || pc.toLowerCase().contains(filterStr.toLowerCase())) {
              pcList.add(pc);
            }
          }
        }
      }
      return pcList;
    } catch (e, stack) {
      logger.severe('Failed to read CSV: $e', e, stack);
      return [];
    }
  }

  Future<void> runDeploy(String sourcePath, int mode, String filterStr) async {
    if (isDeploying) return;

    final config = loadConfig();
    final csvPath = config.getWithFallback('Settings', 'CSV_PATH', './L10-PC-Name.csv');
    final maxThreads = config.getIntWithFallback('Settings', 'MAX_THREADS', 50);

    final resolvedSource = resolvePath(sourcePath);
    if (!FileSystemEntity.isFileSync(resolvedSource) && !FileSystemEntity.isDirectorySync(resolvedSource)) {
      appendDeployLog('Lỗi: Đường dẫn nguồn không hợp lệ hoặc không tồn tại: $resolvedSource');
      return;
    }

    final pcList = _getPcListFromCsv(csvPath, filterStr);
    if (pcList.isEmpty) {
      appendDeployLog('Thông báo: Không tìm thấy PC nào phù hợp với bộ lọc: "$filterStr"');
      return;
    }

    isDeploying = true;
    deployLog = '';
    deployStatuses = List.generate(pcList.length, (index) {
      return DeployStatus(
        id: index + 1,
        pcName: pcList[index],
      );
    });
    appendDeployLog('Bắt đầu xử lý (${mode == 1 ? "Replace" : "Delete"}) cho ${pcList.length} máy…');
    notifyListeners();

    final isDir = FileSystemEntity.isDirectorySync(resolvedSource);

    // Run parallel tasks with a concurrency limit
    await _runWithLimit<String>(pcList, maxThreads, (pcName) async {
      final drive = p.split(resolvedSource).first;
      final driveLetter = drive.isNotEmpty && drive.endsWith(':') ? drive[0] : 'C';
      
      // Compute UNC remote target path
      // e.g. \\PC-01\C$\path\to\file
      final cleanPath = p.relative(resolvedSource, from: p.rootPrefix(resolvedSource));
      final targetPath = '\\\\$pcName\\$driveLetter\$\\$cleanPath';

      // Parse parts to get local_remote_path inside remote computer
      final parts = targetPath.split('\\');
      final remoteDrive = (parts.length > 3 && parts[3].isNotEmpty) ? parts[3][0] : 'C';
      String localRemotePath = (parts.length > 4) ? '$remoteDrive:\\${parts.sublist(4).join('\\')}' : '$remoteDrive:\\';
      if (localRemotePath.endsWith('\\') && localRemotePath.length > 3) {
        localRemotePath = localRemotePath.substring(0, localRemotePath.length - 1);
      }

      final psScript = _buildDeployPsScript(pcName, resolvedSource.replaceAll('/', '\\'), localRemotePath.replaceAll('/', '\\'), mode, isDir);
      
      final index = pcList.indexOf(pcName);
      try {
        final result = await Process.run(
          'powershell',
          ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', psScript],
          runInShell: true,
        );

        final stdout = result.stdout as String? ?? '';
        final stderr = result.stderr as String? ?? '';
        final exitCode = result.exitCode;

        _parseDeployOutput(pcName, stdout, stderr, exitCode, targetPath, index);
      } catch (e) {
        logger.severe('[$pcName] Exception running PowerShell: $e');
        _updateDeployStatus(index, 'Lỗi: ${e.toString()}', targetPath);
      }
    });

    isDeploying = false;
    appendDeployLog('Hoàn tất toàn bộ tác vụ triển khai.');
    notifyListeners();
  }

  void _updateDeployStatus(int index, String status, String targetPath) {
    if (index >= 0 && index < deployStatuses.length) {
      deployStatuses[index].status = status;
      deployStatuses[index].targetPath = targetPath;
      notifyListeners();
    }
  }

  void _parseDeployOutput(String pcName, String stdout, String stderr, int exitCode, String targetPath, int index) {
    for (var line in stdout.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('KILL|')) {
        final parts = line.split('|');
        final tag = parts.length > 1 ? parts[1] : '?';
        if (tag == 'OK' && parts.length >= 6) {
          appendDeployLog('[$pcName] Kill OK | PID=${parts[2]} | ${parts[3]} | ${parts[4]} | method=${parts[5]}');
        } else if (tag == 'FAIL' && parts.length >= 6) {
          appendDeployLog('[$pcName] Kill FAIL | PID=${parts[2]} | ${parts[3]} | ${parts[4]} | ${parts[5]}');
        } else if (tag == 'NONE' && parts.length >= 4) {
          appendDeployLog('[$pcName] Kill: ${parts[2]} | ${parts[3]}');
        } else if (tag == 'SKIP' && parts.length >= 4) {
          appendDeployLog('[$pcName] Kill skip: ${parts[2]} | ${parts[3]}');
        } else {
          appendDeployLog('[$pcName] Kill raw: $line');
        }
      } else if (line.startsWith('ERROR:')) {
        appendDeployLog('[$pcName] PowerShell: $line');
      } else if (line == 'SUCCESS') {
        appendDeployLog('[$pcName] PowerShell: SUCCESS');
      } else if (line.startsWith('LOG|')) {
        appendDeployLog('[$pcName] $line');
      }
    }

    if (stderr.trim().isNotEmpty) {
      for (var errLine in stderr.trim().split('\n')) {
        if (errLine.trim().isNotEmpty) {
          appendDeployLog('[$pcName] stderr: ${errLine.trim()}');
        }
      }
    }

    if (exitCode != 0) {
      appendDeployLog('[$pcName] PowerShell exit code: $exitCode');
    }

    if (stdout.contains('SUCCESS')) {
      _updateDeployStatus(index, 'Thành công', targetPath);
      appendDeployLog('[OK] $pcName hoàn tất.');
    } else {
      String errorMsg = 'Lỗi';
      if (stdout.contains('ERROR:')) {
        final lines = stdout.split('\n');
        for (var l in lines) {
          if (l.contains('ERROR:')) {
            errorMsg = l.replaceAll('ERROR:', '').trim();
            break;
          }
        }
      } else if (stderr.trim().isNotEmpty) {
        errorMsg = stderr.trim().split('\n').first;
      }
      _updateDeployStatus(index, 'Lỗi: $errorMsg', targetPath);
      appendDeployLog('[FAIL] $pcName: Lỗi: $errorMsg');
    }
  }

  Future<void> runConsoleCommand(String command, String filterOption) async {
    if (isExecutingConsole) return;

    final config = loadConfig();
    final csvPath = config.getWithFallback('Settings', 'CSV_PATH', './L10-PC-Name.csv');
    final maxThreads = config.getIntWithFallback('Settings', 'MAX_THREADS', 50);

    final pcList = _getPcListFromCsv(csvPath, filterOption);
    if (pcList.isEmpty) {
      appendConsoleLog('Thông báo: Không tìm thấy PC nào phù hợp với bộ lọc: "$filterOption"');
      return;
    }

    isExecutingConsole = true;
    consoleStatuses = List.generate(pcList.length, (index) {
      return ConsoleStatus(
        id: index + 1,
        pcName: pcList[index],
      );
    });
    appendConsoleLog('▶ Thực thi \'$command\' trên ${pcList.length} máy…');
    notifyListeners();

    await _runWithLimit<String>(pcList, maxThreads, (pcName) async {
      final psScript = _buildConsolePsScript(pcName, command);
      final index = pcList.indexOf(pcName);

      try {
        final result = await Process.run(
          'powershell',
          ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', psScript],
          runInShell: true,
        ).timeout(const Duration(seconds: 120));

        final stdout = result.stdout as String? ?? '';
        final stderr = result.stderr as String? ?? '';

        _parseConsoleOutput(pcName, stdout, stderr, index);
      } on TimeoutException {
        logger.warning('[$pcName] Console Timeout');
        _updateConsoleStatus(index, 'FAIL', 'Timeout (>120s)');
        appendConsoleLog('[FAIL] $pcName: Timeout (>120s)');
      } catch (e) {
        logger.severe('[$pcName] Exception running console: $e');
        _updateConsoleStatus(index, 'FAIL', e.toString());
        appendConsoleLog('[FAIL] $pcName: ${e.toString()}');
      }
    });

    isExecutingConsole = false;
    notifyListeners();
  }

  void _updateConsoleStatus(int index, String status, String output) {
    if (index >= 0 && index < consoleStatuses.length) {
      consoleStatuses[index].status = status;
      consoleStatuses[index].output = output;
      notifyListeners();
    }
  }

  void _parseConsoleOutput(String pcName, String stdout, String stderr, int index) {
    final outputLines = <String>[];
    var success = false;

    for (var line in stdout.split('\n')) {
      final s = line.trim();
      if (s.startsWith('OUTPUT|')) {
        outputLines.add(s.substring('OUTPUT|'.length).trim());
      } else if (s.startsWith('DONE|OK')) {
        success = true;
      } else if (s.startsWith('DONE|FAIL|')) {
        outputLines.add(s.substring('DONE|FAIL|'.length).trim());
      } else if (s.startsWith('ERROR|')) {
        outputLines.add('[ERR] ${s.substring('ERROR|'.length).trim()}');
      }
    }

    if (stderr.trim().isNotEmpty && !success) {
      outputLines.add('[stderr] ${stderr.trim()}');
    }

    final outputText = outputLines.isNotEmpty ? outputLines.join('\n') : (success ? 'OK' : 'No output');
    final firstLine = outputText.split('\n').first;

    _updateConsoleStatus(index, success ? 'OK' : 'FAIL', firstLine);
    
    if (success) {
      appendConsoleLog('[OK] $pcName: $firstLine');
    } else {
      appendConsoleLog('[FAIL] $pcName: $outputText');
    }
  }

  // Helper function to run futures in parallel with a concurrency limit
  Future<void> _runWithLimit<T>(List<T> items, int limit, Future<void> Function(T item) action) async {
    var index = 0;
    Future<void> worker() async {
      while (index < items.length) {
        final current = index++;
        await action(items[current]);
      }
    }
    final workers = List.generate(limit > items.length ? items.length : limit, (_) => worker());
    await Future.wait(workers);
  }

  // --- PowerShell script builders ---

  String _buildDeployPsScript(String pcName, String sourceNorm, String localRemotePath, int mode, bool isDir) {
    final psKillFunctions = r'''
function Normalize-PathString {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    } catch {
        return $Path.TrimEnd('\')
    }
}

function Test-ProcessMatchesTarget {
    param(
        [string]$ProcPath,
        [string]$CommandLine,
        [string]$TargetPath,
        [bool]$IsFile
    )

    $target = Normalize-PathString $TargetPath
    $procPath = Normalize-PathString $ProcPath
    $cmd = if ($CommandLine) { $CommandLine } else { "" }

    if ($IsFile) {
        if ($procPath -and ($procPath -ieq $target)) { return $true }
        if ($cmd -and $cmd -match [regex]::Escape($target)) { return $true }
        return $false
    }

    if ($procPath -and $procPath.StartsWith($target, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($cmd -and $cmd -match [regex]::Escape($target)) { return $true }
    return $false
}

function Get-LockingProcesses {
    param([string]$TargetPath)
    $found = @{}
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Write-Output "KILL|SKIP|$TargetPath|Duong dan khong ton tai tren may dich"
        return @()
    }

    $item = Get-Item -LiteralPath $TargetPath -ErrorAction SilentlyContinue
    $isFile = $item -is [System.IO.FileInfo]
    $targetNorm = Normalize-PathString $TargetPath

    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
        $wp = $_
        $match = Test-ProcessMatchesTarget -ProcPath $wp.ExecutablePath -CommandLine $wp.CommandLine -TargetPath $targetNorm -IsFile $isFile
        if ($match -and -not $found.ContainsKey($wp.ProcessId)) {
            $found[$wp.ProcessId] = [PSCustomObject]@{
                Id = $wp.ProcessId
                Name = $wp.Name
                Path = $wp.ExecutablePath
                CommandLine = $wp.CommandLine
                Method = "CIM.ExecutablePath+CommandLine"
            }
        }
    }

    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $p = $_
        if (-not $p.Path) { return }
        $match = Test-ProcessMatchesTarget -ProcPath $p.Path -CommandLine $null -TargetPath $targetNorm -IsFile $isFile
        if ($match -and -not $found.ContainsKey($p.Id)) {
            $found[$p.Id] = [PSCustomObject]@{
                Id = $p.Id
                Name = $p.ProcessName
                Path = $p.Path
                CommandLine = ""
                Method = "Get-Process.Path"
            }
        }
    }

    return @($found.Values)
}

function Stop-LockingProcesses {
    param([string]$TargetPath)
    $procs = Get-LockingProcesses -TargetPath $TargetPath
    if ($procs.Count -eq 0) {
        Write-Output "KILL|NONE|$TargetPath|Khong tim thay process (ExecutablePath / CommandLine / Path)"
        return
    }
    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Output "KILL|OK|$($proc.Id)|$($proc.Name)|$($proc.Path)|$($proc.Method)"
        } catch {
            Write-Output "KILL|FAIL|$($proc.Id)|$($proc.Name)|$($proc.Path)|$($_.Exception.Message)"
        }
    }
}
''';

    final psInvokeKill = '''
Invoke-Command -Session \$session -ScriptBlock {
    param(\$path)
    \$ErrorActionPreference = 'Stop'

    Get-Process -Name javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $psKillFunctions
    Stop-LockingProcesses -TargetPath \$path
} -ArgumentList \$localRemotePath -ErrorAction SilentlyContinue
''';

    var psScript = '''
\$pc = "$pcName"
\$user = "FT"
\$pass = "123"
\$sourceNorm = "$sourceNorm"
\$localRemotePath = "$localRemotePath"

try {
    \$secPasswd = ConvertTo-SecureString \$pass -AsPlainText -Force
    \$cred = New-Object System.Management.Automation.PSCredential (\$user, \$secPasswd)

    \$session = New-PSSession -ComputerName \$pc -Credential \$cred -ErrorAction Stop
    Write-Output "LOG|SESSION|OK|\$pc"
''';

    if (mode == 1) {
      psScript += psInvokeKill;
      if (isDir) {
        psScript += '''
        Invoke-Command -Session \$session -ScriptBlock {
            param(\$path)
            if (-not (Test-Path \$path)) {
                New-Item -ItemType Directory -Force -Path \$path | Out-Null
            }
        } -ArgumentList \$localRemotePath -ErrorAction Stop

        Copy-Item -Path "\$sourceNorm\\*" -Destination \$localRemotePath -ToSession \$session -Recurse -Force -ErrorAction Stop
        Write-Output "LOG|COPY|OK|\$localRemotePath"
        ''';
      } else {
        psScript += '''
        Invoke-Command -Session \$session -ScriptBlock {
            param(\$path)
            \$remotePath = (Split-Path \$path)
            if (-not (Test-Path \$remotePath)) {
                New-Item -ItemType Directory -Force -Path \$remotePath | Out-Null
            }
            if (Test-Path \$path) {
                try {
                    \$bakName = (Split-Path \$path -Leaf) + ".\$([Guid]::NewGuid().ToString().Substring(0,6)).bak"
                    Rename-Item -Path \$path -NewName \$bakName -Force -ErrorAction Stop
                    Write-Output "LOG|RENAME|OK|\$path -> \$bakName"
                } catch {
                    Write-Output "LOG|RENAME|FAIL|\$path|\$(\$_.Exception.Message)"
                }
            }
        } -ArgumentList \$localRemotePath -ErrorAction Stop

        Copy-Item -Path "\$sourceNorm" -Destination \$localRemotePath -ToSession \$session -Force -ErrorAction Stop
        Write-Output "LOG|COPY|OK|\$localRemotePath"
        ''';
      }
    } else if (mode == 2) {
      psScript += '''
      Invoke-Command -Session \$session -ScriptBlock {
          param(\$path)
          \$ErrorActionPreference = 'Stop'

          Get-Process -Name javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
          $psKillFunctions
          Stop-LockingProcesses -TargetPath \$path
          if (Test-Path \$path) {
              \$item = Get-Item -LiteralPath \$path
              if (\$item -is [System.IO.FileInfo]) {
                  Remove-Item -LiteralPath \$path -Force -ErrorAction Stop
                  Write-Output "LOG|DELETE|OK|file|\$path"
              } else {
                  Remove-Item -LiteralPath \$path -Recurse -Force -ErrorAction Stop
                  Write-Output "LOG|DELETE|OK|folder|\$path"
              }
          } else {
              Write-Output "LOG|DELETE|SKIP|\$path|Khong ton tai"
          }
      } -ArgumentList \$localRemotePath -ErrorAction Stop
      ''';
    }

    psScript += '''
    Write-Output "SUCCESS"
} catch {
    Write-Output "ERROR: \$(\$_.Exception.Message)"
} finally {
    if (\$session) {
        Remove-PSSession -Session \$session -ErrorAction SilentlyContinue
    }
}
''';

    return psScript;
  }

  String _buildConsolePsScript(String pcName, String command) {
    final safeCmd = command.replaceAll("'", "''");

    return '''
\$pc   = '$pcName'
\$user = 'FT'
\$pass = '123'

try {
    \$secPasswd = ConvertTo-SecureString \$pass -AsPlainText -Force
    \$cred      = New-Object System.Management.Automation.PSCredential (\$user, \$secPasswd)
    \$session   = New-PSSession -ComputerName \$pc -Credential \$cred -ErrorAction Stop

    \$result = Invoke-Command -Session \$session -ScriptBlock {
        \$ErrorActionPreference = 'Continue'
        try {
            \$out = Invoke-Expression '$safeCmd' 2>&1 | Out-String
            Write-Output "OUTPUT|\$out"
        } catch {
            Write-Output "ERROR|\$(\$_.Exception.Message)"
        }
    } -ErrorAction Stop

    Remove-PSSession -Session \$session -ErrorAction SilentlyContinue
    Write-Output \$result
    Write-Output "DONE|OK"
} catch {
    Write-Output "DONE|FAIL|\$(\$_.Exception.Message)"
}
''';
  }
}
