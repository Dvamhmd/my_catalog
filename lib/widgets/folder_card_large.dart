import 'package:flutter/material.dart';
import '../models/sub_category_model.dart';
import '../theme/app_theme.dart';
import 'custom_image_view.dart';

class FolderCardLarge extends StatelessWidget {
  final SubCategoryModel subCategory;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderCardLarge({
    super.key,
    required this.subCategory,
    required this.itemCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = subCategory.type.icon;

    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFE0E6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0FFF5D8F),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Food / Drink Icon or Custom Photo Graphic Container
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppTheme.softPinkBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFFE0E6),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: CustomImageView(
                      imagePath: subCategory.imagePath,
                      type: subCategory.type,
                      isCategory: true,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Category Title & Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subCategory.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: itemCount > 0
                                  ? AppTheme.softPinkBackground
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: itemCount > 0
                                    ? const Color(0xFFFFD1DC)
                                    : const Color(0xFFE5E5E8),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  iconData,
                                  size: 14,
                                  color: itemCount > 0
                                      ? AppTheme.primaryPinkDark
                                      : AppTheme.textLight,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '$itemCount menu',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: itemCount > 0
                                        ? AppTheme.primaryPinkDark
                                        : AppTheme.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
