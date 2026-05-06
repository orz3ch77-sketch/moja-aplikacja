import 'dart:io';

void main() {
  final dir = Directory('assets');

  final files = dir
      .listSync()
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/'))
      .where((f) => f.endsWith('.png'))
      .toList();

  files.sort();

  final buffer = StringBuffer();

  buffer.writeln('const assetList = [');

  for (var f in files) {
    buffer.writeln("  '$f',");
  }

  buffer.writeln('];');

  File('./lib/assets_list.dart').writeAsStringSync(buffer.toString());

  // print('✔ Wygenerowano lib/assets_list.dart');
}