import 'package:flutter/material.dart';

class BottomButtonsWidget extends StatelessWidget {
  const BottomButtonsWidget({super.key});

  Widget buildButton({
    required String title,
    required IconData icon,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC121A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.30),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        buildButton(
          title: 'Moje zadania',
          icon: Icons.list_alt_rounded,
          borderColor: const Color(0xFF7A5CFF),
        ),
        buildButton(
          title: 'Dodane',
          icon: Icons.add_circle_outline_rounded,
          borderColor: const Color(0xFF00D0FF),
        ),
      ],
    );
  }
}