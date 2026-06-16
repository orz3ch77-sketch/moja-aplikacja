import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chakra/chakra_test_page.dart';
import 'friends/friends_page.dart';
import 'my_clock/pages/my_clock_page.dart';
import 'my_clock/services/clock_level_metadata.dart';
import 'shared/confirm_delete_dialog.dart';
import 'voice/voice_description_loader.dart';
import 'voice/voice_speaker.dart';

late List<String> assetList;
late List<String> dataList;
Map<String, String> externalLinks = {};

Future<void> loadAppAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest.listAssets();

  assetList = assets
      .where((e) => e.startsWith('assets/') && e.endsWith('.webp'))
      .toList()
    ..sort(naturalCompare);

  dataList = assets
      .where((e) => e.startsWith('assets/data/') && e.endsWith('.json'))
      .toList()
    ..sort(naturalCompare);

  externalLinks = await loadExternalLinks(assets);
}

int naturalCompare(String a, String b) {
  final reg = RegExp(r'\d+|\D+');
  final aa = reg.allMatches(a).map((m) => m.group(0)!).toList();
  final bb = reg.allMatches(b).map((m) => m.group(0)!).toList();

  for (var i = 0; i < aa.length && i < bb.length; i++) {
    final an = int.tryParse(aa[i]);
    final bn = int.tryParse(bb[i]);

    final result =
        an != null && bn != null ? an.compareTo(bn) : aa[i].compareTo(bb[i]);

    if (result != 0) return result;
  }

  return aa.length.compareTo(bb.length);
}

String assetBaseName(String assetPath) {
  return assetPath.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '');
}

String levelHierarchyBaseFor(String base) {
  if (isExternalInternetLinkBase(base)) {
    return base.replaceFirst(RegExp(r'_o\d+$'), '');
  }

  return base;
}

bool isExternalInternetLinkBase(String base) {
  return RegExp(r'^img[\d_]+_o\d+$').hasMatch(base);
}

String? externalInternetLinkFor(String base) {
  final link = externalLinks[base]?.trim();

  if (link == null || link.isEmpty) {
    return null;
  }

  return link;
}

Future<Map<String, String>> loadExternalLinks(List<String> assets) async {
  final linkFiles = assets
      .where(
        (asset) =>
            asset.startsWith('assets/external_links/') &&
            asset.endsWith('.json'),
      )
      .toList()
    ..sort(naturalCompare);

  final links = <String, String>{};

  for (final file in linkFiles) {
    final text = await rootBundle.loadString(file);
    final jsonMap = json.decode(text) as Map<String, dynamic>;
    final fileBase = assetBaseName(file);

    if (jsonMap['url'] != null) {
      links[fileBase] = '${jsonMap['url']}'.trim();
    }

    for (final entry in jsonMap.entries) {
      if (entry.key.startsWith('img')) {
        links[entry.key] = '${entry.value}'.trim();
      }
    }
  }

  return links;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadAppAssets();
  await loadClockLevelTitles();

  await Hive.initFlutter();
  await Hive.openBox('todo_links');
  await Hive.openBox('time_links');
  await Hive.openBox('favorite_links');
  await Hive.openBox('my_clock_tasks');
  await Hive.openBox('shopping_lists');
  await Hive.openBox('shopping_lists_main');
  await Hive.openBox('friends');
  await Hive.openBox('todo_analysis_archive');
  await Hive.openBox('clock_settings');

  runApp(const MyApp());
}

Route slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final offset = Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(animation);

      return SlideTransition(position: offset, child: child);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final openClockBeforeApp =
        Hive.box('clock_settings').get('openClockBeforeApp') == true;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: openClockBeforeApp
          ? Builder(
              builder: (context) {
                return MyClockPage(
                  onBack: () {
                    Navigator.pushReplacement(
                      context,
                      slideRoute(const CategoryPage()),
                    );
                  },
                );
              },
            )
          : const StartPage(),
    );
  }
}

