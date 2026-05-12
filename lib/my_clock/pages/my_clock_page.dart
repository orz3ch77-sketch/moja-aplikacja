import 'package:flutter/material.dart';

import '../widgets/top_bar_widget.dart';
import '../widgets/analog_clock_widget.dart';
import '../widgets/orbit_tasks_widget.dart';
import '../widgets/next_task_widget.dart';
import '../widgets/bottom_buttons_widget.dart';

class MyClockPage extends StatelessWidget {
  const MyClockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050816),
              Color(0xFF02030A),
              Color(0xFF090022),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // TOP BAR
              const TopBarWidget(),

              // DATA
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: const [
                    Text(
                      'ŚRODA',
                      style: TextStyle(
                        color: Color(0xFFB44CFF),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '21 maja 2025',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ZEGAR + ORBIT
              SizedBox(
  height: 540,
  child: Stack(
    alignment: Alignment.center,
    children: const [
      OrbitTasksWidget(),
      AnalogClockWidget(),
    ],
  ),
),

              // NASTĘPNE ZADANIE
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: NextTaskWidget(),
              ),

              const SizedBox(height: 24),

              // DOLNE PRZYCISKI
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: BottomButtonsWidget(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}