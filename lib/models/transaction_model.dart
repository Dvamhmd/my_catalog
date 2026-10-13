import 'dart:convert';
import 'category_type.dart';

class TransactionItemModel {
  final int? menuId;
  final String name;
  final double price;
  final int quantity;
  final double totalPrice;
  final String? imagePath;
  final CategoryType? categoryType;

  TransactionItemModel({
    this.menuId,
    required this.name,
    required this.price,
    required this.quantity,
    double? totalPrice,
    this.imagePath,
    this.categoryType,
  }) : totalPrice = totalPrice ?? (price * quantity);

  Map<String, dynamic> toMap() {
    return {
      'menu_id': menuId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total_price': totalPrice,
      'image_path': imagePath,
      'category_type': categoryType?.name,
    };
  }

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      menuId: map['menu_id'] as int?,
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      totalPrice: (map['total_price'] as num?)?.toDouble(),
      imagePath: map['image_path'] as String?,
      categoryType: map['category_type'] != null
          ? CategoryType.fromString(map['category_type'] as String)
          : null,
    );
  }
}

class TransactionModel {
  final int? id;
  final String invoiceNumber;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final double cashGiven;
  final double change;
  final List<TransactionItemModel> items;

  TransactionModel({
    this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashGiven,
    required this.change,
    required this.items,
  });

  int get totalItemsCount => items.fold(0, (sum, i) => sum + i.quantity);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'cash_given': cashGiven,
      'change': change,
      'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    List<TransactionItemModel> parsedItems = [];
    if (map['items_json'] != null) {
      try {
        final decoded = jsonDecode(map['items_json'] as String);
        if (decoded is List) {
          parsedItems = decoded
              .map((i) => TransactionItemModel.fromMap(Map<String, dynamic>.from(i)))
              .toList();
        }
      } catch (_) {}
    }

    return TransactionModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'Tunai',
      cashGiven: (map['cash_given'] as num?)?.toDouble() ?? 0.0,
      change: (map['change'] as num?)?.toDouble() ?? 0.0,
      items: parsedItems,
    );
  }

  TransactionModel copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? createdAt,
    double? totalAmount,
    String? paymentMethod,
    double? cashGiven,
    double? change,
    List<TransactionItemModel>? items,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashGiven: cashGiven ?? this.cashGiven,
      change: change ?? this.change,
      items: items ?? this.items,
    );
  }
}
