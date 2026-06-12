import 'package:flutter/material.dart';

class ClockTaskModel {
  final String id;
  final int number;
  final String title;
  final String time;
  final String day;
  final IconData icon;
  final Color color;
  final String? imagePath;
  final String? details;

  const ClockTaskModel({
    this.id = '',
    required this.number,
    required this.title,
    required this.time,
    this.day = '',
    required this.icon,
    required this.color,
    this.imagePath,
    this.details,
  });
}
