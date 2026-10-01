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

  static CategoryType fromString(String value) {
    if (value.toLowerCase() == 'drink' || value.toLowerCase() == 'minuman') {
      return CategoryType.drink;
    }
    return CategoryType.food;
  }
}
