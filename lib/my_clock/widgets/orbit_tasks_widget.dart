import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/clock_task_model.dart';

class OrbitTasksWidget extends StatelessWidget {
  const OrbitTasksWidget({
    super.key,
    required this.tasks,
    this.onTaskTap,
  });

  final List<ClockTaskModel> tasks;
  final ValueChanged<ClockTaskModel>? onTaskTap;

  Widget buildTask({
    required ClockTaskModel task,
    required double angle,
  }) {
    const center = 250.0;
    const radius = 214.0;
    const size = 58.0;
    final top = center + math.sin(angle) * radius - size / 2;
    final left = center + math.cos(angle) * radius - size / 2;

    return Positioned(
      top: top,
      left: left,
      width: size,
      height: size,
      child: Tooltip(
        message: '${task.time} ${task.title}',
        child: Semantics(
          label: '${task.time} ${task.title}',
          button: true,
          onTap: onTaskTap == null ? null : () => onTaskTap!(task),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTaskTap == null ? null : () => onTaskTap!(task),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xEE071020),
                  border: Border.all(color: task.color, width: 2.4),
                  boxShadow: [
                    BoxShadow(
                      color: task.color.withValues(alpha: 0.75),
                      blurRadius: 24,
                      spreadRadius: 1.5,
                    ),
                    BoxShadow(
                      color: task.color.withValues(alpha: 0.25),
                      blurRadius: 44,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: task.imagePath == null || task.imagePath!.isEmpty
                      ? _FallbackIcon(task: task)
                      : Image.asset(
                          task.imagePath!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _FallbackIcon(task: task),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _angleForTask(ClockTaskModel task, int fallbackIndex, int taskCount) {
    final parts = task.time.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return (fallbackIndex / taskCount) * math.pi * 2 - math.pi / 2;
    }

    final hourOnDial = hour % 12;
    final minutesOnDial = hourOnDial * 60 + minute;

    return (minutesOnDial / 720) * math.pi * 2 - math.pi / 2;
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(12).toList();
    final taskAngles = [
      for (var index = 0; index < visibleTasks.length; index++)
        _angleForTask(visibleTasks[index], index, visibleTasks.length),
    ];

    return SizedBox(
      width: 500,
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(500),
            painter: _OrbitRingPainter(
              tasks: visibleTasks,
              angles: taskAngles,
            ),
          ),
          for (var index = 0; index < visibleTasks.length; index++)
            buildTask(
              task: visibleTasks[index],
              angle: taskAngles[index],
            ),
        ],
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({
    required this.task,
  });

  final ClockTaskModel task;

  @override
  Widget build(BuildContext context) {
    return Icon(
      task.icon,
      color: task.color,
      size: 31,
      shadows: [
        Shadow(
          color: task.color.withValues(alpha: 0.95),
          blurRadius: 18,
        ),
      ],
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({
    required this.tasks,
    required this.angles,
  });

  final List<ClockTaskModel> tasks;
  final List<double> angles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 214.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x2238D8FF);

    canvas.drawCircle(center, radius, basePaint);

    if (tasks.isEmpty) {
      return;
    }

    for (var index = 0; index < tasks.length; index++) {
      final current = angles[index];
      final next = index == tasks.length - 1
          ? angles.first + math.pi * 2
          : angles[index + 1];
      final sweep = (next - current).clamp(0.25, math.pi * 0.9);
      final start = current + 0.08;
      final color = tasks[index].color;

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13)
        ..color = color.withValues(alpha: 0.32);
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color,
            color.withValues(alpha: 0.45),
          ],
          stops: const [0, 0.55, 1],
          transform: GradientRotation(start),
        ).createShader(rect);

      canvas.drawArc(rect, start, sweep - 0.16, false, glowPaint);
      canvas.drawArc(rect, start, sweep - 0.16, false, linePaint);

      final direction = Offset(math.cos(current), math.sin(current));
      final dotCenter = center + direction * 176;
      final lineStart = center + direction * 188;
      final lineEnd = center + direction * 197;
      final connectorGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: 0.35);
      final connectorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = color;
      final dotGlow = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: 0.45);
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color;

      canvas.drawLine(lineStart, lineEnd, connectorGlow);
      canvas.drawLine(lineStart, lineEnd, connectorPaint);
      canvas.drawCircle(dotCenter, 8, dotGlow);
      canvas.drawCircle(dotCenter, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) {
    return oldDelegate.tasks != tasks || oldDelegate.angles != angles;
  }
}
