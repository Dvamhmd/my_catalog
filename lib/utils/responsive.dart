import 'package:flutter/material.dart';

class Responsive {
  static bool isSmallPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 360;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 600;
  }

  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 10.0;
    if (width > 600) return 24.0;
    return 14.0;
  }

  /// Calculates child aspect ratio for GridView based on columns and available screen width
  /// preventing vertical overflow or text truncation on diverse DPIs
  static double getCardAspectRatio({
    required BuildContext context,
    required int columns,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    // Adjust ratio if user has high system font scale
    final scaleAdjust = (textScale - 1.0).clamp(0.0, 0.5) * 0.15;

    switch (columns) {
      case 1:
        // 1 column (Besar)
        if (width > 600) return 3.2 - scaleAdjust;
        if (width < 360) return 1.8 - scaleAdjust;
        return 2.0 - scaleAdjust;

      case 3:
        // 3 columns (Kecil)
        if (width > 600) return 0.85 - scaleAdjust;
        if (width < 360) return 0.58 - scaleAdjust;
        return 0.64 - scaleAdjust;

      case 2:
      default:
        // 2 columns (Sedang / Default)
        if (width > 600) return 1.05 - scaleAdjust;
        if (width < 360) return 0.70 - scaleAdjust;
        return 0.78 - scaleAdjust;
    }
  }
}
