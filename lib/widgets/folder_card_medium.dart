import 'package:flutter/material.dart';
import '../models/sub_category_model.dart';
import '../theme/app_theme.dart';
import 'custom_image_view.dart';

class FolderCardMedium extends StatelessWidget {
  final SubCategoryModel subCategory;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderCardMedium({
    super.key,
    required this.subCategory,
    required this.itemCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = subCategory.type.icon;
    final hasImage = subCategory.imagePath != null && subCategory.imagePath!.isNotEmpty;

    return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Graphic Section with Large Food / Drink Icon or Custom Photo
              Expanded(
                flex: 16,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.softPinkBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    child: hasImage
                        ? CustomImageView(
                            imagePath: subCategory.imagePath,
                            type: subCategory.type,
                            isCategory: true,
                            fit: BoxFit.cover,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final iconSize = (constraints.maxHeight * 0.65).clamp(52.0, 78.0);
                              return Center(
                                child: Icon(
                                  iconData,
                                  size: iconSize,
                                  color: AppTheme.primaryPinkDark,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),

              // Bottom Details Section (Top-Start aligned)
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        subCategory.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$itemCount menu',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPinkDark,
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
