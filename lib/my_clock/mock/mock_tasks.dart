import 'package:flutter/material.dart';

import '../models/clock_task_model.dart';

const List<ClockTaskModel> mockTasks = [
  ClockTaskModel(
    number: 1,
    title: 'Woda',
    time: '07:00',
    day: 'Dziś',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF00D0FF),
  ),
  ClockTaskModel(
    number: 2,
    title: 'Spacer',
    time: '08:00',
    day: 'Dziś',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF7CFF6B),
  ),
  ClockTaskModel(
    number: 3,
    title: 'Obiad',
    time: '12:00',
    day: 'Dziś',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFFFB84D),
  ),
  ClockTaskModel(
    number: 4,
    title: 'Medytacja',
    time: '20:00',
    day: 'Dziś',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFFB44CFF),
  ),
];