Widget bg() =>
    Positioned.fill(child: Image.asset('assets/pg.webp', fit: BoxFit.cover));

void showTopMessage(BuildContext context, String message) {
  final media = MediaQuery.of(context);
  final topMargin = media.padding.top + 12;
  final bottomMargin = media.size.height > topMargin + 72
      ? media.size.height - topMargin - 72
      : 16.0;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, topMargin, 16, bottomMargin),
      ),
    );
}

Widget fancyTileFrame(String path) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Colors.white24, Colors.black26],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        const BoxShadow(
          color: Colors.white24,
          offset: Offset(-2, -2),
          blurRadius: 6,
        ),
      ],
      border: Border.all(color: Colors.white70, width: 2),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 150,
        height: 150,
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    ),
  );
}

Widget fancyTile(String path) {
  return Center(child: fancyTileFrame(path));
}

Widget selectableFancyTile({
  required String path,
  required bool selectionMode,
  required bool selected,
}) {
  return Center(
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        fancyTileFrame(path),
        if (selectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? Colors.green : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
}

Widget topBar({
  required BuildContext context,
  VoidCallback? onNext,
  VoidCallback? onPrev,
  VoidCallback? onDelete,
  VoidCallback? onTools,
  VoidCallback? onAnalysis,
  String? counter,
}) {
  return Positioned(
    bottom: 20,
    left: 10,
    right: 10,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                icon: const Icon(Icons.home, color: Colors.white),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    slideRoute(const CategoryPage()),
                    (route) => false,
                  );
                },
              ),
              if (onTools != null)
                IconButton(
                  icon: const Icon(Icons.apps, color: Colors.white),
                  onPressed: onTools,
                ),
            ],
          ),
          if (counter != null)
            Text(
              counter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          Row(
            children: [
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: onDelete,
                ),
              if (onAnalysis != null)
                IconButton(
                  tooltip: 'Analiza',
                  icon: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                  ),
                  onPressed: onAnalysis,
                ),
              if (onPrev != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: onPrev,
                ),
              if (onNext != null)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                  ),
                  onPressed: onNext,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.push(context, slideRoute(const CategoryPage()));
        },
        child: Stack(
          children: [
            bg(),
            Center(child: Image.asset('assets/start.png')),
          ],
        ),
      ),
    );
  }
}

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = assetList
        .where((e) => RegExp(r'^assets/img\d+\.webp$').hasMatch(e))
        .map(assetBaseName)
        .toList()
      ..sort(naturalCompare);

    return Scaffold(
      body: Stack(
        children: [
          bg(),
          GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final base = items[i];

              return GestureDetector(
                onTap: () {
                  Navigator.push(context, slideRoute(LevelPage(base: base)));
                },
                child: fancyTile('assets/$base.webp'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class LevelPage extends StatefulWidget {
  final String base;

  const LevelPage({super.key, required this.base});

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  Set<int> selectedItems = {};
  bool selectionMode = false;

  List<String> directLevelsFor(String base) {
    final baseParts = base.split('_');

    return assetList.where((e) {
      if (!e.startsWith('assets/${base}_')) {
        return false;
      }

      if (e.contains('_g')) {
        return false;
      }

      final name = assetBaseName(e);
      final parts = levelHierarchyBaseFor(name).split('_');

      return parts.length == baseParts.length + 1;
    }).toList()
      ..sort(naturalCompare);
  }

  List<String> galleryFor(String base) {
    return assetList.where((e) => e.startsWith('assets/${base}_g')).toList()
      ..sort(naturalCompare);
  }

  String linksBoxNameFor(String base) {
    if (base == 'img8_2') {
      return 'todo_links';
    }

    if (base == 'img8_3') {
      return 'time_links';
    }

    return 'favorite_links';
  }

  bool get isLinksLevel {
    return widget.base == 'img8_2' || widget.base == 'img8_4';
  }

  Future<void> showSelectMessage(String message) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> showTodoAnalysisDialog(Box box) async {
    if (selectedItems.isEmpty) {
      await showSelectMessage('Zaznacz');
      return;
    }

    final selectedCategoryItems = selectedItems.where((index) {
      if (index < 0 || index >= box.length) {
        return false;
      }

      final item = Map<String, dynamic>.from(box.getAt(index));
      final imagePath = item['imagePath'] as String? ?? '';
      final base = assetBaseName(imagePath);

      return base == 'img1' ||
          base == 'img2' ||
          base.startsWith('img1_') ||
          base.startsWith('img2_');
    }).toList();

    if (selectedCategoryItems.isEmpty) {
      await showSelectMessage('Zaznacz kategorię 1 lub 2');
      return;
    }

    final checked = <String>{};
    final ratings = <String, int>{};
    final customNoteController = TextEditingController();
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    const options = [
      (id: 'energy_up', label: 'Wzrost energii', stars: true),
      (id: 'energy_same', label: 'Bez zmian', stars: false),
      (id: 'energy_down', label: 'Spadek energii', stars: true),
      (id: 'mood_good', label: 'Dobre\nsamopoczucie', stars: true),
      (id: 'mood_same', label: 'Bez zmian', stars: false),
      (id: 'mood_bad', label: 'Złe\nsamopoczucie', stars: true),
    ];

    try {
      await showDialog<void>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Zaznacz'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Data: $dateLabel',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final option in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Checkbox(
                              value: checked.contains(option.id),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    checked.add(option.id);
                                  } else {
                                    checked.remove(option.id);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: _analysisOptionLabel(option.label),
                            ),
                            if (option.stars)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var star = 1; star <= 3; star++)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 22,
                                        minHeight: 28,
                                      ),
                                      icon: Icon(
                                        (ratings[option.id] ?? 0) >= star
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFFFC107),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          checked.add(option.id);
                                          ratings[option.id] = star;
                                        });
                                      },
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customNoteController,
                      minLines: 2,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Własne',
                        hintText: 'Dopisz swoje uwagi',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anuluj'),
                ),
                TextButton(
                  onPressed: () async {
                    final selectedRecords = selectedCategoryItems.map((index) {
                      final item = Map<String, dynamic>.from(box.getAt(index));
                      final imagePath = item['imagePath'] as String? ?? '';
                      final base = assetBaseName(imagePath);

                      return {
                        'index': index,
                        'imagePath': imagePath,
                        'title': base,
                      };
                    }).toList();

                    await Hive.box('todo_analysis_archive').add({
                      'createdAt': now.toIso8601String(),
                      'date': dateLabel,
                      'items': selectedRecords,
                      'customNote': customNoteController.text.trim(),
                      'answers': [
                        for (final option in options)
                          if (checked.contains(option.id))
                            {
                              'id': option.id,
                              'label': option.label,
                              if (option.stars)
                                'stars': ratings[option.id] ?? 0,
                            },
                      ],
                    });

                    if (!context.mounted) {
                      return;
                    }

                    Navigator.pop(context);
                    showTopMessage(context, 'Zapisano analizę');
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      customNoteController.dispose();
    }
  }

  Widget _analysisOptionLabel(String label) {
    final parts = label.split('\n');
    if (parts.length == 2 && parts[1] == 'samopoczucie') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(parts.first),
          const Text(
            'samopoczucie',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(fontSize: 13),
          ),
        ],
      );
    }

    return Text(
      label,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.base == 'img8_3') {
      return const MyClockPage();
    }

    if (isLinksLevel) {
      final box = Hive.box(linksBoxNameFor(widget.base));

      return Scaffold(
        body: Stack(
          children: [
            bg(),
            ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box box, _) {
                final links = box.values.toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: links.length,
                  itemBuilder: (_, i) {
                    final item = Map<String, dynamic>.from(links[i]);
                    final imagePath = item['imagePath'] as String;
                    final galleryImages = List<String>.from(
                      item['galleryImages'],
                    );

                    return GestureDetector(
                      onTap: () {
                        if (selectionMode) {
                          setState(() {
                            if (selectedItems.contains(i)) {
                              selectedItems.remove(i);
                            } else {
                              selectedItems.add(i);
                            }
                          });
                          return;
                        }

                        Navigator.push(
                          context,
                          slideRoute(
                            GalleryPage(
                              images: galleryImages,
                              levelImage: imagePath,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        setState(() {
                          selectionMode = true;
                          selectedItems.add(i);
                        });
                      },
                      child: selectableFancyTile(
                        path: imagePath,
                        selectionMode: selectionMode,
                        selected: selectedItems.contains(i),
                      ),
                    );
                  },
                );
              },
            ),
            topBar(
              context: context,
              onAnalysis: widget.base == 'img8_2'
                  ? () => showTodoAnalysisDialog(box)
                  : null,
              onDelete: () {
                if (selectedItems.isEmpty) {
                  return;
                }

                () async {
                  final confirmed = await confirmDeleteDialog(context);
                  if (!confirmed) {
                    return;
                  }

                  final keys = selectedItems.toList()
                    ..sort((a, b) => b.compareTo(a));

                  for (final index in keys) {
                    await box.deleteAt(index);
                  }

                  if (!mounted) return;

                  selectedItems.clear();
                  selectionMode = false;
                  setState(() {});
                }();
              },
            ),
          ],
        ),
      );
    }

    final levels = directLevelsFor(widget.base);

    return Scaffold(
      body: Stack(
        children: [
          bg(),
          GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: levels.length,
            itemBuilder: (_, i) {
              final level = levels[i];

              return GestureDetector(
                onTap: () {
                  final nextBase = assetBaseName(level);

                  if (isExternalInternetLinkBase(nextBase)) {
                    final url = externalInternetLinkFor(nextBase);

                    if (url == null) {
                      showTopMessage(context, 'Brak linku dla $nextBase');
                      return;
                    }

                    launchUrl(
                      Uri.parse(url),
                      webOnlyWindowName: '_blank',
                    );
                    return;
                  }

                  final linkedBase = nextBase;

                  if (linkedBase == 'img1_1_4_3') {
                    Navigator.push(
                      context,
                      slideRoute(const ChakraTestPage()),
                    );
                    return;
                  }

                  if (linkedBase == 'img8_5_1') {
                    Navigator.push(
                      context,
                      slideRoute(const FriendsPage()),
                    );
                    return;
                  }

                  if (linkedBase == 'img8_1') {
                    Navigator.push(
                      context,
                      slideRoute(const MainShoppingListPage()),
                    );
                    return;
                  }

                  if (linkedBase == 'img8_3') {
                    Navigator.push(
                      context,
                      slideRoute(const MyClockPage()),
                    );
                    return;
                  }

                  if (linkedBase == 'img8_2' || linkedBase == 'img8_4') {
                    Navigator.push(
                      context,
                      slideRoute(LevelPage(base: linkedBase)),
                    );
                    return;
                  }

                  final gallery = galleryFor(linkedBase);

                  if (gallery.isNotEmpty) {
                    Navigator.push(
                      context,
                      slideRoute(
                        GalleryPage(images: gallery, levelImage: level),
                      ),
                    );
                    return;
                  }

                  final hasChildren = directLevelsFor(linkedBase).isNotEmpty;

                  if (hasChildren) {
                    Navigator.push(
                      context,
                      slideRoute(LevelPage(base: linkedBase)),
                    );
                  }
                },
                child: fancyTile(level),
              );
            },
          ),
          topBar(context: context),
        ],
      ),
    );
  }
}

