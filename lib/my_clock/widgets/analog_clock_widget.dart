import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnalogClockWidget extends StatelessWidget {
  const AnalogClockWidget({super.key});

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

          // WSKAZÓWKA GODZINOWA
          Positioned(
            top: 110,
            child: Container(
              width: 6,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // WSKAZÓWKA MINUTOWA
          Transform.rotate(
            angle: 0.8,
            child: Container(
              width: 4,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFB44CFF),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // CYFRY
          ...List.generate(
            12,
            (index) {
              final angle =
                  (index * 30 - 90) * math.pi / 180;

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
        ],
      ),
    );
  }
}