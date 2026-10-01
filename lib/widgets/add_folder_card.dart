import 'package:flutter/material.dart';
import '../models/category_type.dart';
import '../models/layout_mode.dart';
import '../theme/app_theme.dart';

class AddFolderCard extends StatelessWidget {
  final CategoryType activeType;
  final LayoutMode layoutMode;
  final VoidCallback onTap;

  const AddFolderCard({
    super.key,
    required this.activeType,
    required this.layoutMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFood = activeType == CategoryType.food;

    if (layoutMode == LayoutMode.large) {
      // 1 Column / Perbaris
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.softPinkBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFB6C6),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppTheme.primaryPink,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tambah Kategori ${isFood ? 'Makanan' : 'Minuman'} Baru',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPinkDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2 or 3 Columns
    final isSmall = layoutMode == LayoutMode.small;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.softPinkBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
        border: Border.all(
          color: const Color(0xFFFFB6C6),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 6 : 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppTheme.primaryPink,
                  size: isSmall ? 18 : 24,
                ),
              ),
              SizedBox(height: isSmall ? 6 : 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Tambah Kategori',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: isSmall ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPinkDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
