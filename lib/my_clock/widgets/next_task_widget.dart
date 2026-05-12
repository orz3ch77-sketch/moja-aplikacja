import 'package:flutter/material.dart';

class NextTaskWidget extends StatelessWidget {
  const NextTaskWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xCC121A2E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF7A5CFF),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x337A5CFF),
            blurRadius: 25,
          ),
        ],
      ),
      child: Row(
        children: [
          // IKONA
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7A5CFF),
                  Color(0xFFB44CFF),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55B44CFF),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(width: 18),

          // TEKST
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Następne zadanie',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Spacer za 25 min',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // STRZAŁKA
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x221F2A44),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}