import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class ImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;

  const ImageCropperDialog({
    super.key,
    required this.imageBytes,
    this.title = 'Sesuaikan & Potong Foto',
  });

  static Future<String?> cropImage(
    BuildContext context, {
    required XFile file,
    String title = 'Sesuaikan & Potong Foto',
  }) async {
    try {
      final bytes = await file.readAsBytes();
      if (!context.mounted) return null;
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ImageCropperDialog(
          imageBytes: bytes,
          title: title,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses gambar: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
      return null;
    }
  }

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController = TransformationController();

  int _quarterTurns = 0;
  double _currentScale = 1.0;
  bool _isSaving = false;
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformationChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.02) {
      setState(() {
        _currentScale = scale.clamp(0.8, 5.0);
      });
    }
  }

  void _rotateClockwise() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _resetTransformation();
    });
  }

  void _resetTransformation() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _updateZoomFromSlider(double newScale) {
    setState(() {
      _currentScale = newScale;
      final Matrix4 matrix = _transformController.value.clone();
      final currentAxisScale = matrix.getMaxScaleOnAxis();
      if (currentAxisScale > 0) {
        final factor = newScale / currentAxisScale;
        matrix.scaleByDouble(factor, factor, 1.0, 1.0);
        _transformController.value = matrix;
      }
    });
  }

  Future<void> _applyCrop() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _showGrid = false;
    });

    try {
      // Beri jeda 80ms agar UI sempat me-render loading overlay & menyembunyikan grid
      await Future.delayed(const Duration(milliseconds: 80));

      final boundary = _cropAreaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }

      // Gunakan pixelRatio 1.6 (~450-480px), ukuran optimal & sangat tajam di layar Retina
      // tanpa membuang memori CPU
      final ui.Image image = await boundary.toImage(pixelRatio: 1.6);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }

      final Uint8List rawRgbaBytes = byteData.buffer.asUint8List();
      final int imageWidth = image.width;
      final int imageHeight = image.height;

      // Konversi langsung RGBA -> WebP tanpa overhead encode & decode PNG
      final Uint8List outputBytes = await compute(_encodeWebPWorker, {
        'rgbaBytes': rawRgbaBytes,
        'width': imageWidth,
        'height': imageHeight,
        'quality': 78,
      });

      if (kIsWeb) {
        final base64String = 'data:image/webp;base64,${base64Encode(outputBytes)}';
        if (mounted) {
          Navigator.of(context).pop(base64String);
        }
      } else {
        io.Directory targetDir;
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = io.Directory('${appDir.path}/catalog_images');
          if (!imagesDir.existsSync()) {
            await imagesDir.create(recursive: true);
          }
          targetDir = imagesDir;
        } catch (_) {
          targetDir = await getTemporaryDirectory();
        }
        final filePath = '${targetDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.webp';
        final file = io.File(filePath);
        await file.writeAsBytes(outputBytes, flush: true);
        if (mounted) {
          Navigator.of(context).pop(filePath);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showGrid = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan hasil potong: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final cropBoxSize = math.min(screenSize.width - 64, 300.0).clamp(220.0, 320.0);

    return PopScope(
      canPop: !_isSaving,
      child: Dialog(
        backgroundColor: AppTheme.surfaceWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: screenSize.height * 0.9,
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.softPinkBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.crop_rotate_rounded, color: AppTheme.primaryPink, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textLight),
                          onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Geser, putar, dan perbesar (zoom) foto agar pas di dalam bingkai tanpa terdistorsi/stretch.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppTheme.textMedium,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Crop Viewport Container
                    Center(
                      child: Container(
                        width: cropBoxSize,
                        height: cropBoxSize,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // RepaintBoundary capturing image inside viewport
                              RepaintBoundary(
                                key: _cropAreaKey,
                                child: Container(
                                  width: cropBoxSize,
                                  height: cropBoxSize,
                                  color: Colors.black,
                                  child: InteractiveViewer(
                                    transformationController: _transformController,
                                    minScale: 0.8,
                                    maxScale: 5.0,
                                    boundaryMargin: EdgeInsets.all(cropBoxSize * 0.8),
                                    child: Center(
                                      child: RotatedBox(
                                        quarterTurns: _quarterTurns,
                                        child: Image.memory(
                                          widget.imageBytes,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Guidelines & Viewfinder Framing Overlays
                              if (_showGrid)
                                IgnorePointer(
                                  child: Stack(
                                    children: [
                                      // Rule of thirds grid lines
                                      Column(
                                        children: [
                                          const Spacer(flex: 1),
                                          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
                                          const Spacer(flex: 1),
                                          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
                                          const Spacer(flex: 1),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Spacer(flex: 1),
                                          Container(width: 1, color: Colors.white.withValues(alpha: 0.25)),
                                          const Spacer(flex: 1),
                                          Container(width: 1, color: Colors.white.withValues(alpha: 0.25)),
                                          const Spacer(flex: 1),
                                        ],
                                      ),
                                      // Border outline
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppTheme.primaryPink.withValues(alpha: 0.8),
                                            width: 2,
                                          ),
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
                    const SizedBox(height: 14),

                    // Zoom slider control
                    Row(
                      children: [
                        const Icon(Icons.zoom_out_rounded, size: 18, color: AppTheme.textMedium),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.primaryPink,
                              inactiveTrackColor: AppTheme.softPinkBackground,
                              thumbColor: AppTheme.primaryPink,
                              trackHeight: 3.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            ),
                            child: Slider(
                              value: _currentScale.clamp(0.8, 4.0),
                              min: 0.8,
                              max: 4.0,
                              onChanged: _isSaving ? null : _updateZoomFromSlider,
                            ),
                          ),
                        ),
                        const Icon(Icons.zoom_in_rounded, size: 20, color: AppTheme.primaryPink),
                      ],
                    ),

                    // Action Toolbar (Rotate, Reset)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            side: const BorderSide(color: Color(0xFFFFD1DC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            foregroundColor: AppTheme.textDark,
                          ),
                          icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 16, color: AppTheme.primaryPink),
                          label: const Text(
                            'Putar 90°',
                            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _isSaving ? null : _rotateClockwise,
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            side: const BorderSide(color: Color(0xFFFFD1DC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            foregroundColor: AppTheme.textDark,
                          ),
                          icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.textMedium),
                          label: const Text(
                            'Reset',
                            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _isSaving ? null : _resetTransformation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bottom Confirmation Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textMedium,
                              side: const BorderSide(color: Color(0xFFFFD1DC)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _isSaving ? null : _applyCrop,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Gunakan Foto',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
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

              // Loading Icon & Modal Overlay saat konversi WebP berlangsung
              if (_isSaving)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppTheme.softPinkBackground,
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                strokeWidth: 3.2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Mengonversi Gambar...',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Mengompres & memformat ke WebP',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Worker fungsi top-level untuk compute isolate
Uint8List _encodeWebPWorker(Map<String, dynamic> params) {
  final Uint8List rgbaBytes = params['rgbaBytes'] as Uint8List;
  final int width = params['width'] as int;
  final int height = params['height'] as int;
  final int quality = (params['quality'] as int?) ?? 78;

  var image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgbaBytes.buffer,
    order: img.ChannelOrder.rgba,
  );

  // Resize cepat jika lebih besar dari 450x450 untuk performa maksimal
  if (image.width > 450 || image.height > 450) {
    image = img.copyResize(
      image,
      width: 450,
      height: 450,
      interpolation: img.Interpolation.linear,
    );
  }

  return Uint8List.fromList(img.encodeWebP(image, quality: quality));
}
