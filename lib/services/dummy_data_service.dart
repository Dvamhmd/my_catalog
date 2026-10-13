import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_type.dart';
import '../models/menu_item_model.dart';
import '../models/sub_category_model.dart';
import 'database_service.dart';

class DummyDataService {
  static final DummyDataService instance = DummyDataService._init();
  DummyDataService._init();

  static const String _prefIsDummyEnabledKey = 'my_catalog_dummy_data_enabled';
  static const String _prefDummySubCatIdsKey = 'my_catalog_dummy_sub_cat_ids';
  static const String _prefDummyMenuItemIdsKey = 'my_catalog_dummy_menu_item_ids';

  final DatabaseService _db = DatabaseService.instance;

  Future<bool> isDummyDataEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefIsDummyEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleDummyData(bool enable) async {
    if (enable) {
      return await enableDummyData();
    } else {
      return await disableDummyData();
    }
  }

  Future<bool> enableDummyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _db.initialize();

      // Ensure any previously tracked dummy data is cleaned first
      await disableDummyData();

      final List<int> createdSubCatIds = [];
      final List<int> createdMenuItemIds = [];

      final existingFoods = await _db.getSubCategories(CategoryType.food);
      final existingDrinks = await _db.getSubCategories(CategoryType.drink);
      final allExistingSubs = [...existingFoods, ...existingDrinks];

      for (final def in _dummyDefinitions) {
        // Find existing or insert new sub category
        final existing = allExistingSubs.cast<SubCategoryModel?>().firstWhere(
              (s) => s != null && s.name.toLowerCase() == def.subCategoryName.toLowerCase() && s.type == def.type,
              orElse: () => null,
            );

        int subId;
        if (existing != null && existing.id != null) {
          subId = existing.id!;
        } else {
          subId = await _db.insertSubCategory(
            SubCategoryModel(
              name: def.subCategoryName,
              type: def.type,
              imagePath: def.subCategoryImage,
            ),
          );
          createdSubCatIds.add(subId);
        }

        // Insert items for this subcategory
        for (final itemDef in def.items) {
          final itemId = await _db.insertMenuItem(
            MenuItemModel(
              name: itemDef.name,
              price: itemDef.price,
              imagePath: itemDef.imagePath,
              subCategoryId: subId,
              subCategoryName: def.subCategoryName,
              type: def.type,
              stock: itemDef.stock,
              description: itemDef.description,
              isAvailable: true,
            ),
          );
          createdMenuItemIds.add(itemId);
        }
      }

      await prefs.setString(_prefDummySubCatIdsKey, jsonEncode(createdSubCatIds));
      await prefs.setString(_prefDummyMenuItemIdsKey, jsonEncode(createdMenuItemIds));
      await prefs.setBool(_prefIsDummyEnabledKey, true);