class GalleryPage extends StatefulWidget {
  final List<String> images;
  final String levelImage;

  const GalleryPage({
    super.key,
    required this.images,
    required this.levelImage,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late PageController controller;
  final VoiceSpeaker voiceSpeaker = const VoiceSpeaker();
  int index = 0;

  bool chromeVisible = true;
  bool toolsOpen = false;
  bool isFavorite = false;
  bool isVoicePlaying = false;

  @override
  void initState() {
    super.initState();
    controller = PageController();
    isFavorite = isSavedInBox('favorite_links');
  }

  bool isSavedInBox(String boxName) {
    final box = Hive.box(boxName);

    return box.values.any((value) {
      final item = Map<String, dynamic>.from(value);
      return item['imagePath'] == widget.levelImage;
    });
  }

  Future<void> saveToBox(String boxName) async {
    if (isSavedInBox(boxName)) {
      return;
    }

    final box = Hive.box(boxName);

    await box.add({
      'imagePath': widget.levelImage,
      'galleryImages': widget.images,
    });
  }

  Future<void> removeFromBox(String boxName) async {
    final box = Hive.box(boxName);
    final keyToDelete = box.keys.cast<dynamic>().firstWhere((key) {
      final item = Map<String, dynamic>.from(box.get(key));
      return item['imagePath'] == widget.levelImage;
    }, orElse: () => null);

    if (keyToDelete != null) {
      await box.delete(keyToDelete);
    }
  }

  Future<void> toggleFavorite() async {
    final addedToFavorites = !isFavorite;

    if (isFavorite) {
      await removeFromBox('favorite_links');
    } else {
      await saveToBox('favorite_links');
    }

    if (!mounted) return;

    setState(() {
      isFavorite = !isFavorite;
    });

    if (addedToFavorites) {
      showTopMessage(context, 'Dodano do: Moje menu do Ulubione');
    }
  }

  void showPinDialog() {
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dodaj do',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await saveToBox('todo_links');

                if (!mounted) return;

                navigator.pop();
                showTopMessage(context, 'Dodano do: Moje menu do zrobienia');
              },
              child: const Text('Do zrobienia'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await saveToBox('time_links');

                if (!mounted) return;

                navigator.pop();
                showTopMessage(context, 'Dodano do: Moje menu do zegara');
              },
              child: const Text('Mój zegar'),
            ),
          ],
        ),
      ),
    );
  }

  bool hasShoppingList() {
    final fileName = widget.images[index]
        .split('/')
        .last
        .replaceAll('.webp', '')
        .split('_g')
        .first;

    final box = Hive.box('shopping_lists');

    return box.containsKey(fileName) ||
        dataList.contains('assets/data/$fileName.json');
  }

  List<Map<String, dynamic>> analysisRecordsForLevel(Box box) {
    final records = [
      for (final value in box.values)
        if (value is Map)
          if (_analysisRecordMatchesLevel(Map<String, dynamic>.from(value)))
            Map<String, dynamic>.from(value),
    ];

    records.sort(
      (a, b) => _analysisRecordTime(b).compareTo(_analysisRecordTime(a)),
    );

    return records;
  }

  DateTime _analysisRecordTime(Map<String, dynamic> record) {
    final createdAt = DateTime.tryParse('${record['createdAt'] ?? ''}');
    if (createdAt != null) {
      return createdAt;
    }

    final dateParts = '${record['date'] ?? ''}'.split('.');
    if (dateParts.length == 3) {
      final day = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final year = int.tryParse(dateParts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _analysisRecordMatchesLevel(Map<String, dynamic> record) {
    final levelBase = assetBaseName(widget.levelImage);
    final currentGalleryBase = assetBaseName(widget.images[index]);
    final items = record['items'];
    if (items is! List) {
      return false;
    }

    return items.any((rawItem) {
      if (rawItem is! Map) {
        return false;
      }

      final item = Map<String, dynamic>.from(rawItem);
      final imagePath = '${item['imagePath'] ?? ''}';
      final itemBase = assetBaseName(imagePath);

      return imagePath == widget.levelImage ||
          itemBase == levelBase ||
          currentGalleryBase.startsWith('${itemBase}_g') ||
          itemBase.startsWith(levelBase);
    });
  }

  Future<void> showAnalysisArchiveDialog(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) {
      return;
    }

    records.sort(
      (a, b) => _analysisRecordTime(b).compareTo(_analysisRecordTime(a)),
    );

    var currentIndex = 0;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final record = records[currentIndex];
          final answers = _analysisAnswers(record);
          final customNote = '${record['customNote'] ?? ''}'.trim();

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Analiza')),
                IconButton(
                  tooltip: 'Usuń',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await confirmDeleteDialog(context);
                    if (!confirmed) {
                      return;
                    }

                    await _deleteAnalysisRecord(record);
                    records.removeAt(currentIndex);

                    if (!context.mounted) {
                      return;
                    }

                    if (records.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }

                    setDialogState(() {
                      if (currentIndex >= records.length) {
                        currentIndex = records.length - 1;
                      }
                    });
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record['date'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (records.length > 1)
                        Text(
                          'Arkusz ${currentIndex + 1} / ${records.length}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (answers.isEmpty)
                    const Text('Brak zaznaczonych opcji')
                  else
                    for (final answer in answers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${answer.$1}${answer.$2 > 0 ? '  ${List.filled(answer.$2, '★').join()}' : ''}',
                        ),
                      ),
                  if (customNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Własne',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(customNote),
                  ],
                  if (records.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Nowsza analiza',
                          icon: const Icon(Icons.chevron_left),
                          onPressed: currentIndex == 0
                              ? null
                              : () {
                                  setDialogState(() => currentIndex--);
                                },
                        ),
                        Text('${currentIndex + 1} / ${records.length}'),
                        IconButton(
                          tooltip: 'Starsza analiza',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: currentIndex == records.length - 1
                              ? null
                              : () {
                                  setDialogState(() => currentIndex++);
                                },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zamknij'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAnalysisRecord(Map<String, dynamic> record) async {
    final box = Hive.box('todo_analysis_archive');
    final createdAt = record['createdAt'];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);
      if (item['createdAt'] == createdAt) {
        await box.delete(key);
        return;
      }
    }
  }

  List<(String, int)> _analysisAnswers(Map<String, dynamic> record) {
    final answers = record['answers'];
    if (answers is! List) {
      return const <(String, int)>[];
    }

    return [
      for (final rawAnswer in answers)
        if (rawAnswer is Map)
          (
            '${Map<String, dynamic>.from(rawAnswer)['label'] ?? ''}',
            int.tryParse(
                    '${Map<String, dynamic>.from(rawAnswer)['stars'] ?? 0}') ??
                0,
          ),
    ];
  }

  Widget buildToolsPanel() {
    final shoppingListExists = hasShoppingList();

    return Positioned(
      right: 0,
      top: MediaQuery.of(context).size.height * 0.24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4E342E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            child: IconButton(
              icon: Icon(
                toolsOpen ? Icons.keyboard_arrow_up : Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  toolsOpen = !toolsOpen;
                });
              },
            ),
          ),
          if (toolsOpen)
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder(
                    valueListenable:
                        Hive.box('todo_analysis_archive').listenable(),
                    builder: (context, Box analysisBox, _) {
                      final records = analysisRecordsForLevel(analysisBox);

                      return IconButton(
                        tooltip: 'Analiza',
                        icon: Icon(
                          Icons.analytics_outlined,
                          color: records.isEmpty ? Colors.grey : Colors.white,
                        ),
                        onPressed: records.isEmpty
                            ? null
                            : () => showAnalysisArchiveDialog(records),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                    ),
                    onPressed: toggleFavorite,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.push_pin_outlined,
                      color: Colors.white,
                    ),
                    onPressed: showPinDialog,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.list_alt,
                      color: shoppingListExists ? Colors.white : Colors.grey,
                    ),
                    onPressed: shoppingListExists
                        ? () {
                            Navigator.push(
                              context,
                              slideRoute(
                                ShoppingListPage(
                                  galleryImage: widget.images[index],
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.mail_outline, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void hideGalleryBars() {
    setState(() {
      chromeVisible = false;
    });
  }

  void showGalleryBars() {
    setState(() {
      chromeVisible = true;
    });
  }

  void toggleToolsPanel() {
    setState(() {
      chromeVisible = true;
      toolsOpen = !toolsOpen;
    });
  }

  void next() {
    if (index < widget.images.length - 1) {
      stopVoice();
      index++;

      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );

      setState(() {});
    }
  }

  void prev() {
    if (index > 0) {
      stopVoice();
      index--;

      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );

      setState(() {});
    }
  }

  void stopVoice() {
    voiceSpeaker.stop();
    if (mounted && isVoicePlaying) {
      setState(() => isVoicePlaying = false);
    }
  }

  Future<void> speakCurrentGalleryImage() async {
    if (isVoicePlaying || voiceSpeaker.isSpeaking) {
      stopVoice();
      return;
    }

    final imagePath = widget.images[index];

    try {
      final description = await VoiceDescriptionLoader.loadForGalleryImage(
        imagePath,
      );

      if (!voiceSpeaker.isSupported) {
        if (!mounted) return;

        showTopMessage(context, 'Odczyt głosowy działa w przeglądarce.');
        return;
      }

      await voiceSpeaker.speak(description.text);

      if (!mounted) return;

      setState(() => isVoicePlaying = true);

      showTopMessage(context, 'Czytam: ${description.title}');
    } on Object {
      if (!mounted) return;

      showTopMessage(context, 'Brak opisu głosowego dla tego obrazu.');
    }
  }

  Widget buildVoiceButton() {
    final imagePath = widget.images[index];

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 14,
      child: FutureBuilder<bool>(
        future: VoiceDescriptionLoader.hasDescriptionForGalleryImage(imagePath),
        builder: (context, snapshot) {
          final hasVoice = snapshot.data ?? false;

          return Material(
            color: Colors.black.withValues(alpha: 0.46),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: hasVoice ? 'Odczytaj opis' : 'Brak opisu głosowego',
              icon: Icon(
                isVoicePlaying
                    ? Icons.stop_circle_outlined
                    : hasVoice
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                color: hasVoice ? Colors.white : Colors.white38,
              ),
              onPressed: hasVoice ? speakCurrentGalleryImage : null,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    voiceSpeaker.stop();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          bg(),
          PageView.builder(
            controller: controller,
            itemCount: widget.images.length,
            onPageChanged: (i) {
              stopVoice();
              setState(() => index = i);
            },
            itemBuilder: (_, i) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hideGalleryBars,
                onDoubleTap: showGalleryBars,
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(120),
                  clipBehavior: Clip.none,
                  minScale: 1,
                  maxScale: 6,
                  child: SizedBox.expand(
                    child: Image.asset(
                      widget.images[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          buildToolsPanel(),
          if (chromeVisible) buildVoiceButton(),
          if (chromeVisible)
            topBar(
              context: context,
              onNext: next,
              onPrev: prev,
              counter: '${index + 1} / ${widget.images.length}',
            ),
        ],
      ),
    );
  }
}

class ShoppingListPage extends StatefulWidget {
  final String galleryImage;

  const ShoppingListPage({
    super.key,
    required this.galleryImage,
  });

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  Map<String, dynamic>? data;
  int? deletingIndex;

  @override
  void initState() {
    super.initState();
    loadJson();
  }

  String get fileName => widget.galleryImage
      .split('/')
      .last
      .replaceAll('.webp', '')
      .split('_g')
      .first;

  Future<void> loadJson() async {
    final box = Hive.box('shopping_lists');
    late Map<String, dynamic> loadedData;

    if (box.containsKey(fileName)) {
      loadedData = Map<String, dynamic>.from(box.get(fileName));
    } else {
      final jsonString = await rootBundle.loadString(
        'assets/data/$fileName.json',
      );

      loadedData = Map<String, dynamic>.from(json.decode(jsonString));
      await box.put(fileName, loadedData);
    }

    setState(() {
      data = loadedData;
    });
  }

  Future<void> sendToMainList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Dodać produkty do listy zakupów?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirm != true || data == null) {
      return;
    }

    final mainBox = Hive.box('shopping_lists_main');

    final mainItems = List.from(mainBox.get('items', defaultValue: []));

    for (final item in data!['items']) {
      mainItems.add(item);
    }

    await mainBox.put('items', mainItems);

    await Hive.box('shopping_lists').put(fileName, {...data!, 'items': []});

    setState(() {
      data!['items'] = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          data == null ? '' : data!['main_title'],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          if (data == null)
            const Center(child: CircularProgressIndicator())
          else
            Padding(
              padding: const EdgeInsets.only(top: 90, bottom: 100),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await confirmDeleteDialog(context);
                      if (!confirmed) {
                        return;
                      }

                      await Hive.box('shopping_lists').delete(fileName);
                      await loadJson();
                    },
                    child: const Text('Odśwież listę'),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(data!['items'].length, (i) {
                    final item = data!['items'][i];
                    final selected = deletingIndex == i;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: selected
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text(item['name']),
                              subtitle: Text(
                                "${item['amount']} ${item['measure']}",
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              setState(() {
                                deletingIndex = i;
                              });

                              final confirm = await confirmDeleteDialog(
                                context,
                              );

                              if (confirm) {
                                setState(() {
                                  data!['items'].removeAt(i);
                                });

                                await Hive.box(
                                  'shopping_lists',
                                ).put(fileName, data);
                              }

                              setState(() {
                                deletingIndex = null;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: sendToMainList,
                  child: const Text('Dodaj do listy zakupów'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainShoppingListPage extends StatefulWidget {
  const MainShoppingListPage({super.key});

  @override
  State<MainShoppingListPage> createState() => _MainShoppingListPageState();
}

class _MainShoppingListPageState extends State<MainShoppingListPage> {
  int? deletingIndex;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('shopping_lists_main');

    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Lista zakupów',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 90, bottom: 150),
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box box, _) {
                final items = List.from(box.get('items', defaultValue: []));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final selected = deletingIndex == i;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: selected
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text(
                                item['name'],
                                style: const TextStyle(color: Colors.black),
                              ),
                              subtitle: Text(
                                "${item['amount']} ${item['measure']}",
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              setState(() {
                                deletingIndex = i;
                              });

                              final confirm = await confirmDeleteDialog(
                                context,
                              );

                              if (confirm) {
                                items.removeAt(i);
                                await box.put('items', items);
                              }

                              setState(() {
                                deletingIndex = null;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box box, _) {
                  final items = List.from(box.get('items', defaultValue: []));

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final confirm = await confirmDeleteDialog(
                                  context,
                                );

                                if (!confirm) {
                                  return;
                                }

                                await box.put('items', []);
                              },
                              child: const Text('Usuń całą listę'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final nameController = TextEditingController();
                                final amountController =
                                    TextEditingController();
                                final measureController =
                                    TextEditingController();

                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Dodaj produkt'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nameController,
                                          decoration: const InputDecoration(
                                            hintText: 'Nazwa',
                                          ),
                                        ),
                                        TextField(
                                          controller: amountController,
                                          decoration: const InputDecoration(
                                            hintText: 'Ilość',
                                          ),
                                        ),
                                        TextField(
                                          controller: measureController,
                                          decoration: const InputDecoration(
                                            hintText: 'Miara',
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context, false);
                                        },
                                        child: const Text('Anuluj'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context, true);
                                        },
                                        child: const Text('Dodaj'),
                                      ),
                                    ],
                                  ),
                                );

                                if (result != true) {
                                  return;
                                }

                                final items = List.from(
                                  box.get('items', defaultValue: []),
                                );

                                items.add({
                                  'name': nameController.text,
                                  'amount':
                                      int.tryParse(amountController.text) ?? 1,
                                  'measure': measureController.text,
                                });

                                await box.put('items', items);
                              },
                              child: const Text('+ Dodaj produkt'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
