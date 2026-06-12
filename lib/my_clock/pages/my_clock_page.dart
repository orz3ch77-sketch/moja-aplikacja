import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/clock_task_model.dart';
import '../services/clock_level_metadata.dart';
import '../services/clock_protocol_loader.dart';
import '../widgets/analog_clock_widget.dart';
import '../widgets/bottom_buttons_widget.dart';
import '../widgets/orbit_tasks_widget.dart';
import '../widgets/top_bar_widget.dart';
import '../../shared/confirm_delete_dialog.dart';

class MyClockPage extends StatefulWidget {
  const MyClockPage({super.key});

  @override
  State<MyClockPage> createState() => _MyClockPageState();
}

class _MyClockPageState extends State<MyClockPage> {
  DateTime _now = DateTime.now();
  bool _weekView = false;
  bool _alarmDialogOpen = false;
  Timer? _clockTimer;
  Timer? _alarmSoundTimer;
  final Set<String> _shownAlarmKeys = <String>{};
  final Set<String> _hiddenOrbitTaskKeys = <String>{};
  int _orbitToggleStartIndex = 0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final now = DateTime.now();
        setState(() => _now = now);
        _checkDueAlarms(now);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _stopAlarmSignal();
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
              final myTasks = _myTasksFromBox(
                myTasksBox.values.toList(),
                now: _now,
                includeWholeWeek: _weekView,
              );
              final visibleOrbitTasks = myTasks
                  .where((task) => !_hiddenOrbitTaskKeys.contains(task.id))
                  .toList();
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
                          constraints.maxWidth - (veryCompact ? 16 : 24);
                      final mobileWidthLimit = constraints.maxWidth *
                          (veryCompact
                              ? 0.92
                              : compact
                                  ? 0.94
                                  : 0.96);
                      final reservedBottom = veryCompact ? 86.0 : 96.0;
                      final reservedTop = veryCompact ? 108.0 : 122.0;
                      final controlsBottom = myTasks.isEmpty
                          ? reservedBottom
                          : reservedBottom + (veryCompact ? 44.0 : 50.0);
                      final heightLimit =
                          constraints.maxHeight - reservedTop - controlsBottom;
                      final rawClockSize =
                          widthLimit < heightLimit ? widthLimit : heightLimit;
                      final limitedClockSize = rawClockSize < mobileWidthLimit
                          ? rawClockSize
                          : mobileWidthLimit;
                      final clockSize = limitedClockSize.clamp(220.0, 470.0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            TopBarWidget(
                              onCalendar: () {
                                _showCalendarDialog();
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                veryCompact ? 0 : 2,
                                20,
                                0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _weekdayName(_now.weekday)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFFB44CFF),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      const TextSpan(text: '  '),
                                      TextSpan(
                                        text:
                                            '${_now.day} ${_monthName(_now.month)} ${_now.year}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: veryCompact
                                        ? 25
                                        : compact
                                            ? 29
                                            : 34,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
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
                                            tasks: visibleOrbitTasks,
                                            onTaskTap: _showTaskDetails,
                                          ),
                                          AnalogClockWidget(now: _now),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _buildOrbitVisibilityToggles(myTasks),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                              child: BottomButtonsWidget(
                                onMyTasks: _showMyTasksSheet,
                                onAdded: _showAddedSheet,
                              ),
                            ),
                          ],
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

  Widget _buildOrbitVisibilityToggles(List<ClockTaskModel> tasks) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    const maxVisibleIcons = 5;
    final maxStartIndex =
        tasks.length > maxVisibleIcons ? tasks.length - maxVisibleIcons : 0;
    final startIndex = _orbitToggleStartIndex.clamp(0, maxStartIndex).toInt();
    final visibleTasks =
        tasks.skip(startIndex).take(maxVisibleIcons).toList(growable: false);
    final canMoveLeft = startIndex > 0;
    final canMoveRight = startIndex < maxStartIndex;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOrbitToggleArrow(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Poprzednie ikony',
              enabled: canMoveLeft,
              onTap: () {
                setState(() {
                  _orbitToggleStartIndex = (startIndex - maxVisibleIcons)
                      .clamp(0, maxStartIndex)
                      .toInt();
                });
              },
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 212,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < visibleTasks.length; index++) ...[
                    _buildOrbitToggleIcon(visibleTasks[index]),
                    if (index != visibleTasks.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            _buildOrbitToggleArrow(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Następne ikony',
              enabled: canMoveRight,
              onTap: () {
                setState(() {
                  _orbitToggleStartIndex = (startIndex + maxVisibleIcons)
                      .clamp(0, maxStartIndex)
                      .toInt();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitToggleArrow({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        icon: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white30,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildOrbitToggleIcon(ClockTaskModel task) {
    final enabled = !_hiddenOrbitTaskKeys.contains(task.id);

    return Tooltip(
      message: enabled
          ? 'Ukryj ${task.time} ${task.title}'
          : 'Pokaż ${task.time} ${task.title}',
      child: Semantics(
        button: true,
        selected: enabled,
        label: '${task.time} ${task.title}',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            setState(() {
              if (enabled) {
                _hiddenOrbitTaskKeys.add(task.id);
              } else {
                _hiddenOrbitTaskKeys.remove(task.id);
              }
            });
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: enabled ? 1 : 0.38,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xDD071020),
                border: Border.all(
                  color: enabled ? task.color : Colors.white30,
                  width: 1.5,
                ),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: task.color.withValues(alpha: 0.38),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.5),
                child: task.imagePath == null || task.imagePath!.isEmpty
                    ? Icon(task.icon, color: task.color, size: 20)
                    : Image.asset(
                        task.imagePath!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          task.icon,
                          color: task.color,
                          size: 20,
                        ),
                      ),
              ),
            ),
          ),
        ),
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

  void _checkDueAlarms(DateTime now) {
    if (_alarmDialogOpen) {
      return;
    }

    final box = Hive.box('my_clock_tasks');
    final dueTasks = _taskItemsForDate(box.values.toList(), now)
        .where(
          (item) =>
              _minutesFromTime(item['time'] as String? ?? '08:00') ==
              now.hour * 60 + now.minute,
        )
        .toList();

    if (dueTasks.isEmpty) {
      return;
    }

    final alarmKey = [
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      for (final item in dueTasks)
        '${item['time'] ?? ''}:${_taskTitleFromItem(item)}',
    ].join('|');

    if (!_shownAlarmKeys.add(alarmKey)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showAlarmDialog(dueTasks);
      }
    });
  }

  void _startAlarmSignal() {
    _stopAlarmSignal();
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
    _alarmSoundTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    });
  }

  void _stopAlarmSignal() {
    _alarmSoundTimer?.cancel();
    _alarmSoundTimer = null;
  }

  Future<void> _showAlarmDialog(List<Map<String, dynamic>> tasks) async {
    if (_alarmDialogOpen) {
      return;
    }

    _alarmDialogOpen = true;
    if (_shouldPlayAlarmSound(tasks)) {
      _startAlarmSignal();
    }
    final affirmationLinks = await _affirmationLinksForTasks(tasks);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Przypomnienie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final task in tasks) ...[
                Text(
                  '${task['time'] ?? '08:00'} — ${_taskTitleFromItem(task)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ((task['details'] as String? ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text((task['details'] as String).trim()),
                ],
                const SizedBox(height: 12),
              ],
              if (affirmationLinks.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'Afirmacje',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final link in affirmationLinks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      onPressed: () => _openAffirmationLink(link.url),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: Text('Włącz głos — ${link.title}'),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );

