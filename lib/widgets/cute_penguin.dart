import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget Penguin Lucu dan Menggemaskan dengan Animasi Interaktif
class CutePenguin extends StatefulWidget {
  final double size;
  final bool isWaving;

  const CutePenguin({
    super.key,
    this.size = 200,
    this.isWaving = true,
  });

  @override
  State<CutePenguin> createState() => _CutePenguinState();
}

class _CutePenguinState extends State<CutePenguin>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _blinkController;
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();

    // Animasi melambaikan tangan/sayap
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Animasi kedipan mata berkala
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Animasi bernafas / membal halus (bouncing)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _blinkController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _waveController,
        _blinkController,
        _breatheController,
      ]),
      builder: (context, child) {
        // Hitung kedipan (hanya berkedip sebentar di ujung siklus)
        double blinkVal = 0.0;
        final blinkProgress = _blinkController.value;
        if (blinkProgress > 0.92) {
          blinkVal = math.sin((blinkProgress - 0.92) / 0.08 * math.pi);
        }

        final waveVal = math.sin(_waveController.value * math.pi);
        final breatheVal = math.sin(_breatheController.value * math.pi);

        return CustomPaint(
          size: Size(widget.size, widget.size * 1.1),
          painter: _CutePenguinPainter(
            waveProgress: waveVal,
            blinkProgress: blinkVal,
            breatheProgress: breatheVal,
          ),
        );
      },
    );
  }
}

class _CutePenguinPainter extends CustomPainter {
  final double waveProgress;
  final double blinkProgress;
  final double breatheProgress;

