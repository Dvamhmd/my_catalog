import 'package:shared_preferences/shared_preferences.dart';
import '../models/layout_mode.dart';

class PreferenceService {
  static const String _keyLayoutColumns = 'layout_mode_columns';

  static Future<LayoutMode> getLayoutMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final columns = prefs.getInt(_keyLayoutColumns) ?? 2; // Default 2 columns (Sedang)
      return LayoutMode.fromColumns(columns);
    } catch (_) {
      return LayoutMode.medium;
    }
  }

  static Future<void> saveLayoutMode(LayoutMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLayoutColumns, mode.columns);
    } catch (_) {}
  }
}
