import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category_type.dart';
import '../models/customer_category_model.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import '../models/transaction_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static bool _useFallbackStorage = false;
  static bool _isInitialized = false;

  // In-memory cache for ultra-fast queries (0ms UI latency)
  final List<SubCategoryModel> _cachedSubCategories = [];
  final List<MenuItemModel> _cachedMenuItems = [];
  final List<TransactionModel> _cachedTransactions = [];
  final List<CustomerCategoryModel> _cachedCustomerCategories = [];

  static const String _prefSubCatsKey = 'my_catalog_sub_categories_json';
  static const String _prefMenuItemsKey = 'my_catalog_menu_items_json';
  static const String _prefTransactionsKey = 'my_catalog_transactions_json';
  static const String _prefCustomerCategoriesKey = 'my_catalog_customer_categories_json';
  static const String _prefCleanResetKey = 'my_catalog_clean_reset_v2';

  DatabaseService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _useFallbackStorage = true;
      await _initFallbackStorage();
    } else {
      try {
        _database = await _initDB('my_catalog.db');
        await _checkAndPerformCleanReset();
        await _loadToCacheFromSqlite();
      } catch (e) {
        debugPrint('SQLite initialization error, falling back to JSON storage: $e');
        _useFallbackStorage = true;
        await _initFallbackStorage();
      }
    }
    await _syncLocalAssetImages();
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

    final db = await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE sub_categories ADD COLUMN image_path TEXT;');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          // Bersihkan seluruh data dummy default lama
          try {
            await db.delete('menu_items');
            await db.delete('sub_categories');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE menu_items ADD COLUMN stock INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE menu_items ADD COLUMN customer_prices_json TEXT;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN customer_category TEXT;');
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS customer_categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                is_default INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
              );
            ''');
            for (final name in defaultCustomerCategoryNames) {
              await db.insert('customer_categories', {
                'name': name,
                'is_default': 1,
                'created_at': DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          } catch (_) {}
        }
      },
    );

    // Pastikan tabel transactions tersedia
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_number TEXT NOT NULL,
          created_at TEXT NOT NULL,
          total_amount REAL NOT NULL,
          payment_method TEXT NOT NULL,
          cash_given REAL NOT NULL,
          change REAL NOT NULL,
          customer_category TEXT,
          customer_phone TEXT,
          loyalty_discount TEXT,
          items_json TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'selesai'
        );
      ''');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN loyalty_discount TEXT;');
    } catch (_) {}

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          is_default INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        );
      ''');
    } catch (_) {}

    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sub_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        image_path TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
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
        stock INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        customer_prices_json TEXT,
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

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cash_given REAL NOT NULL,
        change REAL NOT NULL,
        customer_category TEXT,
        customer_phone TEXT,
        loyalty_discount TEXT,
        items_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'selesai'
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_created_at ON transactions(created_at);
    ''');

    await db.execute('''
      CREATE TABLE customer_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    for (final name in defaultCustomerCategoryNames) {
      await db.insert('customer_categories', {
        'name': name,
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Data dimulai dari awal benar-benar kosong (tanpa dummy)
  }

  Future<void> _checkAndPerformCleanReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasReset = prefs.getBool(_prefCleanResetKey) ?? false;
      if (!hasReset) {
        if (_database != null) {
          await _database!.delete('menu_items');
          await _database!.delete('sub_categories');
          try {
            await _database!.delete('transactions');
          } catch (_) {}
        }
        await prefs.remove(_prefSubCatsKey);
        await prefs.remove(_prefMenuItemsKey);
        await prefs.remove(_prefTransactionsKey);
        await prefs.setBool(_prefCleanResetKey, true);
      }
    } catch (e) {
      debugPrint('Error performing clean reset: $e');
    }
  }

  Future<void> _loadToCacheFromSqlite() async {
    if (_database == null) return;
    try {
      try {
        await _database!.execute("ALTER TABLE sub_categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0");
      } catch (_) {}

      final subMaps = await _database!.query('sub_categories', orderBy: 'sort_order ASC, id ASC');
      _cachedSubCategories.clear();
      _cachedSubCategories.addAll(subMaps.map((m) => SubCategoryModel.fromMap(m)));

      final menuMaps = await _database!.query('menu_items', orderBy: 'is_available DESC, name COLLATE NOCASE ASC');
      _cachedMenuItems.clear();
      _cachedMenuItems.addAll(menuMaps.map((m) => MenuItemModel.fromMap(m)));

      try {
        await _database!.execute("ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT 'selesai'");
      } catch (_) {}
      try {
        await _database!.execute("ALTER TABLE transactions ADD COLUMN customer_phone TEXT");
      } catch (_) {}

      try {
        final trxMaps = await _database!.query('transactions', orderBy: 'created_at DESC');
        _cachedTransactions.clear();
        _cachedTransactions.addAll(trxMaps.map((m) => TransactionModel.fromMap(m)));
      } catch (_) {}

      try {
        final catMaps = await _database!.query('customer_categories', orderBy: 'id ASC');
        _cachedCustomerCategories.clear();
        _cachedCustomerCategories.addAll(catMaps.map((m) => CustomerCategoryModel.fromMap(m)));
        if (_cachedCustomerCategories.isEmpty) {
          for (final name in defaultCustomerCategoryNames) {
            final id = await _database!.insert('customer_categories', {
              'name': name,
              'is_default': 1,
              'created_at': DateTime.now().toIso8601String(),
            });
            _cachedCustomerCategories.add(CustomerCategoryModel(id: id, name: name, isDefault: true));
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error populating cache from SQLite: $e');
    }
  }

  // ==================== FALLBACK STORAGE (WEB & RESILIENCY) ====================

  Future<void> _initFallbackStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasReset = prefs.getBool(_prefCleanResetKey) ?? false;

      if (!hasReset) {
        // Hapus data dummy bawaan sebelumnya agar bersih dari 0
        _cachedSubCategories.clear();
        _cachedMenuItems.clear();
        _cachedTransactions.clear();
        _cachedCustomerCategories.clear();
        int autoId = 1;
        for (final name in defaultCustomerCategoryNames) {
          _cachedCustomerCategories.add(
            CustomerCategoryModel(id: autoId++, name: name, isDefault: true),
          );
        }
        await _saveFallbackToPrefs();
        await prefs.setBool(_prefCleanResetKey, true);
        return;
      }

      final subJson = prefs.getString(_prefSubCatsKey);
      final menuJson = prefs.getString(_prefMenuItemsKey);
      final trxJson = prefs.getString(_prefTransactionsKey);
      final catJson = prefs.getString(_prefCustomerCategoriesKey);

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
        _cachedSubCategories.clear();
        _cachedMenuItems.clear();
      }

      if (trxJson != null) {
        try {
          final List<dynamic> trxList = jsonDecode(trxJson);
          _cachedTransactions.clear();
          _cachedTransactions.addAll(
            trxList.map((m) => TransactionModel.fromMap(Map<String, dynamic>.from(m))),
          );
        } catch (_) {
          _cachedTransactions.clear();
        }
      } else {
        _cachedTransactions.clear();
      }

      if (catJson != null) {
        try {
          final List<dynamic> catList = jsonDecode(catJson);
          _cachedCustomerCategories.clear();
          _cachedCustomerCategories.addAll(
            catList.map((m) => CustomerCategoryModel.fromMap(Map<String, dynamic>.from(m))),
          );
        } catch (_) {
          _cachedCustomerCategories.clear();
        }
      }

      if (_cachedCustomerCategories.isEmpty) {
        int autoId = 1;
        for (final name in defaultCustomerCategoryNames) {
          _cachedCustomerCategories.add(
            CustomerCategoryModel(id: autoId++, name: name, isDefault: true),
          );
        }
      }

      if (subJson == null || menuJson == null || catJson == null) {
        await _saveFallbackToPrefs();
      }
    } catch (e) {
      debugPrint('Error initializing fallback storage: $e');
      _cachedSubCategories.clear();
      _cachedMenuItems.clear();
      _cachedTransactions.clear();
      _cachedCustomerCategories.clear();
    }
  }

  Future<void> _saveFallbackToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subJson = jsonEncode(_cachedSubCategories.map((s) => s.toMap()).toList());
      final menuJson = jsonEncode(_cachedMenuItems.map((m) => m.toMap()).toList());
      final trxJson = jsonEncode(_cachedTransactions.map((t) => t.toMap()).toList());
      final catJson = jsonEncode(_cachedCustomerCategories.map((c) => c.toMap()).toList());
      await prefs.setString(_prefSubCatsKey, subJson);
      await prefs.setString(_prefMenuItemsKey, menuJson);
      await prefs.setString(_prefTransactionsKey, trxJson);
      await prefs.setString(_prefCustomerCategoriesKey, catJson);
    } catch (e) {
      debugPrint('Error saving to SharedPreferences: $e');
    }
  }

  Future<void> _saveCustomerCategoriesToFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catJson = jsonEncode(_cachedCustomerCategories.map((c) => c.toMap()).toList());
      await prefs.setString(_prefCustomerCategoriesKey, catJson);
    } catch (_) {}
  }

  // Mapping sinkronisasi gambar dummy ke asset lokal
  static const Map<String, String> _subCategoryAssetMap = {
    'Snack': 'assets/images/kategori_snack.webp',
    'Main Course': 'assets/images/kategori_main_course.webp',
    'Dessert': 'assets/images/kategori_dessert.webp',
    'Milk Based': 'assets/images/kategori_milk_based.webp',
    'Coffee': 'assets/images/kategori_coffee.webp',
    'Tea': 'assets/images/kategori_tea.webp',
    'Squash': 'assets/images/kategori_squash.webp',
    'Juice': 'assets/images/kategori_juice.webp',
  };

  static const Map<String, String> _menuItemAssetMap = {
    // Snack
    'French Fries Crispy': 'assets/images/makanan_french_fries.webp',
    'Cireng Bumbu Rujak': 'assets/images/makanan_cireng_bumbu_rujak.webp',
    'Dimsum Ayam Mentai': 'assets/images/makanan_dimsum_mentai.webp',
    'Pisang Bakar Coklat Keju': 'assets/images/makanan_pisang_bakar_coklat_keju.webp',
    // Main Course
    'Nasi Goreng Spesial Telur': 'assets/images/makanan_nasi_goreng.webp',
    'Ayam Geprek Sambal Bawang': 'assets/images/makanan_ayam_geprek.webp',
    'Mie Goreng Seafood': 'assets/images/makanan_mie_goreng.webp',
    'Beef Rice Bowl Teriyaki': 'assets/images/makanan_beef_rice_bowl.webp',
    // Dessert
    'Pancake Fluffy Strawberry': 'assets/images/makanan_pancake_fluffy.webp',
    'Croffle Caramel Crunch': 'assets/images/makanan_croffle_caramel.webp',
    'Chewy Fudgy Brownie': 'assets/images/makanan_chewy_brownie.webp',
    'Molten Choco Lava Cake': 'assets/images/makanan_choco_lava.webp',
    // Milk Based
    'Matcha Latte Creamy': 'assets/images/minuman_matcha_latte.webp',
    'Choco Hazelnut Milk': 'assets/images/minuman_choco_hazelnut.webp',
    'Strawberry Milk Breeze': 'assets/images/minuman_strawberry_milk.webp',
    'Taro Velvety Milk': 'assets/images/minuman_taro_milk.webp',
    // Coffee
    'Kopi Susu Gula Aren': 'assets/images/minuman_kopi_susu.webp',
    'Caramel Macchiato Ice': 'assets/images/minuman_caramel_macchiato.webp',
    'Americano Double Shot': 'assets/images/minuman_americano.webp',
    'Vanilla Latte Iced': 'assets/images/minuman_vanilla_latte.webp',
    // Tea
    'Lychee Iced Tea': 'assets/images/minuman_lychee_tea.webp',
    'Lemon Tea Segar': 'assets/images/minuman_lemon_tea.webp',
    'Earl Grey Milk Tea': 'assets/images/minuman_earl_grey.webp',
    'Peach Blossom Tea': 'assets/images/minuman_peach_blossom.webp',
    // Squash
    'Orange Sunrise Squash': 'assets/images/minuman_orange_squash.webp',
    'Blue Ocean Soda Squash': 'assets/images/minuman_blue_ocean.webp',
    'Lemon Mint Fizzy Squash': 'assets/images/minuman_lemon_mint.webp',
    'Strawberry Mojito Squash': 'assets/images/minuman_strawberry_mojito.webp',
    // Juice
    'Jus Alpukat Kocok Kental': 'assets/images/minuman_jus_alpukat.webp',
    'Jus Mangga Harum Manis': 'assets/images/minuman_jus_mangga.webp',
    'Jus Buah Naga Merah': 'assets/images/minuman_jus_buah_naga.webp',
    'Jus Sirsak Asli Segar': 'assets/images/minuman_jus_sirsak.webp',
  };

  Future<void> _syncLocalAssetImages() async {
    bool updated = false;

    // 1. Sync SubCategories cache & persistence
    for (int i = 0; i < _cachedSubCategories.length; i++) {
      final sub = _cachedSubCategories[i];
      final targetAsset = _subCategoryAssetMap[sub.name];
      if (targetAsset != null && sub.imagePath != targetAsset) {
        _cachedSubCategories[i] = sub.copyWith(imagePath: targetAsset);
        updated = true;
        if (!_useFallbackStorage && _database != null && sub.id != null) {
          try {
            await _database!.update(
              'sub_categories',
              {'image_path': targetAsset},
              where: 'id = ?',
              whereArgs: [sub.id],
            );
          } catch (_) {}
        }
      }
    }

    // 2. Sync MenuItems cache & persistence
    for (int i = 0; i < _cachedMenuItems.length; i++) {
      final item = _cachedMenuItems[i];
      final targetAsset = _menuItemAssetMap[item.name];
      if (targetAsset != null && item.imagePath != targetAsset) {
        _cachedMenuItems[i] = item.copyWith(imagePath: targetAsset);
        updated = true;
        if (!_useFallbackStorage && _database != null && item.id != null) {
          try {
            await _database!.update(
              'menu_items',
              {'image_path': targetAsset},
              where: 'id = ?',
              whereArgs: [item.id],
            );
          } catch (_) {}
        }
      }
    }

    if (updated && _useFallbackStorage) {
      await _saveFallbackToPrefs();
    }
  }

  // ==================== SUB CATEGORY CRUD ====================

  Future<List<SubCategoryModel>> getSubCategories(CategoryType type) async {
    if (!_isInitialized) await initialize();

    final list = _cachedSubCategories
        .where((sub) => sub.type == type)
        .toList();
    list.sort((a, b) {
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return list;
  }

  Future<void> reorderSubCategories(List<SubCategoryModel> orderedList) async {
    if (!_isInitialized) await initialize();

    for (int i = 0; i < orderedList.length; i++) {
      final sub = orderedList[i];
      final newSub = sub.copyWith(sortOrder: i);
      final cacheIndex = _cachedSubCategories.indexWhere((s) => s.id == sub.id);
      if (cacheIndex != -1) {
        _cachedSubCategories[cacheIndex] = newSub;
      }
      if (!_useFallbackStorage && _database != null && sub.id != null) {
        try {
          await _database!.update(
            'sub_categories',
            {'sort_order': i},
            where: 'id = ?',
            whereArgs: [sub.id],
          );
        } catch (_) {}
      }
    }

    if (_useFallbackStorage) {
      await _saveFallbackToPrefs();
    }
  }

  Future<int> insertSubCategory(SubCategoryModel subCategory) async {
    if (!_isInitialized) await initialize();

    int newId = DateTime.now().millisecondsSinceEpoch % 1000000;
    if (_cachedSubCategories.isNotEmpty) {
      final maxId = _cachedSubCategories.map((s) => s.id ?? 0).fold(0, (max, id) => id > max ? id : max);
      newId = maxId + 1;
    }

    int nextSortOrder = subCategory.sortOrder;
    if (nextSortOrder == 0) {
      final currentTypeSubs = _cachedSubCategories.where((s) => s.type == subCategory.type);
      if (currentTypeSubs.isNotEmpty) {
        nextSortOrder = currentTypeSubs.map((s) => s.sortOrder).fold(0, (max, o) => o > max ? o : max) + 1;
      }
    }

    final newModel = subCategory.copyWith(id: newId, sortOrder: nextSortOrder);
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
      ..sort((a, b) {
        // Menu yang tersedia di atas (isAvailable == true), sold out di paling bawah
        if (a.isAvailable != b.isAvailable) {
          return a.isAvailable ? -1 : 1;
        }
        // Jika status ketersediaan sama, urutkan nama dari A ke Z (case-insensitive)
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  /// Mengambil semua menu tanpa filter kategori/sub-kategori
  Future<List<MenuItemModel>> getAllMenuItems() async {
    if (!_isInitialized) await initialize();
    return List.unmodifiable(_cachedMenuItems);
  }

  /// Mengambil menu berdasarkan ID dari memori cache secara sinkron
  MenuItemModel? getCachedMenuItemById(int id) {
    final index = _cachedMenuItems.indexWhere((m) => m.id == id);
    if (index != -1) return _cachedMenuItems[index];
    return null;
  }

  /// Mengambil menu berdasarkan ID
  Future<MenuItemModel?> getMenuItemById(int id) async {
    if (!_isInitialized) await initialize();
    return getCachedMenuItemById(id);
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

  Future<Map<int, int>> getSubCategoryItemCounts(CategoryType type) async {
    if (!_isInitialized) await initialize();

    final Map<int, int> counts = {};
    for (final item in _cachedMenuItems) {
      if (item.type == type) {
        counts[item.subCategoryId] = (counts[item.subCategoryId] ?? 0) + 1;
      }
    }
    return counts;
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

  Future<void> updateMenuItemStock(int id, int newStock) async {
    if (!_isInitialized) await initialize();

    final safeStock = newStock < 0 ? 0 : newStock;
    final index = _cachedMenuItems.indexWhere((m) => m.id == id);
    bool shouldBeAvailable = safeStock > 0;
    if (index != -1) {
      final current = _cachedMenuItems[index];
      shouldBeAvailable = safeStock > 0 ? true : false;
      _cachedMenuItems[index] = current.copyWith(
        stock: safeStock,
        isAvailable: shouldBeAvailable,
      );
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.update(
          'menu_items',
          {
            'stock': safeStock,
            'is_available': shouldBeAvailable ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    } else {
      await _saveFallbackToPrefs();
    }
  }

  Future<bool> checkoutOrder(Map<int, int> itemQuantities) async {
    if (!_isInitialized) await initialize();
    if (itemQuantities.isEmpty) return true;

    for (final entry in itemQuantities.entries) {
      final id = entry.key;
      final qty = entry.value;
      final index = _cachedMenuItems.indexWhere((m) => m.id == id);
      if (index != -1) {
        final current = _cachedMenuItems[index];
        final remainingStock = (current.stock - qty).clamp(0, 999999);
        _cachedMenuItems[index] = current.copyWith(
          stock: remainingStock,
          isAvailable: remainingStock > 0 ? current.isAvailable : false,
        );

        if (!_useFallbackStorage && _database != null) {
          try {
            await _database!.update(
              'menu_items',
              {
                'stock': remainingStock,
                'is_available': remainingStock > 0 && current.isAvailable ? 1 : 0,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          } catch (_) {}
        }
      }
    }

    if (_useFallbackStorage || _database == null) {
      unawaited(_saveFallbackToPrefs());
    }

    return true;
  }

  // ==================== TRANSACTION / SALES HISTORY CRUD ====================

  Future<List<TransactionModel>> getTransactions() async {
    if (!_isInitialized) await initialize();
    return List<TransactionModel>.from(_cachedTransactions);
  }

  Future<int> saveTransaction(TransactionModel trx) async {
    if (!_isInitialized) await initialize();

    int newId = DateTime.now().millisecondsSinceEpoch % 10000000;
    if (_cachedTransactions.isNotEmpty) {
      final maxId = _cachedTransactions.map((t) => t.id ?? 0).fold(0, (max, id) => id > max ? id : max);
      newId = maxId + 1;
    }

    final newModel = trx.copyWith(id: newId);
    _cachedTransactions.insert(0, newModel); // Transaksi terbaru di posisi pertama

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.insert('transactions', newModel.toMap());
      } catch (e) {
        debugPrint('Error inserting transaction: $e');
      }
    } else {
      await _saveFallbackToPrefs();
    }

    return newId;
  }

  Future<bool> updateTransaction(TransactionModel trx) async {
    if (!_isInitialized) await initialize();
    if (trx.id == null) return false;

    final index = _cachedTransactions.indexWhere((t) => t.id == trx.id);
    if (index != -1) {
      _cachedTransactions[index] = trx;
    } else {
      _cachedTransactions.insert(0, trx);
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.update(
          'transactions',
          trx.toMap(),
          where: 'id = ?',
          whereArgs: [trx.id],
        );
      } catch (e) {
        debugPrint('Error updating transaction: $e');
      }
    } else {
      await _saveFallbackToPrefs();
    }

    return true;
  }

  Future<bool> deleteTransaction(int id) async {
    if (!_isInitialized) await initialize();

    _cachedTransactions.removeWhere((t) => t.id == id);

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.delete('transactions', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
    } else {
      await _saveFallbackToPrefs();
    }

    return true;
  }

  Future<void> clearTransactions() async {
    if (!_isInitialized) await initialize();

    _cachedTransactions.clear();

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.delete('transactions');
      } catch (_) {}
    } else {
      await _saveFallbackToPrefs();
    }
  }

  // ==================== CUSTOMER CATEGORIES CRUD ====================

  static const List<String> defaultCustomerCategoryNames = [
    'Member',
    'GoFood',
    'GrabFood',
    'Karyawan',
  ];

  List<CustomerCategoryModel> get cachedCustomerCategories =>
      List.unmodifiable(_cachedCustomerCategories);

  Future<List<CustomerCategoryModel>> getCustomerCategories() async {
    if (!_isInitialized) await initialize();
    return List.from(_cachedCustomerCategories);
  }

  Future<int> insertCustomerCategory(String name) async {
    if (!_isInitialized) await initialize();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return -1;

    if (_cachedCustomerCategories.any((c) => c.name.toLowerCase() == trimmed.toLowerCase())) {
      return -1;
    }

    int newId = DateTime.now().millisecondsSinceEpoch % 1000000;
    if (_cachedCustomerCategories.isNotEmpty) {
      final maxId = _cachedCustomerCategories.map((c) => c.id ?? 0).fold(0, (max, id) => id > max ? id : max);
      newId = maxId + 1;
    }

    final newModel = CustomerCategoryModel(
      id: newId,
      name: trimmed,
      isDefault: false,
    );
    _cachedCustomerCategories.add(newModel);

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.insert('customer_categories', newModel.toMap());
      } catch (_) {}
    } else {
      unawaited(_saveCustomerCategoriesToFallback());
    }

    return newId;
  }

  Future<bool> updateCustomerCategory(int id, String newName) async {
    if (!_isInitialized) await initialize();
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    final index = _cachedCustomerCategories.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final oldName = _cachedCustomerCategories[index].name;
    final updatedModel = _cachedCustomerCategories[index].copyWith(name: trimmed);
    _cachedCustomerCategories[index] = updatedModel;

    // Update custom price keys on cached menu items if category was renamed
    if (oldName != trimmed) {
      for (int i = 0; i < _cachedMenuItems.length; i++) {
        final item = _cachedMenuItems[i];
        if (item.customerPrices.containsKey(oldName)) {
          final newMap = Map<String, double>.from(item.customerPrices);
          final priceVal = newMap.remove(oldName);
          if (priceVal != null) {
            newMap[trimmed] = priceVal;
          }
          _cachedMenuItems[i] = item.copyWith(customerPrices: newMap);
          if (!_useFallbackStorage && _database != null) {
            _database!.update(
              'menu_items',
              {'customer_prices_json': jsonEncode(newMap)},
              where: 'id = ?',
              whereArgs: [item.id],
            );
          }
        }
      }
      if (_useFallbackStorage) {
        unawaited(_saveFallbackToPrefs());
      }
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.update(
          'customer_categories',
          updatedModel.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    } else {
      unawaited(_saveCustomerCategoriesToFallback());
    }

    return true;
  }

  Future<bool> deleteCustomerCategory(int id) async {
    if (!_isInitialized) await initialize();
    final index = _cachedCustomerCategories.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final removed = _cachedCustomerCategories.removeAt(index);

    // Remove price entries for this category in cached menu items
    for (int i = 0; i < _cachedMenuItems.length; i++) {
      final item = _cachedMenuItems[i];
      if (item.customerPrices.containsKey(removed.name)) {
        final newMap = Map<String, double>.from(item.customerPrices);
        newMap.remove(removed.name);
        _cachedMenuItems[i] = item.copyWith(customerPrices: newMap);
        if (!_useFallbackStorage && _database != null) {
          _database!.update(
            'menu_items',
            {'customer_prices_json': jsonEncode(newMap)},
            where: 'id = ?',
            whereArgs: [item.id],
          );
        }
      }
    }
    if (_useFallbackStorage) {
      unawaited(_saveFallbackToPrefs());
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.delete(
          'customer_categories',
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    } else {
      unawaited(_saveCustomerCategoriesToFallback());
    }

    return true;
  }

  Future<void> resetCustomerCategoriesToDefault() async {
    if (!_isInitialized) await initialize();
    _cachedCustomerCategories.clear();
    int autoId = 1;
    for (final name in defaultCustomerCategoryNames) {
      _cachedCustomerCategories.add(
        CustomerCategoryModel(id: autoId++, name: name, isDefault: true),
      );
    }

    if (!_useFallbackStorage && _database != null) {
      try {
        await _database!.delete('customer_categories');
        for (final cat in _cachedCustomerCategories) {
          await _database!.insert('customer_categories', cat.toMap());
        }
      } catch (_) {}
    } else {
      await _saveCustomerCategoriesToFallback();
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
