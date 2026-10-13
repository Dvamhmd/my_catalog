import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'custom_image_view.dart';

class KasirMenuCardMedium extends StatelessWidget {
  final MenuItemModel item;
  final int cartQty;
  final Function(BuildContext context) onAddToCart;
  final VoidCallback onDecrement;

  const KasirMenuCardMedium({
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
        color: isOutOfStock ? const Color(0xFFE2E3E7) : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryPink
              : (isOutOfStock ? const Color(0xFFCBCDD3) : const Color(0xFFFFE0E6)),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Top Section
              Expanded(
                flex: 14,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomImageView(
                        imagePath: item.imagePath,
                        type: item.type,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                        ),
                      ),
                    ),
                    // Subcategory Pill on Top Left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            item.subCategoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryPinkDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Stock Badge on Top Right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: item.stock > 0
                              ? Colors.black.withValues(alpha: 0.6)
                              : AppTheme.dangerRed,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.stock > 0 ? 'Stok: ${item.stock}' : 'Stok: 0',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Selected cart qty badge
                    if (isSelected)
                      Positioned(
                        bottom: 8,
                        right: 8,
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
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Availability Overlay
                    if (isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Habis',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Details Bottom Section
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isOutOfStock ? AppTheme.textLight : AppTheme.textDark,
                        ),
                      ),

                      // Price and action row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Formatters.currency(item.price),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isOutOfStock
                                      ? AppTheme.primaryPink.withValues(alpha: 0.38)
                                      : AppTheme.primaryPink,
                                ),
                              ),
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
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: AppTheme.softPinkBackground,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFFFD1DC)),
                                      ),
                                      child: const Icon(Icons.remove_rounded, size: 13, color: AppTheme.primaryPinkDark),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '$cartQty',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11.5,
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
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryPink,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Builder(
                                builder: (btnCtx) => Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.softPinkBackground,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 14,
                                    color: AppTheme.primaryPinkDark,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
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