      return true;
    } catch (e) {
      debugPrint('Error enabling dummy data: $e');
      return false;
    }
  }

  Future<bool> disableDummyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _db.initialize();

      final itemIdsJson = prefs.getString(_prefDummyMenuItemIdsKey);
      if (itemIdsJson != null) {
        try {
          final List<dynamic> rawIds = jsonDecode(itemIdsJson);
          for (final raw in rawIds) {
            if (raw is int) {
              await _db.deleteMenuItem(raw);
            }
          }
        } catch (_) {}
      }

      final subCatIdsJson = prefs.getString(_prefDummySubCatIdsKey);
      if (subCatIdsJson != null) {
        try {
          final List<dynamic> rawIds = jsonDecode(subCatIdsJson);
          for (final raw in rawIds) {
            if (raw is int) {
              await _db.deleteSubCategory(raw);
            }
          }
        } catch (_) {}
      }

      await prefs.remove(_prefDummyMenuItemIdsKey);
      await prefs.remove(_prefDummySubCatIdsKey);
      await prefs.setBool(_prefIsDummyEnabledKey, false);

      return true;
    } catch (e) {
      debugPrint('Error disabling dummy data: $e');
      return false;
    }
  }

  // ==================== DEFINISI DATA DUMMY ====================

  static final List<_DummySubCategoryGroup> _dummyDefinitions = [
    // --- Kategori Makanan ---
    _DummySubCategoryGroup(
      subCategoryName: 'Snack',
      type: CategoryType.food,
      subCategoryImage: 'assets/images/kategori_snack.webp',
      items: [
        _DummyMenuItem(
          name: 'French Fries Crispy',
          price: 18000,
          stock: 25,
          description: 'Kentang goreng renyah berbumbu gurih disajikan hangat dengan saus cocolan.',
          imagePath: 'assets/images/makanan_french_fries.webp',
        ),
        _DummyMenuItem(
          name: 'Cireng Bumbu Rujak',
          price: 15000,
          stock: 30,
          description: 'Cireng goreng krispi kenyal disajikan dengan cocolan bumbu rujak pedas manis.',
          imagePath: 'assets/images/makanan_cireng_bumbu_rujak.webp',
        ),
        _DummyMenuItem(
          name: 'Dimsum Ayam Mentai',
          price: 24000,
          stock: 20,
          description: 'Dimsum daging ayam lembut dengan balutan saus mentai gurih dibakar torch.',
          imagePath: 'assets/images/makanan_dimsum_mentai.webp',
        ),
        _DummyMenuItem(
          name: 'Pisang Bakar Coklat Keju',
          price: 16000,
          stock: 15,
          description: 'Pisang kepok panggang harum bertabur coklat meses dan parutan keju gurih melimpah.',
          imagePath: 'assets/images/makanan_pisang_bakar_coklat_keju.webp',
        ),
      ],
    ),
    _DummySubCategoryGroup(
      subCategoryName: 'Main Course',
      type: CategoryType.food,
      subCategoryImage: 'assets/images/kategori_main_course.webp',
      items: [
        _DummyMenuItem(
          name: 'Nasi Goreng Spesial Telur',
          price: 28000,
          stock: 35,
          description: 'Nasi goreng racikan bumbu khas dengan telur ceplok, sosis, dan kerupuk renyah.',
          imagePath: 'assets/images/makanan_nasi_goreng.webp',
        ),
        _DummyMenuItem(
          name: 'Ayam Geprek Sambal Bawang',
          price: 25000,
          stock: 40,
          description: 'Ayam krispi gurih digeprek bersama cabai rawit pedas dan aroma minyak bawang segar.',
          imagePath: 'assets/images/makanan_ayam_geprek.webp',
        ),
        _DummyMenuItem(
          name: 'Mie Goreng Seafood',
          price: 30000,
          stock: 20,
          description: 'Mie telur kenyal ditumis dengan udang, cumi segar, telur, dan sayuran renyah.',
          imagePath: 'assets/images/makanan_mie_goreng.webp',
        ),
        _DummyMenuItem(
          name: 'Beef Rice Bowl Teriyaki',
          price: 35000,
          stock: 15,
          description: 'Irisan daging sapi lembut saus teriyaki manis gurih di atas nasi hangat pulen.',
          imagePath: 'assets/images/makanan_beef_rice_bowl.webp',
        ),
      ],
    ),
    _DummySubCategoryGroup(
      subCategoryName: 'Dessert',
      type: CategoryType.food,
      subCategoryImage: 'assets/images/kategori_dessert.webp',
      items: [
        _DummyMenuItem(
          name: 'Pancake Fluffy Strawberry',
          price: 22000,
          stock: 18,
          description: 'Pancake ala Jepang lembut berpadu siraman madu dan potongan buah stroberi segar.',
          imagePath: 'assets/images/makanan_pancake_fluffy.webp',
        ),
        _DummyMenuItem(
          name: 'Croffle Caramel Crunch',
          price: 20000,
          stock: 22,
          description: 'Croissant waffle renyah berkaramel dengan lelehan saus karamel dan almond sangrai.',
          imagePath: 'assets/images/makanan_croffle_caramel.webp',
        ),
        _DummyMenuItem(
          name: 'Chewy Fudgy Brownie',
          price: 18000,
          stock: 25,
          description: 'Kue brownies coklat pekat bertabur choco chips dengan tekstur fudgy lumer di mulut.',
          imagePath: 'assets/images/makanan_chewy_brownie.webp',
        ),
        _DummyMenuItem(
          name: 'Molten Choco Lava Cake',
          price: 26000,
          stock: 14,
          description: 'Kue coklat lembut dengan lelehan coklat hangat manis di bagian tengah.',
          imagePath: 'assets/images/makanan_choco_lava.webp',
        ),
      ],
    ),

    // --- Kategori Minuman ---
    _DummySubCategoryGroup(
      subCategoryName: 'Milk Based',
      type: CategoryType.drink,
      subCategoryImage: 'assets/images/kategori_milk_based.webp',
      items: [
        _DummyMenuItem(
          name: 'Matcha Latte Creamy',
          price: 24000,
          stock: 30,
          description: 'Bubuk matcha murni diseduh dengan susu segar dingin menghasilkan rasa harum creamy.',
          imagePath: 'assets/images/minuman_matcha_latte.webp',
        ),
        _DummyMenuItem(
          name: 'Choco Hazelnut Milk',
          price: 22000,
          stock: 25,
          description: 'Minuman coklat pekat dipadu susu dingin dan sirup kacang hazelnut yang lezat.',
          imagePath: 'assets/images/minuman_choco_hazelnut.webp',
        ),
        _DummyMenuItem(
          name: 'Strawberry Milk Breeze',
          price: 22000,
          stock: 28,
          description: 'Susu segar dingin berpadu selai buah stroberi asli bercita rasa manis asam segar.',
          imagePath: 'assets/images/minuman_strawberry_milk.webp',
        ),
        _DummyMenuItem(
          name: 'Taro Velvety Milk',
          price: 23000,
          stock: 20,
          description: 'Minuman susu rasa ubi taro ungu lembut bercita rasa manis legit khas dan menenangkan.',
          imagePath: 'assets/images/minuman_taro_milk.webp',
        ),
      ],
    ),
    _DummySubCategoryGroup(
      subCategoryName: 'Coffee',
      type: CategoryType.drink,
      subCategoryImage: 'assets/images/kategori_coffee.webp',
      items: [
        _DummyMenuItem(
          name: 'Kopi Susu Gula Aren',
          price: 18000,
          stock: 50,
          description: 'Espresso robusta mantap dengan susu segar dan manis legit gula aren murni.',
          imagePath: 'assets/images/minuman_kopi_susu.webp',
        ),
        _DummyMenuItem(
          name: 'Caramel Macchiato Ice',
          price: 26000,
          stock: 25,
          description: 'Kopi espresso berlayer dengan susu creamy dingin dan siraman saus karamel lezat.',
          imagePath: 'assets/images/minuman_caramel_macchiato.webp',
        ),
        _DummyMenuItem(
          name: 'Americano Double Shot',
          price: 16000,
          stock: 40,
          description: 'Dua shot espresso asli disajikan dingin dengan air mineral segar beraroma bold.',
          imagePath: 'assets/images/minuman_americano.webp',
        ),
        _DummyMenuItem(
          name: 'Vanilla Latte Iced',
          price: 24000,
          stock: 30,
          description: 'Perpaduan harmonis espresso, susu dingin segar, dan aroma sirup vanila lembut.',
          imagePath: 'assets/images/minuman_vanilla_latte.webp',
        ),
      ],
    ),
    _DummySubCategoryGroup(
      subCategoryName: 'Tea',
      type: CategoryType.drink,
      subCategoryImage: 'assets/images/kategori_tea.webp',
      items: [
        _DummyMenuItem(
          name: 'Lychee Iced Tea',
          price: 18000,
          stock: 35,
          description: 'Teh melati wangi dingin disajikan dengan sirup leci dan buah leci asli yang segar.',
          imagePath: 'assets/images/minuman_lychee_tea.webp',
        ),
        _DummyMenuItem(
          name: 'Lemon Tea Segar',
          price: 15000,
          stock: 40,
          description: 'Seduhan teh hitam pilihan dipadu perasan lemon segar alami penyejuk dahaga.',
          imagePath: 'assets/images/minuman_lemon_tea.webp',
        ),
        _DummyMenuItem(
          name: 'Earl Grey Milk Tea',
          price: 20000,
          stock: 25,
          description: 'Teh earl grey beraroma bergamot berpadu susu lembut ala cafe modern.',
          imagePath: 'assets/images/minuman_earl_grey.webp',
        ),
        _DummyMenuItem(
          name: 'Peach Blossom Tea',
          price: 19000,
          stock: 30,
          description: 'Teh aroma buah persik manis lembut dengan rasa menenangkan dan menyegarkan.',
          imagePath: 'assets/images/minuman_peach_blossom.webp',
        ),
      ],
    ),
    _DummySubCategoryGroup(
      subCategoryName: 'Squash',
      type: CategoryType.drink,
      subCategoryImage: 'assets/images/kategori_squash.webp',
      items: [
        _DummyMenuItem(
          name: 'Orange Sunrise Squash',
          price: 20000,
          stock: 25,
          description: 'Soda dingin dengan sari jeruk manis segar dan sirup grenadine merah merekah.',
          imagePath: 'assets/images/minuman_orange_squash.webp',
        ),
        _DummyMenuItem(
          name: 'Blue Ocean Soda Squash',
          price: 22000,
          stock: 20,
          description: 'Minuman soda biru segar dengan rasa jeruk sitrun dan biji selasih penyejuk cuaca panas.',
          imagePath: 'assets/images/minuman_blue_ocean.webp',
        ),
        _DummyMenuItem(
          name: 'Lemon Mint Fizzy Squash',
          price: 18000,
          stock: 30,
          description: 'Perpaduan soda lemon asam segar dengan daun mint remas pelepas dahaga seketika.',
          imagePath: 'assets/images/minuman_lemon_mint.webp',
        ),
        _DummyMenuItem(
          name: 'Strawberry Mojito Squash',
          price: 22000,
          stock: 25,
          description: 'Soda rasa stroberi merah manis asam dipadu remasan daun mint dan jeruk nipis.',
          imagePath: 'assets/images/minuman_strawberry_mojito.webp',
        ),
      ],
    ),
    _DummySubCategoryGroup(
      subCategoryName: 'Juice',
      type: CategoryType.drink,
      subCategoryImage: 'assets/images/kategori_juice.webp',
      items: [
        _DummyMenuItem(
          name: 'Jus Alpukat Kocok Kental',
          price: 22000,
          stock: 20,
          description: 'Alpukat mentega pilihan diblender kental dengan lelehan coklat manis lezat.',
          imagePath: 'assets/images/minuman_jus_alpukat.webp',
        ),
        _DummyMenuItem(
          name: 'Jus Mangga Harum Manis',
          price: 20000,
          stock: 25,
          description: 'Buah mangga matang pohon diblender dingin tanpa pemanis buatan, manis alami.',
          imagePath: 'assets/images/minuman_jus_mangga.webp',
        ),
        _DummyMenuItem(
          name: 'Jus Buah Naga Merah',
          price: 18000,
          stock: 22,
          description: 'Buah naga merah segar kaya serat dan antioksidan diblender segar serta manis.',
          imagePath: 'assets/images/minuman_jus_buah_naga.webp',
        ),
        _DummyMenuItem(
          name: 'Jus Sirsak Asli Segar',
          price: 18000,
          stock: 20,
          description: 'Daging buah sirsak asli dengan sensasi rasa manis asam alami yang menyegarkan.',
          imagePath: 'assets/images/minuman_jus_sirsak.webp',
        ),
      ],
    ),
  ];
}

class _DummySubCategoryGroup {
  final String subCategoryName;
  final CategoryType type;
  final String subCategoryImage;
  final List<_DummyMenuItem> items;

  const _DummySubCategoryGroup({
    required this.subCategoryName,
    required this.type,
    required this.subCategoryImage,
    required this.items,
  });
}

class _DummyMenuItem {
  final String name;
  final double price;
  final int stock;
  final String description;
  final String imagePath;

  const _DummyMenuItem({
    required this.name,
    required this.price,
    required this.stock,
    required this.description,
    required this.imagePath,
  });
}
