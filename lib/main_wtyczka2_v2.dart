import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

late List<String> assetList;
late List<String> dataList;

Future<void> loadAppAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest.listAssets();

  assetList = assets
      .where(
        (e) =>
            e.startsWith('assets/') &&
            !e.startsWith('assets/data/') &&
            (e.endsWith('.png') || e.endsWith('.webp')),
      )
      .toList()
    ..sort(naturalCompare);

  dataList = assets
      .where((e) => e.startsWith('assets/data/') && e.endsWith('.json'))
      .toList()
    ..sort(naturalCompare);
}

int naturalCompare(String a, String b) {
  final reg = RegExp(r'\d+|\D+');
  final aa = reg.allMatches(a).map((m) => m.group(0)!).toList();
  final bb = reg.allMatches(b).map((m) => m.group(0)!).toList();

  for (var i = 0; i < aa.length && i < bb.length; i++) {
    final an = int.tryParse(aa[i]);
    final bn = int.tryParse(bb[i]);

    final result = an != null && bn != null
        ? an.compareTo(bn)
        : aa[i].compareTo(bb[i]);

    if (result != 0) {
      return result;
    }
  }

  return aa.length.compareTo(bb.length);
}

String assetBaseName(String path) {
  final fileName = path.split('/').last;
  return fileName.replaceAll(RegExp(r'\.(png|webp)$'), '');
}

String shoppingFileNameFromImage(String path) {
  return assetBaseName(path).split('_g').first;
}

String firstExistingAsset(List<String> paths) {
  for (final path in paths) {
    if (assetList.contains(path)) {
      return path;
    }
  }

  return paths.first;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadAppAssets();

  await Hive.initFlutter();
  await Hive.openBox('todo_links');
  await Hive.openBox('time_links');
  await Hive.openBox('shopping_lists');
  await Hive.openBox('shopping_lists_main');

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

      return SlideTransition(
        position: offset,
        child: child,
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartPage(),
    );
  }
}

Widget bg() => Positioned.fill(
      child: Image.asset(
        firstExistingAsset([
          'assets/pg.png',
          'assets/pg.webp',
        ]),
        fit: BoxFit.cover,
      ),
    );

