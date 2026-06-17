import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// The iconic "A" logo for Vin's Alarm
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 80, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(100),
                blurRadius: size * 0.4,
                spreadRadius: size * 0.05,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _ALogoPainter(),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: Text(
              "Vin's Alarm",
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quick Alarms for BRB & Lunch',
            style: TextStyle(
              fontSize: size * 0.14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _ALogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final double cx = size.width / 2;
    final double top = size.height * 0.12;
    final double bottom = size.height * 0.84;
    final double spread = size.width * 0.30;
    final double crossY = size.height * 0.55;
    final double strokeW = size.width * 0.11;
    final double crossGap = size.width * 0.095;

    paint.strokeWidth = strokeW;
    paint.style = PaintingStyle.stroke;
    paint.strokeJoin = StrokeJoin.round;
    paint.strokeCap = StrokeCap.round;

    final path = Path();
    // Left leg
    path.moveTo(cx - spread, bottom);
    path.lineTo(cx, top);
    // Right leg
    path.lineTo(cx + spread, bottom);

    canvas.drawPath(path, paint);

    // Cross bar
    final crossPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - spread * 0.6 + crossGap, crossY),
      Offset(cx + spread * 0.6 - crossGap, crossY),
      crossPaint,
    );

    // Bell icon at top
    final dotPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(cx, top - size.height * 0.01),
      size.width * 0.07,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small logo variant (icon only)
class AppLogoIcon extends StatelessWidget {
  final double size;

  const AppLogoIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: size * 0.4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: CustomPaint(painter: _ALogoPainter()),
    );
  }
}
