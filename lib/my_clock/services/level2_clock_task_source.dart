import 'package:flutter/material.dart';

import '../models/clock_task_model.dart';

class Level2ClockTaskSource {
  const Level2ClockTaskSource();

  List<ClockTaskModel> fromTodoLinks(List<dynamic> values) {
    final tasks = <ClockTaskModel>[];

    for (var index = 0; index < values.length; index++) {
      final raw = values[index];
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);
      final imagePath = (item['imagePath'] as String?) ?? '';
      if (imagePath.trim().toLowerCase().endsWith('.json')) {
        continue;
      }

      tasks.add(
        ClockTaskModel(
          number: index + 1,
          title: _titleFromPath(imagePath),
          time: _timeForIndex(index),
          day: 'Dodane',
          icon: _iconForIndex(index),
          color: _colorForIndex(index),
          imagePath: imagePath,
        ),
      );
    }

    return tasks;
  }

  String _titleFromPath(String path) {
    final fileName = path.replaceAll('\\', '/').split('/').last;
    final withoutExtension = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final withoutPrefix =
        withoutExtension.replaceFirst(RegExp(r'^img\d+_?'), '');
    final normalized = withoutPrefix.replaceAll('_', ' ').trim();

    if (normalized.isEmpty) {
      return withoutExtension;
    }

    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _timeForIndex(int index) {
    final hour = (7 + index * 2).clamp(7, 21);
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  IconData _iconForIndex(int index) {
    const icons = <IconData>[
      Icons.water_drop_rounded,
      Icons.directions_walk_rounded,
      Icons.wb_sunny_rounded,
      Icons.restaurant_rounded,
      Icons.menu_book_rounded,
      Icons.fitness_center_rounded,
      Icons.local_cafe_rounded,
      Icons.self_improvement_rounded,
      Icons.auto_stories_rounded,
    ];

    return icons[index % icons.length];
  }

  Color _colorForIndex(int index) {
    const colors = <Color>[
      Color(0xFF00D0FF),
      Color(0xFF7CFF6B),
      Color(0xFFFFF06A),
      Color(0xFFFFB84D),
      Color(0xFFFF7A30),
      Color(0xFFFF4D5E),
      Color(0xFFFF4FD8),
      Color(0xFFB44CFF),
      Color(0xFF4DA3FF),
    ];

    return colors[index % colors.length];
  }
}
