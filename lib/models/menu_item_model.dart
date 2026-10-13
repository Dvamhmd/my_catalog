import 'dart:convert';
import 'category_type.dart';

class MenuItemModel {
  final int? id;
  final String name;
  final double price;
  final String? imagePath;
  final int subCategoryId;
  final String subCategoryName;
  final CategoryType type;
  final int stock;
  final String? description;
  final bool isAvailable;
  final Map<String, double> customerPrices;
  final DateTime createdAt;

  MenuItemModel({
    this.id,
    required this.name,
    required this.price,
    this.imagePath,
    required this.subCategoryId,
    required this.subCategoryName,
    required this.type,
    this.stock = 0,
    this.description,
    this.isAvailable = true,
    Map<String, double>? customerPrices,
    DateTime? createdAt,
  })  : customerPrices = customerPrices ?? const {},
        createdAt = createdAt ?? DateTime.now();

  double getPriceForCategory(String? categoryName) {
    if (categoryName == null ||
        categoryName.trim().isEmpty ||
        categoryName.toLowerCase() == 'reguler' ||
        categoryName.toLowerCase() == 'umum') {
      return price;
    }
    final customPrice = customerPrices[categoryName];
    if (customPrice != null && customPrice > 0) {
      return customPrice;
    }
    return price;
  }

  bool hasCustomPriceForCategory(String? categoryName) {
    if (categoryName == null ||
        categoryName.trim().isEmpty ||
        categoryName.toLowerCase() == 'reguler' ||
        categoryName.toLowerCase() == 'umum') {
      return false;
    }
    final customPrice = customerPrices[categoryName];
    return customPrice != null && customPrice > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      'image_path': imagePath,
      'sub_category_id': subCategoryId,
      'sub_category_name': subCategoryName,
      'type': type.name,
      'stock': stock,
      'description': description,
      'is_available': isAvailable ? 1 : 0,
      'customer_prices_json': jsonEncode(customerPrices),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    Map<String, double> parsedCustomerPrices = {};
    if (map['customer_prices_json'] != null) {
      try {
        final decoded = jsonDecode(map['customer_prices_json'] as String);
        if (decoded is Map) {
          parsedCustomerPrices = decoded.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          );
        }
      } catch (_) {}
    }

    return MenuItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      imagePath: map['image_path'] as String?,
      subCategoryId: map['sub_category_id'] as int,
      subCategoryName: map['sub_category_name'] as String? ?? 'Umum',
      type: CategoryType.fromString(map['type'] as String),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
      isAvailable: (map['is_available'] as int? ?? 1) == 1,
      customerPrices: parsedCustomerPrices,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  MenuItemModel copyWith({
    int? id,
    String? name,
    double? price,
    String? imagePath,
    int? subCategoryId,
    String? subCategoryName,
    CategoryType? type,
    int? stock,
    String? description,
    bool? isAvailable,
    Map<String, double>? customerPrices,
    DateTime? createdAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      subCategoryName: subCategoryName ?? this.subCategoryName,
      type: type ?? this.type,
      stock: stock ?? this.stock,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      customerPrices: customerPrices ?? this.customerPrices,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
