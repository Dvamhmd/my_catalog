import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category_type.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static bool _useFallbackStorage = false;
  static bool _isInitialized = false;

  // In-memory cache for ultra-fast queries (0ms UI latency)
  final List<SubCategoryModel> _cachedSubCategories = [];
  final List<MenuItemModel> _cachedMenuItems = [];

  static const String _prefSubCatsKey = 'my_catalog_sub_categories_json';
  static const String _prefMenuItemsKey = 'my_catalog_menu_items_json';

  DatabaseService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _useFallbackStorage = true;
      await _initFallbackStorage();
    } else {
      try {
        _database = await _initDB('my_catalog.db');
        await _loadToCacheFromSqlite();
      } catch (e) {
        debugPrint('SQLite initialization error, falling back to JSON storage: $e');
        _useFallbackStorage = true;
        await _initFallbackStorage();
      }
    }
    _isInitialized = true;
  }

  Future<Database?> get database async {
    if (!_isInitialized) {
      await initialize();
    }
    return _database;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sub_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sub_categories_type ON sub_categories(type);
    ''');

    await db.execute('''
      CREATE TABLE menu_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT,
        sub_category_id INTEGER NOT NULL,
        sub_category_name TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sub_category_id) REFERENCES sub_categories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_menu_items_type ON menu_items(type);
    ''');
    await db.execute('''
      CREATE INDEX idx_menu_items_sub_category ON menu_items(sub_category_id);
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final foodCat1Id = await db.insert('sub_categories', {
      'name': 'Makanan Utama',
      'type': CategoryType.food.name,
      'created_at': now,
    });
    final foodCat2Id = await db.insert('sub_categories', {
      'name': 'Cemilan & Snack',
      'type': CategoryType.food.name,
      'created_at': now,
    });
    final foodCat3Id = await db.insert('sub_categories', {
      'name': 'Dessert & Manis',
      'type': CategoryType.food.name,
      'created_at': now,
    });

    final drinkCat1Id = await db.insert('sub_categories', {
      'name': 'Kopi Signature',
      'type': CategoryType.drink.name,
      'created_at': now,
    });
    final drinkCat2Id = await db.insert('sub_categories', {
      'name': 'Jus & Smoothies',
      'type': CategoryType.drink.name,
      'created_at': now,
    });
    final drinkCat3Id = await db.insert('sub_categories', {
      'name': 'Teh & Mocktail',
      'type': CategoryType.drink.name,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Nasi Goreng Spesial',
      'price': 28000.0,
      'image_path': null,
      'sub_category_id': foodCat1Id,
      'sub_category_name': 'Makanan Utama',
      'type': CategoryType.food.name,
      'description': 'Nasi goreng bumbu racikan dengan telur mata sapi, ayam suwir, dan kerupuk renyah.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Ayam Crispy Sambal Matah',
      'price': 32000.0,
      'image_path': null,
      'sub_category_id': foodCat1Id,
      'sub_category_name': 'Makanan Utama',
      'type': CategoryType.food.name,
      'description': 'Ayam goreng renyah dengan taburan sambal matah khas Bali yang segar dan gurih.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Kentang Goreng Truffle',
      'price': 22000.0,
      'image_path': null,
      'sub_category_id': foodCat2Id,
      'sub_category_name': 'Cemilan & Snack',
      'type': CategoryType.food.name,
      'description': 'French fries renyah dengan aroma minyak truffle dan taburan parmesan.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Croissant Butter Soft',
      'price': 20000.0,
      'image_path': null,
      'sub_category_id': foodCat3Id,
      'sub_category_name': 'Dessert & Manis',
      'type': CategoryType.food.name,
      'description': 'Pastry renyah berlapis dengan butter premium aroma wangi.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Caramel Macchiato Ice',
      'price': 26000.0,
      'image_path': null,
      'sub_category_id': drinkCat1Id,
      'sub_category_name': 'Kopi Signature',
      'type': CategoryType.drink.name,
      'description': 'Espresso premium dengan susu lembut dan saus karamel legit.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Matcha Latte Creamy',
      'price': 24000.0,
      'image_path': null,
      'sub_category_id': drinkCat1Id,
      'sub_category_name': 'Kopi Signature',
      'type': CategoryType.drink.name,
      'description': 'Matcha Jepang autentik dipadukan dengan fresh milk lembut.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Mango Smoothie Blast',
      'price': 25000.0,
      'image_path': null,
      'sub_category_id': drinkCat2Id,
      'sub_category_name': 'Jus & Smoothies',
      'type': CategoryType.drink.name,
      'description': 'Jus mangga arumanis segar dengan potongan buah mangga asli di atasnya.',
      'is_available': 1,
      'created_at': now,
    });

    await db.insert('menu_items', {
      'name': 'Lychee Rose Tea Ice',
      'price': 20000.0,
      'image_path': null,
      'sub_category_id': drinkCat3Id,
      'sub_category_name': 'Teh & Mocktail',
      'type': CategoryType.drink.name,
      'description': 'Teh wangi dengan sentuhan sirup mawar dan buah leci segar utuh.',
      'is_available': 1,
      'created_at': now,
    });
  }

  Future<void> _loadToCacheFromSqlite() async {
    if (_database == null) return;
    try {
      final subMaps = await _database!.query('sub_categories', orderBy: 'id ASC');
      _cachedSubCategories.clear();
      _cachedSubCategories.addAll(subMaps.map((m) => SubCategoryModel.fromMap(m)));

      final menuMaps = await _database!.query('menu_items', orderBy: 'id DESC');
      _cachedMenuItems.clear();
      _cachedMenuItems.addAll(menuMaps.map((m) => MenuItemModel.fromMap(m)));
    } catch (e) {
      debugPrint('Error populating cache from SQLite: $e');
    }
  }

  // ==================== FALLBACK STORAGE (WEB & RESILIENCY) ====================

  Future<void> _initFallbackStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subJson = prefs.getString(_prefSubCatsKey);
      final menuJson = prefs.getString(_prefMenuItemsKey);

      if (subJson != null && menuJson != null) {
        final List<dynamic> subList = jsonDecode(subJson);
        final List<dynamic> menuList = jsonDecode(menuJson);

        _cachedSubCategories.clear();
        _cachedSubCategories.addAll(
          subList.map((m) => SubCategoryModel.fromMap(Map<String, dynamic>.from(m))),
        );

        _cachedMenuItems.clear();
        _cachedMenuItems.addAll(
          menuList.map((m) => MenuItemModel.fromMap(Map<String, dynamic>.from(m))),
        );
      } else {
        _seedFallbackData();
        await _saveFallbackToPrefs();
      }
    } catch (e) {
      debugPrint('Error initializing fallback storage: $e');
      if (_cachedSubCategories.isEmpty) {
        _seedFallbackData();
      }
    }
  }

  void _seedFallbackData() {
    final now = DateTime.now();
    _cachedSubCategories.clear();
    _cachedMenuItems.clear();

    _cachedSubCategories.addAll([
      SubCategoryModel(id: 1, name: 'Makanan Utama', type: CategoryType.food, createdAt: now),
      SubCategoryModel(id: 2, name: 'Cemilan & Snack', type: CategoryType.food, createdAt: now),
      SubCategoryModel(id: 3, name: 'Dessert & Manis', type: CategoryType.food, createdAt: now),
      SubCategoryModel(id: 4, name: 'Kopi Signature', type: CategoryType.drink, createdAt: now),
      SubCategoryModel(id: 5, name: 'Jus & Smoothies', type: CategoryType.drink, createdAt: now),
      SubCategoryModel(id: 6, name: 'Teh & Mocktail', type: CategoryType.drink, createdAt: now),
    ]);

    _cachedMenuItems.addAll([
      MenuItemModel(
        id: 1,
        name: 'Nasi Goreng Spesial',
        price: 28000.0,
        subCategoryId: 1,
        subCategoryName: 'Makanan Utama',
        type: CategoryType.food,
        description: 'Nasi goreng bumbu racikan dengan telur mata sapi, ayam suwir, dan kerupuk renyah.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 2,
        name: 'Ayam Crispy Sambal Matah',
        price: 32000.0,
        subCategoryId: 1,
        subCategoryName: 'Makanan Utama',
        type: CategoryType.food,
        description: 'Ayam goreng renyah dengan taburan sambal matah khas Bali yang segar dan gurih.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 3,
        name: 'Kentang Goreng Truffle',
        price: 22000.0,
        subCategoryId: 2,
        subCategoryName: 'Cemilan & Snack',
        type: CategoryType.food,
        description: 'French fries renyah dengan aroma minyak truffle dan taburan parmesan.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 4,
        name: 'Croissant Butter Soft',
        price: 20000.0,
        subCategoryId: 3,
        subCategoryName: 'Dessert & Manis',
        type: CategoryType.food,
        description: 'Pastry renyah berlapis dengan butter premium aroma wangi.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 5,
        name: 'Caramel Macchiato Ice',
        price: 26000.0,
        subCategoryId: 4,
        subCategoryName: 'Kopi Signature',
        type: CategoryType.drink,
        description: 'Espresso premium dengan susu lembut dan saus karamel legit.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 6,
        name: 'Matcha Latte Creamy',
        price: 24000.0,
        subCategoryId: 4,
        subCategoryName: 'Kopi Signature',
        type: CategoryType.drink,
        description: 'Matcha Jepang autentik dipadukan dengan fresh milk lembut.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 7,
        name: 'Mango Smoothie Blast',
        price: 25000.0,
        subCategoryId: 5,
        subCategoryName: 'Jus & Smoothies',
        type: CategoryType.drink,
        description: 'Jus mangga arumanis segar dengan potongan buah mangga asli di atasnya.',
        isAvailable: true,
        createdAt: now,
      ),
      MenuItemModel(
        id: 8,
        name: 'Lychee Rose Tea Ice',
        price: 20000.0,
        subCategoryId: 6,
        subCategoryName: 'Teh & Mocktail',
        type: CategoryType.drink,
        description: 'Teh wangi dengan sentuhan sirup mawar dan buah leci segar utuh.',
        isAvailable: true,
        createdAt: now,
      ),
    ]);
  }

  Future<void> _saveFallbackToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subJson = jsonEncode(_cachedSubCategories.map((s) => s.toMap()).toList());
      final menuJson = jsonEncode(_cachedMenuItems.map((m) => m.toMap()).toList());
      await prefs.setString(_prefSubCatsKey, subJson);
      await prefs.setString(_prefMenuItemsKey, menuJson);
    } catch (e) {
      debugPrint('Error saving to SharedPreferences: $e');
    }
  }

  // ==================== SUB CATEGORY CRUD ====================

  Future<List<SubCategoryModel>> getSubCategories(CategoryType type) async {
    if (!_isInitialized) await initialize();

    return _cachedSubCategories
        .where((sub) => sub.type == type)
        .toList()
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
  }

  Future<int> insertSubCategory(SubCategoryModel subCategory) async {
    if (!_isInitialized) await initialize();

    int newId = DateTime.now().millisecondsSinceEpoch % 1000000;
    if (_cachedSubCategories.isNotEmpty) {
      final maxId = _cachedSubCategories.map((s) => s.id ?? 0).fold(0, (max, id) => id > max ? id : max);
      newId = maxId + 1;
    }

    final newModel = subCategory.copyWith(id: newId);
    _cachedSubCategories.add(newModel);

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.insert('sub_categories', newModel.toMap());
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }

    return newId;
  }

  Future<int> updateSubCategory(SubCategoryModel subCategory) async {
    if (!_isInitialized) await initialize();

    final index = _cachedSubCategories.indexWhere((s) => s.id == subCategory.id);
    if (index != -1) {
      _cachedSubCategories[index] = subCategory;
    }

    // Also update associated menu items' sub_category_name in cache
    for (int i = 0; i < _cachedMenuItems.length; i++) {
      if (_cachedMenuItems[i].subCategoryId == subCategory.id) {
        _cachedMenuItems[i] = _cachedMenuItems[i].copyWith(
          subCategoryName: subCategory.name,
        );
      }
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.update(
          'menu_items',
          {'sub_category_name': subCategory.name},
          where: 'sub_category_id = ?',
          whereArgs: [subCategory.id],
        );
        await _database!.update(
          'sub_categories',
          subCategory.toMap(),
          where: 'id = ?',
          whereArgs: [subCategory.id],
        );
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }

    return 1;
  }

  Future<int> deleteSubCategory(int id) async {
    if (!_isInitialized) await initialize();

    _cachedSubCategories.removeWhere((s) => s.id == id);
    _cachedMenuItems.removeWhere((m) => m.subCategoryId == id);

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.delete('menu_items', where: 'sub_category_id = ?', whereArgs: [id]);
        await _database!.delete('sub_categories', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }

    return 1;
  }

  // ==================== MENU ITEMS CRUD ====================

  Future<List<MenuItemModel>> getMenuItems({
    required CategoryType type,
    int? subCategoryId,
    String? searchQuery,
  }) async {
    if (!_isInitialized) await initialize();

    final query = searchQuery?.trim().toLowerCase();

    return _cachedMenuItems.where((item) {
      if (item.type != type) return false;
      if (subCategoryId != null && item.subCategoryId != subCategoryId) return false;
      if (query != null && query.isNotEmpty) {
        final matchesName = item.name.toLowerCase().contains(query);
        final matchesDesc = item.description?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesDesc) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
  }

  Future<int> getMenuItemCount({
    required CategoryType type,
    int? subCategoryId,
  }) async {
    if (!_isInitialized) await initialize();

    return _cachedMenuItems.where((item) {
      if (item.type != type) return false;
      if (subCategoryId != null && item.subCategoryId != subCategoryId) return false;
      return true;
    }).length;
  }

  Future<int> insertMenuItem(MenuItemModel item) async {
    if (!_isInitialized) await initialize();

    int newId = DateTime.now().millisecondsSinceEpoch % 1000000;
    if (_cachedMenuItems.isNotEmpty) {
      final maxId = _cachedMenuItems.map((m) => m.id ?? 0).fold(0, (max, id) => id > max ? id : max);
      newId = maxId + 1;
    }

    final newModel = item.copyWith(id: newId);
    _cachedMenuItems.insert(0, newModel);

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.insert('menu_items', newModel.toMap());
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }

    return newId;
  }

  Future<int> updateMenuItem(MenuItemModel item) async {
    if (!_isInitialized) await initialize();

    final index = _cachedMenuItems.indexWhere((m) => m.id == item.id);
    if (index != -1) {
      _cachedMenuItems[index] = item;
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.update(
          'menu_items',
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }

    return 1;
  }

  Future<int> deleteMenuItem(int id) async {
    if (!_isInitialized) await initialize();

    _cachedMenuItems.removeWhere((m) => m.id == id);

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.delete('menu_items', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }

    return 1;
  }

  Future<void> toggleAvailability(int id, bool currentStatus) async {
    if (!_isInitialized) await initialize();

    final index = _cachedMenuItems.indexWhere((m) => m.id == id);
    if (index != -1) {
      _cachedMenuItems[index] = _cachedMenuItems[index].copyWith(
        isAvailable: !currentStatus,
      );
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.update(
          'menu_items',
          {'is_available': currentStatus ? 0 : 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    } else {
      unawaited(_saveFallbackToPrefs());
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _isInitialized = false;
    }
  }
}
