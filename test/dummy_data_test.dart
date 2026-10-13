import 'package:flutter_test/flutter_test.dart';
import 'package:my_catalog/models/category_type.dart';
import 'package:my_catalog/services/database_service.dart';
import 'package:my_catalog/services/dummy_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.initialize();
  });

  test('DummyDataService default state is off', () async {
    final service = DummyDataService.instance;
    final isEnabled = await service.isDummyDataEnabled();
    expect(isEnabled, isFalse);
  });

  test('DummyDataService can enable and populate 8 subcategories and 32 menu items', () async {
    final service = DummyDataService.instance;
    final db = DatabaseService.instance;

    // Enable dummy data
    final enableSuccess = await service.enableDummyData();
    expect(enableSuccess, isTrue);

    final isEnabled = await service.isDummyDataEnabled();
    expect(isEnabled, isTrue);

    // Check SubCategories
    final foodSubs = await db.getSubCategories(CategoryType.food);
    final drinkSubs = await db.getSubCategories(CategoryType.drink);

    // Kategori Makanan: Snack, Main Course, Dessert
    final foodSubNames = foodSubs.map((s) => s.name).toSet();
    expect(foodSubNames.contains('Snack'), isTrue);
    expect(foodSubNames.contains('Main Course'), isTrue);
    expect(foodSubNames.contains('Dessert'), isTrue);

    // Kategori Minuman: Milk Based, Coffee, Tea, Squash, Juice
    final drinkSubNames = drinkSubs.map((s) => s.name).toSet();
    expect(drinkSubNames.contains('Milk Based'), isTrue);
    expect(drinkSubNames.contains('Coffee'), isTrue);
    expect(drinkSubNames.contains('Tea'), isTrue);
    expect(drinkSubNames.contains('Squash'), isTrue);
    expect(drinkSubNames.contains('Juice'), isTrue);

    // Total subcategories = 8
    expect(foodSubs.length + drinkSubs.length, equals(8));

    // Check Menu Items
    final foodItems = await db.getMenuItems(type: CategoryType.food);
    final drinkItems = await db.getMenuItems(type: CategoryType.drink);

    // 3 food subcategories * 4 items = 12 food items
    expect(foodItems.length, equals(12));
    // 5 drink subcategories * 4 items = 20 drink items
    expect(drinkItems.length, equals(20));
    // Total 32 items
    expect(foodItems.length + drinkItems.length, equals(32));

    // Verify all items have positive stock, valid prices, descriptions, and imagePath
    for (final item in [...foodItems, ...drinkItems]) {
      expect(item.name.isNotEmpty, isTrue);
      expect(item.price > 0, isTrue);
      expect(item.stock > 0, isTrue);
      expect(item.description != null && item.description!.isNotEmpty, isTrue);
      expect(
          item.imagePath != null &&
              (item.imagePath!.startsWith('http') ||
                  item.imagePath!.startsWith('assets/')),
          isTrue);
    }

    // Disable dummy data
    final disableSuccess = await service.disableDummyData();
    expect(disableSuccess, isTrue);
    expect(await service.isDummyDataEnabled(), isFalse);

    // Verify all dummy items and subcategories are cleared
    final remainingFoodSubs = await db.getSubCategories(CategoryType.food);
    final remainingDrinkSubs = await db.getSubCategories(CategoryType.drink);
    final remainingFoodItems = await db.getMenuItems(type: CategoryType.food);
    final remainingDrinkItems = await db.getMenuItems(type: CategoryType.drink);

    expect(remainingFoodSubs.isEmpty, isTrue);
    expect(remainingDrinkSubs.isEmpty, isTrue);
    expect(remainingFoodItems.isEmpty, isTrue);
    expect(remainingDrinkItems.isEmpty, isTrue);
  });
}
