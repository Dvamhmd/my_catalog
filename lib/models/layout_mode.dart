import 'package:flutter/material.dart';

enum LayoutMode {
  large(1, 'Besar', '1 Kolom', Icons.view_agenda_rounded),
  medium(2, 'Sedang', '2 Kolom', Icons.grid_view_rounded),
  small(3, 'Kecil', '3 Kolom', Icons.apps_rounded);

  final int columns;
  final String label;
  final String subtitle;
  final IconData icon;

  const LayoutMode(this.columns, this.label, this.subtitle, this.icon);

  static LayoutMode fromColumns(int cols) {
    switch (cols) {
      case 1:
        return LayoutMode.large;
      case 3:
        return LayoutMode.small;
      case 2:
      default:
        return LayoutMode.medium;
    }
  }
}
