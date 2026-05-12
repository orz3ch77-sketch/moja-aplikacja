import 'package:flutter/material.dart';

import '../models/clock_task_model.dart';

const List<ClockTaskModel> mockTasks = [
  ClockTaskModel(
    title: 'Woda',
    time: '07:00',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF00D0FF),
  ),
  ClockTaskModel(
    title: 'Spacer',
    time: '08:00',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF7CFF6B),
  ),
  ClockTaskModel(
    title: 'Obiad',
    time: '12:00',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFFFB84D),
  ),
  ClockTaskModel(
    title: 'Medytacja',
    time: '20:00',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFFB44CFF),
  ),
];