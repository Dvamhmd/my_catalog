import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/category_type.dart';
import '../theme/app_theme.dart';

class CustomImageView extends StatelessWidget {
  final String? imagePath;
  final CategoryType type;
  final bool isCategory;
  final IconData? fallbackIcon;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const CustomImageView({
    super.key,
    this.imagePath,
    required this.type,
    this.isCategory = false,
    this.fallbackIcon,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    final cleanPath = imagePath?.trim();
    final int? targetCacheWidth = (width != null && width!.isFinite && width! > 0) ? (width! * 2).toInt() : null;
    final int? targetCacheHeight = (height != null && height!.isFinite && height! > 0) ? (height! * 2).toInt() : null;

    Widget imageContent;

    if (cleanPath != null && cleanPath.isNotEmpty) {
      if (cleanPath.startsWith('data:image') ||
          (cleanPath.length > 100 && !cleanPath.contains('/') && !cleanPath.contains('\\'))) {
        try {
          final base64Str = cleanPath.contains(',') ? cleanPath.split(',').last : cleanPath;
          final bytes = base64Decode(base64Str);
          imageContent = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: targetCacheWidth,
            cacheHeight: targetCacheHeight,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } catch (_) {
          imageContent = _buildPlaceholder();
        }
      } else if (kIsWeb || cleanPath.startsWith('blob:') || cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        imageContent = Image.network(
          cleanPath,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: targetCacheWidth,
          cacheHeight: targetCacheHeight,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else {
        try {
          final file = io.File(cleanPath);
          imageContent = Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: targetCacheWidth,
            cacheHeight: targetCacheHeight,
            errorBuilder: (context, error, stackTrace) {
              try {
                final base64Str = cleanPath.contains(',') ? cleanPath.split(',').last : cleanPath;
                final bytes = base64Decode(base64Str);
                return Image.memory(
                  bytes,
                  width: width,
                  height: height,
                  fit: fit,
                  cacheWidth: targetCacheWidth,
                  cacheHeight: targetCacheHeight,
                  errorBuilder: (c, e, s) => _buildPlaceholder(),
                );
              } catch (_) {
                return _buildPlaceholder();
              }
            },
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
    final iconData = fallbackIcon ?? (isCategory ? type.categoryIcon : type.menuIcon);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = (width != null && width! > 0 && width!.isFinite)
            ? width!
            : (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 90.0);
        final double h = (height != null && height! > 0 && height!.isFinite)
            ? height!
            : (constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 90.0);

        final minDim = w < h ? w : h;
        // Icon lebih besar (52% dari minDim) agar tidak terlalu banyak space kosong
        final iconSize = (minDim * 0.52).clamp(28.0, 64.0);

        return Container(
          width: width,
          height: height,
          color: AppTheme.softPinkBackground,
          child: Center(
            child: Icon(
              iconData,
              size: iconSize,
              color: AppTheme.primaryPinkDark,
            ),
          ),
        );
      },
    );
  }
}
