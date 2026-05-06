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
      .where((e) => e.startsWith('assets/') && e.endsWith('.webp'))
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

    final result =
        an != null && bn != null ? an.compareTo(bn) : aa[i].compareTo(bb[i]);

    if (result != 0) return result;
  }

  return aa.length.compareTo(bb.length);
}

String assetBaseName(String assetPath) {
  return assetPath.split('/').last.replaceAll('.webp', '');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadAppAssets();

  await Hive.initFlutter();
  await Hive.openBox('todo_links');
  await Hive.openBox('time_links');
  await Hive.openBox('favorite_links');
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

      return SlideTransition(position: offset, child: child);
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

Widget bg() =>
    Positioned.fill(child: Image.asset('assets/pg.webp', fit: BoxFit.cover));

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
      final parts = name.split('_');

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
    return widget.base == 'img8_2' ||
        widget.base == 'img8_3' ||
        widget.base == 'img8_4';
  }

  @override
  Widget build(BuildContext context) {
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

                  if (nextBase == 'img8_1') {
                    Navigator.push(
                      context,
                      slideRoute(const MainShoppingListPage()),
                    );
                    return;
                  }

                  if (nextBase == 'img8_2' ||
                      nextBase == 'img8_3' ||
                      nextBase == 'img8_4') {
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
                        GalleryPage(images: gallery, levelImage: level),
                      ),
                    );
                    return;
                  }

                  final hasChildren = directLevelsFor(nextBase).isNotEmpty;

                  if (hasChildren) {
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

  bool chromeVisible = true;
  bool toolsOpen = false;
  bool isFavorite = false;

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
    if (isFavorite) {
      await removeFromBox('favorite_links');
    } else {
      await saveToBox('favorite_links');
    }

    if (!mounted) return;

    setState(() {
      isFavorite = !isFavorite;
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
                    icon: const Icon(
                      Icons.monetization_on_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
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
      toolsOpen = false;
    });
  }

  void showGalleryBars() {
    setState(() {
      chromeVisible = true;
    });
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
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hideGalleryBars,
                onDoubleTap: showGalleryBars,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(child: Image.asset(widget.images[i])),
                ),
              );
            },
          ),
          if (chromeVisible) buildToolsPanel(),
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

  const ShoppingListPage({super.key, required this.galleryImage});

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

    if (box.containsKey(fileName)) {
      final savedData = Map<String, dynamic>.from(box.get(fileName));

      setState(() {
        data = savedData;
      });

      return;
    }

    final jsonString = await rootBundle.loadString(
      'assets/data/$fileName.json',
    );

    final jsonData = Map<String, dynamic>.from(json.decode(jsonString));

    await box.put(fileName, jsonData);

    setState(() {
      data = jsonData;
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

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  content: const Text('Potwierdź usunięcie'),
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

                              if (confirm == true) {
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

                              if (confirm == true) {
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
              child: Row(
                children: [
                  Expanded(
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
                                child: const Text('Anuluj'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context, true);
                                },
                                child: const Text('Ok'),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final nameController = TextEditingController();
                        final amountController = TextEditingController();
                        final measureController = TextEditingController();

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
                          'amount': int.tryParse(amountController.text) ?? 1,
                          'measure': measureController.text,
                        });

                        await box.put('items', items);
                      },
                      child: const Text('+ Dodaj produkt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