Widget fancyTile(String path) {
  return Center(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Colors.white24,
            Colors.black26,
          ],
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
        border: Border.all(
          color: Colors.white70,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 150,
          height: 150,
          child: Image.asset(
            path,
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

Widget topBar({
  required BuildContext context,
  VoidCallback? onNext,
  VoidCallback? onPrev,
  VoidCallback? onDelete,
  String? counter,
}) {
  return Positioned(
    left: 10,
    right: 10,
    bottom: 0,
    child: SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
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
          Navigator.push(
            context,
            slideRoute(const CategoryPage()),
          );
        },
        child: Stack(
          children: [
            bg(),
            Center(
              child: Image.asset(
                firstExistingAsset([
                  'assets/start.png',
                  'assets/start.webp',
                ]),
              ),
            ),
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
    final itemsByBase = <String, String>{};

    for (final asset in assetList) {
      if (RegExp(r'^assets/img\d+\.(png|webp)$').hasMatch(asset)) {
        itemsByBase.putIfAbsent(assetBaseName(asset), () => asset);
      }
    }

    final items = itemsByBase.entries.toList()
      ..sort((a, b) => naturalCompare(a.key, b.key));

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
              final base = items[i].key;
              final imagePath = items[i].value;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    slideRoute(
                      LevelPage(base: base),
                    ),
                  );
                },
                child: fancyTile(imagePath),
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

  const LevelPage({
    super.key,
    required this.base,
  });

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
      final parts = name.split('_');

      return parts.length == baseParts.length + 1;
    }).toList()
      ..sort(naturalCompare);
  }

  List<String> galleryFor(String base) {
    return assetList
        .where((e) => e.startsWith('assets/${base}_g'))
        .toList()
      ..sort(naturalCompare);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.base == 'img8_2' || widget.base == 'img8_3') {
      final box = Hive.box(
        widget.base == 'img8_2' ? 'todo_links' : 'time_links',
      );

      final links = box.values.toList();

      return Scaffold(
        body: Stack(
          children: [
            bg(),
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: links.length,
              itemBuilder: (_, i) {
                final item = Map<String, dynamic>.from(links[i]);
                final imagePath = item['imagePath'] as String;
                final galleryImages = List<String>.from(item['galleryImages']);

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
                  child: Stack(
                    children: [
                      fancyTile(imagePath),
                      if (selectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: selectedItems.contains(i)
                                  ? Colors.green
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: selectedItems.contains(i)
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
              },
            ),
            topBar(
              context: context,
              onDelete: () {
                if (selectedItems.isEmpty) {
                  return;
                }

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final keys = selectedItems.toList()
                              ..sort((a, b) => b.compareTo(a));

                            final navigator = Navigator.of(context);

                            for (final index in keys) {
                              await box.deleteAt(index);
                            }

                            if (!mounted) return;

                            selectedItems.clear();
                            selectionMode = false;
                            navigator.pop();
                            setState(() {});
                          },
                          child: const Text('Usuń'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Anuluj'),
                        ),
                      ],
                    ),
                  ),
                );
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

                  if (nextBase == 'img8_1') {
                    Navigator.push(
                      context,
                      slideRoute(const MainShoppingListPage()),
                    );
                    return;
                  }

                  if (nextBase == 'img8_2' || nextBase == 'img8_3') {
                    Navigator.push(
                      context,
                      slideRoute(LevelPage(base: nextBase)),
                    );
                    return;
                  }

                  final gallery = galleryFor(nextBase);

                  if (gallery.isNotEmpty) {
                    Navigator.push(
                      context,
                      slideRoute(
                        GalleryPage(
                          images: gallery,
                          levelImage: level,
                        ),
                      ),
                    );
                    return;
                  }

                  if (directLevelsFor(nextBase).isNotEmpty) {
                    Navigator.push(
                      context,
                      slideRoute(LevelPage(base: nextBase)),
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
  int index = 0;

  bool toolsOpen = false;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  Future<void> saveToBox(String boxName) async {
    final box = Hive.box(boxName);

    await box.add({
      'imagePath': widget.levelImage,
      'galleryImages': widget.images,
    });
  }

  void showPinDialog() {
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                await saveToBox('todo_links');

                if (!mounted) return;

                navigator.pop();
              },
              child: const Text('Do zrobienia'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await saveToBox('time_links');

                if (!mounted) return;

                navigator.pop();
              },
              child: const Text('Inżynieria mojego czasu'),
            ),
          ],
        ),
      ),
    );
  }

  bool hasShoppingList() {
    final fileName = shoppingFileNameFromImage(widget.images[index]);
    final box = Hive.box('shopping_lists');

    return box.containsKey(fileName) ||
        dataList.contains('assets/data/$fileName.json');
  }

  Widget buildToolsPanel() {
    final shoppingListExists = hasShoppingList();

    return Positioned(
      right: -8,
      top: MediaQuery.of(context).size.height * 0.35,
      child: Row(
        children: [
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
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        isFavorite = !isFavorite;
                      });
                    },
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
                    icon: const Icon(
                      Icons.monetization_on_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.mail_outline,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(
              right: 8,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF4E342E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: Icon(
                toolsOpen ? Icons.arrow_forward : Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  toolsOpen = !toolsOpen;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void next() {
    if (index < widget.images.length - 1) {
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
      index--;

      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );

      setState(() {});
    }
  }

  @override
  void dispose() {
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
            onPageChanged: (i) => setState(() => index = i),
            itemBuilder: (_, i) {
              return InteractiveViewer(
                child: Center(
                  child: Image.asset(widget.images[i]),
                ),
              );
            },
          ),
          buildToolsPanel(),
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
  List<bool> checkedItems = [];

  String get fileName => shoppingFileNameFromImage(widget.galleryImage);

  @override
  void initState() {
    super.initState();
    loadJson();
  }

  Future<void> loadJson() async {
    final box = Hive.box('shopping_lists');

    if (box.containsKey(fileName)) {
      final savedData = Map<String, dynamic>.from(box.get(fileName));

      setState(() {
        data = savedData;
        checkedItems = List<bool>.from(
          savedData['checkedItems'] ??
              List.generate(savedData['items'].length, (_) => false),
        );
      });

      return;
    }

    final jsonString = await rootBundle.loadString(
      'assets/data/$fileName.json',
    );

    final jsonData = Map<String, dynamic>.from(json.decode(jsonString));

    checkedItems = List.generate(
      jsonData['items'].length,
      (_) => false,
    );

    jsonData['checkedItems'] = checkedItems;

    await box.put(fileName, jsonData);

    setState(() {
      data = jsonData;
    });
  }

  Future<void> saveCurrentList() async {
    if (data == null) {
      return;
    }

    data!['checkedItems'] = checkedItems;

    await Hive.box('shopping_lists').put(
      fileName,
      data,
    );
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                      ),
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
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.only(
                top: 90,
                bottom: 100,
              ),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Hive.box('shopping_lists').delete(fileName);
                      await loadJson();
                    },
                    child: const Text('Odśwież listę'),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(
                    data!['items'].length,
                    (i) {
                      final item = data!['items'][i];

                      return Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: checkedItems[i],
                              onChanged: (value) async {
                                setState(() {
                                  checkedItems[i] = value ?? false;
                                  data!['checkedItems'] = checkedItems;
                                });

                                await saveCurrentList();
                              },
                              title: Text(
                                item['name'],
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                "${item['amount']} ${item['measure']}",
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              setState(() {
                                data!['items'].removeAt(i);
                                checkedItems.removeAt(i);
                                data!['checkedItems'] = checkedItems;
                              });

                              await saveCurrentList();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 2,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () async {
                          final selected = checkedItems.any((e) => e);

                          if (!selected) {
                            showDialog(
                              context: context,
                              builder: (_) => const AlertDialog(
                                content: Center(
                                  heightFactor: 1,
                                  child: Text(
                                    'Zaznacz',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          final box = Hive.box('shopping_lists_main');

                          final shoppingItems = List<dynamic>.from(
                            box.get(
                              'items',
                              defaultValue: [],
                            ),
                          );

                          for (var i = 0; i < data!['items'].length; i++) {
                            if (checkedItems[i]) {
                              final newItem = Map<String, dynamic>.from(
                                data!['items'][i],
                              );

                              final existingIndex = shoppingItems.indexWhere(
                                (item) => item['name'] == newItem['name'],
                              );

                              if (existingIndex != -1) {
                                shoppingItems[existingIndex]['amount'] +=
                                    newItem['amount'];
                              } else {
                                shoppingItems.add(newItem);
                              }
                            }
                          }

                          await box.put('items', shoppingItems);

                          if (!context.mounted) {
                            return;
                          }

                          showDialog(
                            context: context,
                            builder: (_) => const AlertDialog(
                              content: Center(
                                heightFactor: 1,
                                child: Text(
                                  'Dodano',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('Dodaj do listy zakupów'),
                      ),
                    ),
                  ],
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
  const MainShoppingListPage({
    super.key,
  });

  @override
  State<MainShoppingListPage> createState() => _MainShoppingListPageState();
}

class _MainShoppingListPageState extends State<MainShoppingListPage> {
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                    ),
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
            padding: const EdgeInsets.only(
              top: 90,
              bottom: 90,
            ),
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box box, _) {
                final items = List.from(
                  box.get(
                    'items',
                    defaultValue: [],
                  ),
                );

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];

                    return Row(
                      children: [
                        Checkbox(
                          value: false,
                          onChanged: (_) {},
                        ),
                        Expanded(
                          child: ListTile(
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              "${item['amount']} ${item['measure']}",
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                content: const Center(
                                  heightFactor: 1,
                                  child: Text(
                                    'Potwierdź usunięcie',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context, false);
                                    },
                                    child: const Text('Nie'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context, true);
                                    },
                                    child: const Text('Tak'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm != true) {
                              return;
                            }

                            items.removeAt(i);

                            await box.put('items', items);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: const Center(
                            heightFactor: 1,
                            child: Text(
                              'Potwierdź usunięcie',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, false);
                              },
                              child: const Text('Nie'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, true);
                              },
                              child: const Text('Tak'),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) {
                        return;
                      }

                      await box.put('items', []);
                    },
                    child: const Text('Usuń całą listę'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
