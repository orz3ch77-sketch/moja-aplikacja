import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../mock/mock_tasks.dart';
import '../models/clock_task_model.dart';
import '../services/clock_level_metadata.dart';
import '../services/next_task_service.dart';
import '../widgets/analog_clock_widget.dart';
import '../widgets/bottom_buttons_widget.dart';
import '../widgets/next_task_widget.dart';
import '../widgets/orbit_tasks_widget.dart';
import '../widgets/top_bar_widget.dart';

class MyClockPage extends StatefulWidget {
  const MyClockPage({super.key});

  @override
  State<MyClockPage> createState() => _MyClockPageState();
}

class _MyClockPageState extends State<MyClockPage> {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addedBox = Hive.box('time_links');
    final myTasksBox = Hive.box('my_clock_tasks');

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder(
        valueListenable: addedBox.listenable(),
        builder: (context, Box addedBox, _) {
          return ValueListenableBuilder(
            valueListenable: myTasksBox.listenable(),
            builder: (context, Box myTasksBox, _) {
              final myTasks = _myTasksFromBox(myTasksBox.values.toList());
              final visibleTasks = myTasks.isEmpty ? mockTasks : myTasks;
              final nextTask = NextTaskService.getNextTask(
                visibleTasks,
                now: _now,
              );

              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF050816),
                      Color(0xFF02030A),
                      Color(0xFF090022),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 760;
                      final veryCompact = constraints.maxHeight < 680 ||
                          constraints.maxWidth < 380;
                      final widthLimit =
                          constraints.maxWidth - (veryCompact ? 20 : 32);
                      final mobileWidthLimit = constraints.maxWidth *
                          (veryCompact
                              ? 0.68
                              : compact
                                  ? 0.78
                                  : 0.90);
                      final heightLimit = constraints.maxHeight *
                          (veryCompact
                              ? 0.30
                              : compact
                                  ? 0.36
                                  : 0.46);
                      final rawClockSize =
                          widthLimit < heightLimit ? widthLimit : heightLimit;
                      final limitedClockSize = rawClockSize < mobileWidthLimit
                          ? rawClockSize
                          : mobileWidthLimit;
                      final clockSize = limitedClockSize.clamp(200.0, 460.0);

                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            children: [
                              const TopBarWidget(),
                              Padding(
                                padding: EdgeInsets.only(
                                  top: compact ? 4 : 8,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _weekdayName(_now.weekday).toUpperCase(),
                                      style: TextStyle(
                                        color: const Color(0xFFB44CFF),
                                        fontSize: veryCompact
                                            ? 16
                                            : compact
                                                ? 18
                                                : 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    SizedBox(height: veryCompact ? 2 : 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${_now.day} ${_monthName(_now.month)} ${_now.year}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: veryCompact
                                                ? 28
                                                : compact
                                                    ? 34
                                                    : 42,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(0, veryCompact ? -18 : -10),
                                child: Center(
                                  child: SizedBox(
                                    width: clockSize.toDouble(),
                                    height: clockSize.toDouble(),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: SizedBox(
                                        width: 500,
                                        height: 500,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            OrbitTasksWidget(
                                              tasks: visibleTasks,
                                            ),
                                            AnalogClockWidget(now: _now),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: veryCompact ? 0 : 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: NextTaskWidget(task: nextTask),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: BottomButtonsWidget(
                                  onMyTasks: _showMyTasksSheet,
                                  onAdded: _showAddedSheet,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showMyTasksSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClockSheet(
        child: ValueListenableBuilder(
          valueListenable: Hive.box('my_clock_tasks').listenable(),
          builder: (context, Box box, _) {
            return _buildMyTasksPanel(box, maxHeight: 520);
          },
        ),
      ),
    );
  }

  void _showAddedSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClockSheet(
        child: ValueListenableBuilder(
          valueListenable: Hive.box('time_links').listenable(),
          builder: (context, Box box, _) {
            return _buildAddedPanel(box, maxHeight: 520);
          },
        ),
      ),
    );
  }

  Widget _buildMyTasksPanel(
    Box box, {
    double maxHeight = 190,
  }) {
    final items = box.values.toList();

    return _ClockPanel(
      title: 'Moje zadania',
      maxHeight: maxHeight,
      action: FilledButton.icon(
        onPressed: _showCreateCustomTaskDialog,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Dodaj zadanie'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF7A5CFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      child: items.isEmpty
          ? const _EmptyPanelText(
              text:
                  'Dodaj pierwsze zadanie albo wybierz element z zakładki „Dodane”.',
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _MyTaskTile(
                    item: Map<String, dynamic>.from(items[index]),
                    onDelete: () => box.deleteAt(index),
                  ),
              ],
            ),
    );
  }

  Future<void> _showCreateCustomTaskDialog() async {
    final titleController = TextEditingController();
    final dayController = TextEditingController(text: 'Dziś');
    final timeController = TextEditingController(text: '08:00');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dodaj zadanie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nazwa zadania'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: dayController,
              decoration: const InputDecoration(
                labelText: 'Dzień, np. Dziś / Poniedziałek',
              ),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: timeController,
              decoration:
                  const InputDecoration(labelText: 'Godzina, np. 08:00'),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final day = dayController.text.trim();
    final time = timeController.text.trim();
    titleController.dispose();
    dayController.dispose();
    timeController.dispose();

    if (result != true || title.isEmpty) {
      return;
    }

    await Hive.box('my_clock_tasks').add({
      'title': title,
      'day': day.isEmpty ? 'Dziś' : day,
      'time': RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time) ? time : '08:00',
      'imagePath': '',
      'clockIconPath': '',
      'galleryImages': const <String>[],
    });
  }

  Widget _buildAddedPanel(
    Box box, {
    double maxHeight = 190,
  }) {
    final items = box.values.toList();

    return _ClockPanel(
      title: 'Dodane z galerii',
      maxHeight: maxHeight,
      child: items.isEmpty
          ? const _EmptyPanelText(
              text:
                  'Dodaj element z galerii przez pinezkę i wybierz „Inżynieria mojego czasu”.',
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _AddedGalleryTile(
                    item: Map<String, dynamic>.from(items[index]),
                    onCreateTask: () => _showCreateTaskFromAddedDialog(
                      Map<String, dynamic>.from(items[index]),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _showCreateTaskFromAddedDialog(
    Map<String, dynamic> source,
  ) async {
    final imagePath = source['imagePath'] as String? ?? '';
    final titleController = TextEditingController(
      text: clockTitleForImagePath(imagePath),
    );
    final dayController = TextEditingController(text: 'Dziś');
    final timeController = TextEditingController(text: '08:00');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Utwórz Moje zadanie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Nazwa zadania'),
            ),
            TextField(
              controller: dayController,
              decoration: const InputDecoration(
                labelText: 'Dzień, np. Dziś / Poniedziałek',
              ),
            ),
            TextField(
              controller: timeController,
              decoration:
                  const InputDecoration(labelText: 'Godzina, np. 08:00'),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final day = dayController.text.trim();
    final time = timeController.text.trim();
    titleController.dispose();
    dayController.dispose();
    timeController.dispose();

    if (result != true || title.isEmpty) {
      return;
    }

    await Hive.box('my_clock_tasks').add({
      'title': title,
      'day': day.isEmpty ? 'Dziś' : day,
      'time': RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time) ? time : '08:00',
      'imagePath': imagePath,
      'clockIconPath': clockIconPathForImagePath(imagePath),
      'galleryImages': source['galleryImages'],
    });

    if (!mounted) return;
  }

  List<ClockTaskModel> _myTasksFromBox(List<dynamic> values) {
    final tasks = <ClockTaskModel>[];

    for (var index = 0; index < values.length; index++) {
      final raw = values[index];
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);
      tasks.add(
        ClockTaskModel(
          number: index + 1,
          title: _taskTitleFromItem(item),
          day: item['day'] as String? ?? 'Dziś',
          time: item['time'] as String? ?? '08:00',
          icon: clockIconForImagePath(item['imagePath'] as String? ?? ''),
          color: _colorForIndex(index),
          imagePath:
              item['clockIconPath'] as String? ?? item['imagePath'] as String?,
        ),
      );
    }

    return tasks;
  }

  Color _colorForIndex(int index) {
    const colors = <Color>[
      Color(0xFF00D0FF),
      Color(0xFF7CFF6B),
      Color(0xFFFFF06A),
      Color(0xFFFFB84D),
      Color(0xFFFF7A30),
      Color(0xFFFF4D5E),
      Color(0xFFFF4FD8),
      Color(0xFFB44CFF),
      Color(0xFF4DA3FF),
    ];

    return colors[index % colors.length];
  }

  String _weekdayName(int weekday) {
    const names = <int, String>{
      1: 'Poniedziałek',
      2: 'Wtorek',
      3: 'Środa',
      4: 'Czwartek',
      5: 'Piątek',
      6: 'Sobota',
      7: 'Niedziela',
    };

    return names[weekday] ?? '';
  }

  String _monthName(int month) {
    const names = <int, String>{
      1: 'stycznia',
      2: 'lutego',
      3: 'marca',
      4: 'kwietnia',
      5: 'maja',
      6: 'czerwca',
      7: 'lipca',
      8: 'sierpnia',
      9: 'września',
      10: 'października',
      11: 'listopada',
      12: 'grudnia',
    };

    return names[month] ?? '';
  }
}

String _taskTitleFromItem(Map<String, dynamic> item) {
  final rawTitle = (item['title'] as String? ?? '').trim();
  final imagePath = item['imagePath'] as String? ?? '';
  final generatedTitle = clockTitleForImagePath(imagePath);

  if (rawTitle.isEmpty || _looksLikeAssetCodeTitle(rawTitle)) {
    return generatedTitle;
  }

  return rawTitle;
}

bool _looksLikeAssetCodeTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return RegExp(r'^(img)?[\d_\s]+$').hasMatch(normalized);
}

class _ClockPanel extends StatelessWidget {
  const _ClockPanel({
    required this.title,
    required this.child,
    this.action,
    this.maxHeight = 190,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC121A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x5538D8FF),
          width: 1.1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockSheet extends StatelessWidget {
  const _ClockSheet({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyPanelText extends StatelessWidget {
  const _EmptyPanelText({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.25,
        ),
      ),
    );
  }
}

class _MyTaskTile extends StatelessWidget {
  const _MyTaskTile({
    required this.item,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imagePath =
        item['clockIconPath'] as String? ?? item['imagePath'] as String? ?? '';
    final title = _taskTitleFromItem(item);
    final day = item['day'] as String? ?? 'Dziś';
    final time = item['time'] as String? ?? '08:00';

    return _ClockTileShell(
      leading: _LevelIcon(imagePath: imagePath),
      title: title,
      subtitle: '$day • $time',
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white70),
        onPressed: onDelete,
      ),
    );
  }
}

class _AddedGalleryTile extends StatelessWidget {
  const _AddedGalleryTile({
    required this.item,
    required this.onCreateTask,
  });

  final Map<String, dynamic> item;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final imagePath = item['imagePath'] as String? ?? '';

    return _ClockTileShell(
      leading: _LevelIcon(imagePath: levelImagePathForImagePath(imagePath)),
      title: clockTitleForImagePath(imagePath),
      subtitle: 'Wybierz i utwórz Moje zadanie',
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00D0FF)),
        onPressed: onCreateTask,
      ),
      onTap: onCreateTask,
    );
  }
}

class _ClockTileShell extends StatelessWidget {
  const _ClockTileShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xAA071020),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x7700D0FF)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _LevelIcon extends StatelessWidget {
  const _LevelIcon({
    required this.imagePath,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: imagePath.isEmpty
            ? const ColoredBox(
                color: Color(0xFF111827),
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.white70,
                ),
              )
            : Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF111827),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
      ),
    );
  }
}
