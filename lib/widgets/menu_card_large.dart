import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'custom_image_view.dart';

class MenuCardLarge extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onTap;

  const MenuCardLarge({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = !item.isAvailable || item.stock <= 0;

    return Container(
      decoration: BoxDecoration(
        color: isOutOfStock ? const Color(0xFFE2E3E7) : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFCBCDD3)
              : const Color(0xFFFFE0E6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0FFF5D8F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image with availability overlay
                Stack(
                  children: [
                    CustomImageView(
                      imagePath: item.imagePath,
                      type: item.type,
                      width: 82,
                      height: 82,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    if (isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Habis',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Subcategory Badge & Stock Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppTheme.softPinkBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.subCategoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryPinkDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: item.stock > 0
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.stock > 0
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFFFFCDD2),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.stock > 0 ? 'Stok: ${item.stock}' : 'Stok: 0',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: item.stock > 0
                                    ? const Color(0xFF2E7D32)
                                    : AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Menu Name
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: item.isAvailable
                              ? AppTheme.textDark
                              : AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Description (optional)
                      if (item.description != null && item.description!.isNotEmpty)
                        Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: AppTheme.textMedium,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      const SizedBox(height: 6),

                      // Price
                      Text(
                        Formatters.currency(item.price),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isOutOfStock
                              ? AppTheme.primaryPink.withValues(alpha: 0.38)
                              : AppTheme.primaryPink,
                        ),
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
