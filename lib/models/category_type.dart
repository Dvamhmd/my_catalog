import 'package:flutter/material.dart';

enum CategoryType {
  food,
  drink;

  String get displayName {
    switch (this) {
      case CategoryType.food:
        return 'Makanan';
      case CategoryType.drink:
        return 'Minuman';
    }
  }

  String get emoji {
    switch (this) {
      case CategoryType.food:
        return '🍱';
      case CategoryType.drink:
        return '🍹';
    }
  }

  /// Icon untuk Kategori (Makanan: Sendok Garpu/Pisau, Minuman: Gelas Martini)
  IconData get icon {
    switch (this) {
      case CategoryType.food:
        return Icons.restaurant_rounded;
      case CategoryType.drink:
        return Icons.local_bar_rounded;
    }
  }

  IconData get categoryIcon => icon;

  /// Icon untuk Menu (Makanan: Burger, Minuman: Cup Take Away dengan Sedotan)
  IconData get menuIcon {
    switch (this) {
      case CategoryType.food:
        return Icons.lunch_dining_rounded;
      case CategoryType.drink:
        return Icons.local_drink_rounded;
    }
  }

  static CategoryType fromString(String value) {
    if (value.toLowerCase() == 'drink' || value.toLowerCase() == 'minuman') {
      return CategoryType.drink;
    }
    return CategoryType.food;
  }
}
