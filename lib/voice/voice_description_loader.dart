import 'dart:convert';

import 'package:flutter/services.dart';

class VoiceDescription {
  const VoiceDescription({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;
}

class VoiceDescriptionLoader {
  static const String _folder = 'assets/voice_descriptions';
  static Future<Set<String>>? _assetPaths;

  static String voiceAssetPathForGalleryImage(String galleryImage) {
    final fileName = galleryImage.replaceAll('\\', '/').split('/').last;
    final base = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final voiceBase = base.replaceFirstMapped(
      RegExp(r'_g(\d+)$'),
      (match) => '_w${match.group(1)}',
    );

    return '$_folder/$voiceBase.json';
  }

  static Future<bool> hasDescriptionForGalleryImage(String galleryImage) async {
    final paths = await _loadAssetPaths();
    final assetPath = voiceAssetPathForGalleryImage(galleryImage);
    if (!paths.contains(assetPath)) {
      return false;
    }

    try {
      final description = await loadForGalleryImage(galleryImage);
      return description.text.trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  static Future<VoiceDescription> loadForGalleryImage(
    String galleryImage,
  ) async {
    final assetPath = voiceAssetPathForGalleryImage(galleryImage);
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Plik opisu głosowego musi być obiektem JSON.');
    }

    final title = (decoded['title'] as String? ?? 'Opis głosowy').trim();
    final text = (decoded['text'] as String? ?? '').trim();

    if (text.isEmpty) {
      throw const FormatException('Plik opisu głosowego ma puste pole "text".');
    }

    return VoiceDescription(
      title: title.isEmpty ? 'Opis głosowy' : title,
      text: text,
    );
  }

  static Future<Set<String>> _loadAssetPaths() {
    return _assetPaths ??= _readAssetPaths();
  }

  static Future<Set<String>> _readAssetPaths() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().toSet();
  }
}
