import 'package:flutter/material.dart';

class TopBarWidget extends StatelessWidget {
  const TopBarWidget({super.key});

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
          Container(
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

          // DZIEŃ / TYDZIEŃ
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0x221F2A44),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF6A5CFF),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // DZIEŃ
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7A5CFF),
                        Color(0xFFB44CFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Dzień',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // TYDZIEŃ
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33141A2E),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Tydzień',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
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