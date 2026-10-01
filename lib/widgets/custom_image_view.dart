import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/category_type.dart';

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
    final isFood = type == CategoryType.food;
    final iconData = isFood ? Icons.restaurant_rounded : Icons.local_drink_rounded;

    // Menghitung ukuran icon yang proporsional dengan dimensi gambar
    final minDim = (width != null && height != null)
        ? (width! < height! ? width! : height!)
        : (height ?? width ?? 80.0);
    final iconSize = (minDim * 0.38).clamp(20.0, 48.0);

    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          iconData,
          size: iconSize,
          color: const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
