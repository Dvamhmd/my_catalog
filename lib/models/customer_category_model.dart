class CustomerCategoryModel {
  final int? id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;

  CustomerCategoryModel({
    this.id,
    required this.name,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CustomerCategoryModel.fromMap(Map<String, dynamic> map) {
    return CustomerCategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CustomerCategoryModel copyWith({
    int? id,
    String? name,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return CustomerCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
