import 'package:flutter/material.dart';

class TopBarWidget extends StatelessWidget {
  const TopBarWidget({
    super.key,
    this.onCalendar,
  });

  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // POWRÓT
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0x221F2A44),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF5F6BFF),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x335F6BFF),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF7A5CFF),
                    Color(0xFFB44CFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF6A5CFF),
                  width: 1,
                ),
              ),
              child: const Text(
                'Kalendarz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          // USTAWIENIA
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0x221F2A44),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFB44CFF),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33B44CFF),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
