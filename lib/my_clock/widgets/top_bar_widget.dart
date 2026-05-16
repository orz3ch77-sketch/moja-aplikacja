import 'package:flutter/material.dart';

class TopBarWidget extends StatelessWidget {
  const TopBarWidget({
    super.key,
    required this.weekView,
    required this.onWeekViewChanged,
  });

  final bool weekView;
  final ValueChanged<bool> onWeekViewChanged;

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
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onWeekViewChanged(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: weekView
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF7A5CFF),
                                Color(0xFFB44CFF),
                              ],
                            ),
                      color: weekView ? const Color(0x33141A2E) : null,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Dzień',
                      style: TextStyle(
                        color: weekView ? Colors.white70 : Colors.white,
                        fontWeight:
                            weekView ? FontWeight.w600 : FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // TYDZIEŃ
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onWeekViewChanged(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: weekView
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF7A5CFF),
                                Color(0xFFB44CFF),
                              ],
                            )
                          : null,
                      color: weekView ? null : const Color(0x33141A2E),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Tydzień',
                      style: TextStyle(
                        color: weekView ? Colors.white : Colors.white70,
                        fontWeight:
                            weekView ? FontWeight.bold : FontWeight.w600,
                        fontSize: 16,
                      ),
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
