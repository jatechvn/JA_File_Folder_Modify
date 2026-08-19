// lib/modules/ui/main_window.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../logic.dart';
import '../constants.dart';
import 'styles.dart';
import 'localization.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _activeTab = 0; // 0: Deploy, 1: Console

  // Controllers for Tab 1 (Deploy)
  final TextEditingController _filePathController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  int _deployMode = 1; // 1: Replace, 2: Delete
  final ScrollController _deployScrollController = ScrollController();
  final ScrollController _deployLogScrollController = ScrollController();

  // Controllers for Tab 2 (Console)
  final TextEditingController _consoleCmdController = TextEditingController();
  String _consoleFilter = ''; // '': All, 'MMI': MMI, 'CMDL': CMDL
  final ScrollController _consoleScrollController = ScrollController();
  final ScrollController _consoleLogScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppLogic>(context, listen: false).updateConsolePcCount(_consoleFilter);
    });
  }

  @override
  void dispose() {
    _filePathController.dispose();
    _filterController.dispose();
    _consoleCmdController.dispose();
    _deployScrollController.dispose();
    _deployLogScrollController.dispose();
    _consoleScrollController.dispose();
    _consoleLogScrollController.dispose();
    super.dispose();
  }

  void _updateFilterBasedOnPath(String path) {
    if (path.toUpperCase().contains('MMI')) {
      _filterController.text = 'MMI';
    } else if (path.toUpperCase().contains('CMDL')) {
      _filterController.text = 'CMDL';
    }
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select File to Deploy',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _filePathController.text = path;
      _updateFilterBasedOnPath(path);
    }
  }

  Future<void> _selectFolder() async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Folder to Deploy',
    );
    if (result != null) {
      _filePathController.text = result;
      _updateFilterBasedOnPath(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final logic = Provider.of<AppLogic>(context);
    final lang = Provider.of<LanguageProvider>(context);

    // Auto-scroll logs to end when content changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_deployLogScrollController.hasClients) {
        _deployLogScrollController.jumpTo(_deployLogScrollController.position.maxScrollExtent);
      }
      if (_consoleLogScrollController.hasClients) {
        _consoleLogScrollController.jumpTo(_consoleLogScrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Row(
        children: [
          // 1. LEFT SIDEBAR
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: theme.sidebarBg,
              border: Border(right: BorderSide(color: theme.borderTheme, width: 1)),
            ),
            child: Column(
              children: [
                // Top spacing to avoid system title bar overlay
                const SizedBox(height: 48),

                // Sidebar Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_shared, color: Color(0xFF00ADB5), size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'v$appVersion',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textSecondary.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 16),

                // Navigation Tabs
                _buildSidebarTabButton(
                  index: 0,
                  icon: Icons.drive_file_move_outlined,
                  title: context.tr('tab_deploy'),
                  theme: theme,
                ),
                _buildSidebarTabButton(
                  index: 1,
                  icon: Icons.terminal_outlined,
                  title: context.tr('tab_console'),
                  theme: theme,
                ),

                const Spacer(),

                // Language & Theme controls at bottom
                const Divider(height: 1, color: Colors.white10),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language switch button
                      IconButton(
                        tooltip: 'Language / Ngôn ngữ',
                        onPressed: () {
                          lang.setLocale(lang.locale == 'vi' ? 'en' : 'vi');
                          logic.updateConsolePcCount(_consoleFilter);
                        },
                        icon: const Icon(Icons.language, color: Color(0xFF00ADB5)),
                      ),
                      // Theme Switch button
                      TextButton.icon(
                        onPressed: () => theme.toggleTheme(),
                        icon: Icon(
                          theme.isDark ? Icons.light_mode : Icons.dark_mode,
                          color: const Color(0xFF00ADB5),
                          size: 20,
                        ),
                        label: Text(
                          theme.isDark ? context.tr('theme_light') : context.tr('theme_dark'),
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. MAIN CONTENT AREA
          Expanded(
            child: Container(
              color: theme.mainBg,
              child: Column(
                children: [
                  // Spacer to avoid title bar buttons on the right
                  const SizedBox(height: 48),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: _activeTab == 0 ? _buildDeployView(theme, logic) : _buildConsoleView(theme, logic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTabButton({
    required int index,
    required IconData icon,
    required String title,
    required ThemeProvider theme,
  }) {
    final isSelected = _activeTab == index;
    final accentColor = const Color(0xFF00ADB5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _activeTab = index;
            });
          },
          icon: Icon(
            icon,
            color: isSelected ? accentColor : theme.textSecondary,
            size: 20,
          ),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? theme.textPrimary : theme.textSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: DEPLOY VIEW ---
  Widget _buildDeployView(ThemeProvider theme, AppLogic logic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Source selector (with Drag & Drop support)
        Text(
          context.tr('label_source'),
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        DropTarget(
          onDragDone: (details) {
            if (details.files.isNotEmpty) {
              final path = details.files.first.path;
              _filePathController.text = path;
              _updateFilterBasedOnPath(path);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.borderTheme),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _filePathController,
                      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFF00ADB5)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Drag file/folder here or select...',
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _selectFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    foregroundColor: theme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(context.tr('btn_select_file')),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectFolder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    foregroundColor: theme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(context.tr('btn_select_folder')),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Mode selection
        Row(
          children: [
            Text(
              context.tr('label_mode'),
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(width: 16),
            Radio<int>(
              value: 1,
              groupValue: _deployMode,
              activeColor: const Color(0xFF00ADB5),
              onChanged: (val) {
                if (val != null) setState(() => _deployMode = val);
              },
            ),
            Text(context.tr('mode_replace'), style: TextStyle(color: theme.textPrimary, fontSize: 13)),
            const SizedBox(width: 16),
            Radio<int>(
              value: 2,
              groupValue: _deployMode,
              activeColor: const Color(0xFF00ADB5),
              onChanged: (val) {
                if (val != null) setState(() => _deployMode = val);
              },
            ),
            Text(context.tr('mode_delete'), style: TextStyle(color: theme.textPrimary, fontSize: 13)),
          ],
        ),

        const SizedBox(height: 12),

        // 3. PC Name Filter
        Text(
          context.tr('label_filter'),
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderTheme),
          ),
          child: TextField(
            controller: _filterController,
            style: TextStyle(color: theme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'e.g. MMI, CMDL...',
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 4. Start Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: logic.isDeploying
                ? null
                : () {
                    final source = _filePathController.text.trim();
                    if (source.isEmpty) {
                      _showSnackBar(context.tr('err_invalid_path'));
                      return;
                    }
                    logic.runDeploy(source, _deployMode, _filterController.text.trim());
                  },
            style: ElevatedButton.styleFrom(
              backgroundBuilder: (context, states, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00ADB5), Color(0xFF0056FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: child,
                );
              },
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: logic.isDeploying
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    context.tr('btn_start_deploy'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: 0.5),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // 5. Deployment status table
        Text(
          context.tr('label_status'),
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: _buildDeployTable(logic.deployStatuses, theme),
        ),

        const SizedBox(height: 12),

        // 6. Log console output
        Container(
          height: 95,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderTheme),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView(
              controller: _deployLogScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                SelectableText(
                  logic.deployLog.isEmpty ? 'System Logs Idle...' : logic.deployLog.trim(),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12.5,
                    color: Color(0xFF00ADB5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeployTable(List<DeployStatus> statuses, ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    context.tr('col_id'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    context.tr('col_pc'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    context.tr('col_status'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    context.tr('col_path'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: Scrollbar(
              controller: _deployScrollController,
              child: ListView.builder(
                controller: _deployScrollController,
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final item = statuses[index];
                  Color statusColor = theme.isDark ? const Color(0xFF00D4FF) : const Color(0xFF0056FF);
                  if (item.status.contains('Thành công') || item.status == 'OK') {
                    statusColor = const Color(0xFF00FF9D);
                  } else if (item.status.contains('Lỗi') || item.status.contains('FAIL')) {
                    statusColor = const Color(0xFFFF4500);
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: theme.borderTheme, width: 0.5)),
                      color: item.status.contains('Lỗi')
                          ? Colors.redAccent.withOpacity(0.06)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text('${item.id}', style: TextStyle(color: theme.textSecondary, fontSize: 12.5)),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            item.pcName,
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            item.status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              item.targetPath,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: REMOTE CONSOLE VIEW ---
  Widget _buildConsoleView(ThemeProvider theme, AppLogic logic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PC filter selector row
        Row(
          children: [
            Text(
              context.tr('label_console_filter'),
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(width: 16),
            Radio<String>(
              value: '',
              groupValue: _consoleFilter,
              activeColor: const Color(0xFF00ADB5),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _consoleFilter = val);
                  logic.updateConsolePcCount(val);
                }
              },
            ),
            Text('All', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
            const SizedBox(width: 16),
            Radio<String>(
              value: 'MMI',
              groupValue: _consoleFilter,
              activeColor: const Color(0xFF00ADB5),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _consoleFilter = val);
                  logic.updateConsolePcCount(val);
                }
              },
            ),
            Text('MMI', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
            const SizedBox(width: 16),
            Radio<String>(
              value: 'CMDL',
              groupValue: _consoleFilter,
              activeColor: const Color(0xFF00ADB5),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _consoleFilter = val);
                  logic.updateConsolePcCount(val);
                }
              },
            ),
            Text('CMDL', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
            const Spacer(),
            Text(
              '(${logic.consolePcCount} PCs)',
              style: const TextStyle(color: Color(0xFF00ADB5), fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Command input field
        Text(
          context.tr('label_console_cmd'),
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderTheme),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _consoleCmdController,
                  style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFF00ADB5)),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: context.tr('placeholder_console_cmd'),
                  ),
                  onSubmitted: (cmd) {
                    if (cmd.trim().isNotEmpty) {
                      logic.runConsoleCommand(cmd.trim(), _consoleFilter);
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  _consoleCmdController.clear();
                },
                icon: Icon(Icons.clear, color: theme.textSecondary, size: 18),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Exec & Clear Buttons
        Row(
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: logic.isExecutingConsole
                      ? null
                      : () {
                          final cmd = _consoleCmdController.text.trim();
                          if (cmd.isEmpty) return;
                          logic.runConsoleCommand(cmd, _consoleFilter);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundBuilder: (context, states, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00FF9D), Color(0xFF0056FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: child,
                      );
                    },
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: logic.isExecutingConsole
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          context.tr('btn_console_exec'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    logic.clearConsoleLog();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35),
                    side: const BorderSide(color: Color(0x66FF6B35), width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    context.tr('btn_clear'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 4. Command results table
        Text(
          context.tr('label_console_results'),
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: _buildConsoleTable(logic.consoleStatuses, theme),
        ),

        const SizedBox(height: 12),

        // 5. Console outputs log box
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderTheme),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView(
              controller: _consoleLogScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                SelectableText(
                  logic.consoleLog.isEmpty ? 'Console Output logs idle...' : logic.consoleLog.trim(),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: Color(0xFF00ADB5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleTable(List<ConsoleStatus> statuses, ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    context.tr('col_id'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    context.tr('col_pc'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    context.tr('col_status'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    context.tr('col_output'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Scrollbar(
              controller: _consoleScrollController,
              child: ListView.builder(
                controller: _consoleScrollController,
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final item = statuses[index];
                  Color statusColor = theme.isDark ? const Color(0xFF00D4FF) : const Color(0xFF0056FF);
                  if (item.status == 'OK') {
                    statusColor = const Color(0xFF00FF9D);
                  } else if (item.status == 'FAIL') {
                    statusColor = const Color(0xFFFF4500);
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: theme.borderTheme, width: 0.5)),
                      color: item.status == 'FAIL'
                          ? Colors.redAccent.withOpacity(0.06)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text('${item.id}', style: TextStyle(color: theme.textSecondary, fontSize: 12.5)),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            item.pcName,
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            item.status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              item.output,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
