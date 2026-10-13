import 'package:shared_preferences/shared_preferences.dart';
import '../models/layout_mode.dart';
import '../models/sub_category_view_mode.dart';
import '../widgets/app_drawer.dart';

class PreferenceService {
  static const String _keyLayoutColumns = 'layout_mode_columns';
  static const String _keySubCatViewMode = 'sub_category_view_mode';
  static const String _keyLastActiveMenu = 'last_active_menu';

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

  static Future<SubCategoryViewMode> getSubCategoryViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keySubCatViewMode);
      return SubCategoryViewMode.fromString(modeStr);
    } catch (_) {
      return SubCategoryViewMode.tab;
    }
  }

  static Future<void> saveSubCategoryViewMode(SubCategoryViewMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubCatViewMode, mode.name);
    } catch (_) {}
  }

  static Future<AppDrawerMenu> getLastActiveMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final menuName = prefs.getString(_keyLastActiveMenu);
      if (menuName != null) {
        for (final menu in AppDrawerMenu.values) {
          if (menu.name == menuName) {
            return menu;
          }
        }
      }
      return AppDrawerMenu.admin;
    } catch (_) {
      return AppDrawerMenu.admin;
    }
  }

  static Future<void> saveLastActiveMenu(AppDrawerMenu menu) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastActiveMenu, menu.name);
    } catch (_) {}
  }
}

