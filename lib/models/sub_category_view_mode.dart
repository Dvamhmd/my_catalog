import 'package:flutter/material.dart';

enum SubCategoryViewMode {
  tab('Tab', 'Tampilan Per Tab', Icons.tab_rounded),
  category('Kategori', 'Tampilan Per Kategori', Icons.category_rounded);

  final String label;
  final String description;
  final IconData icon;

  const SubCategoryViewMode(this.label, this.description, this.icon);

  static SubCategoryViewMode fromString(String? val) {
    if (val == 'category' || val == 'folder') return SubCategoryViewMode.category;
    return SubCategoryViewMode.tab;
  }
}
