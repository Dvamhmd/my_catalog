import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      // Tunggu satu frame agar grid menghilang dari render tree sebelum di-capture
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = _cropAreaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        final base64String = 'data:image/png;base64,${base64Encode(pngBytes)}';
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
        final filePath = '${targetDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = io.File(filePath);
        await file.writeAsBytes(pngBytes, flush: true);
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

    return Dialog(
      backgroundColor: AppTheme.surfaceWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: screenSize.height * 0.9,
        ),
        child: SingleChildScrollView(
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
                    onPressed: () => Navigator.of(context).pop(null),
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
                        onChanged: _updateZoomFromSlider,
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
                    onPressed: _rotateClockwise,
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
                    onPressed: _resetTransformation,
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
                      onPressed: () => Navigator.of(context).pop(null),
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
      ),
    );
  }
}
