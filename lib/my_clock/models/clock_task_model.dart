import 'package:flutter/material.dart';

class ClockTaskModel {
  final int number;
  final String title;
  final String time;
  final String day;
  final IconData icon;
  final Color color;
  final String? imagePath;

  const ClockTaskModel({
    required this.number,
    required this.title,
    required this.time,
    this.day = '',
    required this.icon,
    required this.color,
    this.imagePath,
  });
}
