// lib/modules/ui/localization.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _locale = 'vi'; // Default to vi since the original tool was in Vietnamese

  String get locale => _locale;

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = prefs.getString('app_locale') ?? 'vi';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLocale(String value) async {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', value);
    } catch (_) {}
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'File/Folder Modify Deployer',
      'tab_deploy': '📁  File / Folder Deploy',
      'tab_console': '🖥  Remote Console',
      'label_source': '1. File/Folder Source (Drag & Drop):',
      'btn_select_file': 'Select File',
      'btn_select_folder': 'Select Folder',
      'label_mode': '2. Mode Selection:',
      'mode_replace': 'Replace',
      'mode_delete': 'Delete',
      'label_filter': '3. PC Name Filter (Optional):',
      'btn_start_deploy': 'START PARALLEL DEPLOY',
      'label_status': 'Real-time Deployment Status:',
      'col_id': 'ID',
      'col_pc': 'PC Name',
      'col_status': 'Status',
      'col_path': 'Path',
      'col_output': 'Output',
      'label_console_filter': 'PC Filter:',
      'label_console_cmd': 'Command (PowerShell):',
      'btn_console_exec': '⚡  EXECUTE ON ALL PCs',
      'btn_clear': '🗑  Clear',
      'label_console_results': 'Real-time Command Results:',
      'placeholder_console_cmd': 'e.g. hostname  |  Get-Service -Name \'MyApp\'  |  ipconfig /all',
      'theme_dark': '🌙 Dark',
      'theme_light': '☀️ Light',
      'err_invalid_path': 'Please select or drag a valid file/folder path!',
      'err_no_csv': 'Cannot find CSV_PATH configuration!',
      'msg_no_pc': 'No matching PCs found!',
    },
    'vi': {
      'app_title': 'File/Folder Modify Deployer',
      'tab_deploy': '📁  Triển khai File / Thư mục',
      'tab_console': '🖥  Bảng điều khiển từ xa',
      'label_source': '1. Nguồn File/Thư mục (Kéo & Thả):',
      'btn_select_file': 'Chọn File',
      'btn_select_folder': 'Chọn Thư mục',
      'label_mode': '2. Chọn chế độ:',
      'mode_replace': 'Thay thế (Replace)',
      'mode_delete': 'Xóa (Delete)',
      'label_filter': '3. Bộ lọc tên PC (Không bắt buộc):',
      'btn_start_deploy': 'BẮT ĐẦU TRIỂN KHAI SONG SONG',
      'label_status': 'Trạng thái triển khai thực tế:',
      'col_id': 'ID',
      'col_pc': 'Tên PC',
      'col_status': 'Trạng thái',
      'col_path': 'Đường dẫn',
      'col_output': 'Kết quả',
      'label_console_filter': 'Bộ lọc PC:',
      'label_console_cmd': 'Lệnh (PowerShell):',
      'btn_console_exec': '⚡  THỰC THI TRÊN TẤT CẢ PC',
      'btn_clear': '🗑  Xóa',
      'label_console_results': 'Kết quả lệnh thực tế:',
      'placeholder_console_cmd': 'Ví dụ: hostname  |  Get-Service -Name \'MyApp\'  |  ipconfig /all',
      'theme_dark': '🌙 Tối',
      'theme_light': '☀️ Sáng',
      'err_invalid_path': 'Vui lòng chọn hoặc kéo thả file/folder hợp lệ!',
      'err_no_csv': 'Không tìm thấy cấu hình CSV_PATH!',
      'msg_no_pc': 'Không tìm thấy PC nào phù hợp!',
    }
  };

  String translate(String key, {Map<String, String>? args}) {
    String value = _localizedValues[_locale]?[key] ?? _localizedValues['en']?[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? args}) {
    return Provider.of<LanguageProvider>(this).translate(key, args: args);
  }
}
