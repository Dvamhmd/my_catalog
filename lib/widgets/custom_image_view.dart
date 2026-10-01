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

    Widget imageContent;

    if (imagePath != null && imagePath!.isNotEmpty) {
      if (imagePath!.startsWith('data:image') || (imagePath!.length > 100 && !imagePath!.contains('/') && !imagePath!.contains('\\'))) {
        try {
          final base64Str = imagePath!.contains(',') ? imagePath!.split(',').last : imagePath!;
          final bytes = base64Decode(base64Str);
          imageContent = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } catch (_) {
          imageContent = _buildPlaceholder();
        }
      } else if (kIsWeb || imagePath!.startsWith('blob:') || imagePath!.startsWith('http://') || imagePath!.startsWith('https://')) {
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