    _stopAlarmSignal();
    _alarmDialogOpen = false;
  }

  bool _shouldPlayAlarmSound(List<Map<String, dynamic>> tasks) {
    return tasks.any((task) {
      final alarmSound = task['alarmSound'] as String? ?? 'alert';
      return alarmSound != 'none';
    });
  }

  Future<List<_AlarmAffirmationLink>> _affirmationLinksForTasks(
    List<Map<String, dynamic>> tasks,
  ) async {
    final links = <_AlarmAffirmationLink>[];
    final seen = <String>{};

    for (final task in tasks) {
      final selectedAlarmBase = _alarmLinkBaseFromSound(
        task['alarmSound'] as String?,
      );
      if (selectedAlarmBase != null && seen.add(selectedAlarmBase)) {
        final selectedLink = await _clockAlarmLinkForBase(selectedAlarmBase);
        if (selectedLink != null) {
          links.add(selectedLink);
        }
      }
    }

    return links;
  }

  List<String> _stringListFromItem(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return [
      for (final item in value)
        if (item is String) item,
    ];
  }

  Future<_AlarmAffirmationLink?> _clockAlarmLinkForBase(String base) async {
    try {
      final text = await rootBundle.loadString(
        'assets/clock_alarm_links/$base.json',
      );
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final rawLink = decoded['url'] != null ? decoded : decoded[base];
      final url = rawLink is Map<String, dynamic> ? rawLink['url'] : rawLink;
      final title = rawLink is Map<String, dynamic>
          ? '${rawLink['title'] ?? ''}'.trim()
          : '';
      final normalized = '$url'.trim();
      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        return _AlarmAffirmationLink(
          title: title,
          url: normalized,
        );
      }
    } on Object {
      return null;
    }

    return null;
  }

  String? _alarmLinkBaseFromSound(String? alarmSound) {
    if (alarmSound == null || !alarmSound.startsWith('link:')) {
      return null;
    }

    final base = alarmSound.substring('link:'.length).trim();
    return base.isEmpty ? null : base;
  }

  Future<List<_AlarmAffirmationLink>> _loadClockAlarmLinks() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest
        .listAssets()
        .where(
          (asset) =>
              asset.startsWith('assets/clock_alarm_links/') &&
              asset.endsWith('.json'),
        )
        .toList()
      ..sort((a, b) => a.compareTo(b));

    final links = <_AlarmAffirmationLink>[];
    for (final file in files) {
      final base = _assetBaseName(file);
      final link = await _clockAlarmLinkForBase(base);
      if (link != null) {
        links.add(link.copyWith(value: 'link:$base'));
      }
    }

    return links;
  }

  Future<void> _openAffirmationLink(String url) async {
    final uri = Uri.tryParse(_alarmAutoplayUrl(url));
    if (uri == null) {
      return;
    }

    await launchUrl(
      uri,
      webOnlyWindowName: '_blank',
    );
  }

  String _alarmAutoplayUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return url;
    }

    final host = uri.host.toLowerCase();
    if (!host.contains('youtube.com') && !host.contains('youtu.be')) {
      return url;
    }

    String? videoId;
    if (host.contains('youtu.be')) {
      videoId = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'shorts') {
      videoId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    } else if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'watch') {
      videoId = uri.queryParameters['v'];
    }

    if (videoId == null || videoId.trim().isEmpty) {
      return uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'autoplay': '1',
          'mute': '0',
        },
      ).toString();
    }

    return Uri.https('www.youtube.com', '/watch', {
      'v': videoId,
      'autoplay': '1',
      'mute': '0',
    }).toString();
  }

  Future<_AlarmSoundSelection?> _showAlarmSoundDialog({
    required String initialSound,
  }) async {
    var selectedSound = initialSound;

    return showDialog<_AlarmSoundSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FutureBuilder<List<_AlarmAffirmationLink>>(
        future: _loadClockAlarmLinks(),
        builder: (context, snapshot) {
          final affirmationLinks =
              snapshot.data ?? const <_AlarmAffirmationLink>[];

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Wybierz dźwięk'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        value: 'alert',
                        groupValue: selectedSound,
                        onChanged: (value) {
                          setDialogState(
                              () => selectedSound = value ?? 'alert');
                        },
                        title: const Text('Dźwięk alarmu'),
                        secondary:
                            const Icon(Icons.notifications_active_outlined),
                      ),
                      RadioListTile<String>(
                        value: 'none',
                        groupValue: selectedSound,
                        onChanged: (value) {
                          setDialogState(() => selectedSound = value ?? 'none');
                        },
                        title: const Text('Bez dźwięku'),
                        subtitle: const Text('Tylko wyskakujące przypomnienie'),
                        secondary: const Icon(Icons.notifications_none_rounded),
                      ),
                      for (final link in affirmationLinks)
                        RadioListTile<String>(
                          value: link.value,
                          groupValue: selectedSound,
                          onChanged: (value) {
                            setDialogState(
                                () => selectedSound = value ?? 'alert');
                          },
                          title: Text(link.title),
                          subtitle: const Text('Afirmacja z linku'),
                          secondary:
                              const Icon(Icons.play_circle_outline_rounded),
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
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _AlarmSoundSelection(
                          value: selectedSound,
                          label: _alarmSoundLabel(
                            selectedSound,
                            affirmationLinks: affirmationLinks,
                          ),
                        ),
                      );
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCalendarDialog() async {
    final rawTasks = Hive.box('my_clock_tasks').values.toList();

    await showDialog<void>(
      context: context,
      builder: (_) => _ClockCalendarDialog(
        initialMonth: DateTime(_now.year, _now.month),
        tasks: rawTasks,
        today: _now,
        titleForItem: _calendarTitleFromItem,
        tasksForDate: (date) => _taskItemsForDate(rawTasks, date),
        monthName: _monthName,
        weekdayName: _weekdayName,
      ),
    );
  }

  Widget _buildMyTasksPanel(
    Box box, {
    double maxHeight = 190,
  }) {
    final items = box.values.toList();
    final selectedTaskIndexes = ValueNotifier<Set<int>>({});

    return _ClockPanel(
      title: 'Moje zadania',
      maxHeight: maxHeight,
      actionBelowTitle: true,
      action: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          ValueListenableBuilder<Set<int>>(
            valueListenable: selectedTaskIndexes,
            builder: (context, selected, _) {
              return IconButton(
                tooltip: 'Usuń',
                icon: const Icon(Icons.delete_outline),
                color: selected.isEmpty ? Colors.white30 : Colors.white,
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final confirmed = await confirmDeleteDialog(context);
                        if (!confirmed) {
                          return;
                        }

                        final indexes = selected.toList()
                          ..sort((a, b) => b.compareTo(a));
                        for (final index in indexes) {
                          if (index >= 0 && index < box.length) {
                            await box.deleteAt(index);
                          }
                        }
                        selectedTaskIndexes.value = <int>{};
                      },
              );
            },
          ),
          FilledButton.icon(
            onPressed: _showCreateWakeUpDialog,
            icon: const Icon(Icons.alarm_add_rounded, size: 20),
            label: const Text(
              'Budzenie',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00B8D9),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _showCreateCustomTaskDialog,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Dodaj zadanie',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7A5CFF),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      child: items.isEmpty
          ? const _EmptyPanelText(
              text:
                  'Dodaj pierwsze zadanie albo wybierz element z zakładki „Dodane”.',
            )
          : _MyTasksList(
              items: items,
              now: _now,
              selectedIndexes: selectedTaskIndexes,
              onEditTask: _showEditMyTaskDialog,
            ),
    );
  }

  Future<void> _showAddToClockOptions(Map<String, dynamic> source) async {
    final hasProtocol = await ClockProtocolLoader.hasProtocolForImagePath(
      source['imagePath'] as String? ?? '',
    );
    final initialDayLimit = await ClockProtocolLoader.dayLimitForImagePath(
      source['imagePath'] as String? ?? '',
    );
    final daysController = TextEditingController(
      text: initialDayLimit == null ? '' : '$initialDayLimit',
    );
    DateTime? selectedDate;
    var addDaily = !hasProtocol && initialDayLimit != null;
    var selectedAlarmSound = 'alert';
    var selectedAlarmSoundLabel = 'Dźwięk alarmu';
    var selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
    var selectedStarts = <DateTime>[];

    final result = await showDialog<_ProtocolAddChoice>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('+ Zadanie'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ustaw',
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDialog<DateTime>(
                        context: context,
                        builder: (_) => _ProtocolStartDateDialog(
                          initialDate: selectedDate ?? _now,
                          monthName: _monthName,
                        ),
                      );

                      if (date == null || !context.mounted) {
                        return;
                      }

                      final timeSelection =
                          await showDialog<_ProtocolTimeSelection>(
                        context: context,
                        builder: (_) => _ProtocolStartTimeDialog(
                          initialTime: TimeOfDay(
                            hour: selectedStarts.isEmpty
                                ? _now.hour
                                : selectedStarts.first.hour,
                            minute: selectedStarts.isEmpty
                                ? _now.minute
                                : selectedStarts.first.minute,
                          ),
                          initialExtraTimes: selectedStarts
                              .skip(1)
                              .map(
                                (start) => TimeOfDay(
                                  hour: start.hour,
                                  minute: start.minute,
                                ),
                              )
                              .toList(),
                        ),
                      );

                      if (timeSelection == null) {
                        return;
                      }

                      if (!context.mounted) {
                        return;
                      }

                      final alarmSound = await _showAlarmSoundDialog(
                        initialSound: selectedAlarmSound,
                      );

                      if (alarmSound == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedDate = date;
                        selectedAlarmSound = alarmSound.value;
                        selectedAlarmSoundLabel = alarmSound.label;
                        selectedStarts = timeSelection.times
                            .map(
                              (time) => DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            )
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Zacznij'),
                  ),
                  if (selectedStarts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Start: ${_formatDate(selectedStarts.first)} ${selectedStarts.map((start) => _formatTimeOfDay(TimeOfDay(hour: start.hour, minute: start.minute))).join(', ')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Dźwięk: $selectedAlarmSoundLabel'),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wpisz ilość dni',
                      hintText: 'opcjonalnie',
                    ),
                  ),
                  if (!hasProtocol) ...[
                    CheckboxListTile(
                      value: addDaily,
                      onChanged: (value) {
                        setDialogState(() {
                          addDaily = value ?? false;
                          if (addDaily) {
                            selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
                          }
                        });
                      },
                      title: const Text('Dodaj codziennie'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (addDaily)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            for (final weekday in const [
                              (1, 'Pn'),
                              (2, 'Wt'),
                              (3, 'Śr'),
                              (4, 'Cz'),
                              (5, 'Pt'),
                              (6, 'So'),
                              (7, 'Nd'),
                            ])
                              FilterChip(
                                label: Text(
                                  weekday.$2,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: selectedWeekdays.contains(
                                  weekday.$1,
                                ),
                                showCheckmark: false,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding: EdgeInsets.zero,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedWeekdays.add(weekday.$1);
                                    } else {
                                      selectedWeekdays.remove(weekday.$1);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
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
                  if (selectedStarts.isEmpty) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Dodaj ustawienia'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final days = int.tryParse(daysController.text.trim());
                  final dayLimit = days == null || days < 1
                      ? (hasProtocol ? 1 : null)
                      : days;
                  Navigator.pop(
                    context,
                    _ProtocolAddChoice.days(
                      dayLimit,
                      starts: selectedStarts,
                      addDaily: addDaily,
                      weekdays: selectedWeekdays.toList()..sort(),
                      alarmSound: selectedAlarmSound,
                      alarmSoundTitle: selectedAlarmSoundLabel,
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );

    daysController.dispose();

    if (result == null) {
      return;
    }

    final imagePath = source['imagePath'] as String? ?? '';

    for (var index = 0; index < result.starts.length; index++) {
      if (hasProtocol) {
        await _addProtocolFromSource(
          source,
          permanent: result.permanent,
          dayLimit: result.dayLimit,
          start: result.starts[index],
          alarmSound: result.alarmSound,
          alarmSoundTitle: result.alarmSoundTitle,
          clearExisting: index == 0,
        );
      } else {
        await _addSingleGalleryTaskFromSource(
          source,
          permanent: result.permanent,
          dayLimit: result.dayLimit,
          start: result.starts[index],
          addDaily: result.addDaily,
          weekdays: result.weekdays,
          alarmSound: result.alarmSound,
          alarmSoundTitle: result.alarmSoundTitle,
          clearExisting: index == 0,
        );
      }
    }
  }

  Future<void> _addSingleGalleryTaskFromSource(
    Map<String, dynamic> source, {
    required bool permanent,
    required int? dayLimit,
    required DateTime start,
    required bool addDaily,
    required List<int> weekdays,
    required String alarmSound,
    required String alarmSoundTitle,
    bool clearExisting = true,
  }) async {
    final imagePath = source['imagePath'] as String? ?? '';
    final clockIconPath = clockIconPathForImagePath(imagePath);
    final sourceId = 'single:${imagePath.isEmpty ? clockIconPath : imagePath}';
    final box = Hive.box('my_clock_tasks');
    final startDate = DateTime(start.year, start.month, start.day)
        .toIso8601String()
        .substring(0, 10);
    final startTime = _formatTimeOfDay(
      TimeOfDay(hour: start.hour, minute: start.minute),
    );

    if (clearExisting) {
      final oldKeys = <dynamic>[];
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is Map && value['source'] == sourceId) {
          oldKeys.add(key);
        }
      }

      for (final key in oldKeys) {
        await box.delete(key);
      }
    }

    await box.add({
      'title': clockTitleForImagePath(imagePath),
      'day': permanent
          ? 'Stałe'
          : addDaily
              ? dayLimit == null
                  ? 'Codziennie'
                  : 'Dni 1-$dayLimit'
              : 'Dziś',
      'time': startTime,
      'imagePath': imagePath,
      'clockIconPath': clockIconPath,
      'galleryImages': source['galleryImages'],
      'source': sourceId,
      'alarmSound': alarmSound,
      'alarmSoundTitle': alarmSoundTitle,
      if (!permanent && addDaily) 'repeatDaily': true,
      if (!permanent && addDaily && dayLimit != null) 'dayFrom': 1,
      if (!permanent && addDaily && dayLimit != null) 'dayTo': dayLimit,
      if (!permanent && addDaily && weekdays.length < 7) 'weekdays': weekdays,
      if (!permanent) 'startDate': startDate,
      if (!permanent) 'startTime': startTime,
    });

    if (mounted) {
      setState(() => _weekView = true);
    }
  }

  Future<void> _addProtocolFromSource(
    Map<String, dynamic> source, {
    required bool permanent,
    required int? dayLimit,
    required DateTime start,
    required String alarmSound,
    required String alarmSoundTitle,
    bool clearExisting = true,
  }) async {
    final imagePath = source['imagePath'] as String? ?? '';
    final clockIconPath = clockIconPathForImagePath(imagePath);
    final protocolPath =
        ClockProtocolLoader.protocolAssetPathForImagePath(imagePath);
    late final List<Map<String, dynamic>> protocolTasks;

    try {
      protocolTasks = await ClockProtocolLoader.loadTasksForImagePath(
        imagePath,
      );
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Brak pliku kuracji'),
          content: Text('Zegar nie znalazł pliku:\n$protocolPath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        ),
      );
      return;
    }

    final box = Hive.box('my_clock_tasks');
    final oldProtocolKeys = <dynamic>[];
    final startDate = DateTime(start.year, start.month, start.day)
        .toIso8601String()
        .substring(0, 10);
    final startTime = _formatTimeOfDay(
      TimeOfDay(hour: start.hour, minute: start.minute),
    );

    if (clearExisting) {
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is Map && value['source'] == protocolPath) {
          oldProtocolKeys.add(key);
        }
      }

      for (final key in oldProtocolKeys) {
        await box.delete(key);
      }
    }

    for (final task in protocolTasks) {
      final preparedTask = _prepareProtocolTask(
        task,
        permanent: permanent,
        dayLimit: dayLimit,
      );
      if (preparedTask == null) {
        continue;
      }

      await box.add({
        ...preparedTask,
        'imagePath': imagePath,
        'clockIconPath': clockIconPath,
        'galleryImages': source['galleryImages'],
        'alarmSound': alarmSound,
        'alarmSoundTitle': alarmSoundTitle,
        if (!permanent) 'startDate': startDate,
        if (!permanent) 'startTime': startTime,
      });
    }

    if (mounted) {
      setState(() => _weekView = true);
    }
  }

  Map<String, dynamic>? _prepareProtocolTask(
    Map<String, dynamic> task, {
    required bool permanent,
    required int? dayLimit,
  }) {
    final prepared = Map<String, dynamic>.from(task);

    if (permanent) {
      prepared.remove('dayFrom');
      prepared.remove('dayTo');
      prepared['day'] = 'Stałe';
      return prepared;
    }

    if (dayLimit == null) {
      return prepared;
    }

    final dayFrom = _positiveIntFromItem(prepared['dayFrom']) ?? 1;
    final dayTo = _positiveIntFromItem(prepared['dayTo']) ?? dayLimit;

    if (dayFrom > dayLimit) {
      return null;
    }

    prepared['dayFrom'] = dayFrom;
    prepared['dayTo'] = dayTo > dayLimit ? dayLimit : dayTo;
    prepared['day'] = 'Dni $dayFrom-${prepared['dayTo']}';

    return prepared;
  }

  Future<void> _showCreateWakeUpDialog() async {
    final daysController = TextEditingController();
    DateTime? selectedDate;
    var addDaily = false;
    var selectedAlarmSound = 'alert';
    var selectedAlarmSoundLabel = 'Dźwięk alarmu';
    var selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
    var selectedStarts = <DateTime>[];

    final result = await showDialog<_ProtocolAddChoice>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Budzenie'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ustaw'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDialog<DateTime>(
                        context: context,
                        builder: (_) => _ProtocolStartDateDialog(
                          initialDate: selectedDate ?? _now,
                          monthName: _monthName,
                        ),
                      );

                      if (date == null || !context.mounted) {
                        return;
                      }

                      final timeSelection =
                          await showDialog<_ProtocolTimeSelection>(
                        context: context,
                        builder: (_) => _ProtocolStartTimeDialog(
                          initialTime: TimeOfDay(
                            hour: selectedStarts.isEmpty
                                ? _now.hour
                                : selectedStarts.first.hour,
                            minute: selectedStarts.isEmpty
                                ? _now.minute
                                : selectedStarts.first.minute,
                          ),
                          initialExtraTimes: selectedStarts
                              .skip(1)
                              .map(
                                (start) => TimeOfDay(
                                  hour: start.hour,
                                  minute: start.minute,
                                ),
                              )
                              .toList(),
                        ),
                      );

                      if (timeSelection == null || !context.mounted) {
                        return;
                      }

                      final alarmSound = await _showAlarmSoundDialog(
                        initialSound: selectedAlarmSound,
                      );

                      if (alarmSound == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedDate = date;
                        selectedAlarmSound = alarmSound.value;
                        selectedAlarmSoundLabel = alarmSound.label;
                        selectedStarts = timeSelection.times
                            .map(
                              (time) => DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            )
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Zacznij'),
                  ),
                  if (selectedStarts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Start: ${_formatDate(selectedStarts.first)} ${selectedStarts.map((start) => _formatTimeOfDay(TimeOfDay(hour: start.hour, minute: start.minute))).join(', ')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Dźwięk: $selectedAlarmSoundLabel'),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wpisz ilość dni',
                      hintText: 'opcjonalnie',
                    ),
                  ),
                  CheckboxListTile(
                    value: addDaily,
                    onChanged: (value) {
                      setDialogState(() {
                        addDaily = value ?? false;
                        if (addDaily) {
                          selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
                        }
                      });
                    },
                    title: const Text('Dodaj codziennie'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (addDaily)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          for (final weekday in const [
                            (1, 'Pn'),
                            (2, 'Wt'),
                            (3, 'Śr'),
                            (4, 'Cz'),
                            (5, 'Pt'),
                            (6, 'So'),
                            (7, 'Nd'),
                          ])
                            FilterChip(
                              label: Text(
                                weekday.$2,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selectedWeekdays.contains(weekday.$1),
                              showCheckmark: false,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              padding: EdgeInsets.zero,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedWeekdays.add(weekday.$1);
                                  } else {
                                    selectedWeekdays.remove(weekday.$1);
                                  }
                                });
                              },
                            ),
                        ],
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
                  if (selectedStarts.isEmpty) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Dodaj ustawienia'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final days = int.tryParse(daysController.text.trim());
                  Navigator.pop(
                    context,
                    _ProtocolAddChoice.days(
                      days == null || days < 1 ? null : days,
                      starts: selectedStarts,
                      addDaily: addDaily,
                      weekdays: selectedWeekdays.toList()..sort(),
                      alarmSound: selectedAlarmSound,
                      alarmSoundTitle: selectedAlarmSoundLabel,
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );

    daysController.dispose();

    if (result == null) {
      return;
    }

    for (final start in result.starts) {
      await _addWakeUpTask(
        start: start,
        addDaily: result.addDaily,
        dayLimit: result.dayLimit,
        weekdays: result.weekdays,
        alarmSound: result.alarmSound,
        alarmSoundTitle: result.alarmSoundTitle,
      );
    }
  }

  Future<void> _addWakeUpTask({
    required DateTime start,
    required bool addDaily,
    required int? dayLimit,
    required List<int> weekdays,
    required String alarmSound,
    required String alarmSoundTitle,
  }) async {
    final startDate = DateTime(start.year, start.month, start.day)
        .toIso8601String()
        .substring(0, 10);
    final startTime = _formatTimeOfDay(
      TimeOfDay(hour: start.hour, minute: start.minute),
    );

    await Hive.box('my_clock_tasks').add({
      'title': 'Budzenie',
      'day': addDaily
          ? dayLimit == null
              ? 'Codziennie'
              : 'Dni 1-$dayLimit'
          : 'Dziś',
      'time': startTime,
      'imagePath': '',
      'clockIconPath': '',
      'galleryImages': const <String>[],
      'source': 'wake:$startDate:$startTime',
      'alarmSound': alarmSound,
      'alarmSoundTitle': alarmSoundTitle,
      if (addDaily) 'repeatDaily': true,
      if (addDaily && dayLimit != null) 'dayFrom': 1,
      if (addDaily && dayLimit != null) 'dayTo': dayLimit,
      if (addDaily && weekdays.length < 7) 'weekdays': weekdays,
      'startDate': startDate,
      'startTime': startTime,
    });

    if (mounted) {
      setState(() => _weekView = true);
    }
  }

  Future<void> _showCreateCustomTaskDialog() async {
    final titleController = TextEditingController();
    final daysController = TextEditingController();
    DateTime? selectedDate;
    var addDaily = false;
    var selectedAlarmSound = 'alert';
    var selectedAlarmSoundLabel = 'Dźwięk alarmu';
    var selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
    var selectedStarts = <DateTime>[];

    final result = await showDialog<_ProtocolAddChoice>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('+ Zadanie'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ustaw'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDialog<DateTime>(
                        context: context,
                        builder: (_) => _ProtocolStartDateDialog(
                          initialDate: selectedDate ?? _now,
                          monthName: _monthName,
                        ),
                      );

                      if (date == null || !context.mounted) {
                        return;
                      }

                      final timeSelection =
                          await showDialog<_ProtocolTimeSelection>(
                        context: context,
                        builder: (_) => _ProtocolStartTimeDialog(
                          initialTime: TimeOfDay(
                            hour: selectedStarts.isEmpty
                                ? _now.hour
                                : selectedStarts.first.hour,
                            minute: selectedStarts.isEmpty
                                ? _now.minute
                                : selectedStarts.first.minute,
                          ),
                          initialExtraTimes: selectedStarts
                              .skip(1)
                              .map(
                                (start) => TimeOfDay(
                                  hour: start.hour,
                                  minute: start.minute,
                                ),
                              )
                              .toList(),
                        ),
                      );

                      if (timeSelection == null || !context.mounted) {
                        return;
                      }

                      final alarmSound = await _showAlarmSoundDialog(
                        initialSound: selectedAlarmSound,
                      );

                      if (alarmSound == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedDate = date;
                        selectedAlarmSound = alarmSound.value;
                        selectedAlarmSoundLabel = alarmSound.label;
                        selectedStarts = timeSelection.times
                            .map(
                              (time) => DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            )
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Zacznij'),
                  ),
                  if (selectedStarts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Start: ${_formatDate(selectedStarts.first)} ${selectedStarts.map((start) => _formatTimeOfDay(TimeOfDay(hour: start.hour, minute: start.minute))).join(', ')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Dźwięk: $selectedAlarmSoundLabel'),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wpisz ilość dni',
                      hintText: 'opcjonalnie',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Wpisz zadanie'),
                    textInputAction: TextInputAction.done,
                  ),
                  CheckboxListTile(
                    value: addDaily,
                    onChanged: (value) {
                      setDialogState(() {
                        addDaily = value ?? false;
                        if (addDaily) {
                          selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
                        }
                      });
                    },
                    title: const Text('Dodaj codziennie'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (addDaily)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          for (final weekday in const [
                            (1, 'Pn'),
                            (2, 'Wt'),
                            (3, 'Śr'),
                            (4, 'Cz'),
                            (5, 'Pt'),
                            (6, 'So'),
                            (7, 'Nd'),
                          ])
                            FilterChip(
                              label: Text(
                                weekday.$2,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selectedWeekdays.contains(weekday.$1),
                              showCheckmark: false,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              padding: EdgeInsets.zero,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedWeekdays.add(weekday.$1);
                                  } else {
                                    selectedWeekdays.remove(weekday.$1);
                                  }
                                });
                              },
                            ),
                        ],
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
                  if (selectedStarts.isEmpty) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Dodaj ustawienia'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final days = int.tryParse(daysController.text.trim());
                  Navigator.pop(
                    context,
                    _ProtocolAddChoice.days(
                      days == null || days < 1 ? null : days,
                      starts: selectedStarts,
                      addDaily: addDaily,
                      weekdays: selectedWeekdays.toList()..sort(),
                      alarmSound: selectedAlarmSound,
                      alarmSoundTitle: selectedAlarmSoundLabel,
                    ),
                  );
                },
                child: const Text('Dodaj'),
              ),
            ],
          );
        },
      ),
    );

    final title = titleController.text.trim();
    titleController.dispose();
    daysController.dispose();

    if (result == null || title.isEmpty) {
      return;
    }

    for (final start in result.starts) {
      final startDate = DateTime(start.year, start.month, start.day)
          .toIso8601String()
          .substring(0, 10);
      final startTime = _formatTimeOfDay(
        TimeOfDay(hour: start.hour, minute: start.minute),
      );

      await Hive.box('my_clock_tasks').add({
        'title': title,
        'day': result.addDaily
            ? result.dayLimit == null
                ? 'Codziennie'
                : 'Dni 1-${result.dayLimit}'
            : 'Dziś',
        'time': startTime,
        'imagePath': '',
        'clockIconPath': '',
        'galleryImages': const <String>[],
        'source': 'custom:$title:$startDate:$startTime',
        'alarmSound': result.alarmSound,
        'alarmSoundTitle': result.alarmSoundTitle,
        if (result.addDaily) 'repeatDaily': true,
        if (result.addDaily && result.dayLimit != null) 'dayFrom': 1,
        if (result.addDaily && result.dayLimit != null)
          'dayTo': result.dayLimit,
        if (result.addDaily && result.weekdays.length < 7)
          'weekdays': result.weekdays,
        'startDate': startDate,
        'startTime': startTime,
      });
    }

    if (mounted) {
      setState(() => _weekView = true);
    }
  }

  Future<void> _showEditMyTaskDialog(
    int taskIndex,
    Map<String, dynamic> item,
  ) async {
    final title = _taskTitleFromItem(item);
    final dayLimit = _positiveIntFromItem(item['dayTo']);
    final daysController = TextEditingController(
      text: dayLimit == null ? '' : '$dayLimit',
    );
    final initialDate = _startDateForItem(item) ?? _now;
    final initialTime = _timeFromItem(item['time'] as String? ?? '08:00');
    DateTime? selectedDate = initialDate;
    var addDaily = item['repeatDaily'] == true ||
        _positiveIntFromItem(item['dayFrom']) != null ||
        _positiveIntFromItem(item['dayTo']) != null;
    var selectedAlarmSound = item['alarmSound'] as String? ?? 'alert';
    var selectedAlarmSoundLabel =
        item['alarmSoundTitle'] as String? ?? 'Dźwięk alarmu';
    var selectedWeekdays = _weekdaysFromItem(item).toSet();
    var selectedStarts = <DateTime>[
      DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        initialTime.hour,
        initialTime.minute,
      ),
    ];

    final result = await showDialog<_ProtocolAddChoice>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Zmień ustawienia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ustaw'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDialog<DateTime>(
                        context: context,
                        builder: (_) => _ProtocolStartDateDialog(
                          initialDate: selectedDate ?? _now,
                          monthName: _monthName,
                        ),
                      );

                      if (date == null || !context.mounted) {
                        return;
                      }

                      final timeSelection =
                          await showDialog<_ProtocolTimeSelection>(
                        context: context,
                        builder: (_) => _ProtocolStartTimeDialog(
                          initialTime: TimeOfDay(
                            hour: selectedStarts.first.hour,
                            minute: selectedStarts.first.minute,
                          ),
                          initialExtraTimes: const [],
                        ),
                      );

                      if (timeSelection == null || !context.mounted) {
                        return;
                      }

                      final alarmSound = await _showAlarmSoundDialog(
                        initialSound: selectedAlarmSound,
                      );

                      if (alarmSound == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedDate = date;
                        selectedAlarmSound = alarmSound.value;
                        selectedAlarmSoundLabel = alarmSound.label;
                        selectedStarts = timeSelection.times
                            .take(1)
                            .map(
                              (time) => DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            )
                            .toList();
                      });
                    },
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Zacznij'),
                  ),
                  if (selectedStarts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Start: ${_formatDate(selectedStarts.first)} ${_formatTimeOfDay(TimeOfDay(hour: selectedStarts.first.hour, minute: selectedStarts.first.minute))}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Dźwięk: $selectedAlarmSoundLabel'),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wpisz ilość dni',
                      hintText: 'opcjonalnie',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  CheckboxListTile(
                    value: addDaily,
                    onChanged: (value) {
                      setDialogState(() {
                        addDaily = value ?? false;
                        if (addDaily) {
                          selectedWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
                        }
                      });
                    },
                    title: const Text('Dodaj codziennie'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (addDaily)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          for (final weekday in const [
                            (1, 'Pn'),
                            (2, 'Wt'),
                            (3, 'Śr'),
                            (4, 'Cz'),
                            (5, 'Pt'),
                            (6, 'So'),
                            (7, 'Nd'),
                          ])
                            FilterChip(
                              label: Text(
                                weekday.$2,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selectedWeekdays.contains(weekday.$1),
                              showCheckmark: false,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              padding: EdgeInsets.zero,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedWeekdays.add(weekday.$1);
                                  } else {
                                    selectedWeekdays.remove(weekday.$1);
                                  }
                                });
                              },
                            ),
                        ],
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
                onPressed: () {
                  final days = int.tryParse(daysController.text.trim());
                  Navigator.pop(
                    context,
                    _ProtocolAddChoice.days(
                      days == null || days < 1 ? null : days,
                      starts: selectedStarts,
                      addDaily: addDaily,
                      weekdays: selectedWeekdays.toList()..sort(),
                      alarmSound: selectedAlarmSound,
                      alarmSoundTitle: selectedAlarmSoundLabel,
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );

    daysController.dispose();

    if (result == null || title.isEmpty || result.starts.isEmpty) {
      return;
    }

    final start = result.starts.first;
    final startDate = DateTime(start.year, start.month, start.day)
        .toIso8601String()
        .substring(0, 10);
    final startTime = _formatTimeOfDay(
      TimeOfDay(hour: start.hour, minute: start.minute),
    );
    final updated = Map<String, dynamic>.from(item)
      ..remove('repeatDaily')
      ..remove('dayFrom')
      ..remove('dayTo')
      ..remove('weekdays')
      ..remove('startDate')
      ..remove('startTime')
      ..['title'] = title
      ..['day'] = result.addDaily
          ? result.dayLimit == null
              ? 'Codziennie'
              : 'Dni 1-${result.dayLimit}'
          : 'Dziś'
      ..['time'] = startTime
      ..['alarmSound'] = result.alarmSound
      ..['alarmSoundTitle'] = result.alarmSoundTitle
      ..['startDate'] = startDate
      ..['startTime'] = startTime;

    if (result.addDaily) {
      updated['repeatDaily'] = true;
    }
    if (result.addDaily && result.dayLimit != null) {
      updated['dayFrom'] = 1;
      updated['dayTo'] = result.dayLimit;
    }
    if (result.addDaily && result.weekdays.length < 7) {
      updated['weekdays'] = result.weekdays;
    }

    final box = Hive.box('my_clock_tasks');
    if (taskIndex >= 0 && taskIndex < box.length) {
      await box.putAt(taskIndex, updated);
    }

    if (mounted) {
      setState(() => _weekView = true);
    }
  }

  Widget _buildAddedPanel(
    Box box, {
    double maxHeight = 190,
  }) {
    final items = box.values.toList();
    final selectedAddedIndexes = ValueNotifier<Set<int>>({});

    return _ClockPanel(
      title: 'Dodane z galerii',
      maxHeight: maxHeight,
      action: ValueListenableBuilder<Set<int>>(
        valueListenable: selectedAddedIndexes,
        builder: (context, selected, _) {
          return IconButton(
            tooltip: 'Usuń',
            icon: const Icon(Icons.delete_outline),
            color: selected.isEmpty ? Colors.white30 : Colors.white,
            onPressed: selected.isEmpty
                ? null
                : () async {
                    final confirmed = await confirmDeleteDialog(context);
                    if (!confirmed) {
                      return;
                    }

                    final indexes = selected.toList()
                      ..sort((a, b) => b.compareTo(a));
                    for (final index in indexes) {
                      if (index >= 0 && index < box.length) {
                        await box.deleteAt(index);
                      }
                    }
                    selectedAddedIndexes.value = <int>{};
                  },
          );
        },
      ),
      child: items.isEmpty
          ? const _EmptyPanelText(
              text:
                  'Dodaj element z galerii przez pinezkę i wybierz „Inżynieria mojego czasu”.',
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  ValueListenableBuilder<Set<int>>(
                    valueListenable: selectedAddedIndexes,
                    builder: (context, selected, _) {
                      final allIndexes = List<int>.generate(
                        items.length,
                        (index) => index,
                      ).toSet();
                      final allSelected = allIndexes.isNotEmpty &&
                          allIndexes.every(selected.contains);

                      return _SelectAllTasksTile(
                        selected: allSelected,
                        onChanged: (value) {
                          selectedAddedIndexes.value =
                              value == true ? allIndexes : <int>{};
                        },
                      );
                    },
                  ),
                  for (var index = 0; index < items.length; index++)
                    FutureBuilder<bool>(
                      future: ClockProtocolLoader.hasProtocolForImagePath(
                        (Map<String, dynamic>.from(items[index])['imagePath']
                                as String?) ??
                            '',
                      ),
                      builder: (context, snapshot) {
                        final item = Map<String, dynamic>.from(items[index]);
                        final hasProtocol = snapshot.data ?? false;

                        return _AddedGalleryTile(
                          item: item,
                          hasProtocol: hasProtocol,
                          onCreateProtocol: () => _showAddToClockOptions(item),
                          selectedIndexes: selectedAddedIndexes,
                          originalIndex: index,
                        );
                      },
                    ),
                ],
              ),
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

  List<ClockTaskModel> _myTasksFromBox(
    List<dynamic> values, {
    required DateTime now,
    required bool includeWholeWeek,
  }) {
    final tasks = <ClockTaskModel>[];

    for (var index = 0; index < values.length; index++) {
      final raw = values[index];
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);
      if (!includeWholeWeek && !_isTaskVisibleToday(item, now)) {
        continue;
      }

      tasks.add(
        ClockTaskModel(
          id: _taskOrbitKey(item, index),
          number: index + 1,
          title: _taskTitleFromItem(item),
          day: item['day'] as String? ?? 'Dziś',
          time: item['time'] as String? ?? '08:00',
          icon: clockIconForImagePath(item['imagePath'] as String? ?? ''),
          color: _colorForIndex(index),
          imagePath: _taskImagePath(item),
          details: item['details'] as String?,
        ),
      );
    }

    return tasks;
  }

  String _taskOrbitKey(Map<String, dynamic> item, int index) {
    final sourceId = '${item['sourceId'] ?? ''}';
    final imagePath = '${item['imagePath'] ?? ''}';
    final title = _taskTitleFromItem(item);
    final time = '${item['time'] ?? '08:00'}';
    final day = '${item['day'] ?? ''}';

    return '$index|$sourceId|$imagePath|$title|$day|$time';
  }

  String _taskImagePath(Map<String, dynamic> item) {
    final imagePath = item['imagePath'] as String? ?? '';
    final clockIconPath = item['clockIconPath'] as String?;

    if (clockIconPath == null || clockIconPath.contains('/clock_icons/')) {
      return clockIconPathForImagePath(imagePath);
    }

    return clockIconPath;
  }

  bool _isTaskVisibleToday(Map<String, dynamic> item, DateTime now) {
    return _isTaskVisibleOnDate(item, now, today: now);
  }

  bool _isTaskVisibleOnDate(
    Map<String, dynamic> item,
    DateTime date, {
    required DateTime today,
  }) {
    if (!_isWithinDescriptiveDayRange(item, date, today: today)) {
      return false;
    }

    final weekdays = item['weekdays'];
    if (weekdays is List) {
      return weekdays
          .map((value) => int.tryParse('$value'))
          .whereType<int>()
          .contains(date.weekday);
    }

    if (_hasDescriptiveDayRange(item)) {
      return _isProtocolTask(item) || item['repeatDaily'] == true;
    }

    final startDate = _startDateForItem(item);
    if (item['repeatDaily'] != true && startDate != null) {
      return _sameDate(date, startDate);
    }

    final day = (item['day'] as String? ?? '').trim().toLowerCase();
    if (day.isEmpty || day == 'dziś' || day == 'dzis') {
      return _sameDate(date, today);
    }

    if (day == 'codziennie') {
      return true;
    }

    return _weekdayName(date.weekday).toLowerCase() == day;
  }

  bool _hasDescriptiveDayRange(Map<String, dynamic> item) {
    return _positiveIntFromItem(item['dayFrom']) != null ||
        _positiveIntFromItem(item['dayTo']) != null;
  }

  bool _isProtocolTask(Map<String, dynamic> item) {
    final source = item['source'] as String?;
    return source != null && source.startsWith('assets/clock_protocols/');
  }

  bool _isWithinDescriptiveDayRange(
    Map<String, dynamic> item,
    DateTime date, {
    required DateTime today,
  }) {
    final dayFrom = _positiveIntFromItem(item['dayFrom']);
    final dayTo = _positiveIntFromItem(item['dayTo']);

    if (dayFrom == null && dayTo == null) {
      return true;
    }

    final start = _startDateForItem(item) ??
        DateTime(
          today.year,
          today.month,
          today.day,
        );
    final current = DateTime(date.year, date.month, date.day);
    final protocolDay = current.difference(start).inDays + 1;

    if (dayFrom != null && protocolDay < dayFrom) {
      return false;
    }

    if (dayTo != null && protocolDay > dayTo) {
      return false;
    }

    return protocolDay >= 1;
  }

  DateTime? _startDateForItem(Map<String, dynamic> item) {
    final raw = item['startDate'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  TimeOfDay _timeFromItem(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return TimeOfDay(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  List<int> _weekdaysFromItem(Map<String, dynamic> item) {
    final weekdays = item['weekdays'];
    if (weekdays is! List) {
      return const <int>[1, 2, 3, 4, 5, 6, 7];
    }

    final parsed = weekdays
        .map((value) => int.tryParse('$value'))
        .whereType<int>()
        .where((value) => value >= 1 && value <= 7)
        .toSet()
        .toList()
      ..sort();

    return parsed.isEmpty ? const <int>[1, 2, 3, 4, 5, 6, 7] : parsed;
  }

  List<Map<String, dynamic>> _taskItemsForDate(
    List<dynamic> rawTasks,
    DateTime date,
  ) {
    final items = <Map<String, dynamic>>[];

    for (final raw in rawTasks) {
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);
      if (_isTaskVisibleOnDate(item, date, today: _now)) {
        items.add(item);
      }
    }

    items.sort((a, b) {
      return _minutesFromTime(a['time'] as String? ?? '08:00')
          .compareTo(_minutesFromTime(b['time'] as String? ?? '08:00'));
    });

    return items;
  }

  String _calendarTitleFromItem(Map<String, dynamic> item) {
    final imagePath = item['imagePath'] as String? ?? '';
    final generatedTitle = clockTitleForImagePath(imagePath);

    if (imagePath.isNotEmpty && generatedTitle.isNotEmpty) {
      return generatedTitle;
    }

    return _taskTitleFromItem(item);
  }

  Future<void> _showTaskDetails(ClockTaskModel task) async {
    final details = task.details?.trim();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${task.time} — ${task.title}'),
        content: SingleChildScrollView(
          child: Text(
            details == null || details.isEmpty ? task.title : details,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
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

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _sameTime(TimeOfDay a, TimeOfDay b) {
  return a.hour == b.hour && a.minute == b.minute;
}

String _assetBaseName(String path) {
  return path.replaceAll('\\', '/').split('/').last.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      );
}

bool _isExternalLinkBase(String base) {
  return RegExp(r'^img[\d_]+_o\d+$').hasMatch(base);
}

String _alarmSoundLabel(
  String sound, {
  List<_AlarmAffirmationLink> affirmationLinks =
      const <_AlarmAffirmationLink>[],
}) {
  if (sound == 'none') {
    return 'Bez dźwięku';
  }

  for (final link in affirmationLinks) {
    if (link.value == sound) {
      return link.title;
    }
  }

  return 'Dźwięk alarmu';
}

class _AlarmAffirmationLink {
  const _AlarmAffirmationLink({
    required this.title,
    required this.url,
    this.value = '',
  });

  final String title;
  final String url;
  final String value;

  _AlarmAffirmationLink copyWith({
    String? title,
    String? url,
    String? value,
  }) {
    return _AlarmAffirmationLink(
      title: title ?? this.title,
      url: url ?? this.url,
      value: value ?? this.value,
    );
  }
}

class _AlarmSoundSelection {
  const _AlarmSoundSelection({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class _ProtocolAddChoice {
  const _ProtocolAddChoice.permanent({
    required List<DateTime> starts,
  })  : permanent = true,
        dayLimit = null,
        starts = starts,
        addDaily = false,
        weekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
        alarmSound = 'alert',
        alarmSoundTitle = 'Dźwięk alarmu';

  const _ProtocolAddChoice.days(
    this.dayLimit, {
    required this.starts,
    this.addDaily = true,
    this.weekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
    this.alarmSound = 'alert',
    this.alarmSoundTitle = 'Dźwięk alarmu',
  }) : permanent = false;

  final bool permanent;
  final int? dayLimit;
  final List<DateTime> starts;
  final bool addDaily;
  final List<int> weekdays;
  final String alarmSound;
  final String alarmSoundTitle;
}

class _ProtocolStartDateDialog extends StatefulWidget {
  const _ProtocolStartDateDialog({
    required this.initialDate,
    required this.monthName,
  });

  final DateTime initialDate;
  final String Function(int month) monthName;

  @override
  State<_ProtocolStartDateDialog> createState() =>
      _ProtocolStartDateDialogState();
}

class _ProtocolStartDateDialogState extends State<_ProtocolStartDateDialog> {
  late DateTime visibleMonth;

  @override
  void initState() {
    super.initState();
    visibleMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingEmptyDays = firstDay.weekday - 1;
    final totalCells = leadingEmptyDays + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return AlertDialog(
      title: const Text('Zacznij'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${widget.monthName(visibleMonth.month)} ${visibleMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                _CalendarPickerWeekday('Pn'),
                _CalendarPickerWeekday('Wt'),
                _CalendarPickerWeekday('Śr'),
                _CalendarPickerWeekday('Cz'),
                _CalendarPickerWeekday('Pt'),
                _CalendarPickerWeekday('So'),
                _CalendarPickerWeekday('Nd'),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingEmptyDays + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(
                  visibleMonth.year,
                  visibleMonth.month,
                  dayNumber,
                );
                final selected = _sameDate(date, widget.initialDate);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, date),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFB44CFF)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? const Color(0xFFB44CFF) : Colors.black12,
                      ),
                    ),
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
      ],
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      visibleMonth = DateTime(
        visibleMonth.year,
        visibleMonth.month + delta,
      );
    });
  }
}

class _CalendarPickerWeekday extends StatelessWidget {
  const _CalendarPickerWeekday(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _ProtocolStartTimeDialog extends StatefulWidget {
  const _ProtocolStartTimeDialog({
    required this.initialTime,
    required this.initialExtraTimes,
  });

  final TimeOfDay initialTime;
  final List<TimeOfDay> initialExtraTimes;

  @override
  State<_ProtocolStartTimeDialog> createState() =>
      _ProtocolStartTimeDialogState();
}

class _ProtocolStartTimeDialogState extends State<_ProtocolStartTimeDialog> {
  late int hour;
  late int minute;
  late final List<TimeOfDay> extraTimes;

  @override
  void initState() {
    super.initState();
    hour = widget.initialTime.hour;
    minute = widget.initialTime.minute;
    extraTimes = List<TimeOfDay>.from(widget.initialExtraTimes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Godzina startu')),
          IconButton(
            tooltip: 'Dodaj kolejną godzinę',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addCurrentTime,
          ),
        ],
      ),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: _WheelPicker(
                      value: hour,
                      max: 23,
                      onChanged: (value) => setState(() => hour = value),
                    ),
                  ),
                  const Text(
                    ':',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  Expanded(
                    child: _WheelPicker(
                      value: minute,
                      max: 59,
                      onChanged: (value) => setState(() => minute = value),
                    ),
                  ),
                ],
              ),
            ),
            if (extraTimes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final time in extraTimes)
                      InputChip(
                        label: Text(_formatTimeOfDay(time)),
                        onDeleted: () {
                          setState(() => extraTimes.remove(time));
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        TextButton(
          onPressed: () {
            final times = <TimeOfDay>[];
            for (final time in [
              TimeOfDay(hour: hour, minute: minute),
              ...extraTimes,
            ]) {
              if (!times.any((saved) => _sameTime(saved, time))) {
                times.add(time);
              }
            }

            Navigator.pop(
              context,
              _ProtocolTimeSelection(times),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  void _addCurrentTime() {
    final selected = TimeOfDay(hour: hour, minute: minute);
    if (extraTimes.any((time) => _sameTime(time, selected))) {
      return;
    }

    setState(() => extraTimes.add(selected));
  }
}

class _ProtocolTimeSelection {
  const _ProtocolTimeSelection(List<TimeOfDay> times) : times = times;

  final List<TimeOfDay> times;
}

class _WheelPicker extends StatelessWidget {
  const _WheelPicker({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: FixedExtentScrollController(initialItem: value),
      itemExtent: 42,
      diameterRatio: 1.35,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: max + 1,
        builder: (context, index) {
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: index == value ? 28 : 21,
                fontWeight: index == value ? FontWeight.w900 : FontWeight.w600,
                color:
                    index == value ? const Color(0xFF7A5CFF) : Colors.black54,
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _ClockCalendarDialog extends StatefulWidget {
  const _ClockCalendarDialog({
    required this.initialMonth,
    required this.tasks,
    required this.today,
    required this.titleForItem,
    required this.tasksForDate,
    required this.monthName,
    required this.weekdayName,
  });

  final DateTime initialMonth;
  final List<dynamic> tasks;
  final DateTime today;
  final String Function(Map<String, dynamic> item) titleForItem;
  final List<Map<String, dynamic>> Function(DateTime date) tasksForDate;
  final String Function(int month) monthName;
  final String Function(int weekday) weekdayName;

  @override
  State<_ClockCalendarDialog> createState() => _ClockCalendarDialogState();
}

class _ClockCalendarDialogState extends State<_ClockCalendarDialog> {
  late DateTime visibleMonth;

  @override
  void initState() {
    super.initState();
    visibleMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingEmptyDays = firstDay.weekday - 1;
    final totalCells = leadingEmptyDays + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Dialog(
      backgroundColor: const Color(0xFF10131D),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Poprzedni rok',
                    icon: const Icon(Icons.keyboard_double_arrow_left),
                    color: Colors.white70,
                    onPressed: () => _changeMonth(years: -1),
                  ),
                  IconButton(
                    tooltip: 'Poprzedni miesiąc',
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.white,
                    onPressed: () => _changeMonth(months: -1),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.monthName(visibleMonth.month)} ${visibleMonth.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Następny miesiąc',
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.white,
                    onPressed: () => _changeMonth(months: 1),
                  ),
                  IconButton(
                    tooltip: 'Następny rok',
                    icon: const Icon(Icons.keyboard_double_arrow_right),
                    color: Colors.white70,
                    onPressed: () => _changeMonth(years: 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  _WeekdayLabel('Pn'),
                  _WeekdayLabel('Wt'),
                  _WeekdayLabel('Śr'),
                  _WeekdayLabel('Cz'),
                  _WeekdayLabel('Pt'),
                  _WeekdayLabel('So'),
                  _WeekdayLabel('Nd'),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rowCount * 7,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - leadingEmptyDays + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final date = DateTime(
                    visibleMonth.year,
                    visibleMonth.month,
                    dayNumber,
                  );
                  final tasks = widget.tasksForDate(date);

                  return _CalendarDayCell(
                    day: dayNumber,
                    isToday: _sameDate(date, widget.today),
                    hasTasks: tasks.isNotEmpty,
                    onTap: tasks.isEmpty ? null : () => _showDayTasks(date),
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zamknij'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeMonth({int months = 0, int years = 0}) {
    setState(() {
      visibleMonth = DateTime(
        visibleMonth.year + years,
        visibleMonth.month + months,
      );
    });
  }

  Future<void> _showDayTasks(DateTime date) async {
    final tasks = widget.tasksForDate(date);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${date.day} ${widget.monthName(date.month)} ${date.year}',
        ),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in tasks)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.titleForItem(item)),
                    subtitle: Text(item['time'] as String? ?? '08:00'),
                    leading: const Icon(Icons.event_available_rounded),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.hasTasks,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool hasTasks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hasTasks
              ? const Color(0xFFFF3B30).withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? const Color(0xFFB44CFF)
                : hasTasks
                    ? const Color(0x88FF3B30)
                    : Colors.white12,
            width: isToday ? 1.6 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: hasTasks ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight:
                    isToday || hasTasks ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            if (hasTasks)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClockPanel extends StatelessWidget {
  const _ClockPanel({
    required this.title,
    required this.child,
    this.action,
    this.actionBelowTitle = false,
    this.maxHeight = 190,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final bool actionBelowTitle;
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
          if (actionBelowTitle && action != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: action!,
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MyTasksList extends StatefulWidget {
  const _MyTasksList({
    required this.items,
    required this.now,
    required this.selectedIndexes,
    required this.onEditTask,
  });

  final List<dynamic> items;
  final DateTime now;
  final ValueNotifier<Set<int>> selectedIndexes;
  final void Function(int index, Map<String, dynamic> item) onEditTask;

  @override
  State<_MyTasksList> createState() => _MyTasksListState();
}

class _MyTasksListState extends State<_MyTasksList> {
  static const double _estimatedTileHeight = 76;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNextTask());
  }

  @override
  void didUpdateWidget(covariant _MyTasksList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNextTask());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _sortedTaskEntries();
    final nextPosition = _nextTaskPosition(entries);

    return ValueListenableBuilder<Set<int>>(
      valueListenable: widget.selectedIndexes,
      builder: (context, selected, _) {
        final allIndexes = entries.map((entry) => entry.originalIndex).toSet();
        final allSelected =
            allIndexes.isNotEmpty && allIndexes.every(selected.contains);

        return ListView.builder(
          controller: _controller,
          padding: EdgeInsets.zero,
          itemCount: entries.length + 1,
          itemBuilder: (context, position) {
            if (position == 0) {
              return _SelectAllTasksTile(
                selected: allSelected,
                onChanged: (value) {
                  widget.selectedIndexes.value =
                      value == true ? allIndexes : <int>{};
                },
              );
            }

            final entry = entries[position - 1];

            return _MyTaskTile(
              item: entry.item,
              isNextTask: position - 1 == nextPosition,
              selectedIndexes: widget.selectedIndexes,
              originalIndex: entry.originalIndex,
              onTap: () => widget.onEditTask(entry.originalIndex, entry.item),
            );
          },
        );
      },
    );
  }

  List<_TaskEntry> _sortedTaskEntries() {
    final entries = <_TaskEntry>[];

    for (var index = 0; index < widget.items.length; index++) {
      final raw = widget.items[index];
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);
      entries.add(
        _TaskEntry(
          originalIndex: index,
          item: item,
          minutes: _minutesFromTime(item['time'] as String? ?? '08:00'),
        ),
      );
    }

    entries.sort((a, b) {
      final timeCompare = a.minutes.compareTo(b.minutes);
      if (timeCompare != 0) {
        return timeCompare;
      }

      return a.originalIndex.compareTo(b.originalIndex);
    });

    return entries;
  }

  int _nextTaskPosition(List<_TaskEntry> entries) {
    if (entries.isEmpty) {
      return -1;
    }

    final nowMinutes = widget.now.hour * 60 + widget.now.minute;

    for (var index = 0; index < entries.length; index++) {
      if (entries[index].minutes >= nowMinutes) {
        return index;
      }
    }

    return 0;
  }

  void _scrollToNextTask() {
    if (!_controller.hasClients) {
      return;
    }

    final entries = _sortedTaskEntries();
    final nextPosition = _nextTaskPosition(entries);
    if (nextPosition < 0) {
      return;
    }

    final target = ((nextPosition + 1) * _estimatedTileHeight)
        .clamp(0.0, _controller.position.maxScrollExtent);

    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }
}

class _TaskEntry {
  const _TaskEntry({
    required this.originalIndex,
    required this.item,
    required this.minutes,
  });

  final int originalIndex;
  final Map<String, dynamic> item;
  final int minutes;
}

class _SelectAllTasksTile extends StatelessWidget {
  const _SelectAllTasksTile({
    required this.selected,
    required this.onChanged,
  });

  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66071020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            activeColor: const Color(0xFF7A5CFF),
            checkColor: Colors.white,
            side: const BorderSide(color: Colors.white70, width: 1.6),
            onChanged: onChanged,
          ),
          const Expanded(
            child: Text(
              'Zaznacz wszystko',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _minutesFromTime(String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

  return hour.clamp(0, 23) * 60 + minute.clamp(0, 59);
}

int? _positiveIntFromItem(Object? value) {
  final parsed = int.tryParse('$value');
  if (parsed == null || parsed < 1) {
    return null;
  }

  return parsed;
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
    required this.isNextTask,
    required this.selectedIndexes,
    required this.originalIndex,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final bool isNextTask;
  final ValueNotifier<Set<int>> selectedIndexes;
  final int originalIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = _taskTileImagePath(item);
    final title = _taskTitleFromItem(item);
    final day = item['day'] as String? ?? 'Dziś';
    final time = item['time'] as String? ?? '08:00';
    final amount = (item['amount'] as String? ?? '').trim();
    final subtitle = amount.isEmpty ? '$day • $time' : '$day • $time • $amount';

    return _ClockTileShell(
      leading: _LevelIcon(imagePath: imagePath),
      title: title,
      subtitle: subtitle,
      highlighted: isNextTask,
      trailing: ValueListenableBuilder<Set<int>>(
        valueListenable: selectedIndexes,
        builder: (context, selected, _) {
          final checked = selected.contains(originalIndex);

          return Checkbox(
            value: checked,
            activeColor: isNextTask ? Colors.white : const Color(0xFF7A5CFF),
            checkColor: isNextTask ? const Color(0xFFE02020) : Colors.white,
            side: BorderSide(
              color: isNextTask ? Colors.white : Colors.white70,
              width: 1.6,
            ),
            onChanged: (value) {
              final next = Set<int>.from(selected);
              if (value == true) {
                next.add(originalIndex);
              } else {
                next.remove(originalIndex);
              }
              selectedIndexes.value = next;
            },
          );
        },
      ),
      onTap: onTap,
    );
  }
}

String _taskTileImagePath(Map<String, dynamic> item) {
  final imagePath = item['imagePath'] as String? ?? '';
  final clockIconPath = item['clockIconPath'] as String?;

  if (clockIconPath == null || clockIconPath.contains('/clock_icons/')) {
    return clockIconPathForImagePath(imagePath);
  }

  return clockIconPath;
}

class _AddedGalleryTile extends StatelessWidget {
  const _AddedGalleryTile({
    required this.item,
    required this.hasProtocol,
    required this.onCreateProtocol,
    required this.selectedIndexes,
    required this.originalIndex,
  });

  final Map<String, dynamic> item;
  final bool hasProtocol;
  final VoidCallback? onCreateProtocol;
  final ValueNotifier<Set<int>> selectedIndexes;
  final int originalIndex;

  @override
  Widget build(BuildContext context) {
    final imagePath = item['imagePath'] as String? ?? '';

    return _ClockTileShell(
      leading: _LevelIcon(imagePath: levelImagePathForImagePath(imagePath)),
      title: clockTitleForImagePath(imagePath),
      subtitle: hasProtocol
          ? 'Możesz dodać harmonogram do zegara'
          : 'Możesz dodać zadanie do zegara',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Dodaj do zegara',
            icon: const Icon(Icons.add_alarm_rounded),
            color: const Color(0xFFB44CFF),
            disabledColor: Colors.white24,
            onPressed: onCreateProtocol,
          ),
          ValueListenableBuilder<Set<int>>(
            valueListenable: selectedIndexes,
            builder: (context, selected, _) {
              final checked = selected.contains(originalIndex);

              return Checkbox(
                value: checked,
                activeColor: const Color(0xFF7A5CFF),
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.white70, width: 1.6),
                onChanged: (value) {
                  final next = Set<int>.from(selected);
                  if (value == true) {
                    next.add(originalIndex);
                  } else {
                    next.remove(originalIndex);
                  }
                  selectedIndexes.value = next;
                },
              );
            },
          ),
        ],
      ),
      onTap: onCreateProtocol,
    );
  }
}

class _ClockTileShell extends StatelessWidget {
  const _ClockTileShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.cornerAction,
    this.onTap,
    this.highlighted = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget? cornerAction;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: highlighted
                  ? const Color(0xFFE02020).withValues(alpha: 0.88)
                  : const Color(0xAA071020),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted ? Colors.white : const Color(0x7700D0FF),
                width: highlighted ? 1.6 : 1,
              ),
              boxShadow: highlighted
                  ? const [
                      BoxShadow(
                        color: Color(0x99FF2A2A),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
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
          if (cornerAction != null)
            Positioned(
              top: -8,
              right: -4,
              child: Material(
                color: const Color(0xEE071020),
                shape: const CircleBorder(),
                child: cornerAction,
              ),
            ),
        ],
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
