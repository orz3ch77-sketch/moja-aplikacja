import 'dart:convert';

import 'package:flutter/services.dart';

import 'clock_level_metadata.dart';

class ClockProtocolLoader {
  static const String _folder = 'assets/clock_protocols';
  static Future<Set<String>>? _assetPaths;

  static String protocolAssetPathForImagePath(String imagePath) {
    final base = clockLevelBaseFromImagePath(imagePath);

    return '$_folder/${base}_k.json';
  }

  static Future<bool> hasProtocolForImagePath(String imagePath) async {
    final paths = await _loadAssetPaths();
    return paths.contains(protocolAssetPathForImagePath(imagePath));
  }

  static Future<int?> dayLimitForImagePath(String imagePath) async {
    final protocolLimit = await _dayLimitFromProtocol(imagePath);
    if (protocolLimit != null) {
      return protocolLimit;
    }

    return _dayLimitFromData(imagePath);
  }

  static Future<List<Map<String, dynamic>>> loadTasksForImagePath(
    String imagePath,
  ) async {
    final assetPath = protocolAssetPathForImagePath(imagePath);
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Plik kuracji musi zawierać obiekt JSON.');
    }

    final tasks = decoded['tasks'];
    if (tasks is! List) {
      throw const FormatException('Plik kuracji musi zawierać listę "tasks".');
    }

    return [
      for (final rawTask in tasks)
        if (rawTask is Map)
          _taskFromJson(
            Map<String, dynamic>.from(rawTask),
            source: assetPath,
          ),
    ];
  }

  static Future<Set<String>> _loadAssetPaths() {
    return _assetPaths ??= _readAssetPaths();
  }

  static Future<Set<String>> _readAssetPaths() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().toSet();
  }

  static Future<int?> _dayLimitFromProtocol(String imagePath) async {
    final paths = await _loadAssetPaths();
    final assetPath = protocolAssetPathForImagePath(imagePath);
    if (!paths.contains(assetPath)) {
      return null;
    }

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final directLimit = _firstPositiveInt(decoded, const [
        'clock_days',
        'clockDays',
        'days',
        'durationDays',
        'dayLimit',
      ]);
      if (directLimit != null) {
        return directLimit;
      }

      final tasks = decoded['tasks'];
      if (tasks is! List) {
        return null;
      }

      var maxDay = 0;
      for (final task in tasks) {
        if (task is! Map) {
          continue;
        }
        final dayTo = _positiveInt(task['dayTo']);
        if (dayTo != null && dayTo > maxDay) {
          maxDay = dayTo;
        }
      }

      return maxDay > 0 ? maxDay : null;
    } on Object {
      return null;
    }
  }

  static Future<int?> _dayLimitFromData(String imagePath) async {
    final base = clockLevelBaseFromImagePath(imagePath);
    if (base.isEmpty) {
      return null;
    }

    final assetPath = 'assets/data/$base.json';
    final paths = await _loadAssetPaths();
    if (!paths.contains(assetPath)) {
      return null;
    }

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return _firstPositiveInt(decoded, const [
        'clock_days',
        'clockDays',
        'days',
        'durationDays',
        'dayLimit',
      ]);
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> _taskFromJson(
    Map<String, dynamic> json, {
    required String source,
  }) {
    final time = (json['time'] as String? ?? '').trim();
    final title = (json['title'] as String? ?? '').trim();
    final amount = (json['amount'] as String? ?? '').trim();
    final details = (json['details'] as String? ?? '').trim();
    final day = (json['day'] as String? ?? 'Codziennie').trim();
    final weekdays = json['weekdays'];
    final dayFrom = _positiveInt(json['dayFrom']);
    final dayTo = _positiveInt(json['dayTo']);

    return {
      'title': title.isEmpty ? 'Etap kuracji' : title,
      'day': day.isEmpty ? 'Codziennie' : day,
      'time': RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time) ? time : '08:00',
      if (amount.isNotEmpty) 'amount': amount,
      'details': details,
      'source': source,
      if (weekdays is List) 'weekdays': weekdays,
      if (dayFrom != null) 'dayFrom': dayFrom,
      if (dayTo != null) 'dayTo': dayTo,
    };
  }

  static int? _firstPositiveInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = _positiveInt(json[key]);
      if (value != null) {
        return value;
      }
    }

    return null;
  }

  static int? _positiveInt(Object? value) {
    final parsed = int.tryParse('$value');
    if (parsed == null || parsed < 1) {
      return null;
    }

    return parsed;
  }
}