  _CutePenguinPainter({
    required this.waveProgress,
    required this.blinkProgress,
    required this.breatheProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.55);

    // Subtle breath offset
    final bounceY = breatheProgress * 4.0;

    // 1. Bayangan Lembut di Bawah Penguin
    final shadowPaint = Paint()
      ..color = const Color(0xFFD84A75).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, h * 0.96),
        width: w * 0.72 - (breatheProgress * 6),
        height: 16 + (breatheProgress * 2),
      ),
      shadowPaint,
    );

    // 2. Kaki Oranye Lucu
    final feetPaint = Paint()
      ..color = const Color(0xFFFF9E43)
      ..style = PaintingStyle.fill;
    final feetShadowPaint = Paint()
      ..color = const Color(0xFFE87E23)
      ..style = PaintingStyle.fill;

    // Kaki kiri
    canvas.save();
    canvas.translate(w * 0.36, h * 0.91 + bounceY);
    canvas.rotate(-0.15);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.22, height: h * 0.1),
      feetShadowPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: w * 0.2, height: h * 0.09),
      feetPaint,
    );
    canvas.restore();

    // Kaki kanan
    canvas.save();
    canvas.translate(w * 0.64, h * 0.91 + bounceY);
    canvas.rotate(0.15);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.22, height: h * 0.1),
      feetShadowPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: w * 0.2, height: h * 0.09),
      feetPaint,
    );
    canvas.restore();

    // 3. Sayap Kiri (diam santai atau bergoyang lembut)
    final bodyDarkPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2B2D42), Color(0xFF1D1E2C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.save();
    final leftWingAngle = 0.25 - (breatheProgress * 0.05);
    canvas.translate(w * 0.18, h * 0.55 + bounceY);
    canvas.rotate(leftWingAngle);
    final leftWingPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-w * 0.18, h * 0.12, -w * 0.05, h * 0.26)
      ..quadraticBezierTo(w * 0.08, h * 0.15, 0, 0);
    canvas.drawPath(leftWingPath, bodyDarkPaint);
    canvas.restore();

    // 4. Badan Utama Penguin (Bentuk Bulat Menggemaskan)
    final bodyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + bounceY - 6),
      width: w * 0.76,
      height: h * 0.76,
    );

    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(w * 0.38),
      topRight: Radius.circular(w * 0.38),
      bottomLeft: Radius.circular(w * 0.34),
      bottomRight: Radius.circular(w * 0.34),
    );
    canvas.drawRRect(bodyRRect, bodyDarkPaint);

    // 5. Perut Putih Lembut Berbentuk Hati / Oval Bulat
    final bellyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF2F5F8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bodyRect);

    final bellyPath = Path();
    final bellyTop = h * 0.32 + bounceY;
    final bellyBottom = h * 0.88 + bounceY;
    final bellyLeft = w * 0.22;
    final bellyRight = w * 0.78;

    bellyPath.moveTo(w * 0.5, bellyTop);
    bellyPath.cubicTo(
      bellyLeft - 4,
      bellyTop + h * 0.08,
      bellyLeft + 2,
      bellyBottom - h * 0.05,
      w * 0.5,
      bellyBottom,
    );
    bellyPath.cubicTo(
      bellyRight - 2,
      bellyBottom - h * 0.05,
      bellyRight + 4,
      bellyTop + h * 0.08,
      w * 0.5,
      bellyTop,
    );
    canvas.drawPath(bellyPath, bellyPaint);

    // 6. Sayap Kanan (Melambai ramah "Halo!")
    canvas.save();
    // Wave angle berkisar antara -0.8 s.d. -0.2 radian (melambai riang ke atas)
    final waveAngle = -0.55 - (waveProgress * 0.45);
    canvas.translate(w * 0.82, h * 0.52 + bounceY);
    canvas.rotate(waveAngle);

    final rightWingPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w * 0.18, -h * 0.06, w * 0.16, h * 0.2)
      ..quadraticBezierTo(w * 0.02, h * 0.12, 0, 0);
    canvas.drawPath(rightWingPath, bodyDarkPaint);
    canvas.restore();

    // 7. Pipi Merona Pink (Rosy Blush)
    final blushPaint = Paint()
      ..color = const Color(0xFFFF7096).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.31, h * 0.49 + bounceY),
        width: w * 0.13,
        height: h * 0.07,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.69, h * 0.49 + bounceY),
        width: w * 0.13,
        height: h * 0.07,
      ),
      blushPaint,
    );

    // 8. Mata Bulat Berbinar & Berkedip
    final eyeY = h * 0.42 + bounceY;
    final eyeRadius = w * 0.075;

    if (blinkProgress > 0.4) {
      // Mata Terpejam Senyum Melengkung (^ ^)
      final happyEyePaint = Paint()
        ..color = const Color(0xFF1D1E2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final leftHappyEye = Path()
        ..moveTo(w * 0.32, eyeY + 2)
        ..quadraticBezierTo(w * 0.38, eyeY - 8, w * 0.44, eyeY + 2);
      canvas.drawPath(leftHappyEye, happyEyePaint);

      final rightHappyEye = Path()
        ..moveTo(w * 0.56, eyeY + 2)
        ..quadraticBezierTo(w * 0.62, eyeY - 8, w * 0.68, eyeY + 2);
      canvas.drawPath(rightHappyEye, happyEyePaint);
    } else {
      // Mata Terbuka Bulat Berbinar
      final eyePaint = Paint()..color = const Color(0xFF1D1E2C);
      final shinePaint = Paint()..color = Colors.white;

      // Mata Kiri
      final leftEyeCenter = Offset(w * 0.38, eyeY);
      canvas.drawCircle(leftEyeCenter, eyeRadius, eyePaint);
      // Kilau besar mata kiri
      canvas.drawCircle(
        Offset(leftEyeCenter.dx - 2.5, leftEyeCenter.dy - 3),
        eyeRadius * 0.42,
        shinePaint,
      );
      // Kilau kecil mata kiri
      canvas.drawCircle(
        Offset(leftEyeCenter.dx + 3, leftEyeCenter.dy + 3),
        eyeRadius * 0.2,
        shinePaint,
      );

      // Mata Kanan
      final rightEyeCenter = Offset(w * 0.62, eyeY);
      canvas.drawCircle(rightEyeCenter, eyeRadius, eyePaint);
      // Kilau besar mata kanan
      canvas.drawCircle(
        Offset(rightEyeCenter.dx - 2.5, rightEyeCenter.dy - 3),
        eyeRadius * 0.42,
        shinePaint,
      );
      // Kilau kecil mata kanan
      canvas.drawCircle(
        Offset(rightEyeCenter.dx + 3, rightEyeCenter.dy + 3),
        eyeRadius * 0.2,
        shinePaint,
      );
    }

    // 9. Paruh Oranye Menggemaskan
    final beakPaint = Paint()..color = const Color(0xFFFF9E43);
    final beakShadow = Paint()..color = const Color(0xFFE87E23);

    final beakPath = Path()
      ..moveTo(w * 0.42, h * 0.47 + bounceY)
      ..quadraticBezierTo(w * 0.5, h * 0.45 + bounceY, w * 0.58, h * 0.47 + bounceY)
      ..quadraticBezierTo(w * 0.5, h * 0.56 + bounceY, w * 0.42, h * 0.47 + bounceY);

    canvas.drawPath(beakPath, beakShadow);
    final beakTopPath = Path()
      ..moveTo(w * 0.43, h * 0.47 + bounceY)
      ..quadraticBezierTo(w * 0.5, h * 0.45 + bounceY, w * 0.57, h * 0.47 + bounceY)
      ..quadraticBezierTo(w * 0.5, h * 0.54 + bounceY, w * 0.43, h * 0.47 + bounceY);
    canvas.drawPath(beakTopPath, beakPaint);

    // 10. Pita / Aksesori Cantik Warna Rose Pink (Sesuai Brand Tema App)
    final ribbonPaint = Paint()..color = const Color(0xFFD84A75);
    final ribbonKnotPaint = Paint()..color = const Color(0xFFB52E55);

    final bowCenter = Offset(w * 0.5, h * 0.63 + bounceY);
    // Sayap pita kiri
    final leftBow = Path()
      ..moveTo(bowCenter.dx, bowCenter.dy)
      ..quadraticBezierTo(bowCenter.dx - 18, bowCenter.dy - 12, bowCenter.dx - 20, bowCenter.dy)
      ..quadraticBezierTo(bowCenter.dx - 18, bowCenter.dy + 12, bowCenter.dx, bowCenter.dy);
    canvas.drawPath(leftBow, ribbonPaint);

    // Sayap pita kanan
    final rightBow = Path()
      ..moveTo(bowCenter.dx, bowCenter.dy)
      ..quadraticBezierTo(bowCenter.dx + 18, bowCenter.dy - 12, bowCenter.dx + 20, bowCenter.dy)
      ..quadraticBezierTo(bowCenter.dx + 18, bowCenter.dy + 12, bowCenter.dx, bowCenter.dy);
    canvas.drawPath(rightBow, ribbonPaint);

    // Simpul tengah pita
    canvas.drawCircle(bowCenter, 5.5, ribbonKnotPaint);
  }

  @override
  bool shouldRepaint(covariant _CutePenguinPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.blinkProgress != blinkProgress ||
        oldDelegate.breatheProgress != breatheProgress;
  }
}
