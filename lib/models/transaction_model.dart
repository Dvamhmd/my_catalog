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
  static const String statusSelesai = 'selesai';
  static const String statusBelumSelesai = 'belum_selesai';

  final int? id;
  final String invoiceNumber;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final double cashGiven;
  final double change;
  final String? customerCategory;
  final String? customerPhone;
  final String? loyaltyDiscount;
  final List<TransactionItemModel> items;
  final String status;

  TransactionModel({
    this.id,
    required String invoiceNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashGiven,
    required this.change,
    this.customerCategory,
    this.customerPhone,
    this.loyaltyDiscount,
    required this.items,
    this.status = statusSelesai,
  }) : invoiceNumber = invoiceNumber.startsWith('TRX-')
            ? invoiceNumber.replaceFirst('TRX-', 'NLA-')
            : invoiceNumber;

  bool get isCompleted => status == statusSelesai;
  bool get isPending => status == statusBelumSelesai;

  int get totalItemsCount => items.fold(0, (sum, i) => sum + i.quantity);

  String? get displayLoyaltyDiscount {
    if (loyaltyDiscount != null && loyaltyDiscount!.isNotEmpty) {
      return loyaltyDiscount;
    }
    if (items.isEmpty) return null;
    final hasDrinks = items.any((i) => i.categoryType == CategoryType.drink);
    final hasFoods = items.any((i) => i.categoryType == CategoryType.food);
    final allDrinksFree = hasDrinks && items.where((i) => i.categoryType == CategoryType.drink).every((i) => i.price == 0);
    final allFoodsFree = hasFoods && items.where((i) => i.categoryType == CategoryType.food).every((i) => i.price == 0);
    if (allDrinksFree && allFoodsFree) {
      return 'Loyalty Food & Drink';
    } else if (allDrinksFree) {
      return 'Loyalty Drink';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'cash_given': cashGiven,
      'change': change,
      'customer_category': customerCategory,
      'customer_phone': customerPhone,
      'loyalty_discount': loyaltyDiscount,
      'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      'status': status,
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

    final rawInvoice = map['invoice_number'] as String? ?? '';
    final formattedInvoice = rawInvoice.startsWith('TRX-')
        ? rawInvoice.replaceFirst('TRX-', 'NLA-')
        : rawInvoice;

    return TransactionModel(
      id: map['id'] as int?,
      invoiceNumber: formattedInvoice,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      cashGiven: (map['cash_given'] as num?)?.toDouble() ?? 0.0,
      change: (map['change'] as num?)?.toDouble() ?? 0.0,
      customerCategory: map['customer_category'] as String?,
      customerPhone: map['customer_phone'] as String?,
      loyaltyDiscount: map['loyalty_discount'] as String?,
      items: parsedItems,
      status: map['status'] as String? ?? TransactionModel.statusSelesai,
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
    String? customerCategory,
    String? customerPhone,
    String? loyaltyDiscount,
    List<TransactionItemModel>? items,
    String? status,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashGiven: cashGiven ?? this.cashGiven,
      change: change ?? this.change,
      customerCategory: customerCategory ?? this.customerCategory,
      customerPhone: customerPhone ?? this.customerPhone,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
      items: items ?? this.items,
      status: status ?? this.status,
    );
  }
}


