import '../models/clock_task_model.dart';

class NextTaskService {
  static ClockTaskModel? getNextTask(
    List<ClockTaskModel> tasks, {
    DateTime? now,
  }) {
    if (tasks.isEmpty) {
      return null;
    }

    final current = now ?? DateTime.now();
    final nowMinutes = current.hour * 60 + current.minute;
    final ordered = [...tasks]..sort((a, b) {
        return _minutes(a.time).compareTo(_minutes(b.time));
      });

    for (final task in ordered) {
      if (_minutes(task.time) >= nowMinutes) {
        return task;
      }
    }

    return ordered.first;
  }

  static int _minutes(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }
}
