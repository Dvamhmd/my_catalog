import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'custom_image_view.dart';

class KasirMenuCardSmall extends StatelessWidget {
  final MenuItemModel item;
  final int cartQty;
  final Function(BuildContext context) onAddToCart;
  final VoidCallback onDecrement;

  const KasirMenuCardSmall({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryPink
              : (isOutOfStock ? const Color(0xFFE5E5E5) : const Color(0xFFFFE0E6)),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryPink.withValues(alpha: 0.16)
                : const Color(0x0AFF5D8F),
            blurRadius: isSelected ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOutOfStock ? null : () => onAddToCart(context),
          borderRadius: BorderRadius.circular(12),
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
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                    ),
                    // Stock Badge on Top Right
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.stock > 0
                              ? Colors.black.withValues(alpha: 0.6)
                              : AppTheme.dangerRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.stock > 0 ? 'Stok: ${item.stock}' : 'Stok: 0',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Selected cart qty badge on top-left
                    if (isSelected)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Text(
                            '${cartQty}x',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Habis',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
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
                  padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock ? AppTheme.textLight : AppTheme.textDark,
                        ),
                      ),
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
                                  fontSize: 12.5,
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
                              Builder(
                                builder: (btnCtx) => GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onAddToCart(btnCtx),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryPink,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                                  ),
                                ),
                              )
                            else
                              Builder(
                                builder: (btnCtx) => Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.softPinkBackground,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_shopping_cart_rounded, size: 12, color: AppTheme.primaryPinkDark),
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
