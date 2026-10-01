import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _waddleController;
  late AnimationController _bubbleController;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _bubbleScaleAnimation;
  late Animation<double> _bubbleFadeAnimation;

  Timer? _navigationTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // 1. Animasi Masuk (Scale Bounce)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    // 2. Animasi Penguin Berjalan / Goyang Lucu (Waddling & Bouncing)
    _waddleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // 3. Animasi Balon Ucapan "Welcome Naila"
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _bubbleScaleAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.elasticOut,
    );

    _bubbleFadeAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeIn,
    );

    // 4. Glow Pulsing Halo di Belakang Penguin
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 5. Floating Sparkles & Hearts Controller
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _startSequence();
  }

  void _startSequence() {
    _entranceController.forward().then((_) {
      if (mounted) {
        _bubbleController.forward();
      }
    });

    // Otomatis berpindah ke HomeScreen setelah 3.5 detik
    _navigationTimer = Timer(const Duration(milliseconds: 3500), () {
      _goToHomeScreen();
    });
  }

  void _goToHomeScreen() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _navigationTimer?.cancel();

    HapticFeedback.lightImpact();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnim = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          final scaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: fadeAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _waddleController.dispose();
    _bubbleController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToHomeScreen,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFF4F8),
                Color(0xFFFFE3ED),
                Color(0xFFFFCCD8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Floating Sparkles & Hearts
              AnimatedBuilder(
                animation: _sparkleController,
                builder: (context, child) {
                  return CustomPaint(
                    size: size,
                    painter: _FloatingSparklesPainter(
                      progress: _sparkleController.value,
                    ),
                  );
                },
              ),

              // 2. Lingkaran Cahaya Lembut di Belakang Penguin
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow = _pulseController.value;
                  return Container(
                    width: 270 + (glow * 25),
                    height: 270 + (glow * 25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.55),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPink.withValues(
                            alpha: 0.14 + (glow * 0.08),
                          ),
                          blurRadius: 40 + (glow * 15),
                          spreadRadius: 10 + (glow * 10),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 3. Konten Utama (Balon "Welcome Naila" + Penguin Lucu)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Balon Ucapan: Welcome Naila
                      FadeTransition(
                        opacity: _bubbleFadeAnimation,
                        child: ScaleTransition(
                          scale: _bubbleScaleAnimation,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildWelcomeBubble(),
                              // Ekor balon
                              CustomPaint(
                                size: const Size(20, 12),
                                painter: _SpeechTailPainter(
                                  color: Colors.white,
                                  borderColor: const Color(0xFFFFD1DC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Karakter Penguin yang Menggemaskan (Sesuai Desain yang Dilampirkan)
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: AnimatedBuilder(
                          animation: _waddleController,
                          builder: (context, child) {
                            // Gerakan waddle: goyang kiri-kanan & membal naik-turun
                            final t = _waddleController.value;
                            final angle = (math.sin(t * math.pi) - 0.5) * 0.12;
                            final bounceY = math.sin(t * math.pi) * 8.0;

                            return Transform.translate(
                              offset: Offset(0, -bounceY),
                              child: Transform.rotate(
                                angle: angle,
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryPink.withValues(alpha: 0.15),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(110),
                                    child: Image.asset(
                                      'assets/images/penguin_naila.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Indikator Loading Cantik
                      _buildBottomIndicator(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Tombol Lewati di Kanan Atas
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                right: 20,
                child: TextButton(
                  onPressed: _goToHomeScreen,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFFFFD1DC),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Lewati',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPink,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppTheme.primaryPink,
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

  Widget _buildWelcomeBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD1DC), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨', style: TextStyle(fontSize: 18)),
              SizedBox(width: 6),
              Text(
                'Welcome Naila',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryPink,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(width: 6),
              Text('💖', style: TextStyle(fontSize: 18)),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Have a nice day! 🌸',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMedium,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryPink.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Membuka Katalog...',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPinkDark,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Ketuk di mana saja untuk melanjutkan',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: AppTheme.textLight.withValues(alpha: 0.9),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _SpeechTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingSparklesPainter extends CustomPainter {
  final double progress;

  _FloatingSparklesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final elements = [
      _Sparkle(x: 0.12, y: 0.22, size: 14, speed: 1.0, isHeart: true),
      _Sparkle(x: 0.86, y: 0.18, size: 18, speed: 0.8, isHeart: true),
      _Sparkle(x: 0.15, y: 0.72, size: 16, speed: 1.2, isHeart: true),
      _Sparkle(x: 0.84, y: 0.68, size: 14, speed: 0.9, isHeart: true),
      _Sparkle(x: 0.26, y: 0.15, size: 8, speed: 1.4, isHeart: false),
      _Sparkle(x: 0.74, y: 0.28, size: 10, speed: 1.1, isHeart: false),
      _Sparkle(x: 0.10, y: 0.45, size: 9, speed: 0.7, isHeart: false),
      _Sparkle(x: 0.90, y: 0.48, size: 11, speed: 1.3, isHeart: false),
    ];

    for (final el in elements) {
      final floatY = math.sin((progress * 2 * math.pi * el.speed)) * 12;
      final floatX = math.cos((progress * 2 * math.pi * el.speed)) * 6;
      final offset = Offset(
        el.x * size.width + floatX,
        el.y * size.height + floatY,
      );

      if (el.isHeart) {
        _drawHeart(
          canvas,
          offset,
          el.size,
          const Color(0xFFD84A75).withValues(alpha: 0.32),
        );
      } else {
        _drawStar(
          canvas,
          offset,
          el.size,
          const Color(0xFFFFB3C6).withValues(alpha: 0.6),
        );
      }
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final s = size / 2;
    path.moveTo(center.dx, center.dy + s * 0.5);
    path.cubicTo(
      center.dx - s * 1.2,
      center.dy - s * 0.7,
      center.dx - s * 0.6,
      center.dy - s * 1.5,
      center.dx,
      center.dy - s * 0.5,
    );
    path.cubicTo(
      center.dx + s * 0.6,
      center.dy - s * 1.5,
      center.dx + s * 1.2,
      center.dy - s * 0.7,
      center.dx,
      center.dy + s * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final r = size / 2;
    path.moveTo(center.dx, center.dy - r);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + r, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - r, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FloatingSparklesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Sparkle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final bool isHeart;

  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.isHeart,
  });
}
