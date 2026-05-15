import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnalogClockWidget extends StatelessWidget {
  const AnalogClockWidget({
    super.key,
    required this.now,
  });

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101935),
            Color(0xFF060B18),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFB44CFF),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55B44CFF),
            blurRadius: 35,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // WEWNĘTRZNE KOŁO
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0x336A5CFF),
                width: 2,
              ),
            ),
          ),

          // CYFRY
          ...List.generate(
            12,
            (index) {
              final angle = (index * 30 - 90) * math.pi / 180;

              final radius = 140.0;

              final x = radius * math.cos(angle);
              final y = radius * math.sin(angle);

              return Positioned(
                left: 170 + x - 10,
                top: 170 + y - 10,
                child: Text(
                  '${index == 0 ? 12 : index}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),

          CustomPaint(
            size: const Size.square(340),
            painter: _ClockHandsPainter(now: now),
          ),

          // ŚRODEK
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x88FFFFFF),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockHandsPainter extends CustomPainter {
  const _ClockHandsPainter({required this.now});

  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final hourAngle =
        (((now.hour % 12) + now.minute / 60) / 12 * math.pi * 2) - math.pi / 2;
    final minuteAngle =
        ((now.minute + now.second / 60) / 60 * math.pi * 2) - math.pi / 2;
    final secondAngle = (now.second / 60 * math.pi * 2) - math.pi / 2;

    _drawHand(canvas, center, hourAngle, 82, 7, Colors.white);
    _drawHand(canvas, center, minuteAngle, 118, 5, const Color(0xFFB44CFF));
    _drawHand(canvas, center, secondAngle, 126, 2.5, const Color(0xFFFF4D5E));
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    final end = Offset(
      center.dx + math.cos(angle) * length,
      center.dy + math.sin(angle) * length,
    );

    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ClockHandsPainter oldDelegate) {
    return oldDelegate.now != now;
  }
}
