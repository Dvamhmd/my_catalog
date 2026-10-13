import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'custom_image_view.dart';

class MenuCardSmall extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onTap;

  const MenuCardSmall({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFCBCDD3)
              : const Color(0xFFFFE0E6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0AFF5D8F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Top Section
              Expanded(
                flex: 10,
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
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: item.isAvailable
                              ? AppTheme.textDark
                              : AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.currency(item.price),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isOutOfStock
                                ? AppTheme.primaryPink.withValues(alpha: 0.38)
                                : AppTheme.primaryPink,
                          ),
                        ),
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
