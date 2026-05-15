import 'package:flutter/material.dart';

class BottomButtonsWidget extends StatelessWidget {
  const BottomButtonsWidget({
    super.key,
    required this.onMyTasks,
    required this.onAdded,
  });

  final VoidCallback onMyTasks;
  final VoidCallback onAdded;

  Widget buildButton({
    required String title,
    required IconData icon,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
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
                color: borderColor.withValues(alpha: 0.30),
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        buildButton(
          title: 'Moje zadania',
          icon: Icons.list_alt_rounded,
          borderColor: const Color(0xFF7A5CFF),
          onTap: onMyTasks,
        ),
        buildButton(
          title: '+ Dodane',
          icon: Icons.add_circle_outline_rounded,
          borderColor: const Color(0xFF00D0FF),
          onTap: onAdded,
        ),
      ],
    );
  }
}
