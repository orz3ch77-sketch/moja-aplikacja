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

    return {
      'title': title.isEmpty ? 'Etap kuracji' : title,
      'day': day.isEmpty ? 'Codziennie' : day,
      'time': RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time) ? time : '08:00',
      if (amount.isNotEmpty) 'amount': amount,
      'details': details,
      'source': source,
      if (weekdays is List) 'weekdays': weekdays,
    };
  }
}
