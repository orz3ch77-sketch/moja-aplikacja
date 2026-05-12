import 'package:flutter/material.dart';

class ClockTaskModel {
  final String title;
  final String time;
  final IconData icon;
  final Color color;

  const ClockTaskModel({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });
}