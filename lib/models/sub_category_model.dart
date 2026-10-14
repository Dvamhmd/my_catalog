import 'category_type.dart';

class SubCategoryModel {
  final int? id;
  final String name;
  final CategoryType type;
  final String? imagePath;
  final int sortOrder;
  final DateTime createdAt;

  SubCategoryModel({
    this.id,
    required this.name,
    required this.type,
    this.imagePath,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.name,
      'image_path': imagePath,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SubCategoryModel.fromMap(Map<String, dynamic> map) {
    return SubCategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: CategoryType.fromString(map['type'] as String),
      imagePath: map['image_path'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SubCategoryModel copyWith({
    int? id,
    String? name,
    CategoryType? type,
    String? imagePath,
    bool clearImage = false,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return SubCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubCategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          imagePath == other.imagePath &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ type.hashCode ^ (imagePath?.hashCode ?? 0) ^ sortOrder.hashCode;
}

