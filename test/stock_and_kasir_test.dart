import 'package:flutter_test/flutter_test.dart';
import 'package:my_catalog/models/category_type.dart';
import 'package:my_catalog/models/menu_item_model.dart';
import 'package:my_catalog/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.initialize();
  });

  test('MenuItemModel should support stock property correctly', () {
    final item = MenuItemModel(
      id: 1,
      name: 'Nasi Goreng',
      price: 25000,
      subCategoryId: 10,
      subCategoryName: 'Makanan Utama',
      type: CategoryType.food,
      stock: 15,
      isAvailable: true,
    );

    expect(item.stock, 15);
    final map = item.toMap();
    expect(map['stock'], 15);

    final fromMap = MenuItemModel.fromMap(map);
    expect(fromMap.stock, 15);

    final updated = item.copyWith(stock: 8);
    expect(updated.stock, 8);
  });

  test('DatabaseService should update stock and checkout orders accurately', () async {
    final db = DatabaseService.instance;

    final item1 = MenuItemModel(
      name: 'Es Teh Manis',
      price: 5000,
      subCategoryId: 1,
      subCategoryName: 'Minuman Dingin',
      type: CategoryType.drink,
      stock: 10,
    );
    final id1 = await db.insertMenuItem(item1);

    // Update stock directly
    await db.updateMenuItemStock(id1, 25);
    var items = await db.getMenuItems(type: CategoryType.drink);
    var savedItem = items.firstWhere((i) => i.id == id1);
    expect(savedItem.stock, 25);

    // Checkout order of 5
    final success = await db.checkoutOrder({id1: 5});
    expect(success, isTrue);

    items = await db.getMenuItems(type: CategoryType.drink);
    savedItem = items.firstWhere((i) => i.id == id1);
    expect(savedItem.stock, 20);

    // Checkout remaining 20
    await db.checkoutOrder({id1: 20});
    items = await db.getMenuItems(type: CategoryType.drink);
    savedItem = items.firstWhere((i) => i.id == id1);
    expect(savedItem.stock, 0);
    expect(savedItem.isAvailable, isFalse);
  });
}
