import 'category_type.dart';

class MenuItemModel {
  final int? id;
  final String name;
  final double price;
  final String? imagePath;
  final int subCategoryId;
  final String subCategoryName;
  final CategoryType type;
  final String? description;
  final bool isAvailable;
  final DateTime createdAt;

  MenuItemModel({
    this.id,
    required this.name,
    required this.price,
    this.imagePath,
    required this.subCategoryId,
    required this.subCategoryName,
    required this.type,
    this.description,
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      'image_path': imagePath,
      'sub_category_id': subCategoryId,
      'sub_category_name': subCategoryName,
      'type': type.name,
      'description': description,
      'is_available': isAvailable ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      imagePath: map['image_path'] as String?,
      subCategoryId: map['sub_category_id'] as int,
      subCategoryName: map['sub_category_name'] as String? ?? 'Umum',
      type: CategoryType.fromString(map['type'] as String),
      description: map['description'] as String?,
      isAvailable: (map['is_available'] as int? ?? 1) == 1,
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
    String? description,
    bool? isAvailable,
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
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
