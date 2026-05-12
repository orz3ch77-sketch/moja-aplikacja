import 'package:flutter/material.dart';

class OrbitTasksWidget extends StatelessWidget {
  const OrbitTasksWidget({super.key});

  Widget buildTask({
    required String time,
    required String title,
    required IconData icon,
    required Color color,
    required double top,
    required double left,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xCC121A2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      height: 500,
      child: Stack(
        children: [
          // GÓRA
          buildTask(
            time: '07:00',
            title: 'Woda',
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF00D0FF),
            top: 20,
            left: 185,
          ),

          // PRAWO
          buildTask(
            time: '08:00',
            title: 'Spacer',
            icon: Icons.directions_walk_rounded,
            color: const Color(0xFF7CFF6B),
            top: 185,
            left: 360,
          ),

          // DÓŁ
          buildTask(
            time: '12:00',
            title: 'Obiad',
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFFFB84D),
            top: 380,
            left: 180,
          ),

          // LEWO
          buildTask(
            time: '20:00',
            title: 'Medytacja',
            icon: Icons.self_improvement_rounded,
            color: const Color(0xFFB44CFF),
            top: 190,
            left: 10,
          ),
        ],
      ),
    );
  }
}