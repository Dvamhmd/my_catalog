import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'custom_image_view.dart';

class KasirMenuCardLarge extends StatelessWidget {
  final MenuItemModel item;
  final int cartQty;
  final Function(BuildContext context) onAddToCart;
  final VoidCallback onDecrement;

  const KasirMenuCardLarge({
    super.key,
    required this.item,
    required this.cartQty,
    required this.onAddToCart,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = item.stock <= 0 || !item.isAvailable;
    final isSelected = cartQty > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryPink
              : (isOutOfStock ? const Color(0xFFE5E5E5) : const Color(0xFFFFE0E6)),
          width: isSelected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryPink.withValues(alpha: 0.16)
                : const Color(0x0FFF5D8F),
            blurRadius: isSelected ? 12 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOutOfStock ? null : () => onAddToCart(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image with availability overlay & cart count badge
                Stack(
                  children: [
                    CustomImageView(
                      imagePath: item.imagePath,
                      type: item.type,
                      width: 96,
                      height: 96,
                      borderRadius: BorderRadius.circular(14),
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
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${cartQty}x',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
                          color: item.isAvailable && item.stock > 0
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

                      // Price and action row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          if (!isOutOfStock)
                            if (isSelected)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onDecrement,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppTheme.softPinkBackground,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFFFD1DC)),
                                      ),
                                      child: const Icon(Icons.remove_rounded, size: 16, color: AppTheme.primaryPinkDark),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$cartQty',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  Builder(
                                    builder: (btnCtx) => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => onAddToCart(btnCtx),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryPink,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Builder(
                                builder: (btnCtx) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.softPinkBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_shopping_cart_rounded,
                                        size: 14,
                                        color: AppTheme.primaryPinkDark,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Pilih',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryPinkDark,
                                        ),
                                      ),
                                    ],
                                  ),
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
