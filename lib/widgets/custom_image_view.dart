import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/category_type.dart';
import '../theme/app_theme.dart';

class CustomImageView extends StatelessWidget {
  final String? imagePath;
  final CategoryType type;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const CustomImageView({
    super.key,
    this.imagePath,
    required this.type,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    Widget imageContent;

    if (imagePath != null && imagePath!.isNotEmpty) {
      if (kIsWeb) {
        imageContent = Image.network(
          imagePath!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else {
        try {
          final file = io.File(imagePath!);
          imageContent = Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: width != null ? (width! * 2).toInt() : null,
            cacheHeight: height != null ? (height! * 2).toInt() : null,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } catch (_) {
          imageContent = _buildPlaceholder();
        }
      }
    } else {
      imageContent = _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: imageContent,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFF0F3),
            Color(0xFFFFD6E0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xE6FFFFFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1FFF5D8F),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                type.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              type.displayName,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPinkDark,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
